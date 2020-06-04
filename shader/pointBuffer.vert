out vec3 vColor;

void main()
{
	gl_Position = TDDeform(P);
	vColor = Cd.xyz;
}
