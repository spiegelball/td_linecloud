in vec4 vEncodedPos;

layout(location = 0) out vec4 fragColor;

void main()
{
	fragColor = vEncodedPos;   
}
