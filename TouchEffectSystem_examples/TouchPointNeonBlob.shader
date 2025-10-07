Shader "UI/TouchPointNeonBlob"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 2.0
        
        // Core animation properties
        [Toggle] _Scaling ("Disappearing Scaling", Float) = 1
        [Toggle] _Fading ("Disappearing Fading", Float) = 1

        // Blob ring appearance properties - configurable by designers
        _RingColor ("Ring Color", Color) = (0, 0.5, 1, 1)
        _RingRadius ("Ring Radius", Range(0, 0.45)) = 0.3
        _RingThickness ("Ring Thickness", Range(0, 0.2)) = 0.03
        _RingOpacity ("Ring Opacity", Range(0.0, 1.0)) = 0.8
        
        // Organic shape generation properties
        _BlobVariation ("Blob Variation", Range(0.0, 1.0)) = 0.3
        _BlobComplexity ("Blob Complexity", Range(2, 8)) = 4
        _ShapeVariety ("Shape Variety", Range(1.0, 20.0)) = 5.0
        
        // Glow effect properties
        _InnerGlowIntensity ("Inner Glow Intensity", Range(0.0, 3.0)) = 1.0
        _InnerGlowSize ("Inner Glow Size", Range(0.01, 0.1)) = 0.03
        _OuterGlowIntensity ("Outer Glow Intensity", Range(0.0, 3.0)) = 1.5
        _OuterGlowSize ("Outer Glow Size", Range(0.01, 0.1)) = 0.1
        _GlowColor ("Glow Color", Color) = (0.3, 0.7, 1, 1)
        
        // Platform optimization and touch behavior properties
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
        // UI transparency rendering configuration
        Tags 
        { 
            "RenderType"="Transparent" 
            "Queue"="Transparent" 
            "IgnoreProjector"="True"
        }
        
        // Standard alpha blending setup for UI elements
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off
        ZTest LEqual

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #include "UnityCG.cginc"

            // Vertex input data structure
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            // Vertex to fragment data transfer structure
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            // Shader property declarations matching Properties block
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _TimeNow;
            float _StartTime;
            float _Lifetime;
            fixed4 _RingColor;
            float _RingRadius;
            float _RingThickness;
            float _RingOpacity;
            float _BlobVariation;
            float _BlobComplexity;
            float _ShapeVariety;
            float _InnerGlowIntensity;
            float _InnerGlowSize;
            float _OuterGlowIntensity;
            float _OuterGlowSize;
            fixed4 _GlowColor;
            float _UseMobileOptimization;
            float _Scaling, _Fading;

            // Optimized pseudo-random number generator for blob shape variation
            // Uses fast mathematical properties for consistent cross-platform results
            float noise(float2 p)
            {
                return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Optimized blob shape generation function
            // Creates organic deformation of circular ring using time-based random parameters
            float blobDistance(float2 p)
            {
                // Generate consistent random seed from quantized particle creation time
                float seed = floor(_StartTime * _ShapeVariety) * 200.0 / _ShapeVariety;
                
                // Convert to polar coordinates for radial deformation
                float angle = atan2(p.y, p.x);
                float radius = length(p);
                
                // Precompute random deformation parameters to avoid repeated noise() calls
                float2 seedOffsets1 = float2(seed + 1.0, seed + 2.0);
                float2 seedOffsets2 = float2(seed + 3.0, seed + 4.0);
                float2 seedOffsets3 = float2(seed + 5.0, seed + 6.0);
                
                // Generate random frequencies and phases for organic shape variation
                float freq1 = floor(2.0 + noise(seedOffsets1) * 4.0);
                float freq2 = floor(3.0 + noise(seedOffsets2) * 3.0);
                float phase1 = noise(seedOffsets3) * 6.28318;
                float phase2 = noise(seedOffsets1.yx) * 6.28318;
                
                // Calculate deformation amplitudes with variation control
                float2 ampNoise = float2(noise(seedOffsets2.yx), noise(seedOffsets3.yx));
                float2 amplitudes = (float2(0.7, 0.5) + ampNoise * float2(0.3, 0.5)) * _BlobVariation;
                
                // Apply organic deformations using optimized sine calculations
                float deformation = sin(angle * freq1 + phase1) * amplitudes.x * 0.2 + 
                                   sin(angle * freq2 + phase2) * amplitudes.y * 0.15;
                
                // Combine base shape with deformation and clamp to prevent artifacts
                float blobShape = clamp(1.0 + deformation, 0.6, 1.4);
                
                return radius / blobShape;
            }

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // Main fragment shader - generates animated neon blob effect with edge lighting
            fixed4 frag (v2f i) : SV_Target
            {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                // Early exit prevents rendering expired particles
                float age = (_TimeNow - _StartTime) / _Lifetime;
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === COORDINATE SYSTEM SETUP ===
                // Convert UV coordinates to center-based system for distance calculations
                float2 offset = i.uv - 0.5;
                float distanceFromCenter = blobDistance(offset);
                
                // === SIZE SCALING OVER LIFETIME ===
                // Apply subtle shrinking animation as particle ages
                float sizeScale = 1.0 - age * 0.3;
                if(_Scaling == 0)
                {
                    sizeScale = 1;
                }      
                float scaledRadius = _RingRadius * sizeScale;
                float halfThickness = _RingThickness * 0.5 * sizeScale;
                
                // === BLOB RING BOUNDARIES ===
                // Define inner and outer edges of the deformed ring
                float ringInner = scaledRadius - halfThickness;
                float ringOuter = scaledRadius + halfThickness;
                
                // === BASE RING GENERATION ===
                // Create main blob ring with smooth anti-aliased edges
                float ringMask = smoothstep(ringInner - 0.01, ringInner, distanceFromCenter) * 
                                (1.0 - smoothstep(ringOuter, ringOuter + 0.01, distanceFromCenter));
                
                // === OPTIMIZED GLOW SYSTEM ===
                // Calculate both inner and outer glow without conditional branching
                
                // Inner glow calculation - extends inward from ring edge
                float innerDistance = max(0.0, ringInner - distanceFromCenter);
                float innerFalloff = innerDistance / max(_InnerGlowSize, 0.001);
                float innerGlow = exp(-innerFalloff) * _InnerGlowIntensity * 
                                 smoothstep(ringInner, ringInner - _InnerGlowSize, distanceFromCenter) *
                                 step(distanceFromCenter, ringInner);
                
                // Outer glow calculation - extends outward from ring edge
                float outerDistance = max(0.0, distanceFromCenter - ringOuter);
                float outerFalloff = outerDistance / max(_OuterGlowSize, 0.001);
                float outerGlow = exp(-outerFalloff) * _OuterGlowIntensity * 
                                 smoothstep(ringOuter + _OuterGlowSize, ringOuter, distanceFromCenter) *
                                 step(ringOuter, distanceFromCenter);
                
                // === GLOW COMBINATION ===
                // Merge glow effects and create unified visibility mask
                float totalGlow = max(innerGlow, outerGlow);
                float glowMask = step(0.01, totalGlow);
                float combinedMask = max(ringMask, glowMask);
                
                // === COLOR BLENDING SYSTEM ===
                // Blend ring and glow colors based on glow intensity
                float maxGlowIntensity = max(_InnerGlowIntensity, _OuterGlowIntensity);
                float glowBlend = saturate(totalGlow / max(maxGlowIntensity, 0.001)) * 0.7;
                float3 finalColor = lerp(_RingColor.rgb, _GlowColor.rgb, glowBlend);
                
                // === ALPHA COMPOSITION ===
                // Calculate separate alpha contributions and combine using maximum
                float ringAlpha = ringMask * _RingOpacity;
                float glowAlpha = totalGlow * _GlowColor.a * 0.8;
                float finalAlpha = max(ringAlpha, glowAlpha);
                
                // === EDGE AND TEMPORAL FADE EFFECTS ===
                // Prevent artifacts at texture boundaries and provide natural fade-out
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.05, min(edgeDistance.x, edgeDistance.y));
                float timeFade = 1.0 - smoothstep(0.7, 1.0, age);
                 if(_Fading == 0)
                {
                    timeFade = 1;
                }       
                
                // === FINAL COMPOSITING ===
                // Apply all fade effects to final alpha
                finalAlpha *= edgeFade * timeFade;
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}