uniform sampler2D uDepthBuffer;

// Range the depth buffer was packed with
uniform float uNear;
uniform float uFar;

// Distance range mapped to the 0-1 output, in Mine-imator units
uniform float uMapNear;
uniform float uMapFar;

// 1 = near is white, far is black
uniform int uNearWhite;

varying vec2 vTexCoord;

float unpackDepth(vec4 c)
{
	return c.r + c.g / 255.0 + c.b / (255.0 * 255.0);
}

void main()
{
	vec4 depthColor = texture2D(uDepthBuffer, vTexCoord);
	
	// Background (nothing rendered) counts as infinitely far
	float value = 1.0;
	
	if (depthColor.a > 0.5)
	{
		float dist = uNear + unpackDepth(depthColor) * (uFar - uNear);
		value = clamp((dist - uMapNear) / max(uMapFar - uMapNear, 0.0001), 0.0, 1.0);
	}
	
	if (uNearWhite > 0)
		value = 1.0 - value;
	
	gl_FragColor = vec4(value, value, value, 1.0);
}
