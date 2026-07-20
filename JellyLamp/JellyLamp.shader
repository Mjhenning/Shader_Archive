//---------------------------------------------------------
// Jelly Lamp
//
// Raymarched Signed Distance Field (SDF) lava lamp.
//
// Rather than modelling the liquid with geometry, the lava is represented as a Signed Distance Field composed from multiple simple SDF primitives.
//
// The liquid volume consists of:
//
// • Animated metaball blobs
// • A deformable bottom reservoir
// • A deformable top reservoir
// • Smooth SDF blending between every component
// • A capsule-shaped container that constrains the liquid
//
// Every pixel casts a ray into the SDF. The ray marches until it reaches the liquid surface, where the surface normal is estimated numerically and used for lighting.
//
// Originally based on TanukiVR's Lava Lamp shader, itself based on Luftprut's original implementation.
//
// Expanded into a fully procedural lava simulation by F0XTA1L.
//---------------------------------------------------------


Shader "F0XTA1L/JellyLamp" {
	Properties{
		
		[Header(Shell)]
		_TopColor("Top Color", Color) = (0.2,0.6,1,1)
		_BottomColor("Bottom Color", Color) = (0.6,1,0.9,1)

		_RimColor("Rim Color", Color) = (0.4,1,1,1)
		_RimPower("Rim Power", Range(0.5,8)) = 4
		_RimStrength("Rim Strength", Range(0,3)) = 1.2

		_HighlightStrength("Top Highlight", Range(0,3)) = 1.2
		_HighlightSize("Highlight Size", Range(0.1,2)) = 0.8

		_BumpMap("Normal Map",2D)="bump"{}
		_Distortion("Normal Strength",Range(0,1))=0.2

		_SpecuColor("Specular Color",Color)=(1,1,1,1)
		_Shininess("Shininess",Range(8,128))=32

		_Alpha("Glass Alpha",Range(0,1))=0.55
		_RefractionStrength("Glass Refraction", Range(0,0.2)) = 0.04
		
		_GlassTint("Glass Tint", Color) = (0.85,1,1,1)
		
		[Header(Appearance)]
		[HDR]_LavaColor("Lava Color", Color) = (1,1,1,1)
		_Glow("Glow Multiplier", Range(0, 10)) = 1
		_LiquidGlow("Liquid Glow Multiplier", Range(0,10)) = 0
		
		[Space(10)]
		[Header(Material)]
		_Glossiness("Smoothness", Range(0,1)) = 0.9
		_Metallic("Metallic", Range(0,1)) = 0
		
		[Space(10)]
		[Header(Container)]
		_ContainerCenter("Center", Vector) = (0,0,0,0)
		_ContainerSize("Size (XYZ)", Vector) = (0.45,1.2,0.45,0)
		_ContainerRoundness("End Radius", Float) = 0.45
		_BottomFill("Bottom Fill", Range(0,1)) = 0.05
		_TopFill("Top Fill", Range(0,1)) = 0.95
		
		[Space(10)]
		[Header(Blobs)]
		_BlobCount("Blob Count", Range(1,32)) = 12
		_MinBlobRadius("Minimum Blob Radius", Range(0.02,0.5)) = 0.08
		_MaxBlobRadius("Maximum Blob Radius", Range(0.02,0.5)) = 0.22
		
		// How far blobs are allowed to wander from the center.
		_BlobSpread("Horizontal Spread", Range(0.2,1.0)) = 0.95
		
		_BlobWobble("Blob Wobble", Range(0,0.15)) = 0.05
		
		// Amount each blob slowly expands/contracts over time.
		_BlobPulse("Blob Pulse", Range(0,0.5)) = 0.18
		
		_BlobLifetimeFade("Blob Lifetime Fade", Range(0.01,0.4)) = 0.12
		
		[Header(Motion)]
		_LavaScrollSpeed("Lava Scroll Speed", Float) = 0.1
		_BlobSpeed("Blob Speed", Range(0.05,3)) = 1
		
		// Random per-blob speed multiplier.
		// 0 = every blob moves together.
		// 1 = each blob has an independent speed.
		_BlobSpeedVariation("Speed Variation", Range(0,1)) = 0.3
		
		// Radius of the top and bottom lava reservoirs.
		_PoolSize("Top/Bottom Pool Size", Range(0,1)) = 0.32
		
		[Space(10)]
		[Header(Advanced)]
		_LavaAttenuation("Internal Fog Density", Float) = 4
		_Seed("Object Seed", Range(0.001, 1)) = 1
		[KeywordEnum(None, Polynomial, Exponential)] _SDFSmoothing("SDF Smoothing", Float) = 1

	}
		SubShader{
			Tags
			{
			    "Queue"="Transparent"
			    "RenderType"="Transparent"
			    "DisableBatching"="True"
			}

			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite On
			Cull Back
			LOD 200

			CGPROGRAM
			#pragma surface surf Standard fullforwardshadows vertex:vert alpha
			#pragma target 3.0
			#pragma shader_feature _ _SDFSMOOTHING_POLYNOMIAL _SDFSMOOTHING_EXPONENTIAL

		// Higher = quality, lower = performance
		#define RAY_STEPS 24
		// Small constant for gradients calculation
		#define EPSILON 0.001
		// How fast does ray converge on surface (i.e. percentage of distance to move each step)
		#define STRIDE 0.99

		struct Input
		{
		    float3 objViewDir;
		    float4 objPos;

		    float2 uv_BumpMap;

		    float3 worldPos;
		    float3 worldNormal;
		    INTERNAL_DATA
		};

		// [Header(Appearance)]
		fixed4 _LavaColor;
		float _Glow;
		float _LiquidGlow;
			
			fixed4 _TopColor;
			fixed4 _BottomColor;

			fixed4 _RimColor;
			float _RimPower;
			float _RimStrength;

			float _HighlightStrength;
			float _HighlightSize;

			sampler2D _BumpMap;
			float _Distortion;

			fixed4 _SpecuColor;
			float _Shininess;

			float _Alpha;
			float _RefractionStrength;
			fixed4 _GlassTint;
			
		// [Space(10)]
		// [Header(Material)]		
		half _Glossiness;
		half _Metallic;
			
		// [Space(10)]
		// [Header(Container)]
		float4 _ContainerCenter;
		float4 _ContainerSize;
		float _ContainerRoundness;
		float _BottomFill;
		float _TopFill;
			
		// [Space(10)]
		// [Header(Blobs)]
		float _BlobCount;
		float _MinBlobRadius;
		float _MaxBlobRadius;
		float _BlobSpread;
		float _BlobWobble;
		float _BlobPulse;
		float _BlobLifetimeFade;
			
		// [Space(10)]
		// [Header(Motion)]
		float _LavaScrollSpeed;	
		float _PoolSize;
		float _BlobSpeed;
		float _BlobSpeedVariation;
			
		// [Space(10)]
		// [Header(Advanced)]	
		float _LavaAttenuation;
		float _Seed;

#if _SDFSMOOTHING_EXPONENTIAL
		// Exponential smooth min
		#define K 16
		float smin(float a, float b)
		{
			float res = exp2(-K * a) + exp2(-K * b);
			return -log2(res) / K;
		}
#elif _SDFSMOOTHING_POLYNOMIAL
		// Polynomial smooth min (faster)
		#define K 0.35
		float smin(float a, float b)
		{
			float h = saturate(0.5 + 0.5 * (b - a) / K);
			return lerp(b, a, h) - K * h * (1.0 - h);
		}
#else
		// No smoothing (fastest)
		#define smin(a,b) min(a,b)
#endif

		// Simple deterministic pseudo-random number generator.
		// Used to give each blob unique movement characteristics.
		float hash(float n)
		{
		    return frac(sin(n) * 43758.5453123);
		}
			
		float sdf_lavaLamp(float3 objSpacePos)
		{
			float sdf_balls = 1000.0;
			
			//--------------------------------------------
			// Container dimensions
			//--------------------------------------------
			//
			// Convert the sample point into the lamp's local coordinate system and calculate the usable lava region.
			//
			// The fill percentages define where the upper and lower lava reservoirs are positioned inside the glass container.
				
			float3 localPos = objSpacePos - _ContainerCenter.xyz;
				
			float containerHeight = _ContainerSize.y;

			float minY = lerp(-containerHeight,containerHeight,_BottomFill);

			float maxY = lerp(-containerHeight,containerHeight,_TopFill);
			
			//--------------------------------------------
			// Static lava reservoirs
			//--------------------------------------------
			//
			// The original Tanuki shader terminated the lava using two flat clipping planes.
			//
			// This version instead represents both reservoirs as flattened metaballs (compressed spheres).
			//
			// Because reservoirs and blobs are all SDFs,
			// they can blend together using smooth-min.
			// This produces rounded pools that naturally
			// absorb and release blobs instead of relying
			// on hard clipping.

			float3 bottomPoolPos = localPos;
			bottomPoolPos.y = (bottomPoolPos.y - minY) * 4.5;

			float bottomPool = length(bottomPoolPos) - _PoolSize;
			
			
			float3 topPoolPos = localPos;
			topPoolPos.y = (topPoolPos.y - maxY) * 4.5;

			float topPool = length(topPoolPos) - _PoolSize;
			
			
			//--------------------------------------------
			// Animated blobs
			//--------------------------------------------
			//
			// Each blob is generated procedurally from its integer ID.
			//
			// No blob positions are stored.
			//
			// Instead, every property (position, speed,
			// radius, wobble, drift, phase, etc.) is
			// deterministically generated from a hash
			// function and the user supplied seed.
			//
			// This guarantees identical behaviour every
			// frame while avoiding large arrays or CPU-side
			// animation.
			
			for(int i = 0; i < 32; i++)
			{
			    if(i >= _BlobCount) break;

			    float id = i + 1;

				//-----------------------------------
				// 1. Generate blob parameters
				//-----------------------------------
				//
				// Every blob receives its own deterministic pseudo-random properties derived from its ID.
				//
				// These values remain stable over time, giving
				// each blob a unique "personality" without
				// requiring any stored simulation state.

			    float angle = hash(id * 7.1 + _Seed) * 6.2831853;

			    float radial = sqrt(hash(id * 11.3 + _Seed));

			    float horizontalRadius = min(_ContainerSize.x, _ContainerSize.z);

				float spread = (horizontalRadius-_MaxBlobRadius) * _BlobSpread * radial;

			    float x = cos(angle) * spread;
				float z = sin(angle) * spread;

				//-----------------------------------
				// 2. Animate vertical movement
				//-----------------------------------
				//
				// Blob movement is driven by a sine wave instead of a looping lifetime.
				//
				// Unlike spawn/despawn systems, sine motion is
				// continuous and never teleports blobs back to
				// the bottom of the lamp.
				//
				// Applying smoothstep reshapes the sine wave so
				// blobs linger near the reservoirs while moving
				// more quickly through the middle of the lamp,
				// producing a more convincing buoyancy effect.

				float randomSpeed = lerp(1.0, lerp(0.5, 1.5, hash(id * 13.7 + _Seed)), _BlobSpeedVariation);

				float speed = _BlobSpeed * randomSpeed;

			    float phase = hash(id * 17.9 + _Seed);

				float spawnDelay = hash(id * 41.3 + _Seed);

				float cycle = _Time.y * _LavaScrollSpeed * speed * 6.2831853 + hash(id * 51.7 + _Seed) * 6.2831853;

				float travel = 0.5 + 0.5 * sin(cycle);

				// Ease the sine wave so blobs spend longer near the reservoirs and accelerate through the center of the lamp.
				travel = smoothstep(0.0,1.0,travel);

				float y = lerp(minY,maxY,travel);
				
				//-----------------------------------
				// 3. Apply horizontal drift
				//-----------------------------------
				//
				// Real lava blobs rarely travel in perfectly vertical lines.
				//
				// Each blob slowly orbits around its original
				// position using a low-frequency circular drift,
				// helping prevent repetitive motion.

				float driftSpeed = lerp(0.08,0.25,hash(id * 19.3 + _Seed)) * speed;

				float driftRadius = spread * 0.35;

				float driftAngle =
				    _Time.y * driftSpeed +
				    hash(id * 83.1 + _Seed) * 6.2831853;

				x += cos(driftAngle) * driftRadius;
				z += sin(driftAngle) * driftRadius;
				
				//-----------------------------------
				// 4. Apply wobble
				//-----------------------------------
				//
				// Small independent oscillations are added on top of the drift.
				//
				// This breaks up perfectly circular movement,
				// making the blobs feel softer and more organic.

				float wobbleSpeed = lerp(0.6,1.6,hash(id * 31.7 + _Seed)) * speed;

				float wobbleAmount = lerp(0.6,1.3,hash(id * 27.1 + _Seed)) * _BlobWobble;

				x += sin(_Time.y * wobbleSpeed + phase * 9.1) * wobbleAmount;

				z += cos(_Time.y * wobbleSpeed * 0.8 + phase * 12.7) * wobbleAmount;
				
				
				//-----------------------------------
				// 5. Calculate blob radius
				//-----------------------------------
				//
				// Every blob receives a unique base size.
				//
				// A slow pulse is then applied so blobs gently
				// inflate and contract over time, imitating the
				// changing pressure seen in real lava lamps.

			    float radius = lerp(_MinBlobRadius, _MaxBlobRadius, hash(id * 23.8 + _Seed));

			    float pulse = 1.0 + sin(_Time.y * speed * 2.0 + phase * 6.2831853) * _BlobPulse;

			    pulse = max(0.5, pulse);

			    radius *= pulse;
				
				//-----------------------------------
				// 6. Constrain to container
				//-----------------------------------
				//
				// Horizontal movement is clamped so the entire blob remains inside the glass.
				//
				// Larger blobs therefore receive a slightly
				// smaller movement radius than smaller blobs.
				
				float maxRadius = horizontalRadius - radius * 0.75;

				float horizontalDistance = length(float2(x,z));

				if(horizontalDistance > maxRadius)
				{
				    float2 dir = float2(x,z) / horizontalDistance;

				    x = dir.x * maxRadius;
				    z = dir.y * maxRadius;
				}
				
				
				//-----------------------------------
				// 7. Blend into top/bottom reservoirs
				//-----------------------------------
				//
				// Rather than allowing blobs to simply intersect
				// the reservoirs, nearby blobs temporarily deform
				// them.
				//
				// As a blob approaches either reservoir, a second
				// flattened metaball is projected into that pool.
				// Because both shapes are merged using smooth-min,
				// the reservoir grows upward to meet the blob.
				//
				// This creates the illusion that blobs emerge
				// from, and dissolve back into, the liquid
				// reservoir instead of suddenly appearing or
				// disappearing.
				//
				// The influence fades with distance so only blobs
				// close to a reservoir affect its shape.
				
				float poolInfluence = smoothstep(radius * 3.0, radius, abs(y - minY));
				
				float3 poolBlobPos = localPos - float3(x, minY, z);

				// Compress vertically so blobs deform the pool without creating tall spikes.
				poolBlobPos.y *= 3.5;

				float poolBlob = length(poolBlobPos) - (_PoolSize + radius * 0.55 * poolInfluence);

				bottomPool = smin(bottomPool, poolBlob);
				
				float topInfluence = smoothstep(radius * 3.0, radius, abs(y - maxY));

				float3 topBlobPos = localPos - float3(x, maxY, z);

				topBlobPos.y *= 3.5;

				float topBlob = length(topBlobPos) - (_PoolSize + radius * 0.55 * topInfluence);

				topPool = smin(topPool, topBlob);

				//-----------------------------------
				// 8. Stretch blob
				//-----------------------------------
				//
				// Blobs become vertically elongated as they approach either reservoir.
				//
				// Stretching occurs by scaling object space before
				// evaluating the sphere SDF rather than modifying
				// the sphere itself, preserving smooth blending.
				//
				// This mimics the characteristic necking seen
				// when real lava separates from the pool.

				float3 blobPos = localPos - float3(x, y, z);

				float bottomStretch = 1.0 - smoothstep(0.0,0.35,travel);

				float topStretch = smoothstep(0.65,1.0,travel);

				float stretchAmount = max(bottomStretch, topStretch);

				float stretch = lerp(1.0,1.8,stretchAmount);

				blobPos.y /= stretch;

				float blobDistance = length(blobPos) - radius;
				
				//-----------------------------------
				// 9. Merge into the liquid SDF
				//-----------------------------------
				//
				// Each blob contributes to a single signed distance field.
				//
				// Smooth-min is used instead of a normal minimum
				// so neighbouring blobs merge together into a
				// continuous liquid volume.

			    sdf_balls = smin(sdf_balls, blobDistance);
			}
			
			//--------------------------------------------
			// Merge all liquid components
			//--------------------------------------------
			//
			// Combine:
			//
			// • Animated blobs
			// • Bottom reservoir
			// • Top reservoir
			//
			// into one continuous signed distance field.
			
			float distance = sdf_balls;
			distance = smin(distance, bottomPool);
			distance = smin(distance, topPool);
			
			//--------------------------------------------
			// Constrain the liquid to the container
			//--------------------------------------------
			//
			// The final liquid SDF is intersected with a capsule-shaped container.
			//
			// This prevents blobs and reservoirs from
			// expanding through the glass while allowing the
			// container shape to be adjusted independently
			// from the liquid simulation.
			
			float3 containerPos = localPos;

			float radius = _ContainerRoundness;

			float halfHeight = max(_ContainerSize.y - radius,radius);

			float y = clamp(containerPos.y,-halfHeight,halfHeight);

			float3 normalizedPos = containerPos - float3(0,y,0);

			// Elliptical cross section
			normalizedPos.x /= _ContainerSize.x;
			normalizedPos.z /= _ContainerSize.z;

			float container = length(float3(normalizedPos.x, normalizedPos.y / radius, normalizedPos.z)) - 1.0;

			distance = max(distance, container);
			return distance;
		}

		// Estimate the SDF normal using finite differences.
		// This is used for lighting the raymarched surface.
		float3 gradient_lavaLamp(float3 objSpacePos)
		{
			float3 dx = float3(EPSILON, 0, 0);
			float3 dy = float3(0, EPSILON, 0);
			float3 dz = float3(0, 0, EPSILON);

			float dist0 = sdf_lavaLamp(objSpacePos);

			return float3(sdf_lavaLamp(objSpacePos + dx) - dist0,sdf_lavaLamp(objSpacePos + dy) - dist0,sdf_lavaLamp(objSpacePos + dz) - dist0);
		}

		// Sphere-trace through the SDF until we converge on the liquid surface.
		float3 raycastToLavaSurface(float3 objSpaceRayStart, float3 objSpaceRayDirection)
		{
			float3 rayPos = objSpaceRayStart;
			for (int i = 0; i < RAY_STEPS; i++)
			{
				float distance = sdf_lavaLamp(rayPos);
				rayPos += distance * objSpaceRayDirection * STRIDE;
			}
			return rayPos;
		}

		void vert(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.objPos = v.vertex;
			o.objViewDir = ObjSpaceViewDir(v.vertex);
		}

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			// Standard surface properties
			float3 normalTex =UnpackNormal(tex2D(_BumpMap,IN.uv_BumpMap));
			normalTex.xy *= _Distortion;
			o.Normal = normalTex;
			
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;

			
			// Lava lamp effect sampling
			float3 viewDirNormalized =-normalize(IN.objViewDir);

			float3 worldNormal =WorldNormalVector(IN, o.Normal);

			// convert world normal into object space
			float3 objectNormal = normalize(mul((float3x3)unity_WorldToObject,worldNormal));

			viewDirNormalized = normalize(refract(viewDirNormalized,objectNormal,1.0 - _RefractionStrength));
			float3 lavaSurfacePos = raycastToLavaSurface(IN.objPos, viewDirNormalized);
			float3 lavaSurfaceNormal = normalize(gradient_lavaLamp(lavaSurfacePos));

			// Lava lamp effect shading
			float attenuation = exp(_LavaAttenuation * length(lavaSurfacePos - IN.objPos));
			float lavaShaded = saturate(dot(-viewDirNormalized, lavaSurfaceNormal) * 0.5 + 0.5);

			float3 viewDir =normalize(UnityWorldSpaceViewDir(IN.worldPos));
			float rim =pow(1 -saturate(dot(worldNormal,viewDir)),_RimPower);
			float3 rimLight =_RimColor.rgb *rim *_RimStrength;
			
			//Alpha
			float fresnel =pow(1.0 - saturate(dot(worldNormal,viewDir)),4.0);
			o.Alpha =saturate(_Alpha +fresnel * 0.25);
			
			float3 up = float3(0,1,0);

			float highlight =pow(saturate(dot(worldNormal, up)),10);
			highlight *= _HighlightSize;
			float3 highlightColor =highlight *_HighlightStrength;
			
			float3 lightDir =normalize(_WorldSpaceLightPos0.xyz);
			float3 halfDir =normalize(lightDir +viewDir);
			float spec =pow(max(0,dot(worldNormal,halfDir)),_Shininess);
			float3 specular =spec *_SpecuColor.rgb;
			
			float localHeight = (IN.objPos.y + _ContainerSize.y) / (_ContainerSize.y * 2.0);
			float height = saturate(localHeight);
			
			float3 gradient =lerp(_BottomColor.rgb,_TopColor.rgb,height);
			o.Albedo =gradient+ rimLight+ highlightColor+ specular;
			
			float3 lavaEmission =_LavaColor.rgb *_GlassTint.rgb *(lavaShaded / attenuation) *_Glow;
			
			float innerGlow = exp(-attenuation * 0.35);

			lavaEmission +=_LavaColor.rgb * innerGlow * 0.5;

			float glassVisibility = 1.0 - fresnel;

			o.Emission = lavaEmission * glassVisibility;
			o.Emission +=gradient *_LiquidGlow;
		}
		ENDCG
	}
		FallBack "Standard"
}


//---------------------------------------------------------
// Version History
//
// v1.0.0
// • Initial release.
// • Expanded TanukiVR's lava lamp shader into a fully procedural
//   SDF-based lava simulation.
// • Added configurable blob generation.
// • Added configurable container geometry.
// • Replaced spawn/despawn motion with continuous sine movement.
// • Added rounded top and bottom reservoirs.
// • Added dynamic reservoir deformation.
// • Added blob speed controls and per-blob variation.
// • Improved glass rendering and material controls.
// • Increased blob count from 16 to 32.
// • Refactored and documented the shader for future development.
//---------------------------------------------------------
