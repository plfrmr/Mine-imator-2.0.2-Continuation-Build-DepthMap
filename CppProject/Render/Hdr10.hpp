#pragma once
// HDR10 output: SMPTE ST 2084 (PQ) transfer, Rec.2020 primaries.
// The renderer produces extended range, display gamma encoded Rec.709 colors (1.0 = SDR paper white, more for highlights).
// These helpers turn them into PQ-encoded 16-bit PNGs (with cICP/mDCv/cLLi chunks) and 10-bit 4:2:0 video frames.

#include "Asset/Surface.hpp"

#include <QBuffer>
#include <QFile>
#include <QImage>
#include <algorithm>
#include <cmath>
#include <thread>
#include <vector>

namespace CppProject
{
	namespace Hdr10
	{
		// Display gamma the SDR image is graded for (what the user sees on an sRGB monitor)
		constexpr float DisplayGamma = 2.2f;

		struct Settings
		{
			float paperWhite = 203.f;	// Nits of SDR white (1.0)
			float peak = 1000.f;		// Mastering display peak in nits
		};

		// Reads a surface as RGBA floats (8-bit surfaces are converted to 0-1).
		inline std::vector<float> ReadSurface(Surface* surf)
		{
			IntType w = surf->size.width(), h = surf->size.height();
			std::vector<float> rgba((size_t)w * h * 4);
			if (surf->frameBuffer->hdr)
				surf->frameBuffer->CopyData(true, (uchar*)rgba.data());
			else
			{
				std::vector<uchar> bytes((size_t)w * h * 4);
				surf->frameBuffer->CopyData(true, bytes.data());
				for (size_t i = 0; i < bytes.size(); i++)
					rgba[i] = bytes[i] / 255.f;
			}
			return rgba;
		}

		// Linear light (nits) to the PQ signal (0-1).
		inline float PQ(float nits)
		{
			const float m1 = 0.1593017578125f, m2 = 78.84375f, c1 = 0.8359375f, c2 = 18.8515625f, c3 = 18.6875f;
			float p = std::pow(std::clamp(nits / 10000.f, 0.f, 1.f), m1);
			return std::pow((c1 + c2 * p) / (1.f + c3 * p), m2);
		}

		// Extended range, gamma encoded Rec.709 color to linear Rec.2020 in nits (clipped to the peak).
		inline void ToNits(const float* rgb, const Settings& s, float out[3])
		{
			float l[3];
			for (int i = 0; i < 3; i++)
				l[i] = std::isfinite(rgb[i]) ? std::pow(std::max(rgb[i], 0.f), DisplayGamma) * s.paperWhite : 0.f;

			out[0] = 0.6274040f * l[0] + 0.3292820f * l[1] + 0.0433136f * l[2];
			out[1] = 0.0690970f * l[0] + 0.9195400f * l[1] + 0.0113612f * l[2];
			out[2] = 0.0163916f * l[0] + 0.0880132f * l[1] + 0.8955950f * l[2];
			for (int i = 0; i < 3; i++)
				out[i] = std::clamp(out[i], 0.f, s.peak);
		}

		// Runs func(y) for every row on all CPU cores.
		template<typename F> inline void ParallelRows(int height, F func)
		{
			int threads = std::max(1, std::min((int)std::thread::hardware_concurrency(), 32));
			std::vector<std::thread> pool;
			for (int t = 0; t < threads; t++)
				pool.emplace_back([=]() { for (int y = t; y < height; y += threads) func(y); });
			for (std::thread& th : pool)
				th.join();
		}

		// Converts RGBA floats to PQ encoded Rec.2020 (RGB 0-1, alpha kept). Returns the content light levels (MaxCLL, MaxFALL).
		inline void Encode(std::vector<float>& rgba, int w, int h, const Settings& s, float& maxCll, float& maxFall)
		{
			std::vector<float> rowMax(h, 0.f), rowSum(h, 0.f);
			ParallelRows(h, [&](int y)
			{
				for (int x = 0; x < w; x++)
				{
					float* p = &rgba[((size_t)y * w + x) * 4];
					float nits[3];
					ToNits(p, s, nits);
					float m = std::max(nits[0], std::max(nits[1], nits[2]));
					rowMax[y] = std::max(rowMax[y], m);
					rowSum[y] += m;
					for (int i = 0; i < 3; i++)
						p[i] = PQ(nits[i]);
				}
			});

			maxCll = 0.f;
			double sum = 0.0;
			for (int y = 0; y < h; y++)
			{
				maxCll = std::max(maxCll, rowMax[y]);
				sum += rowSum[y];
			}
			maxFall = (float)(sum / std::max(1, w * h));
		}

		inline uint32_t Crc32(const uchar* data, size_t len, uint32_t crc = 0)
		{
			static uint32_t table[256];
			static bool init = false;
			if (!init)
			{
				for (uint32_t n = 0; n < 256; n++)
				{
					uint32_t c = n;
					for (int k = 0; k < 8; k++)
						c = (c & 1) ? 0xEDB88320u ^ (c >> 1) : c >> 1;
					table[n] = c;
				}
				init = true;
			}
			crc = ~crc;
			for (size_t i = 0; i < len; i++)
				crc = table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
			return ~crc;
		}

		inline void PutU16(QByteArray& b, uint32_t v) { b.append((char)(v >> 8)); b.append((char)v); }
		inline void PutU32(QByteArray& b, uint32_t v) { PutU16(b, v >> 16); PutU16(b, v & 0xFFFF); }

		inline QByteArray PngChunk(const char* type, const QByteArray& data)
		{
			QByteArray chunk;
			PutU32(chunk, data.size());
			QByteArray body = QByteArray(type, 4) + data;
			chunk += body;
			PutU32(chunk, Crc32((const uchar*)body.constData(), body.size()));
			return chunk;
		}

		// Saves a surface as an HDR10 PNG (16-bit, PQ, Rec.2020 tagged with cICP), returns whether successful.
		inline bool SavePng(Surface* surf, const QString& filename, const Settings& s)
		{
			int w = surf->size.width(), h = surf->size.height();
			std::vector<float> rgba = ReadSurface(surf);

			float lo[4] = { 1e9f, 1e9f, 1e9f, 1e9f }, hi[4] = { -1e9f, -1e9f, -1e9f, -1e9f };
			for (size_t i = 0; i < rgba.size(); i++)
			{
				lo[i % 4] = std::min(lo[i % 4], rgba[i]);
				hi[i % 4] = std::max(hi[i % 4], rgba[i]);
			}
			Printer::Line(QString("HDR10 image %1x%2 (%3): R %4..%5 G %6..%7 B %8..%9 A %10..%11")
				.arg(w).arg(h).arg(surf->frameBuffer->hdr ? "float" : "8-bit")
				.arg(lo[0]).arg(hi[0]).arg(lo[1]).arg(hi[1]).arg(lo[2]).arg(hi[2]).arg(lo[3]).arg(hi[3]));

			float maxCll, maxFall;
			Encode(rgba, w, h, s, maxCll, maxFall);

			QImage img(w, h, QImage::Format_RGBA64);
			for (int y = 0; y < h; y++)
			{
				quint16* line = (quint16*)img.scanLine(y);
				for (int x = 0; x < w * 4; x++)
					line[x] = (quint16)std::lround(std::clamp(rgba[(size_t)y * w * 4 + x], 0.f, 1.f) * 65535.f);
			}

			QByteArray png;
			QBuffer buffer(&png);
			buffer.open(QIODevice::WriteOnly);
			if (!img.save(&buffer, "PNG"))
				return false;

			// cICP: Rec.2020 primaries (9), PQ transfer (16), RGB (0), full range (1)
			QByteArray cicp;
			cicp.append((char)9); cicp.append((char)16); cicp.append((char)0); cicp.append((char)1);

			// mDCv: mastering display (Rec.2020 red, green, blue and D65 white in 0.00002 units, luminance in 0.0001 nits)
			QByteArray mdcv;
			PutU16(mdcv, 35400); PutU16(mdcv, 14600);
			PutU16(mdcv, 8500); PutU16(mdcv, 39850);
			PutU16(mdcv, 6550); PutU16(mdcv, 2300);
			PutU16(mdcv, 15635); PutU16(mdcv, 16450);
			PutU32(mdcv, (uint32_t)(s.peak * 10000.f));
			PutU32(mdcv, 50);

			// cLLi: content light levels in 0.0001 nits
			QByteArray clli;
			PutU32(clli, (uint32_t)(std::max(1.f, maxCll) * 10000.f));
			PutU32(clli, (uint32_t)(std::max(1.f, maxFall) * 10000.f));

			// Insert after IHDR (8 byte signature + 25 byte IHDR chunk)
			const int ihdrEnd = 8 + 25;
			if (png.size() < ihdrEnd)
				return false;
			png.insert(ihdrEnd, PngChunk("cICP", cicp) + PngChunk("mDCv", mdcv) + PngChunk("cLLi", clli));

			QFile file(filename);
			if (!file.open(QIODevice::WriteOnly))
				return false;
			file.write(png);
			return true;
		}

		// Fills 10-bit 4:2:0 planes (16-bit little endian words, limited range Rec.2020 non-constant luminance) from a surface.
		inline void ToYuv420p10(Surface* surf, const Settings& s, uint8_t* const planes[3], const int linesize[3])
		{
			int w = surf->size.width(), h = surf->size.height();
			std::vector<float> rgba = ReadSurface(surf);
			float maxCll, maxFall;
			Encode(rgba, w, h, s, maxCll, maxFall);

			auto px = [&](int x, int y) { return &rgba[((size_t)std::min(y, h - 1) * w + std::min(x, w - 1)) * 4]; };

			// Luma
			ParallelRows(h, [&](int y)
			{
				uint16_t* line = (uint16_t*)(planes[0] + (size_t)y * linesize[0]);
				for (int x = 0; x < w; x++)
				{
					const float* p = px(x, y);
					float luma = 0.2627f * p[0] + 0.6780f * p[1] + 0.0593f * p[2];
					line[x] = (uint16_t)std::clamp((int)std::lround(64.f + 876.f * luma), 0, 1023);
				}
			});

			// Chroma (averaged over 2x2 pixels)
			int cw = (w + 1) / 2, ch = (h + 1) / 2;
			ParallelRows(ch, [&](int cy)
			{
				uint16_t* cbLine = (uint16_t*)(planes[1] + (size_t)cy * linesize[1]);
				uint16_t* crLine = (uint16_t*)(planes[2] + (size_t)cy * linesize[2]);
				for (int cx = 0; cx < cw; cx++)
				{
					float r = 0.f, g = 0.f, b = 0.f;
					for (int i = 0; i < 4; i++)
					{
						const float* p = px(cx * 2 + (i & 1), cy * 2 + (i >> 1));
						r += p[0]; g += p[1]; b += p[2];
					}
					r *= 0.25f; g *= 0.25f; b *= 0.25f;
					float luma = 0.2627f * r + 0.6780f * g + 0.0593f * b;
					float cb = (b - luma) / 1.8814f, cr = (r - luma) / 1.4746f;
					cbLine[cx] = (uint16_t)std::clamp((int)std::lround(512.f + 896.f * cb), 0, 1023);
					crLine[cx] = (uint16_t)std::clamp((int)std::lround(512.f + 896.f * cr), 0, 1023);
				}
			});
		}
	}
}
