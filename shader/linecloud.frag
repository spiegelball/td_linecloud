// Example Pixel Shader

// uniform vec4 exampleUniform;

in Vertex
{
	vec3 worldSpacePos;
	vec3 coords[4];
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
	
	float rad = 0.0;
	
	vec4 p0Proj = worldToProjSpace(p0);
	vec4 p1Proj = worldToProjSpace(p1);
	float disP0 = length(iVert.worldSpacePos-p0);
	float disP1 = length(iVert.worldSpacePos-p1);
	
	vec4 color = vec4(0.0);
	
	alpha *= tra;
	/*if (disP0 >= a/2.0 && disP1 >= b/2.0) {
		alpha *= tra;
		gl_FragDepth = gl_FragCoord.z;
	}
	else 
	{
		if (disP0 < disP1) {
			gl_FragDepth = p0Proj.z;
			color.xyz = vec3(-p0Proj.z/30.0);
			alpha = 0.2;
		}
		else {
			gl_FragDepth = p1Proj.z;			
			alpha = 0.2;
		}
	}*/ 
	 
    color.a = alpha;
    
    vec3 camSpacePos = (uTDMat.cam * vec4(iVert.worldSpacePos, 1.0)).xyz;
    vec3 viewVec = normalize(uTDMat.camInverse[3].xyz - iVert.worldSpacePos );
	
    
    for (int i = 0; i < TD_NUM_LIGHTS; i++) {
    	vec3 dC = vec3(0);
    	vec3 sC = vec3(0);
    	vec4 lightPos = uTDLights[i].position;
    	TDLighting(dC, sC, i, camSpacePos, normalize(vec3((lightPos.xyz - camSpacePos).xyz)), 1.0, vec3(1.0,0.0,0.0), viewVec, 1.0 );
    	color.xyz += dC;
    	//color.xyz += sC;
    }
    
	color.xyz *= color.a;
    
	TDAlphaTest(color.a);
    TDOutputSwizzle(color);
    TDDither(color);
    fragColor = color;
}

