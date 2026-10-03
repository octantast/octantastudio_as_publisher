Shader "UI/ComicImpactLayers"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 0.8
        
        // Core animation properties
        [Toggle] _Scaling ("Disappearing Scaling", Float) = 1
        [Toggle] _Fading ("Disappearing Fading", Float) = 1

        // Layer color properties - configurable by designers
        _FlashColor ("Flash Color", Color) = (1, 1, 1, 1)
        _Layer1Color ("Layer 1 Color", Color) = (1, 1, 1, 1)
        _Layer2Color ("Layer 2 Color", Color) = (1, 0.75, 0.2, 1)
        _Layer3Color ("Layer 3 Color", Color) = (0.9, 0.5, 0.1, 1)
        _OutlineColor ("Outline Color", Color) = (0.3, 0.15, 0.05, 1)

        
        // Flash properties - central bright point
        _FlashRadius ("Flash Radius", Range(0, 0.5)) = 0.05
        
        // Layer 1 properties - innermost spike layer
        _Layer1Radius ("Layer 1 Radius", Range(0, 0.25)) = 0.1
        _Layer1SpikeCount ("Layer 1 Spike Count", Range(4, 16)) = 8
        _Layer1SpikeLength ("Layer 1 Spike Length", Range(0.05, 0.5)) = 0.25
        
        // Layer 2 properties - middle spike layer
        _Layer2Radius ("Layer 2 Radius", Range(0, 0.5)) = 0.15
        _Layer2SpikeCount ("Layer 2 Spike Count", Range(4, 16)) = 4
        _Layer2SpikeLength ("Layer 2 Spike Length", Range(0.05, 0.2)) = 0.1
        
        // Layer 3 properties - outermost spike layer
        _Layer3Radius ("Layer 3 Radius", Range(0, 0.5)) = 0.2
        _Layer3SpikeCount ("Layer 3 Spike Count", Range(0, 16)) = 0
        _Layer3SpikeLength ("Layer 3 Spike Length", Range(0.05, 0.2)) = 0.05
        
        // Global spike properties - affect all layers
        _SpikeSharpness ("Spike Sharpness", Range(0.01, 0.8)) = 0.1
        
        // Outline properties - comic book style edge definition
        _OutlineWidth ("Outline Width", Range(0.008, 0.025)) = 0.012
        _OutlineCoverage ("Outline Coverage", Range(0.3, 1.0)) = 0.7
        
        // Detail properties - scattered accent elements
        _DetailCount ("Detail Count", Range(4, 16)) = 10
        _DetailSize ("Detail Size", Range(0.005, 0.02)) = 0.01
        
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
            float4 _FlashColor, _Layer1Color, _Layer2Color, _Layer3Color, _OutlineColor;
            float _FlashRadius;
            float _Layer1Radius, _Layer1SpikeCount, _Layer1SpikeLength;
            float _Layer2Radius, _Layer2SpikeCount, _Layer2SpikeLength;
            float _Layer3Radius, _Layer3SpikeCount, _Layer3SpikeLength;
            float _SpikeSharpness;
            float _OutlineWidth, _OutlineCoverage;
            float _DetailCount, _DetailSize;
            float _Scaling, _Fading;
            float _UseMobileOptimization;
            float _OneTouchHoldAge, _HoldingForbidden;

            // Optimized pseudo-random number generator for layer variation
            // Uses fast mathematical properties for consistent cross-platform results
            float rand(float2 co) {
                return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Generate circle with sharp triangular spikes radiating outward
            // Creates comic book impact effect with random spike variation
            // Returns signed distance field where negative values indicate inside the shape
            float spikyCircle(float2 p, float baseRadius, int spikeCount, float spikeLength, float layerSeed) {
                // Convert to polar coordinates for radial spike generation
                float angle = atan2(p.y, p.x);
                float dist = length(p);
                
                // Start with base circle radius
                float finalRadius = baseRadius;
                
                // === SPIKE GENERATION LOOP ===
                // Add sharp triangular spikes to circle perimeter
                for (int s = 0; s < 16; s++) {
                    if (s >= spikeCount) break;
                    
                    // Unique seed per spike for variation
                    float spikeSeed = layerSeed + float(s) * 47.3;
                    
                    // Random spike angle for organic distribution
                    float spikeAngle = rand(float2(spikeSeed, 0)) * 6.28318;
                    
                    // Random spike length variation for natural appearance
                    float spikeLen = spikeLength * (0.6 + rand(float2(spikeSeed, 1)) * 0.8);
                    
                    // Calculate angular distance to spike center line
                    float angleDiff = angle - spikeAngle;
                    angleDiff = atan2(sin(angleDiff), cos(angleDiff));
                    
                    // Spike width with random variation
                    float spikeHalfAngle = _SpikeSharpness * (0.8 + rand(float2(spikeSeed, 2)) * 0.4);
                    
                    // Check if point falls within spike angular range
                    if (abs(angleDiff) < spikeHalfAngle) {
                        // Calculate spike extension using triangular taper
                        // Creates sharp point at tip, full width at base
                        float normalizedAngle = abs(angleDiff) / spikeHalfAngle;
                        float spikeExtension = spikeLen * (1.0 - normalizedAngle);
                        finalRadius = max(finalRadius, baseRadius + spikeExtension);
                    }
                }
                
                return dist - finalRadius;
            }

            // Determine if outline should be drawn at given angle
            // Creates comic book style partial outlines for visual variety
            float shouldDrawOutline(float angle, float seed) {
                float segments = 8.0;
                float segmentIndex = floor((angle + 3.14159) / 6.28318 * segments);
                float segmentSeed = seed + segmentIndex * 67.8;
                return step(rand(float2(segmentSeed, 0)), _OutlineCoverage);
            }

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // Main fragment shader - generates multi-layered comic impact effect with spikes and details
            fixed4 frag (v2f i) : SV_Target {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                // Preview mode - show static effect at 30% lifecycle for inspector
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.3, previewMode);
                
                // Early exit prevents rendering expired particles
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === HOLDING BEHAVIOR SYSTEM ===
                // Freeze visual progression when holding enabled
                float effectiveAge = age;
                if (_HoldingForbidden == 0 && age > _OneTouchHoldAge)
                {
                    effectiveAge = _OneTouchHoldAge;
                }
                
                // === COORDINATE SYSTEM SETUP ===
                // Convert to center-based coordinates for radial layer generation
                float2 uv = i.uv - 0.5;
                float angle = atan2(uv.y, uv.x);
                
                // Generate unique seed per particle for variation
                float particleSeed = frac(_StartTime * 12.9898);
                
                // === SIZE SCALING OVER LIFETIME ===
                // Apply shrinking animation as particle ages for impact dissipation
                float sizeScale = 1.0;
                if (_Scaling > 0.5) {
                    sizeScale = 1.0 - effectiveAge * 0.4;
                }
                
                // === LAYER 3 GENERATION (OUTERMOST) ===
                // Generate outermost spike layer with optional spikes
                int layer3Count = int(_Layer3SpikeCount);
                float layer3Dist = spikyCircle(uv, _Layer3Radius * sizeScale, layer3Count, _Layer3SpikeLength * sizeScale, particleSeed + 300.0);
                float layer3Mask = step(layer3Dist, 0.0);
                
                // === LAYER 2 GENERATION (MIDDLE) ===
                // Generate middle spike layer with moderate spike count
                int layer2Count = int(_Layer2SpikeCount);
                float layer2Dist = spikyCircle(uv, _Layer2Radius * sizeScale, layer2Count, _Layer2SpikeLength * sizeScale, particleSeed + 200.0);
                float layer2Mask = step(layer2Dist, 0.0);
                
                // === LAYER 1 GENERATION (INNER) ===
                // Generate innermost spike layer with highest spike density
                int layer1Count = int(_Layer1SpikeCount);
                float layer1Dist = spikyCircle(uv, _Layer1Radius * sizeScale, layer1Count, _Layer1SpikeLength * sizeScale, particleSeed + 100.0);
                float layer1Mask = step(layer1Dist, 0.0);
                
                // === FLASH GENERATION (CENTER) ===
                // Central bright flash point for impact focal point
                float flashDist = length(uv) - _FlashRadius * sizeScale;
                float flashMask = step(flashDist, 0.0);
                
                // === SELECTIVE OUTLINE GENERATION ===
                // Create partial outlines for comic book aesthetic
                float drawOutline3 = shouldDrawOutline(angle, particleSeed + 30.0);
                float drawOutline2 = shouldDrawOutline(angle, particleSeed + 20.0);
                float drawOutline1 = shouldDrawOutline(angle, particleSeed + 10.0);
                
                // Layer 3 outline - only where coverage test passes
                float outline3 = 0.0;
                if (drawOutline3 > 0.5) {
                    float outlineDist3 = spikyCircle(uv, _Layer3Radius * sizeScale + _OutlineWidth, layer3Count, _Layer3SpikeLength * sizeScale, particleSeed + 300.0);
                    outline3 = step(outlineDist3, 0.0) * (1.0 - layer3Mask);
                }
                
                // Layer 2 outline - only where coverage test passes
                float outline2 = 0.0;
                if (drawOutline2 > 0.5) {
                    float outlineDist2 = spikyCircle(uv, _Layer2Radius * sizeScale + _OutlineWidth, layer2Count, _Layer2SpikeLength * sizeScale, particleSeed + 200.0);
                    outline2 = step(outlineDist2, 0.0) * (1.0 - layer2Mask);
                }
                
                // Layer 1 outline - only where coverage test passes
                float outline1 = 0.0;
                if (drawOutline1 > 0.5) {
                    float outlineDist1 = spikyCircle(uv, _Layer1Radius * sizeScale + _OutlineWidth, layer1Count, _Layer1SpikeLength * sizeScale, particleSeed + 100.0);
                    outline1 = step(outlineDist1, 0.0) * (1.0 - layer1Mask);
                }
                
                // === DETAIL ELEMENTS GENERATION ===
                // Add scattered accent shapes around impact for visual richness
                float details = 0.0;
                int detailCountInt = int(_DetailCount);
                
                for (int d = 0; d < 16; d++) {
                    if (d >= detailCountInt) break;
                    
                    // Unique seed per detail for variation
                    float detailSeed = float(d) * 456.789 + particleSeed * 123.456;
                    
                    // Random detail position around outer layer
                    float detailAngle = rand(float2(detailSeed, 0)) * 6.28318;
                    float detailDist = _Layer3Radius * sizeScale * (1.4 + rand(float2(detailSeed, 1)) * 0.4);
                    float2 detailPos = float2(cos(detailAngle), sin(detailAngle)) * detailDist;
                    
                    // Random detail size for variety
                    float detailRadius = _DetailSize * (0.5 + rand(float2(detailSeed, 2)) * 0.5) * sizeScale;
                    float shapeType = rand(float2(detailSeed, 3));
                    
                    float distToDetail = length(uv - detailPos);
                    
                    // Create either circle or dash based on random selection
                    if (shapeType < 0.6) {
                        // Circle detail
                        details = max(details, step(distToDetail, detailRadius));
                    } else {
                        // Dash detail pointing outward from center
                        float2 dashDir = float2(cos(detailAngle), sin(detailAngle));
                        float2 toDetail = uv - detailPos;
                        float alongDash = dot(toDetail, dashDir);
                        float perpDash = length(toDetail - dashDir * alongDash);
                        
                        float dashMask = step(abs(alongDash), detailRadius * 2.0) * step(perpDash, detailRadius * 0.4);
                        details = max(details, dashMask);
                    }
                }
                
                // === COLOR COMPOSITION ===
                // Layer elements from back to front for proper overlap
                float3 finalColor = float3(0, 0, 0);
                float finalAlpha = 0.0;
                
                // Build layers progressively from outermost to innermost
                if (outline3 > 0.5) {
                    finalColor = _OutlineColor.rgb;
                    finalAlpha = 1.0;
                }
                
                if (layer3Mask > 0.5) {
                    finalColor = _Layer3Color.rgb;
                    finalAlpha = 1.0;
                }
                
                if (outline2 > 0.5) {
                    finalColor = _OutlineColor.rgb;
                    finalAlpha = 1.0;
                }
                
                if (layer2Mask > 0.5) {
                    finalColor = _Layer2Color.rgb;
                    finalAlpha = 1.0;
                }
                
                if (outline1 > 0.5) {
                    finalColor = _OutlineColor.rgb;
                    finalAlpha = 1.0;
                }
                
                if (layer1Mask > 0.5) {
                    finalColor = _Layer1Color.rgb;
                    finalAlpha = 1.0;
                }
                
                if (flashMask > 0.5) {
                    finalColor = _FlashColor.rgb;
                    finalAlpha = 1.0;
                }
                
                if (details > 0.5) {
                    finalColor = _OutlineColor.rgb;
                    finalAlpha = 1.0;
                }
                
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