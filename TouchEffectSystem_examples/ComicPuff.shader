Shader "UI/ComicPuff"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 1.2
        
        // Core animation properties
        [Toggle] _Scaling ("Disappearing Scaling", Float) = 1
        [Toggle] _Fading ("Disappearing Fading", Float) = 1
        
        // Puff appearance properties - configurable by designers
        _PuffColor ("Puff Color", Color) = (1, 0.95, 0.9, 1)
        _OutlineColor ("Outline Color", Color) = (0.7, 0.65, 0.6, 1)
        _OutlineWidth ("Outline Width", Range(0.0, 0.05)) = 0.01
        
        // Bubble structure properties - control puff cloud composition
        _BubbleCount ("Bubble Count", Range(3, 12)) = 9
        _BubbleSize ("Bubble Size", Range(0.05, 0.2)) = 0.1
        _BubbleSoftness ("Bubble Softness", Range(0.01, 0.1)) = 0.01
        
        // Animation properties - expansion and floating motion
        _ExpansionSpeed ("Expansion Speed", Range(0.5, 3.0)) = 2
        _FloatSpeed ("Float Speed", Range(0.0, 2.0)) = 2
        
        // Platform optimization and touch behavior properties
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
        // UI transparency rendering configuration
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        
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
            struct appdata { 
                float4 vertex : POSITION; 
                float2 uv : TEXCOORD0; 
            };
            
            // Vertex to fragment data transfer structure
            struct v2f { 
                float4 pos : SV_POSITION; 
                float2 uv : TEXCOORD0;
            };

            // Shader property declarations matching Properties block
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _TimeNow, _StartTime, _Lifetime;
            float4 _PuffColor, _OutlineColor;
            float _OutlineWidth;
            float _BubbleCount, _BubbleSize, _BubbleSoftness;
            float _ExpansionSpeed, _FloatSpeed;
            float _Scaling, _Fading;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            // Optimized pseudo-random number generator for bubble placement
            // Uses fast mathematical properties for consistent cross-platform results
            float rand(float2 co) {
                return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // Main fragment shader - generates comic puff cloud effect with clustered bubbles
            fixed4 frag (v2f i) : SV_Target {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                // Early exit prevents rendering expired particles
                float age = (_TimeNow - _StartTime) / _Lifetime;
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === HOLDING BEHAVIOR SYSTEM ===
                // Freeze visual progression when holding enabled
                float effectiveAge = age;
                if (_HoldingForbidden == 0 && age > _OneTouchHoldAge)
                {
                    effectiveAge = _OneTouchHoldAge;
                }
                
                // === COORDINATE SYSTEM SETUP ===
                // Convert to center-based coordinates for radial puff generation
                float2 uv = i.uv - 0.5;
                float centerDistance = length(uv);
                
                // === SIZE SCALING OVER LIFETIME ===
                // Puff expands outward as it ages for cloud dissipation effect
                float sizeScale = 1.0;
                if (_Scaling > 0.5) {
                    sizeScale = 1.0 + effectiveAge * _ExpansionSpeed;
                }
                
                // === BUBBLE CLUSTER GENERATION SYSTEM ===
                // Build puff from multiple overlapping bubble clusters
                // Each cluster contains 2-4 bubbles for organic cloud appearance
                float puffShape = 0.0;
                float outlineShape = 0.0;
                
                // Generate unique seed per particle for varied puff layouts
                float particleSeed = frac(_StartTime * 12.9898);
                
                int bubbleClusterCount = int(_BubbleCount);
                
                // === CLUSTER LOOP ===
                // Generate multiple bubble clusters arranged in ring pattern
                for (int cluster = 0; cluster < 12; cluster++) {
                    if (cluster >= bubbleClusterCount) break;
                    
                    // === CLUSTER POSITIONING ===
                    // Place clusters around center with deterministic randomness
                    float clusterSeed = float(cluster) * 123.456 + particleSeed * 789.012;
                    float clusterAngle = rand(float2(clusterSeed, 0)) * 6.28318;
                    
                    // Ring radius with variation for organic distribution
                    float ringRadius = 0.20 + rand(float2(clusterSeed, 1)) * 0.08;
                    
                    // === ANIMATED FLOAT MOVEMENT ===
                    // Add gentle floating motion to entire cluster for cartoon effect
                    float floatPhase = effectiveAge * _FloatSpeed + clusterSeed;
                    float floatX = sin(floatPhase) * 0.02;
                    float floatY = cos(floatPhase * 0.7) * 0.02;
                    
                    // Calculate final cluster center with floating offset
                    float2 clusterCenter = float2(cos(clusterAngle), sin(clusterAngle)) * ringRadius;
                    clusterCenter += float2(floatX, floatY);
                    
                    // === BUBBLES PER CLUSTER ===
                    // Generate 2-4 bubbles per cluster for varied puff density
                    int bubblesInCluster = 2 + int(rand(float2(clusterSeed, 3)) * 3.0);
                    
                    // === BUBBLE LOOP ===
                    // Generate individual bubbles within cluster
                    for (int bubble = 0; bubble < 4; bubble++) {
                        if (bubble >= bubblesInCluster) break;
                        
                        float bubbleSeed = clusterSeed + float(bubble) * 45.678;
                        
                        // === BUBBLE OFFSET WITHIN CLUSTER ===
                        // Offset each bubble slightly from cluster center for tight grouping
                        float bubbleAngleOffset = rand(float2(bubbleSeed, 0)) * 6.28318;
                        float bubbleDistOffset = rand(float2(bubbleSeed, 1)) * 0.06;
                        float2 bubbleOffset = float2(cos(bubbleAngleOffset), sin(bubbleAngleOffset)) * bubbleDistOffset;
                        
                        float2 bubblePos = clusterCenter + bubbleOffset;
                        
                        // === BUBBLE SIZE VARIATION ===
                        // Vary bubble sizes for natural organic appearance
                        float bubbleSizeVariation = 0.6 + rand(float2(bubbleSeed, 2)) * 0.8;
                        float scaledBubbleSize = _BubbleSize * bubbleSizeVariation / sizeScale;
                        
                        // === BUBBLE SHAPE GENERATION ===
                        // Calculate distance to bubble center for circular shape
                        float2 toBubble = uv - bubblePos;
                        float bubbleDistance = length(toBubble);
                        
                        // Create soft-edged bubble with smoothstep for anti-aliasing
                        float bubbleShape = 1.0 - smoothstep(scaledBubbleSize - _BubbleSoftness, 
                                                        scaledBubbleSize, 
                                                        bubbleDistance);
                        
                        // === BUBBLE OUTLINE GENERATION ===
                        // Create outline ring around bubble edge for comic style
                        float outlineInner = scaledBubbleSize - _OutlineWidth;
                        float outline = smoothstep(outlineInner - 0.01, outlineInner, bubbleDistance) *
                                       (1.0 - smoothstep(scaledBubbleSize, scaledBubbleSize + 0.01, bubbleDistance));
                        
                        // === BUBBLE ACCUMULATION ===
                        // Combine bubbles using maximum for proper overlap blending
                        puffShape = max(puffShape, bubbleShape);
                        outlineShape = max(outlineShape, outline);
                    }
                }
                
                // === BOUNDARY CONTAINMENT ===
                // Ensure puff stays within particle texture bounds
                float maxRadius = 0.5;
                float boundaryFade = 1.0 - smoothstep(maxRadius - 0.1, maxRadius, centerDistance);
                puffShape *= boundaryFade;
                outlineShape *= boundaryFade;
                
                // === TEMPORAL FADE SYSTEM ===
                // Natural particle fade-out in final 40% of lifetime
                float timeFade = 1.0;
                if (_Fading > 0.5) {
                    timeFade = 1.0 - smoothstep(0.6, 1.0, age);
                }
                
                // === EDGE FADE EFFECTS ===
                // Prevent visual artifacts at texture boundaries
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.05, min(edgeDistance.x, edgeDistance.y));
                
                // === COLOR COMPOSITION ===
                // Build final color from layered puff and outline
                float3 finalColor = _PuffColor.rgb;
                float finalAlpha = puffShape;
                
                // Add outline in areas without main puff for comic book aesthetic
                float outlineOnly = outlineShape * (1.0 - puffShape);
                finalColor = lerp(finalColor, _OutlineColor.rgb, outlineOnly);
                finalAlpha = max(finalAlpha, outlineOnly);
                
                // === FINAL COMPOSITING ===
                // Apply all fade effects to final alpha
                finalAlpha *= timeFade * edgeFade;
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}