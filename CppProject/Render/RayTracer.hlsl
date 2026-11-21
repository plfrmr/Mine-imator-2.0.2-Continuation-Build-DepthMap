// Mine-imator hardware ray tracing (DXR 1.1 inline ray tracing, shader model 6.5)
// Compiled at build time by DXC into RayTracerCS.h, see CMakeLists.txt and RayTracer.cpp.
//
// Inputs are the rasterized G-buffer (what the camera sees directly) and the scene's acceleration structure.
// Outputs, in the same units as the regular renderer:
//   u0 light: the light hitting each pixel (multiplied by the surface color in the composite), from the sun and lights
//             with ray traced shadows, bounced light (global illumination), glowing blocks, sky light and ambient light.
//   u1 specular: ray traced reflections and specular highlights (added on top in the composite).

#define PI 3.14159265

#define FLAG_ALPHA_CUTOUT	1
#define FLAG_INDIRECT		2
#define FLAG_REFLECTIONS	4
#define FLAG_SPECULAR		8
#define FLAG_BOUNCE_LIGHTS	16
#define FLAG_SHADOWS		32
#define FLAG_TINTED_SHADOWS	64

#define LIGHT_SUN	0
#define LIGHT_POINT	1
#define LIGHT_SPOT	2

#define VERTEX_STRIDE 36

// Instance mask bit of objects that cast shadows
#define MASK_SHADOWS 0x02

cbuffer Constants : register(b0)
{
	column_major float4x4 uViewInv;
	column_major float4x4 uProjInv;
	float4 uCamPos;		// xyz = camera position
	float4 uDepth;		// near, far, normal buffer scale, gamma
	uint4 uSize;		// width, height, sample index, flags
	uint4 uCounts;		// number of lights, bounces, reflection bounces, unused
	float4 uSky;		// rgb = sky color, a = sky light strength
	float4 uAmbient;	// rgb = ambient color, a = ambient strength
	float4 uStrengths;	// bounce light strength, emissive strength, reflection strength, roughness cutoff
	float4 uRay;		// max ray distance, ray offset, sun softness (radians), light softness
	float4 uMisc;		// alpha cutout threshold, specular highlight strength, debug view, parallax self-shadowing (1/0)
	float4 uJitter;		// xy = TAA jitter of the G-buffer in normalized device coordinates
	float4 uColor;		// bounce color saturation, glass tint strength, default emissive, unused
	float4 uPBR;		// normal map strength, normal maps enabled (1/0), texture AO strength, parallax depth (0 = off)
};

struct Light
{
	float4 posType;			// xyz = position, w = type
	float4 dirSpecular;		// xyz = direction (sun: towards the sun, spot: where it points), w = specular strength
	float4 colorStrength;	// rgb = color, a = strength
	float4 params;			// range, fade size, size, tan(half spot angle)
	float4 params2;			// spot sharpness, casts shadows (1/0), unused...
};

struct InstanceData
{
	uint meshIndex;
	uint texIndex;
	uint flags;
	float emissive;
	float4 uvRect;
	float4 blendColor;
	float metallic;
	float roughness;
	uint matTexIndex;		// Material map (roughness/metal/emission), NO_TEXTURE if none
	uint normalTexIndex;	// Normal map, NO_TEXTURE if none
	float4 matUvRect;
	float4 normalUvRect;
	uint matFormat;			// 0 = none, 1 = SEUS, 2 = LabPBR
	float2 parallaxTile;	// Tile size of the block sheet in UV for parallax, 0 = not a block sheet
	uint pad2;
	float2 parallaxTexel;	// Size of a height map texel in UV
	uint pad3, pad4;
};

#define NO_TEXTURE 0xFFFFFFFF
#define MATERIAL_SEUS 1
#define MATERIAL_LABPBR 2

// G-buffer
Texture2D<float4> gDepth : register(t0);
Texture2D<float4> gNormal : register(t1);
Texture2D<float4> gDiffuse : register(t2);
Texture2D<float4> gMaterial : register(t3);
Texture2D<float4> gEmissive : register(t4);

// Scene
RaytracingAccelerationStructure gScene : register(t5);
StructuredBuffer<InstanceData> gInstances : register(t6);
StructuredBuffer<Light> gLights : register(t7);
ByteAddressBuffer gMeshBuffers[] : register(t0, space1); // 2 * meshIndex = vertices, 2 * meshIndex + 1 = indices
Texture2D<float4> gTextures[] : register(t0, space2);

SamplerState gSampler : register(s0);

// Output
RWTexture2D<float4> gOutLight : register(u0);
RWTexture2D<float4> gOutSpecular : register(u1);

// ----------------------------------------------------------------------------------------------------------------------
// Random numbers (PCG hash)

uint PcgNext(inout uint state)
{
	state = state * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float Rand(inout uint state)
{
	return (PcgNext(state) >> 8) * (1.0 / 16777216.0);
}

void MakeBasis(float3 n, out float3 t, out float3 b)
{
	float3 up = (abs(n.z) < 0.999) ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
	t = normalize(cross(up, n));
	b = cross(n, t);
}

float3 SampleCosineHemisphere(float3 n, inout uint seed)
{
	float r1 = Rand(seed), r2 = Rand(seed);
	float phi = 2.0 * PI * r1;
	float r = sqrt(r2);
	float3 t, b;
	MakeBasis(n, t, b);
	return normalize(t * (cos(phi) * r) + b * (sin(phi) * r) + n * sqrt(max(0.0, 1.0 - r2)));
}

float3 SampleCone(float3 dir, float angle, inout uint seed)
{
	if (angle <= 0.0)
		return dir;
	float cosMax = cos(angle);
	float cosT = lerp(cosMax, 1.0, Rand(seed));
	float sinT = sqrt(max(0.0, 1.0 - cosT * cosT));
	float phi = 2.0 * PI * Rand(seed);
	float3 t, b;
	MakeBasis(dir, t, b);
	return normalize(t * (cos(phi) * sinT) + b * (sin(phi) * sinT) + dir * cosT);
}

float3 SampleSphere(inout uint seed)
{
	float z = Rand(seed) * 2.0 - 1.0;
	float phi = 2.0 * PI * Rand(seed);
	float r = sqrt(max(0.0, 1.0 - z * z));
	return float3(r * cos(phi), r * sin(phi), z) * pow(Rand(seed), 1.0 / 3.0);
}

// GGX half vector sample (same as the screen-space ray tracer)
float3 SampleGGX(float3 n, float roughness, inout uint seed)
{
	float a = roughness * roughness;
	float r1 = Rand(seed), r2 = Rand(seed);
	float phi = 2.0 * PI * r1;
	float cosTheta = sqrt((1.0 - r2) / (1.0 + (a * a - 1.0) * r2));
	float sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));
	float3 t, b;
	MakeBasis(n, t, b);
	return normalize(t * (cos(phi) * sinTheta) + b * (sin(phi) * sinTheta) + n * cosTheta);
}

// ----------------------------------------------------------------------------------------------------------------------
// G-buffer decoding (matches the GLSL shaders)

float UnpackValue(float4 c)
{
	return c.r + c.g / 255.0 + c.b / (255.0 * 255.0);
}

float TransformDepth(float depth)
{
	float n = uDepth.x, f = uDepth.y;
	return (f - (n * f) / (depth * (f - n) + n)) / (f - n);
}

float3 ViewPosFromDepth(float2 uv, float depth)
{
	float4 pos = mul(uProjInv, float4(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, TransformDepth(depth), 1.0));
	return pos.xyz / pos.w;
}

float3 UnpackNormal(float4 c)
{
	return (c.rgb / uDepth.z) * 2.0 - 1.0;
}

// World position of a G-buffer pixel, valid = false for the background
float3 WorldPosAt(int2 p, out bool valid)
{
	p = clamp(p, int2(0, 0), int2(uSize.xy) - 1);
	float4 depthData = gDepth[p];
	float depth = UnpackValue(depthData);
	valid = (depthData.a >= 0.001 && depth <= 0.999);
	float2 uv = (float2(p) + 0.5) / float2(uSize.xy);
	return mul(uViewInv, float4(ViewPosFromDepth(uv, depth), 1.0)).xyz;
}

// Surface normal from the positions of neighboring pixels. The G-buffer normals are stored in a space that depends on
// each object's rotation, so they can't be turned back into world space. Minecraft geometry is made of flat faces,
// so the geometric normal is exact. At edges the neighbor on the same surface (closest in position) is used.
float3 GeometricNormal(int2 p, float3 pos)
{
	bool v0, v1, v2, v3;
	float3 r = WorldPosAt(p + int2(1, 0), v0);
	float3 l = WorldPosAt(p - int2(1, 0), v1);
	float3 d = WorldPosAt(p + int2(0, 1), v2);
	float3 u = WorldPosAt(p - int2(0, 1), v3);

	float3 dx = (v0 && (!v1 || length(r - pos) < length(pos - l))) ? r - pos : pos - l;
	float3 dy = (v2 && (!v3 || length(d - pos) < length(pos - u))) ? d - pos : pos - u;

	float3 n = cross(dy, dx);
	if (dot(n, n) < 1e-12)
		return normalize(uCamPos.xyz - pos);
	return normalize(n);
}

float3 ToLinear(float3 c)
{
	return pow(max(c, 0.0), uDepth.w);
}

// ----------------------------------------------------------------------------------------------------------------------
// Scene hit data

// Parallax occlusion mapping state of a surface (see ParallaxUV)
struct Parallax
{
	uint tex;			// Normal map holding the height in its alpha, NO_TEXTURE = no parallax
	float4 uvRect;
	float2 tile;		// Tile size of the block sheet in UV
	float2 texel;		// Size of a height map texel in UV
	float2 uv;			// Where the view ray hit the height map
	float depth;		// How deep the hit is, 0-1 of the parallax depth
	float2 side;		// Side of the texel column that was hit, in texels (0 = its top)
	float3 gradU, gradV;	// How the texture coordinate changes in world space: uv += (dot(d, gradU), dot(d, gradV))
	float3 N;			// Face normal
};

struct Surface
{
	float3 pos;
	float3 normal;
	float3 albedo;	// Linear
	float alpha;
	float emissive;
	float ao;		// Texture ambient occlusion (LabPBR normal map blue channel), 1 = none
	float3x3 objectToWorld;
	Parallax pom;
};

uint3 LoadIndices(uint meshIndex, uint primIndex)
{
	return gMeshBuffers[NonUniformResourceIndex(meshIndex * 2 + 1)].Load3(primIndex * 12);
}

float3 UnpackVertexNormal(uint packed)
{
	return float3(packed & 0xFF, (packed >> 8) & 0xFF, (packed >> 16) & 0xFF) / 255.0 * 2.0 - 1.0;
}

float4 UnpackVertexColor(uint packed)
{
	return float4(packed & 0xFF, (packed >> 8) & 0xFF, (packed >> 16) & 0xFF, (packed >> 24) & 0xFF) / 255.0;
}

float2 InterpolateUV(uint meshIndex, uint3 idx, float2 bary)
{
	ByteAddressBuffer vb = gMeshBuffers[NonUniformResourceIndex(meshIndex * 2)];
	float2 uv0 = asfloat(vb.Load2(idx.x * VERTEX_STRIDE + 20));
	float2 uv1 = asfloat(vb.Load2(idx.y * VERTEX_STRIDE + 20));
	float2 uv2 = asfloat(vb.Load2(idx.z * VERTEX_STRIDE + 20));
	return uv0 + (uv1 - uv0) * bary.x + (uv2 - uv0) * bary.y;
}

float4 SampleTexture(uint index, float4 uvRect, float2 uv, float4 fallback)
{
	if (index == NO_TEXTURE)
		return fallback;
	float2 texUv = uvRect.xy + frac(uv) * uvRect.zw;
	return gTextures[NonUniformResourceIndex(index)].SampleLevel(gSampler, texUv, 0);
}

float4 SampleInstanceTexture(InstanceData inst, float2 uv)
{
	return SampleTexture(inst.texIndex, inst.uvRect, uv, float4(1.0, 1.0, 1.0, 1.0));
}

// ----------------------------------------------------------------------------------------------------------------------
// Parallax occlusion mapping (same as the rasterizer): the height is in the normal map's alpha (LabPBR/SEUS, 1 = surface,
// 0 = deepest). Block textures share one sheet, so the ray march wraps around inside the block's own tile.

Parallax NoParallax()
{
	Parallax p = (Parallax)0;
	p.tex = NO_TEXTURE;
	return p;
}

float ParallaxHeight(Parallax p, float2 uv)
{
	float h = SampleTexture(p.tex, p.uvRect, uv, float4(0.5, 0.5, 1.0, 1.0)).a;
	return (h < 0.01) ? 1.0 : h; // 0 = no normal map
}

float2 WrapParallaxTile(float2 uv, float2 tileMin, float2 tile)
{
	float2 m = uv - tileMin;
	return tileMin + clamp(m - tile * floor(m / tile), 0.0, tile * 0.9999);
}

// Depth (0-1 of the parallax depth) of the texel column at a texel position of the tile
float ParallaxTexelDepth(Parallax p, float2 cell, float2 tileMin)
{
	return 1.0 - ParallaxHeight(p, WrapParallaxTile(tileMin + (cell + 0.5) * p.texel, tileMin, p.tile));
}

// Texels moved per unit of depth (0-1 of the parallax depth) when following a world direction into or out of the surface
float2 ParallaxTexelDir(Parallax p, float3 dir)
{
	float2 t = float2(dot(dir, p.gradU), dot(dir, p.gradV)) / max(dot(dir, p.N), 0.05) * (uPBR.w * 16.0) / p.texel;
	t.x = (abs(t.x) < 0.00001) ? 0.00001 : t.x;
	t.y = (abs(t.y) < 0.00001) ? 0.00001 : t.y;
	return t;
}

// Moves the texture coordinate to where the view ray hits the height map. Every texel is a column of its own height:
// the ray steps from texel to texel and hits the top or a side of a column. viewDir = direction towards the viewer.
float2 ParallaxUV(inout Parallax p, float2 uv, float3 viewDir)
{
	p.uv = uv;
	p.depth = 0.0;
	p.side = float2(0.0, 0.0);
	if (dot(viewDir, p.N) <= 0.0)
	{
		p.tex = NO_TEXTURE;
		return uv;
	}

	float2 tileMin = floor(uv / p.tile) * p.tile;
	float2 pos = (uv - tileMin) / p.texel;
	float2 dir = -ParallaxTexelDir(p, viewDir);
	float2 stepDir = float2(dir.x > 0.0 ? 1.0 : -1.0, dir.y > 0.0 ? 1.0 : -1.0);
	float2 cell = floor(pos);
	float2 tDelta = abs(1.0 / dir);
	float2 tMax = (cell + max(stepDir, 0.0) - pos) / dir;
	float2 side = float2(0.0, 0.0);
	float t = 0.0;

	for (int i = 0; i < 128; i++)
	{
		float cellDepth = ParallaxTexelDepth(p, cell, tileMin);

		// Entered this column below its top: hit its side
		if (t >= cellDepth)
		{
			p.side = side;
			break;
		}

		// Hits the top inside this texel
		float tExit = min(min(tMax.x, tMax.y), 1.0);
		if (cellDepth <= tExit)
		{
			t = cellDepth;
			break;
		}

		// Reached the bottom
		if (tExit >= 1.0)
		{
			t = 1.0;
			break;
		}

		// Next texel
		if (tMax.x < tMax.y)
		{
			cell.x += stepDir.x;
			t = tMax.x;
			tMax.x += tDelta.x;
			side = float2(-stepDir.x, 0.0);
		}
		else
		{
			cell.y += stepDir.y;
			t = tMax.y;
			tMax.y += tDelta.y;
			side = float2(0.0, -stepDir.y);
		}
	}

	p.depth = t;
	float2 hitPos = clamp(pos + dir * t, cell + 0.001, cell + 0.999);
	p.uv = WrapParallaxTile(tileMin + hitPos * p.texel, tileMin, p.tile);
	return p.uv;
}

// Self-shadowing: 1 = lit, 0 = a texel column between the parallax hit and the light blocks it (world direction L)
float ParallaxShadow(Parallax p, float3 L)
{
	if (p.tex == NO_TEXTURE || p.depth <= 0.0 || uMisc.w < 0.5 || dot(L, p.N) <= 0.0)
		return 1.0;

	float2 tileMin = floor(p.uv / p.tile) * p.tile;
	float2 pos = (p.uv - tileMin) / p.texel;
	float2 dir = ParallaxTexelDir(p, L);
	float2 stepDir = float2(dir.x > 0.0 ? 1.0 : -1.0, dir.y > 0.0 ? 1.0 : -1.0);
	float2 cell = floor(pos);
	float2 tDelta = abs(1.0 / dir);
	float2 tMax = (cell + max(stepDir, 0.0) - pos) / dir;
	float shadow = 0.0;

	for (int i = 0; i < 64; i++)
	{
		// Leave the current texel, stop when the ray is back above the surface
		float t;
		if (tMax.x < tMax.y)
		{
			cell.x += stepDir.x;
			t = tMax.x;
			tMax.x += tDelta.x;
		}
		else
		{
			cell.y += stepDir.y;
			t = tMax.y;
			tMax.y += tDelta.y;
		}

		if (t >= p.depth)
			break;

		// A column whose top is above the ray blocks the light
		shadow = max(shadow, saturate(((p.depth - t) - ParallaxTexelDepth(p, cell, tileMin)) * 30.0));
	}

	return 1.0 - shadow;
}

// Color and alpha of a candidate triangle, for cutout textures (leaves, glass...)
float4 CandidateColor(uint instanceId, uint primIndex, float2 bary)
{
	InstanceData inst = gInstances[instanceId];
	uint3 idx = LoadIndices(inst.meshIndex, primIndex);
	ByteAddressBuffer vb = gMeshBuffers[NonUniformResourceIndex(inst.meshIndex * 2)];
	float4 c0 = UnpackVertexColor(vb.Load(idx.x * VERTEX_STRIDE + 16));
	return SampleInstanceTexture(inst, InterpolateUV(inst.meshIndex, idx, bary)) * c0 * inst.blendColor;
}

float CandidateAlpha(uint instanceId, uint primIndex, float2 bary)
{
	return CandidateColor(instanceId, primIndex, bary).a;
}

Surface FetchSurface(uint instanceId, uint primIndex, float2 bary, float3x4 objectToWorld, float3 pos, float3 rayDir)
{
	InstanceData inst = gInstances[instanceId];
	uint3 idx = LoadIndices(inst.meshIndex, primIndex);
	ByteAddressBuffer vb = gMeshBuffers[NonUniformResourceIndex(inst.meshIndex * 2)];

	uint3 n = uint3(vb.Load(idx.x * VERTEX_STRIDE + 12), vb.Load(idx.y * VERTEX_STRIDE + 12), vb.Load(idx.z * VERTEX_STRIDE + 12));
	uint3 c = uint3(vb.Load(idx.x * VERTEX_STRIDE + 16), vb.Load(idx.y * VERTEX_STRIDE + 16), vb.Load(idx.z * VERTEX_STRIDE + 16));
	uint3 d = uint3(vb.Load(idx.x * VERTEX_STRIDE + 28), vb.Load(idx.y * VERTEX_STRIDE + 28), vb.Load(idx.z * VERTEX_STRIDE + 28));
	float3 w = float3(1.0 - bary.x - bary.y, bary.x, bary.y);

	float3x3 o2w = (float3x3)objectToWorld;
	float3 normal = UnpackVertexNormal(n.x) * w.x + UnpackVertexNormal(n.y) * w.y + UnpackVertexNormal(n.z) * w.z;
	normal = normalize(mul(o2w, normal));
	bool flipped = (dot(normal, rayDir) > 0.0);
	if (flipped) // Two-sided
		normal = -normal;

	float2 uv = InterpolateUV(inst.meshIndex, idx, bary);
	float4 color = UnpackVertexColor(c.x) * w.x + UnpackVertexColor(c.y) * w.y + UnpackVertexColor(c.z) * w.z;
	float vertexEmissive = (((d.x >> 8) & 0xFF) * w.x + ((d.y >> 8) & 0xFF) * w.y + ((d.z >> 8) & 0xFF) * w.z) / 255.0;

	// Tangent space of the normal and height maps
	float3 T = float3(0.0, 0.0, 0.0), B = float3(0.0, 0.0, 0.0);
	bool hasTangent = false;
	if (inst.normalTexIndex != NO_TEXTURE)
	{
		float3 tangent = mul(o2w, UnpackVertexNormal(vb.Load(idx.x * VERTEX_STRIDE + 32)));
		if (dot(tangent, tangent) > 0.01)
		{
			T = normalize(tangent - dot(tangent, normal) * normal);
			B = cross(T, flipped ? -normal : normal);
			hasTangent = true;
		}
	}

	// Parallax: every texture is sampled where the ray hits the height map (front faces of block sheets)
	Parallax pom = NoParallax();
	if (inst.normalTexIndex != NO_TEXTURE && !flipped && uPBR.w > 0.0 && inst.parallaxTile.x > 0.0 && inst.parallaxTile.y > 0.0 && inst.parallaxTexel.x > 0.0)
	{
		// UV gradients from the triangle's world space edges (works for any face orientation and mirrored textures)
		float3 p0 = mul(o2w, asfloat(vb.Load3(idx.x * VERTEX_STRIDE)));
		float3 e1 = mul(o2w, asfloat(vb.Load3(idx.y * VERTEX_STRIDE))) - p0;
		float3 e2 = mul(o2w, asfloat(vb.Load3(idx.z * VERTEX_STRIDE))) - p0;
		float2 uv0 = asfloat(vb.Load2(idx.x * VERTEX_STRIDE + 20));
		float2 d1 = asfloat(vb.Load2(idx.y * VERTEX_STRIDE + 20)) - uv0;
		float2 d2 = asfloat(vb.Load2(idx.z * VERTEX_STRIDE + 20)) - uv0;
		float3 fn = cross(e1, e2);
		float nn = max(dot(fn, fn), 1e-20);
		float3 c1 = cross(e2, fn), c2 = cross(fn, e1);

		pom.tex = inst.normalTexIndex;
		pom.uvRect = inst.normalUvRect;
		pom.tile = inst.parallaxTile;
		pom.texel = inst.parallaxTexel;
		pom.gradU = (d1.x * c1 + d2.x * c2) / nn;
		pom.gradV = (d1.y * c1 + d2.y * c2) / nn;
		pom.N = normal;
		uv = ParallaxUV(pom, uv, -rayDir);
	}

	float4 tex = SampleInstanceTexture(inst, uv);

	// Normal map (same decoding as the rasterizer)
	float ao = 1.0;
	if (inst.normalTexIndex != NO_TEXTURE && uPBR.y > 0.5)
	{
		float4 nt = SampleTexture(inst.normalTexIndex, inst.normalUvRect, uv, float4(0.5, 0.5, 1.0, 1.0));
		if (inst.matFormat == MATERIAL_LABPBR)
			ao = nt.b;

		if (nt.a >= 0.01 && hasTangent)
		{
			float2 nxy = nt.xy * 2.0 - 1.0;
			float nz = sqrt(max(0.0, 1.0 - dot(nxy, nxy)));
			nxy *= uPBR.x; // Strength scales the slopes, normalized below
			float3 mapped = normalize(T * nxy.x + B * -nxy.y + normal * nz);
			if (dot(mapped, normal) > 0.0)
				normal = mapped;
		}
	}

	// Parallax hit the side of a texel column: light it with the side's normal
	if (pom.tex != NO_TEXTURE && (pom.side.x != 0.0 || pom.side.y != 0.0))
		normal = normalize(pom.side.x * normalize(pom.gradU) + pom.side.y * normalize(pom.gradV));

	// Emission: material map (LabPBR alpha, SEUS blue) or the object/vertex value, scaled by Default emissive like the rasterizer
	float emissive = max(inst.emissive, vertexEmissive * uColor.z);
	if (inst.matTexIndex != NO_TEXTURE && inst.matFormat != 0)
	{
		float4 m = SampleTexture(inst.matTexIndex, inst.matUvRect, uv, float4(0.0, 0.0, 0.0, 1.0));
		if (inst.matFormat == MATERIAL_LABPBR)
			emissive = (m.a < 1.0 ? m.a / 0.9961 : 0.0) * uColor.z;
		else if (inst.matFormat == MATERIAL_SEUS)
			emissive = m.b * uColor.z;
	}

	Surface s;
	s.pos = pos;
	s.normal = normal;
	s.albedo = ToLinear(tex.rgb * color.rgb * inst.blendColor.rgb);
	s.alpha = tex.a * color.a * inst.blendColor.a;
	s.emissive = emissive;
	s.ao = ao;
	s.objectToWorld = o2w;
	s.pom = pom;
	return s;
}

// ----------------------------------------------------------------------------------------------------------------------
// Ray queries

RayDesc MakeRay(float3 origin, float3 dir, float tMax)
{
	RayDesc ray;
	ray.Origin = origin;
	ray.Direction = dir;
	ray.TMin = 0.0;
	ray.TMax = tMax;
	return ray;
}

uint BaseRayFlags()
{
	return (uSize.w & FLAG_ALPHA_CUTOUT) ? RAY_FLAG_NONE : RAY_FLAG_FORCE_OPAQUE;
}

// Returns whether anything blocks the ray (shadow rays)
bool TraceOccluded(float3 origin, float3 dir, float tMax)
{
	RayQuery<RAY_FLAG_NONE> q;
	q.TraceRayInline(gScene, BaseRayFlags() | RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH, MASK_SHADOWS, MakeRay(origin, dir, tMax));
	while (q.Proceed())
	{
		if (q.CandidateType() == CANDIDATE_NON_OPAQUE_TRIANGLE &&
			CandidateAlpha(q.CandidateInstanceID(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics()) >= uMisc.x)
			q.CommitNonOpaqueTriangleHit();
	}
	return q.CommittedStatus() == COMMITTED_TRIANGLE_HIT;
}

// Color that light takes on when passing through colored glass: the glass hue at full brightness, so purple glass lets
// bright purple light through instead of darkening it
float3 GlassTint(float3 color)
{
	float3 c = ToLinear(color);
	float m = max(c.r, max(c.g, c.b));
	return (m > 0.001) ? c / m : float3(1.0, 1.0, 1.0);
}

// Surface color used for bounced light, with adjustable saturation to make color bleeding stronger
float3 BounceColor(float3 albedo)
{
	float luma = dot(albedo, float3(0.2126, 0.7152, 0.0722));
	return max(lerp(float3(luma, luma, luma), albedo, uColor.x), 0.0);
}

// How much light gets through along a shadow ray: 0 when blocked, tinted by see-through surfaces (stained glass...)
float3 TraceTransmittance(float3 origin, float3 dir, float tMax)
{
	if (!(uSize.w & FLAG_TINTED_SHADOWS) || !(uSize.w & FLAG_ALPHA_CUTOUT))
		return TraceOccluded(origin, dir, tMax) ? float3(0.0, 0.0, 0.0) : float3(1.0, 1.0, 1.0);

	float3 transmittance = float3(1.0, 1.0, 1.0);
	RayQuery<RAY_FLAG_NONE> q;
	q.TraceRayInline(gScene, RAY_FLAG_NONE, MASK_SHADOWS, MakeRay(origin, dir, tMax));
	while (q.Proceed())
	{
		if (q.CandidateType() != CANDIDATE_NON_OPAQUE_TRIANGLE)
			continue;

		float4 c = CandidateColor(q.CandidateInstanceID(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics());
		if (c.a >= uMisc.x)
		{
			q.CommitNonOpaqueTriangleHit();
			break;
		}
		else if (c.a > 0.01)
			transmittance *= lerp(float3(1.0, 1.0, 1.0), GlassTint(c.rgb), saturate(c.a * uColor.y));
	}

	if (q.CommittedStatus() == COMMITTED_TRIANGLE_HIT)
		return float3(0.0, 0.0, 0.0);
	return transmittance;
}

// Finds the closest surface along the ray
bool TraceClosest(float3 origin, float3 dir, float tMax, out Surface s)
{
	RayQuery<RAY_FLAG_NONE> q;
	q.TraceRayInline(gScene, BaseRayFlags(), 0xFF, MakeRay(origin, dir, tMax));
	while (q.Proceed())
	{
		if (q.CandidateType() == CANDIDATE_NON_OPAQUE_TRIANGLE &&
			CandidateAlpha(q.CandidateInstanceID(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics()) >= uMisc.x)
			q.CommitNonOpaqueTriangleHit();
	}

	if (q.CommittedStatus() != COMMITTED_TRIANGLE_HIT)
	{
		s = (Surface)0;
		return false;
	}

	float t = q.CommittedRayT();
	s = FetchSurface(q.CommittedInstanceID(), q.CommittedPrimitiveIndex(), q.CommittedTriangleBarycentrics(),
					 q.CommittedObjectToWorld3x4(), origin + dir * t, dir);
	return true;
}

// ----------------------------------------------------------------------------------------------------------------------
// Lighting

float DistributionGGX(float NdotH, float roughness)
{
	float a = roughness * roughness;
	float a2 = a * a;
	float d = NdotH * NdotH * (a2 - 1.0) + 1.0;
	return a2 / (PI * d * d + 0.0001);
}

float GeometrySmith(float NdotV, float NdotL, float roughness)
{
	float r = roughness + 1.0;
	float k = (r * r) / 8.0;
	return (NdotV / (NdotV * (1.0 - k) + k)) * (NdotL / (NdotL * (1.0 - k) + k));
}

// Light from the sun and placed lights with ray traced shadows. Returns diffuse light (same units as the light buffer),
// optionally adds specular highlights for the given view direction and material.
float3 DirectLight(float3 pos, float3 normal, Parallax pom, float3 viewDir, float roughness, float3 specTint, bool doSpecular,
				   inout uint seed, inout float3 specular)
{
	float3 result = float3(0.0, 0.0, 0.0);
	float3 origin = pos + normal * uRay.y;
	bool shadows = (uSize.w & FLAG_SHADOWS) != 0;

	for (uint i = 0; i < uCounts.x; i++)
	{
		Light light = gLights[i];
		uint type = (uint)light.posType.w;
		float3 L;
		float dist, att = 1.0;

		if (type == LIGHT_SUN)
		{
			L = SampleCone(normalize(light.dirSpecular.xyz), uRay.z, seed);
			dist = 100000.0;
		}
		else
		{
			// Sample a point on the light's sphere for soft shadows
			float3 lightPos = light.posType.xyz + SampleSphere(seed) * (light.params.z * 0.5 * uRay.w);
			float3 toLight = lightPos - pos;
			dist = length(toLight);
			L = toLight / max(dist, 0.0001);

			float range = light.params.x, fade = max(light.params.y, 0.0001);
			att = 1.0 - saturate((dist - range * (1.0 - fade)) / (range * fade));

			if (type == LIGHT_SPOT)
			{
				float cosT = dot(-L, normalize(light.dirSpecular.xyz));
				if (cosT <= 0.0)
					att = 0.0;
				else
				{
					float tanT = sqrt(max(0.0, 1.0 - cosT * cosT)) / cosT;
					float ratio = tanT / max(light.params.w, 0.0001);
					float sharp = light.params2.x;
					att *= 1.0 - saturate((ratio - sharp) / max(0.01, 1.0 - sharp));
				}
			}
		}

		float NdotL = dot(normal, L);
		if (NdotL <= 0.0 || att <= 0.0)
			continue;

		// Height map self-shadowing (parallax)
		att *= ParallaxShadow(pom, L);
		if (att <= 0.0)
			continue;

		float3 visibility = float3(1.0, 1.0, 1.0);
		if (shadows && light.params2.y > 0.5)
		{
			float nearSkip = (type == LIGHT_SUN) ? uRay.y * 2.0 : max(uRay.y * 2.0, 1.0);
			visibility = TraceTransmittance(origin, L, max(0.0, dist - nearSkip));
			if (max(visibility.r, max(visibility.g, visibility.b)) <= 0.0)
				continue;
		}

		float3 lightColor = light.colorStrength.rgb * light.colorStrength.a * att * visibility;
		result += lightColor * NdotL;

		if (doSpecular && light.dirSpecular.w > 0.0)
		{
			float3 H = normalize(viewDir + L);
			float NdotV = max(dot(normal, viewDir), 0.0001);
			float NdotH = max(dot(normal, H), 0.0);
			float spec = DistributionGGX(NdotH, roughness) * GeometrySmith(NdotV, NdotL, roughness) / (4.0 * NdotV * NdotL + 0.0001);
			specular += lightColor * light.dirSpecular.w * NdotL * spec * specTint * uMisc.y;
		}
	}

	return result;
}

// Light from the open sky for rays that escape the scene: the ambient color (like Render mode) plus the sky color.
float3 EnvironmentLight()
{
	return uAmbient.rgb * uAmbient.a + uSky.rgb * uSky.a;
}

// Light arriving along a ray, following it through up to "bounces" diffuse bounces (global illumination).
float3 TraceRadiance(float3 origin, float3 dir, uint bounces, inout uint seed)
{
	float3 radiance = float3(0.0, 0.0, 0.0);
	float3 throughput = float3(1.0, 1.0, 1.0);
	bool lightsOnBounces = (uSize.w & FLAG_BOUNCE_LIGHTS) != 0;

	for (uint b = 0; b < bounces; b++)
	{
		Surface s;
		if (!TraceClosest(origin, dir, uRay.x, s))
		{
			radiance += throughput * EnvironmentLight();
			break;
		}

		float3 light = s.emissive * uStrengths.y;
		if (lightsOnBounces)
		{
			float3 unusedSpec = float3(0.0, 0.0, 0.0);
			light += DirectLight(s.pos, s.normal, s.pom, -dir, 1.0, float3(0.0, 0.0, 0.0), false, seed, unusedSpec);
		}

		float3 bounceColor = BounceColor(s.albedo);
		radiance += throughput * bounceColor * light;
		throughput *= bounceColor;

		if (max(throughput.r, max(throughput.g, throughput.b)) < 0.01)
			break;

		origin = s.pos + s.normal * uRay.y;
		dir = SampleCosineHemisphere(s.normal, seed);
	}

	return radiance;
}

// ----------------------------------------------------------------------------------------------------------------------

[numthreads(8, 8, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
	if (id.x >= uSize.x || id.y >= uSize.y)
		return;

	float4 depthData = gDepth[id.xy];
	float depth = UnpackValue(depthData);

	// Nothing rendered here (sky/background)
	if (depthData.a < 0.001 || depth > 0.999)
	{
		gOutLight[id.xy] = float4(0.0, 0.0, 0.0, 1.0);
		gOutSpecular[id.xy] = float4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	uint seed = (id.x * 1973u + id.y * 9277u + uSize.z * 26699u) | 1u;
	PcgNext(seed);

	float2 uv = (float2(id.xy) + 0.5) / float2(uSize.xy);

	// Primary ray from the camera through the same (jittered) point the G-buffer was rasterized at. This gives the exact
	// surface position and normal, the G-buffer depth isn't precise enough to start shadow rays from.
	float2 ndc = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0) - uJitter.xy;
	float4 farView = mul(uProjInv, float4(ndc, 0.5, 1.0));
	float3 farWorld = mul(uViewInv, float4(farView.xyz / farView.w, 1.0)).xyz;
	float3 primaryDir = normalize(farWorld - uCamPos.xyz);

	float3 pos, normal;
	Surface primary;
	float debugNormalSource = 0.0; // 0 = no primary hit, 1 = geometry
	float primaryAO = 1.0;
	Parallax primaryPom = NoParallax();
	if (TraceClosest(uCamPos.xyz, primaryDir, 1000000.0, primary))
	{
		pos = primary.pos;
		normal = primary.normal;
		debugNormalSource = 1.0; // Includes the normal map, applied in FetchSurface
		primaryAO = lerp(1.0, primary.ao, uPBR.z);
		primaryPom = primary.pom;
	}
	else // Fall back to the G-buffer
	{
		pos = mul(uViewInv, float4(ViewPosFromDepth(uv, depth), 1.0)).xyz;
		normal = GeometricNormal(int2(id.xy), pos);
	}
	float3 viewDir = normalize(uCamPos.xyz - pos);
	if (dot(normal, viewDir) < 0.0)
		normal = -normal;

	float4 material = gMaterial[id.xy]; // R = roughness, G = metallic, B = fresnel
	float roughness = max(material.r, 0.02);
	float metallic = material.g;
	float fresnel = material.b;
	float3 albedo = ToLinear(gDiffuse[id.xy].rgb);
	float3 specTint = lerp(float3(1.0, 1.0, 1.0), albedo, metallic);

	float3 specular = float3(0.0, 0.0, 0.0);
	bool doSpecular = (uSize.w & FLAG_SPECULAR) != 0;

	// Developer debug views (Data/rtdebug.txt), shown through the specular buffer
	uint debugView = (uint)uMisc.z;
	if (debugView > 0)
	{
		float3 c = float3(0.0, 0.0, 0.0);
		if (debugView == 1) // World normal
			c = normal * 0.5 + 0.5;
		else if (debugView == 2) // Sun visibility: green = lit, red = shadowed, blue = facing away
		{
			c = float3(1.0, 0.0, 1.0);
			for (uint i = 0; i < uCounts.x; i++)
			{
				Light light = gLights[i];
				if ((uint)light.posType.w != LIGHT_SUN)
					continue;
				float3 L = normalize(light.dirSpecular.xyz);
				if (dot(normal, L) <= 0.0)
					c = float3(0.0, 0.0, 1.0);
				else
					c = TraceOccluded(pos + normal * uRay.y, L, 100000.0) ? float3(1.0, 0.0, 0.0) : float3(0.0, 1.0, 0.0);
				break;
			}
		}
		else if (debugView == 3) // World position
			c = frac(pos / 16.0);
		else if (debugView == 5 || debugView == 6) // Sun shadow ray: 5 = hit distance, 6 = hit object
		{
			c = float3(0.0, 0.0, 0.0);
			for (uint i = 0; i < uCounts.x; i++)
			{
				Light light = gLights[i];
				if ((uint)light.posType.w != LIGHT_SUN)
					continue;
				RayQuery<RAY_FLAG_NONE> q;
				q.TraceRayInline(gScene, BaseRayFlags(), 0xFF, MakeRay(pos + normal * uRay.y, normalize(light.dirSpecular.xyz), 100000.0));
				while (q.Proceed())
				{
					if (q.CandidateType() == CANDIDATE_NON_OPAQUE_TRIANGLE &&
						CandidateAlpha(q.CandidateInstanceID(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics()) >= uMisc.x)
						q.CommitNonOpaqueTriangleHit();
				}
				if (q.CommittedStatus() == COMMITTED_TRIANGLE_HIT)
				{
					if (debugView == 5) // Red = within 0.1 units (self hit), green = within a block, blue = farther
						c = (q.CommittedRayT() < 0.1) ? float3(1.0, 0.0, 0.0) : ((q.CommittedRayT() < 16.0) ? float3(0.0, 1.0, 0.0) : float3(0.0, 0.0, 1.0));
					else
					{
						uint h = q.CommittedInstanceID() * 2654435761u;
						c = float3((h >> 8) & 0xFF, (h >> 16) & 0xFF, (h >> 24) & 0xFF) / 255.0;
					}
				}
				else
					c = float3(1.0, 1.0, 1.0); // Not blocked
				break;
			}
		}
		else if (debugView == 7) // Raw G-buffer normal as stored by the rasterizer
			c = UnpackNormal(gNormal[id.xy]) * 0.5 + 0.5;
		else if (debugView == 4) // The scene as seen by the ray tracer from the camera
		{
			Surface s;
			float3 dir = normalize(pos - uCamPos.xyz);
			c = TraceClosest(uCamPos.xyz, dir, 1000000.0, s) ? s.albedo : float3(1.0, 0.0, 1.0);
		}
		gOutLight[id.xy] = float4(0.0, 0.0, 0.0, 1.0);
		gOutSpecular[id.xy] = float4(c, 1.0);
		return;
	}

	// Direct light
	// Specular highlights are scaled by the surface's fresnel like in Render mode (rough non-metals barely shine)
	float3 light = DirectLight(pos, normal, primaryPom, viewDir, roughness, specTint * fresnel, doSpecular && fresnel > 0.0, seed, specular);

	// Light from the environment and bounced light. A ray that escapes to the sky brings the ambient/sky light (so corners and
	// covered areas get darker), a ray that hits something brings back the light bouncing off it.
	if ((uSize.w & FLAG_INDIRECT) && uCounts.y > 0)
	{
		float3 origin = pos + normal * uRay.y;
		float3 dir = SampleCosineHemisphere(normal, seed);
		Surface s;

		if (!TraceClosest(origin, dir, uRay.x, s))
			light += EnvironmentLight() * primaryAO;
		else
		{
			float3 bounce = s.emissive * uStrengths.y;
			if (uSize.w & FLAG_BOUNCE_LIGHTS)
			{
				float3 unusedSpec = float3(0.0, 0.0, 0.0);
				bounce += DirectLight(s.pos, s.normal, s.pom, -dir, 1.0, float3(0.0, 0.0, 0.0), false, seed, unusedSpec);
			}
			if (uCounts.y > 1)
				bounce += TraceRadiance(s.pos + s.normal * uRay.y, SampleCosineHemisphere(s.normal, seed), uCounts.y - 1, seed);
			light += BounceColor(s.albedo) * bounce * uStrengths.x * primaryAO;
		}
	}
	else
		light += EnvironmentLight() * primaryAO; // No bounce light: flat ambient like Render mode

	// Reflections
	if ((uSize.w & FLAG_REFLECTIONS) && (fresnel > 0.001 || metallic > 0.001) && material.r <= uStrengths.w)
	{
		float3 H = SampleGGX(normal, roughness, seed);
		float3 R = reflect(-viewDir, H);

		if (dot(R, normal) > 0.0)
		{
			float3 reflected;
			Surface s;
			if (TraceClosest(pos + normal * uRay.y, R, uRay.x, s))
			{
				float3 unusedSpec = float3(0.0, 0.0, 0.0);
				float3 hitLight = EnvironmentLight() + s.emissive * uStrengths.y;
				hitLight += DirectLight(s.pos, s.normal, s.pom, -R, 1.0, float3(0.0, 0.0, 0.0), false, seed, unusedSpec);

				if ((uSize.w & FLAG_INDIRECT) && uCounts.z > 0)
					hitLight += TraceRadiance(s.pos + s.normal * uRay.y, SampleCosineHemisphere(s.normal, seed), uCounts.z, seed) * uStrengths.x;

				reflected = s.albedo * hitLight;
			}
			else
				reflected = ToLinear(uSky.rgb);

			specular += reflected * uStrengths.z * fresnel * specTint;
		}
	}

	gOutLight[id.xy] = float4(light, 1.0);
	gOutSpecular[id.xy] = float4(specular, 1.0);
}
