uniform sampler2D uTexture; // static

uniform float uSampleIndex;
uniform int uAlphaHash;

uniform int uColorsExt;
uniform vec4 uRGBAdd;
uniform vec4 uRGBSub;
uniform vec4 uHSBAdd;
uniform vec4 uHSBSub;
uniform vec4 uHSBMul;
uniform vec4 uMixColor;

uniform int uFogShow;
uniform vec4 uFogColor; // static
uniform float uFogDistance; // static
uniform float uFogSize; // static
uniform float uFogHeight; // static

uniform vec3 uCameraPosition; // static

varying vec3 vPosition;
varying float vDepth;
varying vec4 vColor;
varying vec2 vTexCoord;
varying mat3 vTBN;

uniform sampler2D uTextureHeight; // static

vec4 rgbtohsb(vec4 c)
{
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec4(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x, c.a);
}

vec4 hsbtorgb(vec4 c)
{
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return vec4(c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y), c.a);
}

float getFog()
{
	float fog;
	if (uFogShow > 0)
	{
		float fogDepth = distance(vPosition, uCameraPosition);
		
		fog = clamp(1.0 - (uFogDistance - fogDepth) / uFogSize, 0.0, 1.0);
		fog *= clamp(1.0 - (vPosition.z - uFogHeight) / uFogSize, 0.0, 1.0);
	}
	else
		fog = 0.0;
	
	return fog;
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
	float h = texture2DGrad(uTextureHeight, uv, vec2(0.0), vec2(0.0)).a; // Full detail, so every pass finds the same hit
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
	vec2 tex = getParallaxUV(vTexCoord, getTangentDir(normalize(uCameraPosition - vPosition)), pomDepth);
	vec4 baseColor = vColor * texture2DGrad(uTexture, tex, texDx, texDy); // Get base
	
	if (uColorsExt > 0)
	{
		gl_FragColor = clamp(baseColor + uRGBAdd - uRGBSub, 0.0, 1.0); // Transform RGB
		gl_FragColor = hsbtorgb(clamp(rgbtohsb(gl_FragColor) + uHSBAdd - uHSBSub, 0.0, 1.0) * uHSBMul); // Transform HSB
		gl_FragColor = mix(gl_FragColor, uMixColor, uMixColor.a); // Mix
		gl_FragColor = mix(gl_FragColor, uFogColor, getFog()); // Mix fog
		gl_FragColor.a = baseColor.a; // Correct alpha
	}
	else 
	{
		gl_FragColor = mix(baseColor, uFogColor, getFog()); // Mix fog
		gl_FragColor.a = baseColor.a; // Correct alpha
	}
	
	if (uAlphaHash > 0)
	{
		if (gl_FragColor.a < hash(vec2(hash(vPosition.xy + (uSampleIndex / 255.0)), vPosition.z + (uSampleIndex / 255.0))))
			discard;
		else
			gl_FragColor.a = 1.0;
	}
	
	if (gl_FragColor.a == 0.0)
		discard;
}
