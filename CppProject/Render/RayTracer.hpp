#pragma once

#include "Common.hpp"
#include "Render/Matrix.hpp"

// Hardware ray tracing (DXR 1.1 inline ray tracing) for the Raytraced view mode and exports.
//
// The D3D11 renderer still rasterizes the G-buffer (color, depth, normals, materials). While the color pass is drawn,
// every submitted mesh is captured with its world matrix, texture and material. Each mesh gets a bottom level acceleration
// structure (BLAS, cached until the mesh is freed) on a separate D3D12 device on the same graphics card, and the captured
// objects form the top level acceleration structure (TLAS). A compute shader then traces rays against it on the RT cores
// (shadows from the sun and lights, multi-bounce colored light, emissive blocks, sky light, reflections) and writes a
// light buffer and a specular buffer that the regular composite uses. The G-buffer and outputs are shared between the two
// devices as shared textures, synchronized with a shared fence.

namespace CppProject
{
	struct VertexBuffer;

	namespace RayTracer
	{
		// Returns whether hardware ray tracing is available (initializes D3D12 on first call).
		BoolType IsSupported();

		// A short description of the ray tracing status for the interface.
		QString GetStatus();

		// Scene capture: records every vertex buffer submitted between Begin and End.
		void CaptureBegin();
		void CaptureEnd();
		void CapturePause(BoolType pause);
		void CaptureShadows(BoolType castShadows); // Whether the next captured objects block light
		BoolType IsCapturing();
		void CaptureAdd(VertexBuffer* buffer);

		// Whether the scene must be captured again (no scene yet, or its geometry was freed).
		BoolType NeedsCapture();

		// Capture for exporting the scene as a Minecraft model (see ModelExport.cpp): every drawn mesh with its transform,
		// texture and tint. Works on its own, also without hardware ray tracing.
		struct ExportDraw
		{
			void* mesh;			// Mesh<>*
			Matrix world;
			IntType texId;
			float uvRect[4];	// Texture page location: uv = rect.xy + frac(uv) * rect.zw
			float blendColor[4];
		};
		void ExportCaptureBegin();
		void ExportCaptureEnd();
		void ExportCapturePause(BoolType pause); // Skips what's drawn meanwhile (ground, clouds)
		const QVector<ExportDraw>& ExportCaptured();

		// Called when a mesh frees its GPU buffers, drops its cached geometry.
		void ForgetMesh(uint64_t meshUid);

		// Camera (inverse view & projection, column major like the engine) and depth range of the G-buffer.
		void SetCamera(const Matrix& viewInv, const Matrix& projInv, RealType zNear, RealType zFar, RealType camX, RealType camY, RealType camZ);

		// Lights: type 0 = sun, 1 = point, 2 = spot.
		void ClearLights();
		void AddLight(IntType type, RealType x, RealType y, RealType z, RealType dx, RealType dy, RealType dz,
					  RealType r, RealType g, RealType b, RealType strength, RealType range, RealType fadeSize,
					  RealType size, RealType spotFov, RealType spotSharpness, RealType specular, BoolType castShadows);

		// Named numeric settings (bounces, strengths, colors...), see RayTracer.cpp for the list.
		void SetParam(QString name, RealType value);

		// Traces the scene for the given G-buffer surfaces and writes light/specular output surfaces.
		// Returns false if tracing isn't possible (the caller should use the fallback).
		BoolType Trace(IntType depthSurf, IntType normalSurf, IntType diffuseSurf, IntType materialSurf, IntType emissiveSurf,
					   IntType lightOutSurf, IntType specOutSurf, IntType sampleIndex);

		// Developer debug view from Data/rtdebug.txt (0 = off), returns true when it changed since the last call.
		BoolType DebugChanged();

		// Releases all ray tracing resources.
		void Free();
	}
}
