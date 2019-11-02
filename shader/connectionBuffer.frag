// color set in geom buffer
in vec4 vFragColor;

layout(location = 0) out vec4 color;

void main()
{
	color = vFragColor;   
}
