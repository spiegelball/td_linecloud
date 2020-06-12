// (c) by Alexander Court / 2019
// draw connection lines read from edge pixel buffer. do lightning and focus calculations here. 

#define MAXCONNECTIONS 10
#define MAXINT 100000

layout (points) in;
//in vec3 colorAttr[];

// emit triangles here
layout (triangle_strip, max_vertices = 44) out;

// x: number of points, z: number of connections to draw
uniform vec4 uData;
// x: minimum distance, y: maximum distance
uniform vec4 uLimits;
// x: focal length, y: width of drawn connections
uniform vec4 uWidths;
//focus point
uniform vec3 uFocus;

uniform sampler2D pointBuffer;
uniform sampler2D colBuffer;
uniform sampler2D ageLifetimeBuffer;
uniform sampler2D connectionBuffer;

out Vertex
{
	vec3 worldSpacePos;
	vec3 coords[4];
	vec3 color;
    float fadeOutFac;
	float width;
} oVert;

// temporary buffer to hold triangle vertices
struct SVertex
{
	vec3 worldSpacePos;
	vec3 coords[4];
    vec3 color;
    float fadeOutFac;
	float width;
} vBuffer[3];

// map indices to pixels on a square image.
//   x
// y 0  1  2  3  4  5  6  7
//   8  9 10 11 12 13 14  .
//   .  .  .  .  .  .  .  .
//   .  .  .  .  .  .  .  .
//   etc.
//
// idx: index to map
// res: resolution of the image
// 
// return coords in -1..1 range
vec2 mapIdxToTexCoord(int idx, int res)
{
	float xPixel = mod(idx,res); 
	float yPixel = floor(float(idx)/float(res));
	
	xPixel = xPixel/float(res);
	yPixel = yPixel/float(res);
	
	return vec2(xPixel, yPixel);
}

// read point position from point buffer for index idx
vec4 dataFromIndex(sampler2D x, int idx)
{
	int resBuffer = textureSize(x, 0)[0];
	vec2 samplePos = mapIdxToTexCoord(idx, resBuffer);

	return texture(x, samplePos);
}

// read neighbours index from connection buffer for index idx. 
// Remember mapping. One pixel stores up to 4 neighbour ids:
//     r0           g0          b0           a0            r1           g1          b1         ...
// neighbour 0, neighbour 1, neighbour 2, neighbour 3, neighbour 4, neighbour 5, neighbour 6,  ...
int idFromIndex(int idx, int channel)
{
	int resConnectionBuffer = textureSize(connectionBuffer, 0)[0];
	vec2 samplePos = mapIdxToTexCoord(idx, resConnectionBuffer);
	return int(texture(connectionBuffer, samplePos)[channel]);
}

// checks if there is a connection from point with idx source to point with idx target
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

// maps coordinate from camera to projection space
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

// maps coordinate from world to camera space
vec4 worldToProjSpace(vec4 worldPos)
{
	vec4 camSpacePos = uTDMat.cam * worldPos;
	
	return camToProjSpace(camSpacePos);
}

// draws triangle from points in vBuffer
void drawTriangle() {
	
	for (int i = 0; i < 3; i++) {
		oVert.worldSpacePos = vBuffer[i].worldSpacePos;
		oVert.coords = vBuffer[i].coords;
        oVert.color = vBuffer[i].color;
        oVert.fadeOutFac = vBuffer[i].fadeOutFac;
		oVert.width = vBuffer[i].width;
		gl_Position = worldToProjSpace(vec4(vBuffer[i].worldSpacePos, 1.0));
		EmitVertex();
	}
	
	EndPrimitive();
}

// calculates orthonormal vector of vector p0 -> p1 and view vector. This is used to give the connection lines actual "width".
vec3 calcScreenLineOrthonormal(vec3 p0, vec3 p1) {	
	vec3 camPos = uTDMat.camInverse[3].xyz;
	vec3 diffP = p1 - p0;
	vec3 diffCam = camPos - p0;
	vec3 norm = cross(diffP, diffCam);
	norm = normalize(norm);	
	
	return norm;
}

// calculate how "out of focus" point p0 is. Returns 0 if perfect in focus, 1 if at maximum blur distance.
float getDOFFac(vec3 p0) {
	vec3 focusPoint = vec3(uFocus.x, uFocus.y, uFocus.z);
    
    //map focus and p0 to camera space
	vec3 p0Cam = (uTDMat.cam * vec4(p0, 1.0)).xyz;
	vec3 focusCam = (uTDMat.cam * vec4(focusPoint, 1.0)).xyz;
	
	float l = abs(focusCam.z);
	float d = abs(p0Cam.z-focusCam.z);
	
	return clamp(d, 0, l) / l;
} 

// calculate how close to dying a point is and output fac in range [1..0]
float calcFadeOutFac(vec2 ageLifetime0, vec2 ageLifetime1) {
    float fadeOutTime = uData.w;
    
    float age0 = ageLifetime0.x;
    float age1 = ageLifetime1.x;
    // end = lifetime
    float end0 = ageLifetime0.y;
    float end1 = ageLifetime1.y;
    float start0 = end0-fadeOutTime;
    float start1 = end1-fadeOutTime;
    
    // how much "died" is a point
    float f0 = clamp((age0 - start0) / (end0 - start0), 0, 1);
    f0 = 1 - f0;
    float f1 = clamp((age1 - start1) / (end1 - start1), 0, 1);
    f1 = 1 - f1;
    
    return min(f0, f1);
}

// Draw rectangle stripe for point p0 and p1. pA-bF are helper points. Only calculate pM, pE and pF if 
// focus point "cuts" line somewhere between p0 and p1.
//
//                                                         pC      
//   pB                                               ------X      ^
//     X----\             pE                ---------/      |      |
//     |     --------\            ---------/                |      |
//     |              -----X-----/                          |      |
//     |                   |pM                              |      |
// p0  X-------------------X--------------------------------X p1   X widthVec
//     |                   |                                |      
//     |              -----X-----\                          |      
//     |     --------/    pF      ---------\                |      
//     X----/                               ---------\      |      
//    pA                                              ------X      
//                                                         pD      
//                      focus                                    
void drawRect(vec3 p0, vec3 p1, vec3 color0, vec3 color1, vec2 ageLifetime0, vec2 ageLifetime1) {
	
	float focalLength = uWidths.x / 100.;
	float screenWidth = uWidths.y / 100.;
    
    // calculate orthonormal vector of view and p0->p1 difference vector
	vec3 widthVec = calcScreenLineOrthonormal(p0, p1);
	vec3 diffVec = p1 - p0;
	
    // calculate dof factor for p0 and p1
	float d0 = getDOFFac(p0);
	float d1 = getDOFFac(p1);
	
	//above values, multiplied with user set focus width
	float D0 = d0 * focalLength; 
	float D1 = d1 * focalLength;
	
	vec3 pA, pB, pC, pD, pE, pF;
	vec3 coords[4];
	
	vec4 p0Cam = uTDMat.cam*vec4(p0, 1.0);
	vec4 p1Cam = uTDMat.cam*vec4(p1, 1.0);
	vec4 focusCam = uTDMat.cam*vec4(uFocus, 1.0);
	
	float fac = (focusCam.z - p0Cam.z) / (p1Cam.z - p0Cam.z);
    
    // calculate fading out
    float fadeOutFac = calcFadeOutFac(ageLifetime0, ageLifetime1);
	
	if (0.0 < fac && fac < 1.0) {
		vec3 pM = mix(p0, p1, fac);
        vec3 colorM = mix(color0, color1, fac);
		
		pA = pM + widthVec * (screenWidth);
		pB = pM - widthVec * (screenWidth);
		pC = p1 + widthVec * (screenWidth + D1);
		pD = p1 - widthVec * (screenWidth + D1);
		
		float lengths[3] = float[3](length(p1-pM), length(pB-pA), length(pD-pC));
		coords = vec3[4](pA, pB, pC, pD);
		
		vBuffer[0] = SVertex(pA, coords, colorM, fadeOutFac, screenWidth);
		vBuffer[1] = SVertex(pB, coords, colorM, fadeOutFac, screenWidth);
		vBuffer[2] = SVertex(pC, coords, color1, fadeOutFac, screenWidth);
			
		drawTriangle();
			
		vBuffer[0] = SVertex(pC, coords, color1, fadeOutFac, screenWidth);
		vBuffer[1] = SVertex(pD, coords, color1, fadeOutFac, screenWidth);
		vBuffer[2] = SVertex(pB, coords, colorM, fadeOutFac, screenWidth);
			
		drawTriangle();
		
		pE = p0 + widthVec * (screenWidth + D0);
		pF = p0 - widthVec * (screenWidth + D0);
		
		coords = vec3[4](pA, pB, pE, pF);
		lengths = float[3](length(p0-pM), length(pB-pA), length(pF-pE));
		
		vBuffer[0] = SVertex(pA, coords, colorM, fadeOutFac, screenWidth);
		vBuffer[1] = SVertex(pB, coords, colorM, fadeOutFac, screenWidth);
		vBuffer[2] = SVertex(pE, coords, color0, fadeOutFac, screenWidth);
			
		drawTriangle();
		
		vBuffer[0] = SVertex(pE, coords, color0, fadeOutFac, screenWidth);
		vBuffer[1] = SVertex(pF, coords, color0, fadeOutFac, screenWidth);
		vBuffer[2] = SVertex(pB, coords, colorM, fadeOutFac, screenWidth);
			
		drawTriangle();
		
	}
	else {	
		pA = p0 + widthVec * (screenWidth + D0);
		pB = p0 - widthVec * (screenWidth + D0);
		pC = p1 + widthVec * (screenWidth + D1);
		pD = p1 - widthVec * (screenWidth + D1);
			
		float lengths[3] = float[3](length(diffVec), length(pB-pA), length(pD-pC));
		coords = vec3[4](pA, pB, pC, pD);
				
		vBuffer[0] = SVertex(pA, coords, color0, fadeOutFac, screenWidth);
		vBuffer[1] = SVertex(pB, coords, color0, fadeOutFac, screenWidth);
		vBuffer[2] = SVertex(pC, coords, color1, fadeOutFac, screenWidth);
			
		drawTriangle();
			
		vBuffer[0] = SVertex(pC, coords, color1, fadeOutFac, screenWidth);
		vBuffer[1] = SVertex(pD, coords, color1, fadeOutFac, screenWidth);
		vBuffer[2] = SVertex(pB, coords, color0, fadeOutFac, screenWidth);
			
		drawTriangle();
	}
	
}

void main()
{	
	int nVertices = int(uData.x);
	int nConnections = int(uData.z);
	int edgeBlockSize = int(ceil(nConnections / 4.0));

	int idx = gl_PrimitiveIDIn;

	vec2 INIT = vec2(float(MAXINT), float(MAXINT));
	vec2 closest[MAXCONNECTIONS] = {INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT};
	
    // get point positions from index
	vec3 posSource = dataFromIndex(pointBuffer, idx).xyz;
    vec3 colSource = dataFromIndex(colBuffer, idx).xyz;
    vec2 ageLifetimeSource = dataFromIndex(ageLifetimeBuffer, idx).xy;
    vec3 posTarget = vec3(0.0);
    vec3 colTarget = vec3(0.0);
    vec2 ageLifetimeTarget = vec2(0.0);

	// for all possible connection
	for (int i = 0; i < nConnections; i++) {
		int block = int(floor(float(i) / 4.0));
		int channel = int(mod(i, 4)); 
		// id of ith "neighbour" vertex
		int target = idFromIndex(idx*edgeBlockSize+block,channel);
		
		// skip if not set
		if (target == MAXINT)
			break;
		
		if (idx < target || !existsEdge(target, idx, nConnections, edgeBlockSize)) {
            posTarget = dataFromIndex(pointBuffer, target).xyz;
            colTarget = dataFromIndex(colBuffer, target).xyz;
            ageLifetimeTarget = dataFromIndex(ageLifetimeBuffer, target).xy;
			drawRect(posSource, posTarget, colSource, colTarget, ageLifetimeSource, ageLifetimeTarget);
        }
	}
	
}