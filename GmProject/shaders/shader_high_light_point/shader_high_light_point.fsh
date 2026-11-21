#define SQRT05 0.707106781
#define PI 3.14159265

uniform sampler2D uTexture; // static
uniform int uIsSky;
uniform int uIsWater;

uniform float uSampleIndex;
uniform int uAlphaHash;

uniform vec3 uLightPosition; // static
uniform vec4 uLightColor; // static
uniform float uLightStrength; // static
uniform float uLightNear; // static
uniform float uLightFar; // static
uniform float uLightFadeSize; // static
uniform vec3 uShadowPosition; // static
uniform float uLightSpecular;
uniform float uLightSize;

uniform sampler2D uDepthBuffer; // static
uniform float uDepthBufferSize; // static

uniform vec3 uCameraPosition; // static

uniform sampler2D uTextureMaterial; // static
uniform sampler2D uTextureNormal; // static
uniform int uMaterialFormat;
uniform float uDefaultEmissive;
uniform float uDefaultSubsurface;
uniform float uRoughness;
uniform float uMetallic;
uniform float uReflectiveness; // Minimum reflectivity (F0), lets non-metals reflect
uniform float uEmissive;

uniform float uSSS;
uniform vec3 uSSSRadius;
uniform vec4 uSSSColor;
uniform float uSSSHighlight;
uniform float uSSSHighlightStrength;

varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vTangent;
varying mat3 vTBN;
varying vec2 vTexCoord;
varying vec4 vCustom;
varying vec4 vColor;

// Fresnel Schlick approximation
float fresnelSchlickRoughness(float cosTheta, float F0, float roughness)
{
	return F0 + (max((1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// GGX specular (https://learnopengl.com/PBR/Lighting)
float distributionGGX(vec3 N, vec3 H, float roughness)
{
	float a2 = roughness * roughness * roughness * roughness;
	float NdotH = max(dot(N, H), 0.0);
	float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
	return a2 / (PI * denom * denom);
}

float geometrySchlickGGX(float NdotV, float roughness)
{
	float r = (roughness + 1.0);
	float k = (r * r) / 8.0;
	
	return NdotV / (NdotV * (1.0 - k) + k);
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
	return geometrySchlickGGX(max(dot(N, V), 0.0), roughness) *
			geometrySchlickGGX(max(dot(N, L), 0.0), roughness);
}

uniform int uUseNormalMap; // static
// PBR render settings
uniform float uNormalStrength;
uniform float uPBRRoughness;
uniform float uPBRMetallic;
uniform float uPBRReflectivity;

// Applies the PBR render settings (Roughness, Metallic, Reflectivity multipliers)
void scalePBR(inout float roughness, inout float metallic, inout float F0)
{
	roughness = clamp(roughness * uPBRRoughness, 0.0, 1.0);
	metallic = clamp(metallic * uPBRMetallic, 0.0, 1.0);
	F0 = clamp(F0 * uPBRReflectivity, 0.0, 1.0);
}

// Parallax occlusion mapping, from the height map in the normal map's alpha (LabPBR/SEUS: 1 = surface, 0 = deepest).
// Every texel is a column of its own height: the view ray steps from texel to texel and hits either the top or the side
// of a column, so pixel art stays crisp. Block textures share one sheet, so the march wraps around inside the block's tile.
uniform vec2 uParallaxTile; // Size of a block sheet tile in UV, 0 = not a block sheet (no parallax)
uniform vec2 uParallaxTexel; // Size of a height map texel in UV
uniform float uParallaxDepth; // How deep height 0 goes in blocks, 0 = parallax off
uniform float uParallaxShadow; // Self-shadowing, 1 = on

// How the texture coordinate changes when moving in world space: uv changes by (dot(d, gradU), dot(d, gradV)) for a move d.
// Found from the screen derivatives, so it works for any face orientation, mirrored or stretched texture.
void getUVGradients(out vec3 gradU, out vec3 gradV)
{
	vec3 dp1 = dFdx(vPosition);
	vec3 dp2 = dFdy(vPosition);
	vec2 duv1 = dFdx(vTexCoord);
	vec2 duv2 = dFdy(vTexCoord);
	vec3 n = cross(dp1, dp2);
	float nn = max(dot(n, n), 1e-20);
	vec3 c1 = cross(dp2, n);
	vec3 c2 = cross(n, dp1);
	gradU = (duv1.x * c1 + duv2.x * c2) / nn;
	gradV = (duv1.y * c1 + duv2.y * c2) / nn;
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

// Depth (0-1 of the parallax depth) of the texel column at a texel position of the tile
float getParallaxTexelDepth(vec2 cell, vec2 tileMin)
{
	return 1.0 - getParallaxHeight(wrapParallaxTile(tileMin + (cell + 0.5) * uParallaxTexel, tileMin));
}

// Texel moved per unit of depth (0-1 of the parallax depth) when following a direction into or out of the surface
vec2 getParallaxTexelDir(vec3 dir, vec3 normal, vec3 gradU, vec3 gradV)
{
	vec2 d = vec2(dot(dir, gradU), dot(dir, gradV)) / max(dot(dir, normal), 0.05) * (uParallaxDepth * 16.0) / uParallaxTexel;
	d.x = (abs(d.x) < 0.00001 ? 0.00001 : d.x);
	d.y = (abs(d.y) < 0.00001 ? 0.00001 : d.y);
	return d;
}

// Moves the texture coordinate to where the view ray hits the height map. hitDepth returns how deep the hit is (0-1),
// hitSide the side of the texel column that was hit in texels (0 = its top).
vec2 getParallaxUV(vec2 uv, vec3 viewDir, vec3 normal, vec3 gradU, vec3 gradV, out float hitDepth, out vec2 hitSide)
{
	hitDepth = 0.0;
	hitSide = vec2(0.0);
	if (uParallaxDepth <= 0.0 || uParallaxTile.x <= 0.0 || uParallaxTile.y <= 0.0 || uParallaxTexel.x <= 0.0 || dot(viewDir, normal) <= 0.0)
		return uv;

	vec2 tileMin = floor(uv / uParallaxTile) * uParallaxTile;
	vec2 p = (uv - tileMin) / uParallaxTexel;
	vec2 dir = -getParallaxTexelDir(viewDir, normal, gradU, gradV);
	vec2 stepDir = vec2(dir.x > 0.0 ? 1.0 : -1.0, dir.y > 0.0 ? 1.0 : -1.0);
	vec2 cell = floor(p);
	vec2 tDelta = abs(1.0 / dir);
	vec2 tMax = (cell + max(stepDir, vec2(0.0)) - p) / dir;
	vec2 side = vec2(0.0);
	float t = 0.0;

	for (int i = 0; i < 128; i++)
	{
		float cellDepth = getParallaxTexelDepth(cell, tileMin);

		// Entered this column below its top: hit its side
		if (t >= cellDepth)
		{
			hitSide = side;
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
			side = vec2(-stepDir.x, 0.0);
		}
		else
		{
			cell.y += stepDir.y;
			t = tMax.y;
			tMax.y += tDelta.y;
			side = vec2(0.0, -stepDir.y);
		}
	}

	hitDepth = t;
	vec2 hitP = clamp(p + dir * t, cell + 0.001, cell + 0.999);
	return wrapParallaxTile(tileMin + hitP * uParallaxTexel, tileMin);
}

// Normal of the side of a texel column that was hit, or the given normal for the top
vec3 getParallaxNormal(vec3 normal, vec2 hitSide, vec3 gradU, vec3 gradV)
{
	if (hitSide.x == 0.0 && hitSide.y == 0.0)
		return normal;

	return normalize(hitSide.x * normalize(gradU) + hitSide.y * normalize(gradV));
}

// Self-shadowing: 1 = lit, 0 = a texel column between the parallax hit and the light blocks it
float getParallaxShadow(vec2 uv, float hitDepth, vec3 lightDir, vec3 normal, vec3 gradU, vec3 gradV)
{
	if (uParallaxShadow < 0.5 || uParallaxDepth <= 0.0 || uParallaxTile.x <= 0.0 || uParallaxTexel.x <= 0.0 || hitDepth <= 0.0 || dot(lightDir, normal) <= 0.0)
		return 1.0;

	vec2 tileMin = floor(uv / uParallaxTile) * uParallaxTile;
	vec2 p = (uv - tileMin) / uParallaxTexel;
	vec2 dir = getParallaxTexelDir(lightDir, normal, gradU, gradV);
	vec2 stepDir = vec2(dir.x > 0.0 ? 1.0 : -1.0, dir.y > 0.0 ? 1.0 : -1.0);
	vec2 cell = floor(p);
	vec2 tDelta = abs(1.0 / dir);
	vec2 tMax = (cell + max(stepDir, vec2(0.0)) - p) / dir;
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

		if (t >= hitDepth)
			break;

		// A column whose top is above the ray blocks the light
		shadow = max(shadow, clamp(((hitDepth - t) - getParallaxTexelDepth(cell, tileMin)) * 30.0, 0.0, 1.0));
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

float unpackDepth(vec4 c)
{
	return c.r + c.g / 255.0 + c.b / (255.0 * 255.0);
}

vec2 getShadowMapCoord(vec3 look)
{
	float tFOV = tan(PI / 4.0);
	vec3 u, v, toPoint = vPosition - uShadowPosition;
	vec2 coord;
	
	// Prepare 3D to 2D conversion
	look /= sqrt(dot(look, look));
	u = vec3(-look.z * look.x, -look.z * look.y, 1.0 - look.z * look.z);
	u /= sqrt(dot(u, u));
	u *= tFOV; 
	v = vec3(u.y * look.z - look.y * u.z, u.z * look.x - look.z * u.x, u.x * look.y - look.x * u.y);
	
	// Convert
	toPoint /= dot(toPoint,look);
	coord.x = (dot(toPoint, v) / (tFOV * tFOV) + 1.0) * 0.5;
	coord.y = (1.0 - dot(toPoint, u) / (tFOV * tFOV)) * 0.5;
	
	coord.x /= 3.0;
	coord.y *= 0.5;
	
	return coord;
}

// Linear filtering, done in-shader as we use a texture atlas
vec4 getFilteredDepth(vec2 uv, vec2 uvMin)
{
	float samples = 0.0;
	vec2 sampleuv, uvMax, texelOffset;
	vec4 color = vec4(0.0);
	texelOffset = vec2((1.0/vec2(uDepthBufferSize * 3.0, uDepthBufferSize * 2.0)) * 0.5);
	uvMax = uvMin + vec2(1.0/3.0, 0.5);
	
	// Top left
	sampleuv = uv - texelOffset.x;
	if (sampleuv.x > uvMin.x && sampleuv.x < uvMax.x &&
		sampleuv.y > uvMin.y && sampleuv.y < uvMax.y)
	{
		color += texture2D(uDepthBuffer, sampleuv);
		samples += 1.0;
	}
	
	// Top right
	sampleuv.y = uv.y - texelOffset.x;
	sampleuv.x = uv.x + texelOffset.y;
	if (sampleuv.x > uvMin.x && sampleuv.x < uvMax.x &&
		sampleuv.y > uvMin.y && sampleuv.y < uvMax.y)
	{
		color += texture2D(uDepthBuffer, sampleuv);
		samples += 1.0;
	}
	
	// Bottom left
	sampleuv.y = uv.y + texelOffset.x;
	sampleuv.x = uv.x - texelOffset.y;
	if (sampleuv.x > uvMin.x && sampleuv.x < uvMax.x &&
		sampleuv.y > uvMin.y && sampleuv.y < uvMax.y)
	{
		color += texture2D(uDepthBuffer, sampleuv);
		samples += 1.0;
	}
	
	// Bottom right
	sampleuv = uv + texelOffset;
	if (sampleuv.x > uvMin.x && sampleuv.x < uvMax.x &&
		sampleuv.y > uvMin.y && sampleuv.y < uvMax.y)
	{
		color += texture2D(uDepthBuffer, sampleuv);
		samples += 1.0;
	}
	
	return color / samples;
}

float hash(vec2 c)
{
	return fract(10000.0 * sin(17.0 * c.x + 0.1 * c.y) *
	(0.1 + abs(sin(13.0 * c.y + c.x))));
}

void getMaterial(vec2 uv, vec2 texDx, vec2 texDy, out float roughness, out float metallic, out float emissive, out float F0, out float sss)
{
	vec4 matColor = texture2DGrad(uTextureMaterial, uv, texDx, texDy);
	
	if (uMaterialFormat == 2) // LabPBR
	{
		if (matColor.g > 0.898) // Metallic
		{
			metallic = 1.0; F0 = 1.0; sss = 0.0;
		}
		else // Non-metallic
		{
			metallic = 0.0; F0 = matColor.g;
			sss = (matColor.b > 0.255 ? (((matColor.b - 0.255) / 0.745) * max(uSSS, uDefaultSubsurface)) : 0.0);
		}
		
		roughness = pow(1.0 - matColor.r, 2.0);
		emissive = (matColor.a < 1.0 ? matColor.a /= 0.9961 : 0.0) * uDefaultEmissive;
		scalePBR(roughness, metallic, F0);
		F0 = max(F0, uReflectiveness);
		roughness = min(roughness, 1.0 - uReflectiveness);
		
		return;
	}
	
	if (uMaterialFormat == 1) // SEUS
	{
		roughness = (1.0 - matColor.r);
		metallic = matColor.g;
		emissive = (matColor.b * uDefaultEmissive);
	}
	else // No map
	{
		roughness = uRoughness;
		metallic = uMetallic;
		emissive = max(uEmissive, vCustom.z * uDefaultEmissive);
	}
	
	F0 = mix(0.0, 1.0, metallic);
	scalePBR(roughness, metallic, F0);
	F0 = max(F0, uReflectiveness);
	roughness = min(roughness, 1.0 - uReflectiveness);
	sss = max(uSSS, vCustom.w * uDefaultSubsurface);
}

float CSPhase(float dotView, float scatter)
{
	float result = (3.0 * (1.0 - (scatter * scatter))) * (1.0 + dotView);
	result /= 2.0 * (2.0 + pow(scatter, 2.0)) * pow(1.0 + pow(scatter, 2.0) - 2.0 * scatter * dotView, 1.5);
	return result;
}

void main()
{
	vec3 light, spec = vec3(0.0);
	
	// Parallax: every texture is sampled at the offset coordinate, with the surface's derivatives (no mipmap seams)
	vec2 texDx = dFdx(vTexCoord);
	vec2 texDy = dFdy(vTexCoord);
	vec3 pomGradU, pomGradV;
	getUVGradients(pomGradU, pomGradV);
	vec3 pomNormal = normalize(vTBN * vec3(0.0, 0.0, 1.0));
	float pomDepth;
	vec2 pomSide;
	vec2 tex = getParallaxUV(vTexCoord, normalize(uCameraPosition - vPosition), pomNormal, pomGradU, pomGradV, pomDepth, pomSide);
	vec4 baseColor = texture2DGrad(uTexture, tex, texDx, texDy) * vColor;
	
	if (uAlphaHash > 0)
	{
		if (baseColor.a < hash(vec2(hash(vPosition.xy + (uSampleIndex / 255.0)), vPosition.z + (uSampleIndex / 255.0))))
			discard;
		else
			baseColor.a = 1.0;
	}
	
	if (uIsSky > 0)
	{
		light = vec3(0.0);
		spec = vec3(uLightSpecular);
	}
	else
	{
		// Get material data
		float roughness, metallic, emissive, F0, sss;
		getMaterial(tex, texDx, texDy, roughness, metallic, emissive, F0, sss);
		vec3 normal = getMappedNormal(tex, texDx, texDy);
		normal = getParallaxNormal(normal, pomSide, pomGradU, pomGradV);
		
		float shadow = 1.0;
		float att = 0.0;
		vec3 subsurf = vec3(0.0);
		
		// Diffuse factor
		float dif = max(0.0, dot(normal, normalize(uLightPosition - vPosition))); 
		
		// Attenuation factor
		att = 1.0 - clamp((distance(vPosition, uLightPosition) - uLightFar * (1.0 - uLightFadeSize)) / (uLightFar * uLightFadeSize), 0.0, 1.0); 
		dif *= att;
		
		if (dif > 0.0 || sss > 0.0)
		{
			vec2 fragCoord, bufferMin, bufferMax;
			vec3 toLight = vPosition - uShadowPosition;
			vec4 lookDir = vec4( // Get the direction from the pixel to the light
				toLight.x / distance(vPosition.xy, uShadowPosition.xy),
				toLight.y / distance(vPosition.xy, uShadowPosition.xy),
				toLight.z / distance(vPosition.xz, uShadowPosition.xz),
				toLight.z / distance(vPosition.yz, uShadowPosition.yz)
			);
		
			// Get shadow map and texture coordinate
		
			// Z+
			// ooo
			// oxo
			if (lookDir.z > SQRT05 && lookDir.w > SQRT05)
			{ 
				fragCoord = getShadowMapCoord(vec3(0.0, -0.0001, 1.0));
				fragCoord.x += 1.0/3.0;
				fragCoord.y += 0.5;
				
				bufferMin = vec2(1.0/3.0, 0.5);
			}
			
			// Z-
			// ooo
			// oox
			else if (lookDir.z < -SQRT05 && lookDir.w < -SQRT05)
			{
				fragCoord = getShadowMapCoord(vec3(0.0, -0.0001, -1.0));
				fragCoord.x += 2.0/3.0;
				fragCoord.y += 0.5;
				
				bufferMin = vec2(2.0/3.0, 0.5);
			}
		
			// X+
			// xoo
			// ooo
			else if (lookDir.x > SQRT05)
			{ 
				fragCoord = getShadowMapCoord(vec3(1.0, 0.0, 0.0));
				
				bufferMin = vec2(0.0);
			}
		
			// X-
			// oxo
			// ooo
			else if (lookDir.x < -SQRT05)
			{
				fragCoord = getShadowMapCoord(vec3(-1.0, 0.0, 0.0));
				fragCoord.x += 1.0/3.0;
				
				bufferMin = vec2(1.0/3.0, 0.0);
			}
		
			// Y+
			// oox
			// ooo
			else if (lookDir.y > SQRT05)
			{ 
				fragCoord = getShadowMapCoord(vec3(0.0, 1.0, 0.0));
				fragCoord.x += 2.0/3.0;
				
				bufferMin = vec2(2.0/3.0, 0.0);
			}
		
			// Y-
			// ooo
			// xoo
			else
			{ 
				fragCoord = getShadowMapCoord(vec3(0.0, -1.0, 0.0));
				fragCoord.y += 0.5;
				
				bufferMin = vec2(0.0, 0.5);
			}
			
			// Calculate bias
			float bias = 1.0;
			
			// Shadow
			float fragDepth = distance(vPosition, uShadowPosition);
			float sampleDepth = uLightNear + (uLightFar - uLightNear) * unpackDepth(getFilteredDepth(fragCoord, bufferMin));//texture2D(uDepthBuffer, fragCoord));
			shadow = ((fragDepth - bias) > sampleDepth) ? 0.0 : 1.0;
			
			// Get subsurface translucency
			if (sss > 0.0 && dif == 0.0)
			{
				vec3 rad = uSSSRadius * sss;
				vec3 dis = vec3((fragDepth + bias) - sampleDepth) / (uLightColor.rgb * uLightStrength * rad);
				
				if ((fragDepth - (bias * 0.01)) <= sampleDepth)
					dis = vec3(0.0);
				
				subsurf = pow(max(1.0 - pow(dis / rad, vec3(4.0)), 0.0), vec3(2.0)) / (pow(dis, vec3(2.0)) + 1.0) * att;
			}
		}
		
		// Parallax self-shadowing
		shadow *= getParallaxShadow(tex, pomDepth, normalize(uLightPosition - vPosition), pomNormal, pomGradU, pomGradV);
		
		// Diffuse light
		light = uLightColor.rgb * uLightStrength * dif * shadow;
		
		// Subsurface translucency
		if (sss > 0.0)
		{
			float transDif = max(0.0, dot(normalize(-normal), normalize(uLightPosition - vPosition)));
			subsurf += (subsurf * uSSSHighlightStrength * CSPhase(dot(normalize(vPosition - uCameraPosition), normalize(uLightPosition - vPosition)), uSSSHighlight));
			light += uLightColor.rgb * uLightStrength * uSSSColor.rgb * transDif * subsurf;
			light *= mix(vec3(1.0), uSSSColor.rgb, clamp(sss, 0.0, 1.0));
		}
		
		// Calculate specular
		if (uLightSpecular * dif * shadow > 0.0)
		{
			vec3 N = normal;
			vec3 V = normalize(uCameraPosition - vPosition);
			vec3 L = normalize(uLightPosition - vPosition);
			vec3 H = normalize(V + L);
			float NDF = distributionGGX(N, H, roughness);
			float G = geometrySmith(N, V, L, roughness);
		
			float F = fresnelSchlickRoughness(max(dot(H, V), 0.0), F0, roughness);
		
			float numerator = NDF * G * F;
			float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
			float specular = numerator / denominator;
		
			spec = uLightColor.rgb * shadow * uLightSpecular * dif * (specular * mix(vec3(1.0), baseColor.rgb, metallic));
		}
	}
	
	gl_FragData[0] = vec4(light, baseColor.a);
	gl_FragData[1] = vec4(spec, baseColor.a);
	
	if (baseColor.a == 0.0)
		discard;
}
