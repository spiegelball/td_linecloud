// (c) by Alexander Court / 2019
// Store vertex info from mesh in pixel buffer. This is done by rendering vertices positions
// to pixel colors. For every vertex a pixel is rendered where the rgb values correspond
// to x, y and z position of the vertex. AAAs

layout (points) in;

layout (points, max_vertices = 1) out;

uniform vec4 uData;

in vec3 vColor[];

out vec4 vEncodedPos;
out vec3 gColor;
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
	float xPixel = mod(idx,res)+1; 
	float yPixel = floor(float(idx)/float(res))+1;
	
    // map to 0..1 range
	xPixel = xPixel/float(res);
	yPixel = yPixel/float(res);
	
    // map to -1..1 range
	xPixel = (xPixel*2)-1.0;
	yPixel = (yPixel*2)-1.0;
	
	return vec2(xPixel, yPixel);
}

void main()
{		
	int idx = gl_PrimitiveIDIn;
	int res = int(uData.x);
    
    //calculate position of vertex in output buffer
	vec2 screenPos = mapIdxToTexCoord(idx, res);
    //get vertex position
	vec4 p = gl_in[0].gl_Position;
	
    //color pixel according to the vertex' position
	vEncodedPos = vec4(p.x, p.y, p.z, 1.0);
    //set position of the rendered pixel in buffer
	gl_Position = vec4(screenPos.x, screenPos.y,1.0,1.0);
    gColor = vColor[0];
	
    EmitVertex();
	
	EndPrimitive();
}