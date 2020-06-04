// Example Pixel Shader

// uniform vec4 exampleUniform;

in Vertex
{
	vec3 worldSpacePos;
	vec3 coords[4];
	vec3 color;
	float width;
} iVert;

out vec4 fragColor;

float distToLine(vec3 p0, vec3 p1, vec3 px)
{
  return length(cross(px-p0, px-p1)) / length(p1 - p0);
}

vec4 camToProjSpace(vec4 camPos)
{
	vec4 proj = uTDMat.proj * camPos;
	
	camPos.z = -camPos.z;
	camPos.z -= uTDGeneral.nearFar.x;
	camPos.z *= uTDGeneral.nearFar.w;
	camPos.z -= 0.5;
	camPos.z *= 2.0;

	proj.z = camPos.z * proj.w;
	
	return vec4(proj.x, proj.y, proj.z, proj.w);
}

vec4 worldToProjSpace(vec3 worldPos)
{
	vec4 camSpacePos = uTDMat.cam * vec4(worldPos,1.0);
	
	return camToProjSpace(camSpacePos);
}

void main()
{
	TDCheckDiscard();
	
	vec3 p0 = (iVert.coords[0] + iVert.coords[1]) / 2.0;
	vec3 p1 = (iVert.coords[2] + iVert.coords[3]) / 2.0;
	float a = length(iVert.coords[1] - iVert.coords[0]);
	float b = length(iVert.coords[3] - iVert.coords[2]);
	float l = length(p1-p0);
	
	//distance along p0 -> p1 line
	float disBase = distToLine(iVert.coords[1], iVert.coords[0], iVert.worldSpacePos) / l;
	
	
	float fac = mix(a, b, disBase) / 2;
	//orthogonal distance to p0->p1 line
	float disMid = distToLine(p0, p1, iVert.worldSpacePos);
	
	// general alpha
	float alpha = 1 - disMid / fac;
	alpha = clamp(alpha, 0.0,1.0);
	alpha = smoothstep(0.0,1.0,alpha);
	
	float tra = iVert.width / fac;
		
	vec4 color = vec4(iVert.color, 1.0);
	 
    color.a = alpha;
    
    vec3 camSpacePos = (uTDMat.cam * vec4(iVert.worldSpacePos, 1.0)).xyz;
    vec3 viewVec = normalize(uTDMat.camInverse[3].xyz - iVert.worldSpacePos );
	
    // add lightning
    vec3 diffuse = vec3(0.0);
	vec3 spec = vec3(0.0);
	
	// return parameter
	vec3 dC = vec3(0.0);
   	vec3 sC = vec3(0.0);
    for (int i = 0; i < TD_NUM_LIGHTS; i++) {
    	vec4 lightPos = uTDLights[i].position;
    	TDLighting(dC, sC, i, camSpacePos, normalize(vec3((lightPos.xyz - camSpacePos).xyz)), 1.0, vec3(1.0,0.0,0.0), viewVec, 1.0 );
    	diffuse += dC;
    	spec += sC;
    }
    
    color.xyz *= diffuse;
    color.xyz += spec;
	color.xyz *= color.a;
    
	TDAlphaTest(color.a);
    TDOutputSwizzle(color);
    TDDither(color);
    fragColor = color;
}

