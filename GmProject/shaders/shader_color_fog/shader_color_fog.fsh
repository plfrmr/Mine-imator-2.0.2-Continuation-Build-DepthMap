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
	float h = texture2DGrad(uTextureHeight, uv, vec2(0.0), vec2(0.0)).a; // Full detail, so every pass finds the same hit
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
	vec3 pomGradU, pomGradV;
	getUVGradients(pomGradU, pomGradV);
	vec3 pomNormal = normalize(vTBN * vec3(0.0, 0.0, 1.0));
	float pomDepth;
	vec2 pomSide;
	vec2 tex = getParallaxUV(vTexCoord, normalize(uCameraPosition - vPosition), pomNormal, pomGradU, pomGradV, pomDepth, pomSide);
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
