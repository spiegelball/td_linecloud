in vec4 vEncodedPos;
in vec3 gColor;
in vec2 gAgeLifetime;

layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 fragColor2;
layout(location = 2) out vec4 fAgeLifetime;

void main()
{
	fragColor = vEncodedPos;   
	vec4 color = vec4(gColor,1.0);
	fragColor2 = color;
	fAgeLifetime = vec4(gAgeLifetime, 1.0, 1.0);
}
