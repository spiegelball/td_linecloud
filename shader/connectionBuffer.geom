// (c) by Alexander Court / 2019
// Finds closest neighbours of every vertex (connections) and stores those connections in a pixel buffer.

#define MAXCONNECTIONS 10
#define MAXINT 100000

layout (points) in;

layout (points, max_vertices = 4) out;

uniform vec4 uData;
uniform vec4 uSize;
// buffer containing the vertex positions
uniform sampler2D sPosBuffer;

out vec4 vFragColor;

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
// norm: map to -1..1 range if true, 0..1 otherwise
// 
// return coords
vec2 getTexPos(int idx, int res, bool norm)
{
	float xPixel = mod(idx,res); 
	float yPixel = floor(float(idx)/float(res));
	
	if (norm) {
		xPixel+=1;
		yPixel+=1;
	}
	
    // map to 0..1 range
	xPixel = xPixel/float(res);
	yPixel = yPixel/float(res);
	
	if (norm) {
        // map to -1..1 range
		xPixel = (xPixel*2)-1.0;
		yPixel = (yPixel*2)-1.0;
	}
	
	return vec2(xPixel, yPixel);
}

// sample vertex position from vertex buffer
vec4 posFromIndex(int idx)
{
	int resPosBuffer = textureSize(sPosBuffer, 0)[0];
    // get coordinates associated with index in vertex buffer
	vec2 samplePos = getTexPos(idx, resPosBuffer, false);
    //return pixel value for those coordinates (position of the vertex) rgb -> xyz
	return texture(sPosBuffer, samplePos);
}
// shift values in array to the right beginning at index idx. last value of the array is dropped.
// [a,b,c,d,e] -> [a,a,b,c,d] (for idx=0)
//
// idx: index from where to start shifting
// data: array
void shiftFromIndex(int idx, inout vec2[MAXCONNECTIONS] data) {
	for (int i = data.length()-1; i > idx; i--) {
		data[i].x = data[i-1].x;
		data[i].y = data[i-1].y;
	}	
}

// computes closest neighbours of a vertex and store them in a queue sorted by distance.
//
// idx: index of vertex
// data: array of form [(idx_0, distance0), (idx_1, distance1), (idx_2, distance2), ...] which stores neighbours

void closestPoints(int idx, inout vec2[MAXCONNECTIONS] data) {
    //total number of vertices in mesh
	int nVertices = int(uData.x);
    //number of neighbours to find
	int nConnections = int(uData.y);
    
    // neighbours must lie in this distance range from vertex
	float minDist = uData.z;
	float maxDist = uData.w;
	
    //position of current vertex
	vec3 currPos = posFromIndex(idx).xyz;
	
	// calculate distance to every vertex in the mesh. If distance is lower than distance to an already marked 
    // neighbour make "entry" in list. Discard entries with larger distance in case of full list.
	for (int i = 0; i < nVertices; i++) {
		// don't compare vertex to itself
        if (i != idx) {
            // position of vertex i
			vec3 pos = posFromIndex(i).xyz;
            // distance of vertex idx to vertex i
			float dis = distance(currPos, pos);
            
            // if vertex is in allowed distance
            if (minDist <= dis && dis <= maxDist) {
                // compare distance of current vertex to already found neighbours.
                for (int j = 0; j < MAXCONNECTIONS; j++) {
                    // if distance is smaller...
                    if ( dis < data[j].y) {
                        // shift array to maintain order
                        shiftFromIndex(j, data);
                        // make new entry (i, dis) in neighbour list
                        data[j].x = float(i);
                        data[j].y = dis;
                        break;
                    }
                }
            }
		}
	}
}

void main()
{		
	int idx = gl_PrimitiveIDIn;
    // number of closest neighbours to find
	int nConnection = int(uData.y);
    // dimension of the connection buffer
	int resOut = int(uSize.x);
	
	// how many pixels (connection blocks) are needed to store connection infos for one vertex. One rgba pixel stores // 4 connections since every rgba channel can hold one index.
    // if we store 10 connections, we need 3 pixels, since 3*4 >= 10. 
	int nConnectionBlocks = int(ceil(float(nConnection) / 4.0));
	
    // init values for neighour list with (almost ;P) infinite.
	vec2 INIT = vec2(float(MAXINT), float(MAXINT));
	vec2 closest[MAXCONNECTIONS] = {INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT,INIT};
	
    // fill neighbours list.
    closestPoints(idx, closest);
	
    vec4 color;
    // create and emit all pixels storing neighbours for vertex. 
	for (int i = 0; i < nConnectionBlocks; i++)
	{
		color = vec4(vec3(0.0),1.0);
		
		for (int j = 0; j < 4; j++) {
			int closestIdx = i*4+j;
            // if all neighbours processed, terminate outer loop
			if (closestIdx >= nConnection) 
				break;
			
            // index of current neighbour
			int targetIdx = int(closest[closestIdx].x);
            
            // set current pixel channel to index of current neighbour
			color[int(mod(j, 4))] = float(targetIdx);
		}
		
		// position of vertex to emit in connection buffer		
		vec2 screenPos = getTexPos(idx*nConnectionBlocks+i, resOut, true);
		gl_Position = vec4(screenPos.x, screenPos.y,0.0,1.0);
        // set color
		vFragColor = vec4(color);
		EmitVertex();
	}
}