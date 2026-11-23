// Export of the scene (or the selected objects) as a Minecraft Java Edition JSON model with its texture.
//
// The scene is drawn once while every submitted mesh is captured with its transform, texture and tint (see
// RayTracer::ExportCaptureBegin). Each drawn quad becomes a flat element with one face, so any shape works, not just cubes.
// Faces that aren't aligned with the axes get an element rotation: the free x/y/z rotation of newer Minecraft versions, or
// the classic single axis 22.5/45 degree rotation (other angles are then snapped flat). The pixels each face shows are baked
// into one texture atlas, so colors, tints and texture sheets come out right, and the model works from any resource pack.

#include "Generated/Scripts.hpp"

#include "Render/GraphicsApiHandler.hpp"
#include "Render/Mesh.hpp"
#include "Render/RayTracer.hpp"
#include "Render/Texture.hpp"

#include <QDir>
#include <QFile>
#include <QImage>
#include <QtMath>
#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

#if API_D3D11
#include <d3d11_4.h>
#endif

namespace CppProject
{
	namespace ModelExport
	{
		using V3 = std::array<double, 3>;

		static V3 Add(const V3& a, const V3& b) { return { a[0] + b[0], a[1] + b[1], a[2] + b[2] }; }
		static V3 Sub(const V3& a, const V3& b) { return { a[0] - b[0], a[1] - b[1], a[2] - b[2] }; }
		static V3 Mul(const V3& a, double s) { return { a[0] * s, a[1] * s, a[2] * s }; }
		static double Dot(const V3& a, const V3& b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
		static V3 Cross(const V3& a, const V3& b) { return { a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] }; }
		static double Len(const V3& a) { return std::sqrt(Dot(a, a)); }
		static V3 Norm(const V3& a) { double l = Len(a); return l > 1e-12 ? Mul(a, 1.0 / l) : V3{ 0, 0, 0 }; }

		// Mine-imator (x, y, z up) to Minecraft model space (x, y up, z south), the inverse of value_get_point3D
		static V3 ToMc(const V3& p) { return { p[0], p[2], p[1] }; }

		struct Tri
		{
			V3 p[3];
			double uv[3][2];
		};

		struct Quad
		{
			V3 p[4];			// Rectangle corners in order around it (Minecraft space)
			Tri tri[2];			// The drawn triangles inside it, for the texture
			int numTri = 0;
			bool masked = false;// The triangles don't fill the rectangle (bend joints are tapered), the rest is see-through
			V3 normal;			// Side that is visible
			double color[4];	// Vertex color * tint
			IntType texId;
			float uvRect[4];
		};

		struct Face
		{
			// JSON
			V3 from, to;
			QString dir;
			bool rotated = false, legacy = false;
			V3 origin;
			double angles[3] = { 0, 0, 0 };	// Free rotation x, y, z
			QString legacyAxis;
			double legacyAngle = 0;

			// Texture
			const Quad* quad;
			V3 corner, uAxis, vAxis;	// Point(s, t) = corner + uAxis * s + vAxis * t, s/t = 0-1 over the face
			int w = 1, h = 1, atlasX = 0, atlasY = 0;
		};

		struct TexData
		{
			QImage image;
			bool valid = false;
		};

#if API_D3D11
		template <typename T> static void Release(T*& p) { if (p) { p->Release(); p = nullptr; } }

		static bool ReadBuffer(ID3D11Buffer* buf, std::vector<uint8_t>& out)
		{
			if (!buf)
				return false;
			D3D11_BUFFER_DESC desc;
			buf->GetDesc(&desc);
			D3D11_BUFFER_DESC sd = {};
			sd.ByteWidth = desc.ByteWidth;
			sd.Usage = D3D11_USAGE_STAGING;
			sd.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
			ID3D11Buffer* staging = nullptr;
			if (FAILED(D3DDevice->CreateBuffer(&sd, nullptr, &staging)))
				return false;
			D3DContext->CopyResource(staging, buf);
			D3D11_MAPPED_SUBRESOURCE mapped;
			if (FAILED(D3DContext->Map(staging, 0, D3D11_MAP_READ, 0, &mapped)))
			{
				Release(staging);
				return false;
			}
			out.assign((uint8_t*)mapped.pData, (uint8_t*)mapped.pData + desc.ByteWidth);
			D3DContext->Unmap(staging, 0);
			Release(staging);
			return true;
		}

		static bool ReadTexture(IntType texId, QImage& image)
		{
			ID3D11ShaderResourceView* srv = Texture::d3dIdSRVMap.value(texId, nullptr);
			if (!srv)
				return false;
			ID3D11Resource* res = nullptr;
			srv->GetResource(&res);
			ID3D11Texture2D* tex = nullptr;
			res->QueryInterface(IID_PPV_ARGS(&tex));
			Release(res);
			if (!tex)
				return false;

			D3D11_TEXTURE2D_DESC desc;
			tex->GetDesc(&desc);
			bool isFloat = (desc.Format == DXGI_FORMAT_R32G32B32A32_FLOAT);
			if (desc.Format != DXGI_FORMAT_R8G8B8A8_UNORM && !isFloat)
			{
				Release(tex);
				return false;
			}

			D3D11_TEXTURE2D_DESC sd = desc;
			sd.MipLevels = 1;
			sd.ArraySize = 1;
			sd.Usage = D3D11_USAGE_STAGING;
			sd.BindFlags = 0;
			sd.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
			sd.MiscFlags = 0;
			ID3D11Texture2D* staging = nullptr;
			if (FAILED(D3DDevice->CreateTexture2D(&sd, nullptr, &staging)))
			{
				Release(tex);
				return false;
			}
			D3DContext->CopySubresourceRegion(staging, 0, 0, 0, 0, tex, 0, nullptr);
			Release(tex);

			D3D11_MAPPED_SUBRESOURCE mapped;
			if (FAILED(D3DContext->Map(staging, 0, D3D11_MAP_READ, 0, &mapped)))
			{
				Release(staging);
				return false;
			}

			image = QImage(desc.Width, desc.Height, QImage::Format_RGBA8888);
			for (UINT y = 0; y < desc.Height; y++)
			{
				uchar* dst = image.scanLine(y);
				const uchar* src = (const uchar*)mapped.pData + (size_t)y * mapped.RowPitch;
				if (!isFloat)
					memcpy(dst, src, desc.Width * 4);
				else
				{
					const float* f = (const float*)src;
					for (UINT x = 0; x < desc.Width * 4; x++)
						dst[x] = (uchar)std::lround(std::clamp(f[x], 0.f, 1.f) * 255.f);
				}
			}
			D3DContext->Unmap(staging, 0);
			Release(staging);
			return true;
		}
#endif

		// Rotation direction of matrix_build around each axis compared to the right-hand rule (+1 = same)
		static double AxisSign(int axis)
		{
			Matrix m = matrix_build(0, 0, 0, axis == 0 ? 90 : 0, axis == 1 ? 90 : 0, axis == 2 ? 90 : 0, 1, 1, 1);
			auto apply = [&](const V3& p) -> V3 {
				return { m.m[0] * p[0] + m.m[4] * p[1] + m.m[8] * p[2],
						 m.m[1] * p[0] + m.m[5] * p[1] + m.m[9] * p[2],
						 m.m[2] * p[0] + m.m[6] * p[1] + m.m[10] * p[2] };
			};
			// Right-hand rule: X turns Y into Z, Y turns Z into X, Z turns X into Y
			if (axis == 0) return apply({ 0, 1, 0 })[2] > 0 ? 1.0 : -1.0;
			if (axis == 1) return apply({ 0, 0, 1 })[0] > 0 ? 1.0 : -1.0;
			return apply({ 1, 0, 0 })[1] > 0 ? 1.0 : -1.0;
		}

		// Standard right-handed rotation matrices (column vectors), angle in radians
		using M3 = std::array<std::array<double, 3>, 3>;
		static M3 MulM(const M3& a, const M3& b)
		{
			M3 r{};
			for (int i = 0; i < 3; i++)
				for (int j = 0; j < 3; j++)
					for (int k = 0; k < 3; k++)
						r[i][j] += a[i][k] * b[k][j];
			return r;
		}
		static M3 RotX(double a) { double c = std::cos(a), s = std::sin(a); return M3{ { { 1, 0, 0 }, { 0, c, -s }, { 0, s, c } } }; }
		static M3 RotY(double a) { double c = std::cos(a), s = std::sin(a); return M3{ { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } } }; }
		static M3 RotZ(double a) { double c = std::cos(a), s = std::sin(a); return M3{ { { c, -s, 0 }, { s, c, 0 }, { 0, 0, 1 } } }; }

		// Element rotation angles (Minecraft x, y, z in degrees) for a rotation given in Minecraft space. Minecraft
		// (BlockElementRotation, 1.21.11+) builds it as Matrix4f.rotationZYX(z, y, x) = Rz * Ry * Rx, so a vertex turns
		// around x first, then y, then z. In Mine-imator space (block_load_model_file) that is X, then Z (Minecraft y),
		// then Y (Minecraft z).
		static bool DecomposeRotation(const M3& rMc, double angles[3])
		{
			static const double sx = AxisSign(0), sy = AxisSign(1), sz = AxisSign(2);

			// To Mine-imator space (swap y and z on both sides)
			M3 r;
			const int sw[3] = { 0, 2, 1 };
			for (int i = 0; i < 3; i++)
				for (int j = 0; j < 3; j++)
					r[i][j] = rMc[sw[i]][sw[j]];

			// r = RotY(c) * RotZ(b) * RotX(a)
			double a, b, c;
			b = std::asin(std::clamp(r[1][0], -1.0, 1.0));
			if (std::abs(std::cos(b)) > 1e-6)
			{
				a = std::atan2(-r[1][2], r[1][1]);
				c = std::atan2(-r[2][0], r[0][0]);
			}
			else
			{
				a = 0;
				c = std::atan2(r[0][2], r[2][2]);
			}

			// Check
			M3 check = MulM(RotY(c), MulM(RotZ(b), RotX(a)));
			double err = 0;
			for (int i = 0; i < 3; i++)
				for (int j = 0; j < 3; j++)
					err = std::max(err, std::abs(check[i][j] - r[i][j]));

			angles[0] = qRadiansToDegrees(a) * sx;	// Minecraft x = Mine-imator X
			angles[1] = qRadiansToDegrees(b) * sz;	// Minecraft y = Mine-imator Z
			angles[2] = qRadiansToDegrees(c) * sy;	// Minecraft z = Mine-imator Y
			for (int i = 0; i < 3; i++)
				if (std::abs(angles[i]) < 1e-6)
					angles[i] = 0;
			return err < 1e-4;
		}

		static QString Num(double v)
		{
			v = std::round(v * 10000.0) / 10000.0;
			if (v == 0)
				v = 0; // No "-0"
			return QString::number(v, 'g', 8);
		}

		static QString Vec(const V3& v)
		{
			return "[" + Num(v[0]) + ", " + Num(v[1]) + ", " + Num(v[2]) + "]";
		}

		// Texture coordinate of a point on (or projected onto) a triangle's plane, and its smallest barycentric weight
		// (negative outside the triangle)
		static double TriUV(const Tri& t, const V3& p, double& u, double& v)
		{
			V3 e1 = Sub(t.p[1], t.p[0]), e2 = Sub(t.p[2], t.p[0]), d = Sub(p, t.p[0]);
			double d11 = Dot(e1, e1), d12 = Dot(e1, e2), d22 = Dot(e2, e2), dp1 = Dot(d, e1), dp2 = Dot(d, e2);
			double den = d11 * d22 - d12 * d12;
			if (std::abs(den) < 1e-18)
			{
				u = t.uv[0][0];
				v = t.uv[0][1];
				return -1e9;
			}
			double b1 = (d22 * dp1 - d12 * dp2) / den, b2 = (d11 * dp2 - d12 * dp1) / den, b0 = 1.0 - b1 - b2;
			u = b0 * t.uv[0][0] + b1 * t.uv[1][0] + b2 * t.uv[2][0];
			v = b0 * t.uv[0][1] + b1 * t.uv[1][1] + b2 * t.uv[2][1];
			return std::min({ b0, b1, b2 });
		}

		// Texture coordinate of a point on a quad, from the drawn triangle it lies in (or the closest one). Returns
		// whether the point is on a drawn triangle.
		static bool QuadUV(const Quad& q, const V3& p, double& u, double& v)
		{
			double best = -1e18;
			for (int i = 0; i < q.numTri; i++)
			{
				double tu, tv, w = TriUV(q.tri[i], p, tu, tv);
				if (w > best)
				{
					best = w;
					u = tu;
					v = tv;
				}
			}
			return best >= -1e-6;
		}

		static double Frac(double x)
		{
			return x - std::floor(x);
		}

		static V3 FacePoint(const Face& f, double s, double t)
		{
			return Add(f.corner, Add(Mul(f.uAxis, s), Mul(f.vAxis, t)));
		}

		// Whether any part of a face pixel is covered by the drawn triangles (tests its center and corners, so faces
		// meeting at a slanted edge overlap a little instead of leaving gaps)
		static bool PixelCovered(const Face& f, int x, int y)
		{
			if (!f.quad->masked)
				return true;
			const double pts[5][2] = { { 0.5, 0.5 }, { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } };
			for (const auto& o : pts)
			{
				double u, v;
				if (QuadUV(*f.quad, FacePoint(f, (x + o[0]) / f.w, (y + o[1]) / f.h), u, v))
					return true;
			}
			return false;
		}

		// Source texture pixel coordinates of a face point
		static void TexelAt(const Face& f, const TexData& tex, double s, double t, int& px, int& py)
		{
			double u, v;
			QuadUV(*f.quad, FacePoint(f, s, t), u, v);
			double tu = f.quad->uvRect[0] + Frac(u) * f.quad->uvRect[2];
			double tv = f.quad->uvRect[1] + Frac(v) * f.quad->uvRect[3];
			px = std::clamp((int)std::floor(tu * tex.image.width()), 0, tex.image.width() - 1);
			py = std::clamp((int)std::floor(tv * tex.image.height()), 0, tex.image.height() - 1);
		}

		// Size of a face's texture: as many pixels as the source texture has across it
		static void FaceSize(Face& f, const TexData& tex)
		{
			if (!tex.valid)
			{
				f.w = f.h = 1;
				return;
			}
			auto pixels = [&](double s0, double t0, double s1, double t1) {
				double u0, v0, u1, v1;
				QuadUV(*f.quad, Add(f.corner, Add(Mul(f.uAxis, s0), Mul(f.vAxis, t0))), u0, v0);
				QuadUV(*f.quad, Add(f.corner, Add(Mul(f.uAxis, s1), Mul(f.vAxis, t1))), u1, v1);
				double dx = (u1 - u0) * f.quad->uvRect[2] * tex.image.width();
				double dy = (v1 - v0) * f.quad->uvRect[3] * tex.image.height();
				return std::sqrt(dx * dx + dy * dy);
			};
			f.w = std::clamp((int)std::lround(pixels(0, 0.5, 1, 0.5)), 1, 256);
			f.h = std::clamp((int)std::lround(pixels(0.5, 0, 0.5, 1)), 1, 256);
		}

		// Texture axes of each face direction in Minecraft (u to the right, v down as seen from outside)
		static void FaceAxes(const QString& dir, V3& u, V3& v)
		{
			if (dir == "north") { u = { -1, 0, 0 }; v = { 0, -1, 0 }; }
			else if (dir == "south") { u = { 1, 0, 0 }; v = { 0, -1, 0 }; }
			else if (dir == "east") { u = { 0, 0, -1 }; v = { 0, -1, 0 }; }
			else if (dir == "west") { u = { 0, 0, 1 }; v = { 0, -1, 0 }; }
			else if (dir == "up") { u = { 1, 0, 0 }; v = { 0, 0, 1 }; }
			else { u = { 1, 0, 0 }; v = { 0, 0, -1 }; }
		}

		// Axis aligned flat element covering the given corners, facing dir
		static void SetAligned(Face& f, const V3 corners[4], int axis, double plane, const QString& dir)
		{
			V3 mn = corners[0], mx = corners[0];
			for (int i = 1; i < 4; i++)
				for (int k = 0; k < 3; k++)
				{
					mn[k] = std::min(mn[k], corners[i][k]);
					mx[k] = std::max(mx[k], corners[i][k]);
				}
			mn[axis] = mx[axis] = plane;
			f.from = mn;
			f.to = mx;
			f.dir = dir;

			V3 ua, va;
			FaceAxes(dir, ua, va);
			V3 size = Sub(mx, mn);
			f.corner = mn;
			f.corner[axis] = plane;
			for (int k = 0; k < 3; k++)
			{
				if (ua[k] < 0) f.corner[k] = mx[k];
				if (va[k] < 0) f.corner[k] = mx[k];
			}
			f.uAxis = { ua[0] * size[0], ua[1] * size[1], ua[2] * size[2] };
			f.vAxis = { va[0] * size[0], va[1] * size[1], va[2] * size[2] };
		}

		static QString AxisDir(int axis, double sign)
		{
			if (axis == 0) return sign > 0 ? "east" : "west";
			if (axis == 1) return sign > 0 ? "up" : "down";
			return sign > 0 ? "south" : "north";
		}
	}

	using namespace ModelExport;

	void model_capture_begin()
	{
		RayTracer::ExportCaptureBegin();
	}

	void model_capture_pause(BoolType pause)
	{
		GFX->SubmitBatch(); // Draws before the pause still count
		RayTracer::ExportCapturePause(pause);
	}

	void model_capture_end()
	{
		GFX->SubmitBatch(); // Draws still waiting in the batch are captured when submitted
		RayTracer::ExportCaptureEnd();
	}

	StringType model_export_json(StringType folderArg, StringType nameArg, StringType nsArg, RealType sizeBlocks, BoolType freeRotation, BoolType resourcePack)
	{
#if API_D3D11
		QString folder = (QString)folderArg, ns = ((QString)nsArg).toLower(), name;
		for (QChar c : ((QString)nameArg).toLower())
			name += (c.isLetterOrNumber() && c.unicode() < 128) || c == '_' || c == '-' || c == '.' ? c : QChar('_');
		if (name.isEmpty())
			name = "model";
		if (ns.isEmpty())
			ns = "mineimator";

		GFX->SubmitBatch();
		const QVector<RayTracer::ExportDraw>& draws = RayTracer::ExportCaptured();
		if (draws.isEmpty())
			return QString("error: nothing was drawn");

		// Collect the quads of every drawn mesh
		std::vector<Quad> quads;
		IntType skipped = 0;
		QMap<void*, std::pair<std::vector<uint8_t>, std::vector<uint8_t>>> meshData;
		const int stride = 36;

		for (const RayTracer::ExportDraw& draw : draws)
		{
			Mesh<>* mesh = (Mesh<>*)draw.mesh;
			if (!meshData.contains(draw.mesh))
			{
				std::pair<std::vector<uint8_t>, std::vector<uint8_t>> data;
				ReadBuffer(mesh->d3dVertexBuffer, data.first);
				ReadBuffer(mesh->d3dIndexBuffer, data.second);
				meshData.insert(draw.mesh, data);
			}
			const auto& data = meshData[draw.mesh];
			const std::vector<uint8_t>& vb = data.first;
			const uint32_t* ib = (const uint32_t*)data.second.data();
			IntType numIndices = std::min<IntType>(mesh->numIndices, (IntType)(data.second.size() / 4));
			IntType numVerts = (IntType)(vb.size() / stride);
			if (numIndices < 3 || numVerts == 0)
				continue;

			const RealType* m = draw.world.m;
			auto vertex = [&](uint32_t i, V3& pos, V3& nor, double uv[2], double col[4]) {
				const uint8_t* v = vb.data() + (size_t)i * stride;
				float p[3];
				memcpy(p, v, 12);
				uint32_t n, c;
				memcpy(&n, v + 12, 4);
				memcpy(&c, v + 16, 4);
				float t[2];
				memcpy(t, v + 20, 8);
				V3 lp = { p[0], p[1], p[2] };
				V3 ln = { (n & 0xFF) / 255.0 * 2 - 1, ((n >> 8) & 0xFF) / 255.0 * 2 - 1, ((n >> 16) & 0xFF) / 255.0 * 2 - 1 };
				V3 wp = { m[0] * lp[0] + m[4] * lp[1] + m[8] * lp[2] + m[12],
						  m[1] * lp[0] + m[5] * lp[1] + m[9] * lp[2] + m[13],
						  m[2] * lp[0] + m[6] * lp[1] + m[10] * lp[2] + m[14] };
				V3 wn = { m[0] * ln[0] + m[4] * ln[1] + m[8] * ln[2],
						  m[1] * ln[0] + m[5] * ln[1] + m[9] * ln[2],
						  m[2] * ln[0] + m[6] * ln[1] + m[10] * ln[2] };
				pos = ToMc(wp);
				nor = Norm(ToMc(wn));
				uv[0] = t[0];
				uv[1] = t[1];
				col[0] = (c & 0xFF) / 255.0;
				col[1] = ((c >> 8) & 0xFF) / 255.0;
				col[2] = ((c >> 16) & 0xFF) / 255.0;
				col[3] = ((c >> 24) & 0xFF) / 255.0;
			};

			// Reads triangle t, false if it's out of range or has no area
			struct SrcTri { V3 p[3], n[3]; double uv[3][2], col[3][4]; V3 geo; };
			auto readTri = [&](IntType t, SrcTri& s) {
				for (int k = 0; k < 3; k++)
				{
					uint32_t i = ib[t * 3 + k];
					if (i >= (uint32_t)numVerts)
						return false;
					vertex(i, s.p[k], s.n[k], s.uv[k], s.col[k]);
				}
				s.geo = Cross(Sub(s.p[1], s.p[0]), Sub(s.p[2], s.p[0]));
				return Len(s.geo) > 1e-9;
			};

			IntType numTris = numIndices / 3;
			for (IntType t = 0; t < numTris;)
			{
				SrcTri a, b;
				if (!readTri(t, a))
				{
					skipped++;
					t += 1;
					continue;
				}

				// Two triangles sharing an edge in the same plane form one face, any other triangle is a face of its own
				std::vector<V3> poly = { a.p[0], a.p[1], a.p[2] };
				std::vector<const SrcTri*> src = { &a };
				if (t + 1 < numTris && readTri(t + 1, b) && Dot(Norm(a.geo), Norm(b.geo)) > 0.999)
				{
					int extra = -1, shared = 0;
					for (int k = 0; k < 3; k++)
					{
						bool found = false;
						for (int j = 0; j < 3; j++)
							if (Len(Sub(b.p[k], a.p[j])) < 1e-4)
								found = true;
						if (found)
							shared++;
						else
							extra = k;
					}

					if (shared == 2 && extra >= 0)
					{
						// Insert the extra vertex into a's cycle at the shared edge
						int insertAfter = -1;
						for (int e = 0; e < 3; e++)
						{
							bool s1 = false, s2 = false;
							for (int k = 0; k < 3; k++)
							{
								if (Len(Sub(b.p[k], a.p[e])) < 1e-4) s1 = true;
								if (Len(Sub(b.p[k], a.p[(e + 1) % 3])) < 1e-4) s2 = true;
							}
							if (s1 && s2)
								insertAfter = e;
						}
						if (insertAfter >= 0)
						{
							poly.insert(poly.begin() + insertAfter + 1, b.p[extra]);
							src.push_back(&b);
						}
					}
				}
				t += (IntType)src.size();

				// Plane of the face, visible on the side its vertex normals point to
				V3 geoSum = { 0, 0, 0 }, nsum = { 0, 0, 0 };
				double col[4] = { 0, 0, 0, 0 }, polyArea = 0;
				int numCol = 0;
				for (const SrcTri* s : src)
				{
					geoSum = Add(geoSum, s->geo);
					polyArea += Len(s->geo) / 2;
					for (int k = 0; k < 3; k++)
					{
						nsum = Add(nsum, s->n[k]);
						for (int j = 0; j < 4; j++)
							col[j] += s->col[k][j];
						numCol++;
					}
				}
				V3 n = Norm(geoSum);
				if (Dot(n, nsum) < 0)
					n = Mul(n, -1);
				V3 c = { 0, 0, 0 };
				for (const V3& p : poly)
					c = Add(c, Mul(p, 1.0 / poly.size()));

				// Smallest rectangle around it, lined up with one of its edges (Mine-imator geometry is mostly
				// rectangles, which fit exactly; tapered bend joints get see-through corners)
				double bestArea = 1e18, ra0 = 0, ra1 = 0, rb0 = 0, rb1 = 0;
				V3 rx, ry;
				for (size_t e = 0; e < poly.size(); e++)
				{
					V3 edge = Sub(poly[(e + 1) % poly.size()], poly[e]);
					V3 x = Norm(Sub(edge, Mul(n, Dot(edge, n))));
					if (Len(x) < 0.5)
						continue;
					V3 y = Cross(n, x);
					double a0 = 1e18, a1 = -1e18, b0 = 1e18, b1 = -1e18;
					for (const V3& p : poly)
					{
						V3 d = Sub(p, c);
						a0 = std::min(a0, Dot(d, x));
						a1 = std::max(a1, Dot(d, x));
						b0 = std::min(b0, Dot(d, y));
						b1 = std::max(b1, Dot(d, y));
					}
					double area = (a1 - a0) * (b1 - b0);
					if (area < bestArea - 1e-9)
					{
						bestArea = area;
						ra0 = a0; ra1 = a1; rb0 = b0; rb1 = b1;
						rx = x;
						ry = y;
					}
				}
				if (bestArea > 1e17 || bestArea < 1e-10)
				{
					skipped += (IntType)src.size();
					continue;
				}

				Quad q;
				q.p[0] = Add(c, Add(Mul(rx, ra0), Mul(ry, rb0)));
				q.p[1] = Add(c, Add(Mul(rx, ra1), Mul(ry, rb0)));
				q.p[2] = Add(c, Add(Mul(rx, ra1), Mul(ry, rb1)));
				q.p[3] = Add(c, Add(Mul(rx, ra0), Mul(ry, rb1)));
				q.normal = n;
				q.masked = (polyArea < bestArea * 0.995);
				q.numTri = (int)src.size();
				for (int i = 0; i < q.numTri; i++)
					for (int k = 0; k < 3; k++)
					{
						q.tri[i].p[k] = src[i]->p[k];
						q.tri[i].uv[k][0] = src[i]->uv[k][0];
						q.tri[i].uv[k][1] = src[i]->uv[k][1];
					}
				for (int j = 0; j < 4; j++)
					q.color[j] = col[j] / numCol * draw.blendColor[j];
				q.texId = draw.texId;
				memcpy(q.uvRect, draw.uvRect, sizeof(q.uvRect));
				if (q.color[3] > 0.001)
					quads.push_back(q);
			}
		}

		if (quads.empty())
			return QString("error: no faces to export");

		// Fit the model: centered on x/z, standing on y = 0 (or -16 when taller than 2 blocks), the largest side
		// "sizeBlocks" blocks long (at most 3, the size limit of Minecraft models)
		V3 mn = quads[0].p[0], mx = quads[0].p[0];
		for (const Quad& q : quads)
			for (int i = 0; i < 4; i++)
				for (int k = 0; k < 3; k++)
				{
					mn[k] = std::min(mn[k], q.p[i][k]);
					mx[k] = std::max(mx[k], q.p[i][k]);
				}
		V3 size = Sub(mx, mn);
		double largest = std::max({ size[0], size[1], size[2], 1e-6 });
		double scale = std::clamp(sizeBlocks, 0.05, 3.0) * 16.0 / largest;
		double yBase = (size[1] * scale > 32.0) ? -16.0 : 0.0;
		V3 center = { (mn[0] + mx[0]) / 2, mn[1], (mn[2] + mx[2]) / 2 };
		auto fit = [&](const V3& p) { return Add(Mul(Sub(p, center), scale), V3{ 8.0, yBase, 8.0 }); };
		for (Quad& q : quads)
		{
			for (int i = 0; i < 4; i++)
				q.p[i] = fit(q.p[i]);
			for (int i = 0; i < q.numTri; i++)
				for (int k = 0; k < 3; k++)
					q.tri[i].p[k] = fit(q.tri[i].p[k]);
		}

		// Faces
		std::vector<Face> faces;
		IntType snapped = 0;
		faces.reserve(quads.size());
		for (const Quad& q : quads)
		{
			Face f;
			f.quad = &q;
			V3 e0 = Sub(q.p[1], q.p[0]), e3 = Sub(q.p[3], q.p[0]);
			V3 n = q.normal;
			int axis = 0;
			for (int k = 1; k < 3; k++)
				if (std::abs(n[k]) > std::abs(n[axis]))
					axis = k;
			V3 c = Mul(Add(Add(q.p[0], q.p[1]), Add(q.p[2], q.p[3])), 0.25);

			// Edges along the axes too?
			auto alignedVec = [](const V3& v) {
				V3 d = Norm(v);
				return std::max({ std::abs(d[0]), std::abs(d[1]), std::abs(d[2]) }) > 0.9999;
			};
			bool aligned = std::abs(n[axis]) > 0.9999 && alignedVec(e0) && alignedVec(e3);

			if (!aligned)
			{
				// Rotated face: try every face direction of the element and every way of laying its texture on the quad,
				// and keep the smallest rotation (with classic rotations: one that's a single 22.5/45 degree turn).
				// The element's face texture axes (ud, vd) are turned onto the quad's edges (tu, tv), its normal onto n.
				V3 xl = Norm(e0), yl = Norm(Cross(n, xl));
				xl = Cross(yl, n);
				const V3 inPlane[4] = { xl, Mul(xl, -1), yl, Mul(yl, -1) };
				const char* dirs[6] = { "north", "south", "east", "west", "up", "down" };
				const V3 dirNormal[6] = { { 0, 0, -1 }, { 0, 0, 1 }, { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 } };

				bool found = false;
				double bestScore = 1e9, bestAng[3] = { 0, 0, 0 }, bestLegacy = 0;
				int bestWhich = 0;
				QString bestDir;
				V3 bestTu, bestTv, bestUd, bestVd;

				for (int d = 0; d < 6; d++)
				{
					V3 ud, vd;
					FaceAxes(dirs[d], ud, vd);
					const V3& nd = dirNormal[d];
					for (const V3& tu : inPlane)
					{
						V3 tv = Cross(tu, n); // Same handedness as ud x vd = -nd

						M3 r{};
						for (int i = 0; i < 3; i++)
							for (int j = 0; j < 3; j++)
								r[i][j] = tu[i] * ud[j] + tv[i] * vd[j] + n[i] * nd[j];

						double ang[3];
						if (!DecomposeRotation(r, ang))
							continue;

						int nonzero = 0, which = 0;
						for (int k = 0; k < 3; k++)
							if (std::abs(ang[k]) > 0.01)
							{
								nonzero++;
								which = k;
							}
						double legacy = std::round(ang[which] / 22.5) * 22.5;
						bool legacyOk = nonzero <= 1 && std::abs(legacy - ang[which]) < 0.5 && std::abs(legacy) <= 45.0;
						if (!freeRotation && !legacyOk)
							continue;

						double score = std::max({ std::abs(ang[0]), std::abs(ang[1]), std::abs(ang[2]) }) + nonzero * 0.001;
						if (score < bestScore)
						{
							found = true;
							bestScore = score;
							for (int k = 0; k < 3; k++)
								bestAng[k] = ang[k];
							bestWhich = which;
							bestLegacy = legacy;
							bestDir = dirs[d];
							bestTu = tu;
							bestTv = tv;
							bestUd = ud;
							bestVd = vd;
						}
					}
				}

				if (found)
				{
					double a0 = 1e9, a1 = -1e9, b0 = 1e9, b1 = -1e9;
					for (int i = 0; i < 4; i++)
					{
						V3 d = Sub(q.p[i], c);
						a0 = std::min(a0, Dot(d, bestTu));
						a1 = std::max(a1, Dot(d, bestTu));
						b0 = std::min(b0, Dot(d, bestTv));
						b1 = std::max(b1, Dot(d, bestTv));
					}

					// The element before turning: the face lies through the origin, along the face's texture axes
					V3 p0 = Add(c, Add(Mul(bestUd, a0), Mul(bestVd, b0)));
					V3 p1 = Add(c, Add(Mul(bestUd, a1), Mul(bestVd, b1)));
					for (int k = 0; k < 3; k++)
					{
						f.from[k] = std::min(p0[k], p1[k]);
						f.to[k] = std::max(p0[k], p1[k]);
					}
					f.dir = bestDir;
					f.origin = c;
					f.rotated = (bestScore > 0.01);
					if (freeRotation)
						for (int k = 0; k < 3; k++)
							f.angles[k] = bestAng[k];
					else
					{
						f.legacy = true;
						f.legacyAxis = QString("xyz")[bestWhich];
						f.legacyAngle = bestLegacy;
					}

					// Texture axes after turning
					f.corner = Add(c, Add(Mul(bestTu, a0), Mul(bestTv, b0)));
					f.uAxis = Mul(bestTu, a1 - a0);
					f.vAxis = Mul(bestTv, b1 - b0);
					faces.push_back(f);
					continue;
				}

				snapped++;
			}

			// Axis aligned (or snapped flat onto the nearest axis)
			SetAligned(f, q.p, axis, c[axis], AxisDir(axis, n[axis]));
			faces.push_back(f);
		}

		// Read the textures and size each face's part of the atlas
		QMap<IntType, TexData> textures;
		for (Face& f : faces)
		{
			IntType id = f.quad->texId;
			if (!textures.contains(id))
			{
				TexData td;
				td.valid = id > 0 && ReadTexture(id, td.image) && !td.image.isNull();
				textures.insert(id, td);
			}
			FaceSize(f, textures[id]);
		}

		// Pack the faces into a square atlas (1 pixel border per face against bleeding), shrinking them if needed
		int atlas = 16;
		for (int attempt = 0; attempt < 8; attempt++)
		{
			std::vector<int> order(faces.size());
			for (size_t i = 0; i < order.size(); i++)
				order[i] = (int)i;
			std::sort(order.begin(), order.end(), [&](int a, int b) { return faces[a].h > faces[b].h; });

			double area = 0;
			for (const Face& f : faces)
				area += (double)(f.w + 2) * (f.h + 2);
			atlas = 16;
			while ((double)atlas * atlas < area * 1.15)
				atlas *= 2;

			bool fits = false;
			while (atlas <= 8192 && !fits)
			{
				int x = 0, y = 0, rowH = 0;
				fits = true;
				for (int i : order)
				{
					Face& f = faces[i];
					if (f.w + 2 > atlas)
					{
						fits = false;
						break;
					}
					if (x + f.w + 2 > atlas)
					{
						x = 0;
						y += rowH;
						rowH = 0;
					}
					f.atlasX = x + 1;
					f.atlasY = y + 1;
					x += f.w + 2;
					rowH = std::max(rowH, f.h + 2);
				}
				if (fits && y + rowH > atlas)
					fits = false;
				if (!fits)
					atlas *= 2;
			}

			if (fits)
				break;

			// Too big: halve every face
			for (Face& f : faces)
			{
				f.w = std::max(1, f.w / 2);
				f.h = std::max(1, f.h / 2);
			}
			atlas = 0;
		}
		if (atlas == 0 || atlas > 8192)
			return QString("error: the texture would be too large, select fewer objects");

		// Bake the texture
		QImage image(atlas, atlas, QImage::Format_RGBA8888);
		image.fill(Qt::transparent);
		for (const Face& f : faces)
		{
			const TexData& tex = textures[f.quad->texId];
			for (int y = -1; y <= f.h; y++)
				for (int x = -1; x <= f.w; x++)
				{
					// Border pixels repeat the face's edge
					int cx = std::clamp(x, 0, f.w - 1), cy = std::clamp(y, 0, f.h - 1);
					double col[4] = { 1, 1, 1, 1 };
					if (!PixelCovered(f, cx, cy))
						col[3] = 0;
					else if (tex.valid)
					{
						int px, py;
						TexelAt(f, tex, (cx + 0.5) / f.w, (cy + 0.5) / f.h, px, py);
						const uchar* s = tex.image.constScanLine(py) + px * 4;
						for (int k = 0; k < 4; k++)
							col[k] = s[k] / 255.0;
					}
					uchar* d = image.scanLine(f.atlasY + y) + (f.atlasX + x) * 4;
					for (int k = 0; k < 4; k++)
						d[k] = (uchar)std::lround(std::clamp(col[k] * f.quad->color[k], 0.0, 1.0) * 255.0);
				}
		}

		// Model JSON
		QString texRef = ns + ":block/" + name;
		QString json;
		json += "{\n";
		json += "\t\"credit\": \"Made with Mine-imator\",\n";
		json += "\t\"parent\": \"minecraft:block/block\",\n";
		json += "\t\"textures\": {\n\t\t\"0\": \"" + texRef + "\",\n\t\t\"particle\": \"" + texRef + "\"\n\t},\n";
		json += "\t\"elements\": [\n";
		for (size_t i = 0; i < faces.size(); i++)
		{
			const Face& f = faces[i];
			double u1 = f.atlasX * 16.0 / atlas, v1 = f.atlasY * 16.0 / atlas;
			double u2 = (f.atlasX + f.w) * 16.0 / atlas, v2 = (f.atlasY + f.h) * 16.0 / atlas;

			json += "\t\t{\"from\": " + Vec(f.from) + ", \"to\": " + Vec(f.to) + ", ";
			if (f.rotated)
			{
				if (f.legacy)
					json += "\"rotation\": {\"origin\": " + Vec(f.origin) + ", \"axis\": \"" + f.legacyAxis + "\", \"angle\": " + Num(f.legacyAngle) + "}, ";
				else
					json += "\"rotation\": {\"origin\": " + Vec(f.origin) + ", \"x\": " + Num(f.angles[0]) + ", \"y\": " + Num(f.angles[1]) + ", \"z\": " + Num(f.angles[2]) + "}, ";
			}
			json += "\"faces\": {\"" + f.dir + "\": {\"uv\": [" + Num(u1) + ", " + Num(v1) + ", " + Num(u2) + ", " + Num(v2) + "], \"texture\": \"#0\"}}}";
			json += (i + 1 < faces.size()) ? ",\n" : "\n";
		}
		json += "\t]\n}\n";

		// Files
		QString modelFile, textureFile;
		if (resourcePack)
		{
			QString root = folder + "/" + name;
			QDir().mkpath(root + "/assets/" + ns + "/models/block");
			QDir().mkpath(root + "/assets/" + ns + "/textures/block");
			QDir().mkpath(root + "/assets/" + ns + "/items");
			modelFile = root + "/assets/" + ns + "/models/block/" + name + ".json";
			textureFile = root + "/assets/" + ns + "/textures/block/" + name + ".png";

			QFile mcmeta(root + "/pack.mcmeta");
			if (mcmeta.open(QIODevice::WriteOnly))
				mcmeta.write(("{\n\t\"pack\": {\n\t\t\"description\": \"" + name + " (made with Mine-imator)\",\n"
							  "\t\t\"pack_format\": 84,\n\t\t\"min_format\": 84,\n\t\t\"max_format\": 999\n\t}\n}\n").toUtf8());

			QFile item(root + "/assets/" + ns + "/items/" + name + ".json");
			if (item.open(QIODevice::WriteOnly))
				item.write(("{\n\t\"model\": {\n\t\t\"type\": \"minecraft:model\",\n\t\t\"model\": \"" + ns + ":block/" + name + "\"\n\t}\n}\n").toUtf8());
		}
		else
		{
			modelFile = folder + "/" + name + ".json";
			textureFile = folder + "/" + name + ".png";
		}

		QFile file(modelFile);
		if (!file.open(QIODevice::WriteOnly))
			return QString("error: could not write " + modelFile);
		file.write(json.toUtf8());
		file.close();

		if (!image.save(textureFile, "PNG"))
			return QString("error: could not write " + textureFile);

		return QString("%1 faces, %2x%2 texture, %3 rotations snapped flat, %4 triangles skipped, %5")
			.arg(faces.size()).arg(atlas).arg(snapped).arg(skipped).arg(resourcePack ? folder + "/" + name : modelFile);
#else
		Q_UNUSED(folderArg); Q_UNUSED(nameArg); Q_UNUSED(nsArg); Q_UNUSED(sizeBlocks); Q_UNUSED(freeRotation); Q_UNUSED(resourcePack);
		return QString("error: model export needs Direct3D (Windows)");
#endif
	}
}
