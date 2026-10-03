Shader "UI/HealingAura"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 3.0
        [HideInInspector] _TouchPoint ("Touch Point", Vector) = (0, 0, 0, 0)
        [HideInInspector] _CanMove ("Can Move", Float) = 0
        [HideInInspector] _Scale ("Scale", Float) = 1
        [HideInInspector] _Resolution ("Resolution", Vector) = (1920, 1080, 0, 0)
        
        // Healing wave appearance properties - configurable by designers
        _WaveColor ("Wave Color", Color) = (0.4, 1, 0.6, 1)
        _CoreColor ("Core Color", Color) = (0.8, 1, 0.9, 1)
        _WaveCount ("Wave Count", Range(0, 6)) = 2
        _WaveThickness ("Wave Thickness", Range(0, 0.1)) = 0.02
        
        // Movement behavior properties - control animation dynamics
        _ExpansionSpeed ("Expansion Speed", Range(0.3, 2)) = 1.0
        _RotationSpeed ("Rotation Speed", Range(0.5, 3)) = 1.5
        _FlowSpeed ("Flow Speed", Range(0.5, 3)) = 1.8
        _Turbulence ("Turbulence", Range(0, 0.3)) = 0.12
        
        // Visual effect properties - control brightness intensity
        _Brightness ("Brightness", Range(0.5, 3)) = 1.8
        _GlowIntensity ("Glow Intensity", Range(0.3, 2)) = 1.0
        
        // Central burst properties - initial impact flash
        _BurstIntensity ("Burst Intensity", Range(0.5, 3)) = 2.0
        _BurstSize ("Burst Size", Range(0.05, 0.2)) = 0.1
        
        // Sparkle properties - floating light particles
        _SparkleCount ("Sparkle Count", Range(4, 15)) = 8
        _SparkleSize ("Sparkle Size", Range(0.01, 0.04)) = 0.02
        
        // Platform optimization and touch behavior properties
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
        // UI transparency rendering configuration
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        
        // Additive blending for bright healing glow effect
        Blend One One
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
            float _TimeNow, _StartTime, _Lifetime;
            float4 _TouchPoint, _Resolution;
            float _CanMove, _Scale;
            float4 _WaveColor, _CoreColor;
            float _WaveCount, _WaveThickness;
            float _ExpansionSpeed, _RotationSpeed, _FlowSpeed, _Turbulence;
            float _Brightness, _GlowIntensity;
            float _BurstIntensity, _BurstSize;
            float _SparkleCount, _SparkleSize;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            // Optimized deterministic pseudo-random hash function
            // Uses fast mathematical properties for consistent per-element variation
            float hash(float2 p) {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            // Smooth noise interpolation for organic turbulence patterns
            // Bilinear interpolation between noise values for continuous gradients
            float noise(float2 p) {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                
                float a = hash(i);
                float b = hash(i + float2(1.0, 0.0));
                float c = hash(i + float2(0.0, 1.0));
                float d = hash(i + float2(1.0, 1.0));
                
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // Main fragment shader - generates healing aura with burst, waves, and sparkles
            fixed4 frag (v2f i) : SV_Target {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                // Preview mode - show effect at mid-cycle for inspector
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.5, previewMode);
                
                // Early exit prevents rendering expired particles
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === HOLDING BEHAVIOR SYSTEM ===
                // Freeze animation progression when touch is held
                float effectiveAge = age;
                if (_HoldingForbidden == 0) {
                    effectiveAge = min(age, _OneTouchHoldAge);
                }
                
                // === COORDINATE SYSTEM SETUP ===
                // Center-based polar coordinates for radial healing pattern
                float2 center = float2(0.5, 0.5);
                float2 toCenter = i.uv - center;
                float distFromCenter = length(toCenter);
                float angle = atan2(toCenter.y, toCenter.x);
                
                // Initialize color accumulation
                float3 finalColor = float3(0, 0, 0);
                float finalAlpha = 0.0;
                
                // === LIFETIME FADE CALCULATION ===
                // Smooth sine-based fade in and out over particle lifetime
                float lifeFade = sin(effectiveAge * 3.14159);
                lifeFade = pow(lifeFade, 0.6);
                
                // === PRECOMPUTE COMMON VALUES ===
                // Optimize by calculating shared values before loops
                float scaledBurstSize = _BurstSize * _Scale;
                float scaledSparkleSize = _SparkleSize * _Scale;
                
                // === CENTRAL ENERGY BURST ===
                // Bright initial flash at healing touch point
                float burstProgress = smoothstep(0.0, 0.3, effectiveAge);
                float burstFade = 1.0 - smoothstep(0.2, 0.8, effectiveAge);
                float burstCore = exp(-distFromCenter / scaledBurstSize) * burstFade * burstProgress;
                
                // === CROSS FLARE GENERATION ===
                // Four-pointed star rays extending from burst center
                float2 flareCoords = abs(toCenter);
                float burstHalfSize = scaledBurstSize * 0.5;
                float burstTripleSize = scaledBurstSize * 3.0;
                
                float horizontalFlare = exp(-flareCoords.y / burstHalfSize) * 
                                       smoothstep(burstTripleSize, 0.0, flareCoords.x);
                float verticalFlare = exp(-flareCoords.x / burstHalfSize) * 
                                     smoothstep(burstTripleSize, 0.0, flareCoords.y);
                float crossFlare = (horizontalFlare + verticalFlare) * burstFade * burstProgress * 0.6;
                
                // === BURST CONTRIBUTION ===
                // Combine core and flare for final burst effect
                float burst = (burstCore + crossFlare) * _BurstIntensity;
                finalColor += _CoreColor.rgb * burst;
                finalAlpha += burst;
                
                // === ANIMATION TIME CALCULATION ===
                // Flow time for continuous wave animation
                float flowTime = _TimeNow * _FlowSpeed;
                flowTime = lerp(flowTime, effectiveAge * 5.0, previewMode);
                
                // === PRECOMPUTE WAVE VALUES ===
                int waveCount = int(_WaveCount);
                float waveRadiusBase = effectiveAge * _ExpansionSpeed * 0.5;
                float turbulenceFactor = _Turbulence * 6.28318;
                
                // === SPIRALING HEALING WAVES ===
                // Generate multiple expanding spiral waves with organic flow
                for (int w = 0; w < 6; w++) {
                    if (w >= waveCount) break;
                    
                    float waveId = float(w);
                    float wavePhase = waveId * 2.094; // Golden angle for even distribution
                    
                    // === WAVE EXPANSION ===
                    // Waves grow outward from center over time
                    float waveRadius = waveRadiusBase;
                    
                    // === SPIRAL ROTATION CALCULATION ===
                    // Create rotating spiral pattern with distance-based twist
                    float spiralAngle = angle + distFromCenter * 8.0 - flowTime + wavePhase;
                    
                    // === ORGANIC TURBULENCE ===
                    // Add procedural noise for natural flowing movement
                    float turbulence = noise(float2(angle * 3.0, distFromCenter * 5.0 + flowTime)) * turbulenceFactor;
                    spiralAngle += turbulence;
                    
                    // === SPIRAL WAVE PATTERN ===
                    // Generate wave intensity using sine modulation
                    float spiralWave = sin(spiralAngle * 2.0) * 0.5 + 0.5;
                    spiralWave = spiralWave * spiralWave * spiralWave;
                    
                    // === WAVE RANGE DEFINITION ===
                    // Limit wave visibility to expanding ring region
                    float waveRange = smoothstep(waveRadius - 0.2, waveRadius - 0.1, distFromCenter) *
                                     (1.0 - smoothstep(waveRadius, waveRadius + 0.15, distFromCenter));
                    
                    // === WAVE INTENSITY LAYERS ===
                    // Core wave brightness and soft glow halo
                    float waveCore = spiralWave * waveRange;
                    float waveGlow = waveCore * 0.5;
                    
                    // === FLOWING SHIMMER EFFECT ===
                    // Add animated sparkle to wave surface
                    float shimmer = noise(float2(angle * 5.0, distFromCenter * 8.0 - flowTime * 2.0));
                    shimmer = shimmer * 0.4 + 0.6;
                    waveCore *= shimmer;
                    
                    // === WAVE CONTRIBUTION ===
                    // Add wave colors to final output
                    finalColor += _WaveColor.rgb * waveCore * _Brightness;
                    finalColor += _CoreColor.rgb * waveGlow * _GlowIntensity;
                    finalAlpha += waveCore * _Brightness + waveGlow * _GlowIntensity;
                }
                
                // === PRECOMPUTE SPARKLE VALUES ===
                int sparkleCount = int(_SparkleCount);
                float sparkleHalfSize = scaledSparkleSize * 0.5;
                float sparkleRayLength = scaledSparkleSize * 2.5;
                float rotationFactor = effectiveAge * _RotationSpeed;
                
                // === FLOATING SPARKLES GENERATION ===
                // Create orbiting light particles with twinkling effect
                for (int s = 0; s < 15; s++) {
                    if (s >= sparkleCount) break;
                    
                    float sparkleId = float(s);
                    float2 sparkleSeed = float2(sparkleId * 0.743, sparkleId * 0.617);
                    
                    // === SPARKLE ORBIT CALCULATION ===
                    // Circular path around healing center
                    float sparkleAngle = hash(sparkleSeed) * 6.28318 + rotationFactor;
                    float sparkleRadius = 0.15 + hash(sparkleSeed * 1.3) * 0.15;
                    
                    float2 sparklePos = center + float2(cos(sparkleAngle), sin(sparkleAngle)) * sparkleRadius;
                    
                    // === TWINKLING ANIMATION ===
                    // Pulsing brightness for sparkle effect
                    float twinklePhase = hash(sparkleSeed * 1.7) * 6.28318;
                    float twinkleTime = _TimeNow * 3.0 + twinklePhase;
                    twinkleTime = lerp(twinkleTime, effectiveAge * 10.0 + twinklePhase, previewMode);
                    float twinkle = sin(twinkleTime) * 0.5 + 0.5;
                    twinkle = twinkle * twinkle;
                    
                    // === SPARKLE SHAPE GENERATION ===
                    // Four-pointed star with exponential falloff
                    float2 toSparkle = i.uv - sparklePos;
                    float sparkleCore = exp(-length(toSparkle) / sparkleHalfSize);
                    
                    // === STAR RAYS ===
                    // Cross-shaped rays extending from sparkle center
                    float2 absCoords = abs(toSparkle);
                    float hRay = exp(-absCoords.y / scaledSparkleSize) * 
                                smoothstep(sparkleRayLength, 0.0, absCoords.x);
                    float vRay = exp(-absCoords.x / scaledSparkleSize) * 
                                smoothstep(sparkleRayLength, 0.0, absCoords.y);
                    
                    // === SPARKLE COMBINATION ===
                    // Merge core and rays with twinkling intensity
                    float sparkle = (sparkleCore + hRay * 0.4 + vRay * 0.4) * twinkle;
                    
                    // === SPARKLE CONTRIBUTION ===
                    finalColor += _CoreColor.rgb * sparkle;
                    finalAlpha += sparkle * 0.8;
                }
                
                // === RADIAL CONTAINMENT ===
                // Fade healing effect at edges for circular boundary
                float radialFade = 1.0 - smoothstep(0.3, 0.45, distFromCenter);
                
                // === EDGE FADE EFFECTS ===
                // Prevent visual artifacts at texture boundaries
                float2 edgeDist = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.1, min(edgeDist.x, edgeDist.y));
                
                // === TEMPORAL FADE SYSTEM ===
                // Natural fade-out in final 30% of lifetime
                float timeFade = 1.0 - smoothstep(0.7, 1.0, age);
                
                // === FINAL COMPOSITING ===
                // Apply all fade effects to color and alpha channels
                finalAlpha *= lifeFade * radialFade * edgeFade * timeFade;
                finalColor *= lifeFade * radialFade * edgeFade * timeFade;
                
                // === BRIGHTNESS NORMALIZATION ===
                // Clamp values to prevent over-brightness with additive blending
                finalAlpha = saturate(finalAlpha * 0.5);
                finalColor = saturate(finalColor * 0.85);
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}