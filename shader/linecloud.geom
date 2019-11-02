// (c) by Alexander Court / 2019
// draw connection lines read from edge pixel buffer. do lightning and focus calculations here. 

#define MAXCONNECTIONS 10
#define MAXINT 100000

layout (points) in;

layout (triangle_strip, max_vertices = 48) out;

uniform vec4 uData;
uniform vec4 uMaxnormals;
uniform vec4 uMinnormals;
uniform vec4 uLimits;
uniform vec4 uWidths;
uniform vec3 uFocus;

uniform sampler2D sPosBuffer;
uniform sampler2D sEdgeBuffer;

out Vertex
{
	vec3 worldSpacePos;
	vec3 coords[4];
	float width;
	vec3 faceNorm;
} oVert;

struct SVertex
{
	vec3 worldSpacePos;
	vec3 coords[4];
	float width;
	vec3 faceNorm;
} vBuffer[3];

vec2 getTexPos(int idx, int offset, int res)
{
	idx += offset;

	float xPixel = mod(idx,res); 
	float yPixel = floor(float(idx)/float(res));
	
	xPixel = xPixel/float(res);
	yPixel = yPixel/float(res);
	
	return vec2(xPixel, yPixel);
}

vec4 posFromIndex(int idx)
{
	int resPosBuffer = textureSize(sPosBuffer, 0)[0];
	vec2 samplePos = getTexPos(idx, 0, resPosBuffer);
	return texture(sPosBuffer, samplePos);
}

int idFromIndex(int idx, int channel)
{
	int resEdgeBuffer = textureSize(sEdgeBuffer, 0)[0];
	vec2 samplePos = getTexPos(idx, 0, resEdgeBuffer);
	return int(texture(sEdgeBuffer, samplePos)[channel]);
}

bool existsEdge(int source, int target, int nConnections, int edgeBlockSize) {
	for (int i = 0; i < nConnections; i++) {
		int block = int(floor(float(i) / 4.0));
		int channel = int(mod(i, 4)); 
		// id of ith neighbour vertex
		int id = idFromIndex(source*edgeBlockSize+block,channel);
		
		if (target == id)
			return true;
	}
	return false;
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

vec4 worldToProjSpace(vec4 worldPos)
{
	vec4 camSpacePos = uTDMat.cam * worldPos;
	
	return camToProjSpace(camSpacePos);
}

void drawTriangle() {
	
	for (int i = 0; i < 3; i++) {
		oVert.worldSpacePos = vBuffer[i].worldSpacePos;
		oVert.coords = vBuffer[i].coords;
		oVert.width = vBuffer[i].width;
		gl_Position = worldToProjSpace(vec4(vBuffer[i].worldSpacePos, 1.0));
		EmitVertex();
	}
	
	EndPrimitive();
}

vec3 calcScreenNormal(vec3 p0, vec3 p1) {	
	vec3 camPos = uTDMat.camInverse[3].xyz;
	vec3 diffP = p1 - p0;
	vec3 diffCam = camPos - p0;
	vec3 norm = cross(diffP, diffCam);
	norm = normalize(norm);	
	
	return norm;
}

float getDOFFac(vec3 p0) {
	vec3 focusPoint = vec3(uFocus.x, uFocus.y, uFocus.z);

	vec3 p0Cam = (uTDMat.cam * vec4(p0, 1.0)).xyz;
	vec3 focusCam = (uTDMat.cam * vec4(focusPoint, 1.0)).xyz;
	
	float l = abs(focusCam.z);
	float d = abs(p0Cam.z-focusCam.z);
	
	return clamp(d, 0, l) / l;
} 

void drawRect(int idx0, int idx1) {
	
	float focus = uWidths.x;
	float screenWidth = uWidths.y;
	//aspectRatio
    
	vec3 p0 = posFromIndex(idx0).xyz;
	vec3 p1 = posFromIndex(idx1).xyz;
			
	vec3 screenNorm = calcScreenNormal(p0, p1);
	
	vec3 diffVec = p1 - p0;
	
	vec3 faceNorm = cross(screenNorm, diffVec);
	faceNorm = normalize(faceNorm);
	
	float d0 = getDOFFac(p0);
	float d1 = getDOFFac(p1);
	
	//above values, multiplied with focus width
	float D0 = d0 * focus; 
	float D1 = d1 * focus;
	
	vec3 pA, pB, pC, pD, pE, pF;
	vec3 coords[4];
	vec3 normals[2];
	
	vec4 p0Cam = uTDMat.cam*vec4(p0, 1.0);
	vec4 p1Cam = uTDMat.cam*vec4(p1, 1.0);
	vec4 focusCam = uTDMat.cam*vec4(uFocus, 1.0);
	
	float fac = (focusCam.z - p0Cam.z) / (p1Cam.z - p0Cam.z);
	
	if (0.0 < fac && fac < 1.0) {
		vec3 pM = mix(p0, p1, fac);
		
		pA = pM + screenNorm * (screenWidth);
		pB = pM - screenNorm * (screenWidth);
		pC = p1 + screenNorm * (screenWidth + D1);
		pD = p1 - screenNorm * (screenWidth + D1);
		
		float lengths[3] = float[3](length(p1-pM), length(pB-pA), length(pD-pC));
		normals = vec3[2](pB-pA, p1-p0);
		coords = vec3[4](pA, pB, pC, pD);
		
		vBuffer[0] = SVertex(pA, coords, screenWidth, faceNorm);
		vBuffer[1] = SVertex(pB, coords, screenWidth, faceNorm);
		vBuffer[2] = SVertex(pC, coords, screenWidth, faceNorm);
			
		drawTriangle();
			
		vBuffer[0] = SVertex(pC, coords, screenWidth, faceNorm);
		vBuffer[1] = SVertex(pD, coords, screenWidth, faceNorm);
		vBuffer[2] = SVertex(pB, coords, screenWidth, faceNorm);
			
		drawTriangle();
		
		pE = p0 + screenNorm * (screenWidth + D0);
		pF = p0 - screenNorm * (screenWidth + D0);
		
		coords = vec3[4](pA, pB, pE, pF);
		lengths = float[3](length(p0-pM), length(pB-pA), length(pF-pE));
		
		vBuffer[0] = SVertex(pA, coords, screenWidth, faceNorm);
		vBuffer[1] = SVertex(pB, coords, screenWidth, faceNorm);
		vBuffer[2] = SVertex(pE, coords, screenWidth, faceNorm);
			
		drawTriangle();
		
		vBuffer[0] = SVertex(pE, coords, screenWidth, faceNorm);
		vBuffer[1] = SVertex(pF, coords, screenWidth, faceNorm);
		vBuffer[2] = SVertex(pB, coords, screenWidth, faceNorm);
			
		drawTriangle();
		
	}
	else {	
		pA = p0 + screenNorm * (screenWidth + D0);
		pB = p0 - screenNorm * (screenWidth + D0);
		pC = p1 + screenNorm * (screenWidth + D1);
		pD = p1 - screenNorm * (screenWidth + D1);
			
		float lengths[3] = float[3](length(diffVec), length(pB-pA), length(pD-pC));
		normals = vec3[2](pB-pA, p1-p0);
		coords = vec3[4](pA, pB, pC, pD);
				
		vBuffer[0] = SVertex(pA, coords, screenWidth, faceNorm);
		vBuffer[1] = SVertex(pB, coords, screenWidth, faceNorm);
		vBuffer[2] = SVertex(pC, coords, screenWidth, faceNorm);
			
		drawTriangle();
			
		vBuffer[0] = SVertex(pC, coords, screenWidth, faceNorm);
		vBuffer[1] = SVertex(pD, coords, screenWidth, faceNorm);
		vBuffer[2] = SVertex(pB, coords, screenWidth, faceNorm);
			
		drawTriangle();
	}
	
}

void main()
{	
	int nVertices = int(uData.x);
	int res = int(uData.y);
	int nConnections = int(uData.z);
	int edgeBlockSize = int(ceil(nConnections / 4.0));

	int idx = gl_PrimitiveIDIn;
		
	vec2 INIT = vec2(float(MAXINT), float(MAXINT));
	vec2 closest[MAXCONNECTIONS] = {INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT};
	
	// for all possible connection
	for (int i = 0; i < nConnections; i++) {
		int block = int(floor(float(i) / 4.0));
		int channel = int(mod(i, 4)); 
		// id of ith neighbour vertex
		int target = idFromIndex(idx*edgeBlockSize+block,channel);
		
		// skip if not set
		if (target == MAXINT)
			break;
		
		if (idx < target || !existsEdge(target, idx, nConnections, edgeBlockSize))
			drawRect(idx, target);
	}
	
}