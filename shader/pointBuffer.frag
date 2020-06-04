in vec4 vEncodedPos;
in vec3 gColor;

layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 fragColor2;

void main()
{
	fragColor = vEncodedPos;   
	vec4 color = vec4(gColor,1.0);
	fragColor2 = color;
}
