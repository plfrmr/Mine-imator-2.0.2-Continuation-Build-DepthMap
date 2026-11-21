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
uniform float uLightSpotSharpness; // static
uniform vec3 uShadowPosition; // static
uniform float uLightSpecular;

uniform sampler2D uDepthBuffer; // static

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

uniform vec3 uCameraPosition; // static

varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vTangent;
varying mat3 vTBN;
varying vec2 vTexCoord;
varying vec4 vScreenCoord;
varying vec4 vShadowCoord;
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
	return	geometrySchlickGGX(max(dot(N, V), 0.0), roughness) *
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

float unpackDepth(vec4 c)
{
	return c.r + c.g / 255.0 + c.b / (255.0 * 255.0);
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
	float pomDepth;
	vec2 tex = getParallaxUV(vTexCoord, getTangentDir(normalize(uCameraPosition - vPosition)), pomDepth);
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
		
		float dif = 0.0;
		float difMask = 0.0;
		float shadow = 1.0;
		float att = 0.0;
		vec3 subsurf = vec3(0.0);
		
		// Check if not behind the spot light
		if (vScreenCoord.w > 0.0)
		{
			// Diffuse factor
			dif = max(0.0, dot(normal, normalize(uLightPosition - vPosition)));
			
			// Attenuation factor
			att = 1.0 - clamp((distance(vPosition, uLightPosition) - uLightFar * (1.0 - uLightFadeSize)) / (uLightFar * uLightFadeSize), 0.0, 1.0);
			dif *= att;
			
			if (dif > 0.0 || sss > 0.0)
			{
				// Spotlight circle
				float fragDepth = min(vScreenCoord.z, uLightFar);
				vec2 fragCoord = (vec2(vScreenCoord.x, -vScreenCoord.y) / vScreenCoord.z + 1.0) * 0.5;
				
				// Texture position must be valid
				if (fragCoord.x > 0.0 && fragCoord.y > 0.0 && fragCoord.x < 1.0 && fragCoord.y < 1.0)
				{
					// Create circle
					difMask = 1.0 - clamp((distance(fragCoord, vec2(0.5, 0.5)) - 0.5 * uLightSpotSharpness) / (0.5 * max(0.01, 1.0 - uLightSpotSharpness)), 0.0, 1.0);
				} 
				else
					difMask = 0.0;
				
				dif *= difMask;
				
				// Calculate shadow
				fragDepth = min(vShadowCoord.z, uLightFar);
				fragCoord = (vec2(vShadowCoord.x, -vShadowCoord.y) / vShadowCoord.z + 1.0) * 0.5;
				
				if (difMask > 0.0)
				{
					// Calculate bias
					float bias = 1.0;
					
					// Shadow
					float sampleDepth = uLightNear + unpackDepth(texture2D(uDepthBuffer, fragCoord)) * (uLightFar - uLightNear);
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
			}
		}
		
		// Parallax self-shadowing
		shadow *= getParallaxShadow(tex, pomDepth, getTangentDir(normalize(uLightPosition - vPosition)));
		
		// Diffuse light
		light = uLightColor.rgb * uLightStrength * dif * shadow;
		
		// Subsurface translucency
		if (sss > 0.0)
		{
			float transDif = max(0.0, dot(normalize(-normal), normalize(uLightPosition - vPosition)));
			subsurf += (subsurf * uSSSHighlightStrength * CSPhase(dot(normalize(vPosition - uCameraPosition), normalize(uLightPosition - vPosition)), uSSSHighlight));
			light += uLightColor.rgb * uLightStrength * uSSSColor.rgb * transDif * subsurf * difMask;
			light *= mix(vec3(1.0), uSSSColor.rgb, clamp(sss, 0.0, 1.0));
		}
		
		// Calculate specular
		if (uLightSpecular * dif * shadow > 0.0)
		{
			vec3 N = normal;
			vec3 L = normalize(uLightPosition - vPosition);
			vec3 V = normalize(uCameraPosition - vPosition);
			vec3 H = normalize(V + L);
			float NDF = distributionGGX(N, H, roughness);
			float G = geometrySmith(N, V, L, roughness);
		
			float F = fresnelSchlickRoughness(max(dot(H, V), 0.0), F0, roughness);
		
			float numerator = NDF * G * F;
			float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
			float specular = numerator / denominator;
		
			spec = uLightColor.rgb * shadow * difMask * uLightSpecular * dif * (specular * mix(vec3(1.0), baseColor.rgb, metallic));
		}
	}
	
	gl_FragData[0] = vec4(light, baseColor.a);
	gl_FragData[1] = vec4(spec, baseColor.a);
	
	if (baseColor.a == 0.0)
		discard;
}
