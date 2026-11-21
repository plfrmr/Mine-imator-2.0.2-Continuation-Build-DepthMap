uniform sampler2D uTexture; // static
uniform sampler2D uTextureNormal; // static

uniform float uNormalBufferScale;

uniform float uSampleIndex;
uniform int uAlphaHash;

varying vec3 vPosition;
varying vec2 vTexCoord;
varying float vDepth;
varying vec4 vColor;
varying mat3 vTBN;
varying vec3 vViewTS;

vec4 packDepth(float f)
{
	return vec4(floor(f * 255.0) / 255.0, fract(f * 255.0), fract(f * 255.0 * 255.0), 1.0);
}

vec4 packNormal(vec3 n)
{
	return vec4(((n + vec3(1.0)) * 0.5) * uNormalBufferScale, 1.0);
}

uniform int uUseNormalMap; // static

// Depth map pass: how far (in packed depth) the lowest point of a height map is pushed back, 0 = off
uniform float uHeightDepth;
// PBR render settings
uniform float uNormalStrength;
uniform float uPBRRoughness;
uniform float uPBRMetallic;
uniform float uPBRReflectivity;

// Parallax occlusion mapping, from the height map in the normal map's alpha (LabPBR/SEUS: 1 = surface, 0 = deepest).
// Block textures share one sheet, so the ray march wraps around inside the block's own tile of the sheet.
uniform vec2 uParallaxTile; // Size of a block sheet tile in UV, 0 = not a block sheet (no parallax)
uniform float uParallaxDepth; // How deep height 0 goes in blocks, 0 = parallax off
uniform float uParallaxShadow; // Self-shadowing, 1 = on

// Direction in tangent space (x = along U, y = along V, z = out of the surface)
vec3 getTangentDir(vec3 dir)
{
	vec3 T = normalize(vTBN * vec3(1.0, 0.0, 0.0));
	vec3 B = normalize(vTBN * vec3(0.0, 1.0, 0.0));
	vec3 N = normalize(vTBN * vec3(0.0, 0.0, 1.0));
	return vec3(dot(dir, T), dot(dir, B), dot(dir, N));
}

float getParallaxHeight(vec2 uv)
{
	float h = texture2DGrad(uTextureNormal, uv, vec2(0.0), vec2(0.0)).a; // Full detail, so every pass finds the same hit
	return (h < 0.01 ? 1.0 : h); // 0 = no normal map
}

vec2 wrapParallaxTile(vec2 uv, vec2 tileMin)
{
	return tileMin + clamp(mod(uv - tileMin, uParallaxTile), vec2(0.0), uParallaxTile * 0.9999);
}

// Moves the texture coordinate to where the view ray hits the height map. hitDepth returns how deep the hit is (0-1).
vec2 getParallaxUV(vec2 uv, vec3 viewDir, out float hitDepth)
{
	hitDepth = 0.0;
	if (uParallaxDepth <= 0.0 || uParallaxTile.x <= 0.0 || uParallaxTile.y <= 0.0 || viewDir.z <= 0.0)
		return uv;
	
	vec2 tileMin = floor(uv / uParallaxTile) * uParallaxTile;
	
	// More layers when looking from the side, where the ray crosses more of the texture
	float layers = floor(mix(48.0, 12.0, viewDir.z));
	float layerStep = 1.0 / layers;
	vec2 uvStep = -(viewDir.xy / max(viewDir.z, 0.15)) * uParallaxTile * (uParallaxDepth * layerStep);
	
	vec2 curUV = uv;
	float curLayer = 0.0;
	float curDepth = 1.0 - getParallaxHeight(uv);
	vec2 prevUV = uv;
	float prevLayer = 0.0;
	float prevDepth = curDepth;
	
	for (int i = 0; i < 48; i++)
	{
		if (curLayer >= curDepth || float(i) >= layers)
			break;
		
		prevUV = curUV;
		prevLayer = curLayer;
		prevDepth = curDepth;
		curUV += uvStep;
		curLayer += layerStep;
		curDepth = 1.0 - getParallaxHeight(wrapParallaxTile(curUV, tileMin));
	}
	
	// Interpolate between the last two layers for a smooth surface
	float after = curDepth - curLayer;
	float before = prevDepth - prevLayer;
	float w = (abs(after - before) > 0.00001 ? clamp(after / (after - before), 0.0, 1.0) : 0.0);
	hitDepth = mix(curLayer, prevLayer, w);
	return wrapParallaxTile(mix(curUV, prevUV, w), tileMin);
}

// Self-shadowing: 1 = lit, 0 = a raised part of the height map is between the parallax hit and the light
float getParallaxShadow(vec2 uv, float hitDepth, vec3 lightDir)
{
	if (uParallaxShadow < 0.5 || uParallaxDepth <= 0.0 || uParallaxTile.x <= 0.0 || uParallaxTile.y <= 0.0 || hitDepth <= 0.0 || lightDir.z <= 0.0)
		return 1.0;
	
	vec2 tileMin = floor(uv / uParallaxTile) * uParallaxTile;
	float layerStep = hitDepth / 16.0;
	vec2 uvStep = (lightDir.xy / max(lightDir.z, 0.15)) * uParallaxTile * (uParallaxDepth * layerStep);
	vec2 curUV = uv;
	float curLayer = hitDepth;
	float shadow = 0.0;
	
	for (int i = 0; i < 16; i++)
	{
		curUV += uvStep;
		curLayer -= layerStep;
		float blocker = curLayer - (1.0 - getParallaxHeight(wrapParallaxTile(curUV, tileMin)));
		shadow = max(shadow, clamp(blocker * 12.0 * (1.0 - float(i) / 16.0), 0.0, 1.0)); // Softer further away
	}
	
	return 1.0 - shadow;
}

vec3 getMappedNormal(vec2 uv, vec2 texDx, vec2 texDy)
{
	if (uUseNormalMap < 1)
		return vec3(vTBN[2][0], vTBN[2][1], vTBN[2][2]);
	
	vec4 n = texture2DGrad(uTextureNormal, uv, texDx, texDy).rgba;
	n.rgba = (n.a < 0.01 ? vec4(.5, .5, 0.0, 1.0) : n.rgba); // No normal?
	n.xy = n.xy * 2.0 - 1.0; // Decode
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy))); // Get Z
	n.xy *= uNormalStrength; // Normal strength setting: scales the slopes (normalized below), so higher is deeper
	n.y *= -1.0; // Convert Y- to Y+
	return normalize(vTBN * n.xyz);
}

float hash(vec2 c)
{
	return fract(10000.0 * sin(17.0 * c.x + 0.1 * c.y) *
	(0.1 + abs(sin(13.0 * c.y + c.x))));
}

void main()
{
	// Parallax: every texture is sampled at the offset coordinate, with the surface's derivatives (no mipmap seams)
	vec2 texDx = dFdx(vTexCoord);
	vec2 texDy = dFdy(vTexCoord);
	float pomDepth;
	vec2 tex = getParallaxUV(vTexCoord, normalize(vViewTS), pomDepth);
	vec4 baseColor = vColor * texture2DGrad(uTexture, tex, texDx, texDy);
	
	if (baseColor.a == 0.0)
		discard;
	
	if (uAlphaHash > 0 && (baseColor.a < hash(vec2(hash(vPosition.xy + (uSampleIndex / 255.0)), vPosition.z + (uSampleIndex / 255.0)))))
		discard;
	
	// Depth (with the normal map's height detail for the depth map pass)
	float depth = vDepth;
	if (uHeightDepth > 0.0 && uUseNormalMap > 0)
	{
		float height = texture2DGrad(uTextureNormal, tex, texDx, texDy).a;
		if (height >= 0.01) // 0 = no normal map
			depth += (1.0 - height) * uHeightDepth;
	}
	gl_FragData[0] = packDepth(depth);
	
	// Normal
	gl_FragData[1] = packNormal(getMappedNormal(tex, texDx, texDy));
}