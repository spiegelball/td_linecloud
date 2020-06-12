in vec2 life;

out vec3 vColor;
out vec2 vAgeLifetime;

void main()
{
	gl_Position = TDDeform(P);
	vColor = Cd.xyz;
    vAgeLifetime = life;
}
