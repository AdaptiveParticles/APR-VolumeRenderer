out vec4 FragColor;
uniform vec2 viewportSize;
uniform vec2 dsp;
uniform mat4 ipv;
uniform float fwnw;
uniform float nw;

uniform sampler3D volumeCache;

// -- comes from CacheSpec -----
uniform vec3 blockSize;
uniform vec3 paddedBlockSize;
uniform vec3 cachePadOffset;

// -- comes from TextureCache --
uniform vec3 cacheSize; // TODO: get from texture!?

void main()
{
	// frag coord in NDC
	vec2 uv = 2 * ( gl_FragCoord.xy + dsp ) / viewportSize - 1;

	// NDC of frag on near and far plane
	vec4 front = vec4( uv, -1, 1 );
	vec4 back = vec4( uv, 1, 1 );

	// calculate eye ray in world space
	vec4 wfront = ipv * front;
	wfront *= 1 / wfront.w;
	vec4 wback = ipv * back;
	wback *= 1 / wback.w;

	// -- bounding box intersection for all volumes ----------
	float tnear = 1, tfar = 0, tmax = getMaxDepth( uv );
	float n, f;

	// $repeat:{vis,intersectBoundingBox|
	bool vis = false;
	intersectBoundingBox( wfront, wback, n, f );
	f = min( tmax, f );
	if ( n < f )
	{
		tnear = min( tnear, max( 0, n ) );
		tfar = max( tfar, f );
		vis = true;
	}
	// }$

	// -------------------------------------------------------


	if ( tnear < tfar )
	{
		vec4 fb = wback - wfront;
		int numSteps =
			( fwnw > 0.00001 )
			? int ( log( ( tfar * fwnw + nw ) / ( tnear * fwnw + nw ) ) / log ( 1 + fwnw ) )
			: int ( trunc( ( tfar - tnear ) / nw + 1 ) );

		float step = tnear;
		vec4 v = vec4( 0 );
		for ( int i = 0; i < numSteps; ++i, step += nw + step * fwnw )
		{
			vec4 wpos = mix( wfront, wback, step );
			// $repeat:{vis,blockTexture,convert|
			if ( vis )
			{
				float x = blockTexture( wpos, volumeCache, cacheSize, blockSize, paddedBlockSize, cachePadOffset );
				v = max( v, convert( x ) );
			}
			// }$
		}
		FragColor = v;
	}
	else
		FragColor = vec4( 0, 0, 0, 0 );
}
