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

vec3 getMappedNormal(vec2 uv)
{
	if (uUseNormalMap < 1)
		return vec3(vTBN[2][0], vTBN[2][1], vTBN[2][2]);
	
	vec4 n = texture2D(uTextureNormal, uv).rgba;
	n.rgba = (n.a < 0.01 ? vec4(.5, .5, 0.0, 1.0) : n.rgba); // No normal?
	n.xy = n.xy * 2.0 - 1.0; // Decode
	n.xy *= uNormalStrength; // Normal strength setting
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy))); // Get Z
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
	vec2 tex = vTexCoord;
	vec4 baseColor = vColor * texture2D(uTexture, tex);
	
	if (baseColor.a == 0.0)
		discard;
	
	if (uAlphaHash > 0 && (baseColor.a < hash(vec2(hash(vPosition.xy + (uSampleIndex / 255.0)), vPosition.z + (uSampleIndex / 255.0)))))
		discard;
	
	// Depth (with the normal map's height detail for the depth map pass)
	float depth = vDepth;
	if (uHeightDepth > 0.0 && uUseNormalMap > 0)
	{
		float height = texture2D(uTextureNormal, tex).a;
		if (height >= 0.01) // 0 = no normal map
			depth += (1.0 - height) * uHeightDepth;
	}
	gl_FragData[0] = packDepth(depth);
	
	// Normal
	gl_FragData[1] = packNormal(getMappedNormal(tex));
}