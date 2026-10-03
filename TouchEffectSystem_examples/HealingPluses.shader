Shader "UI/HealingPluses"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 2.5
        [HideInInspector] _TouchPoint ("Touch Point", Vector) = (0, 0, 0, 0)
        [HideInInspector] _CanMove ("Can Move", Float) = 0
        [HideInInspector] _Scale ("Scale", Float) = 1
        [HideInInspector] _Resolution ("Resolution", Vector) = (1920, 1080, 0, 0)
        
        // Plus symbol appearance properties - configurable by designers
        _PlusColor ("Plus Color", Color) = (0.4, 1, 0.6, 1)
        _GlowColor ("Glow Color", Color) = (0.6, 1, 0.8, 1)
        _PlusCount ("Plus Count", Range(5, 20)) = 5
        _PlusSize ("Plus Size", Range(0.02, 0.08)) = 0.04
        _PlusThickness ("Plus Thickness", Range(0.3, 0.7)) = 0.5
        
        // Movement behavior properties - control floating animation
        _RiseSpeed ("Rise Speed", Range(0.5, 2.5)) = 1
        _SpreadRadius ("Spread Radius", Range(0.05, 0.5)) = 0.2
        _VerticalSpread ("Vertical Spread", Range(0, 0.5)) = 0.3
        
        // Visual effect properties - control brightness and pulsing
        _Brightness ("Brightness", Range(0.5, 3)) = 1.5
        _GlowIntensity ("Glow Intensity", Range(0.5, 2)) = 1.0
        _PulseSpeed ("Pulse Speed", Range(0, 4)) = 2.0
        
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
            float4 _PlusColor, _GlowColor;
            float _PlusCount, _PlusSize, _PlusThickness;
            float _RiseSpeed, _SpreadRadius, _VerticalSpread;
            float _Brightness, _GlowIntensity, _PulseSpeed;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            // Optimized deterministic pseudo-random hash function
            // Uses fast mathematical properties for consistent per-element variation
            float hash(float2 p) {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            // Generate soft plus symbol shape with anti-aliased edges
            // Creates medical cross with controllable thickness and smooth transitions
            float softPlus(float2 p, float size, float thickness) {
                float2 absP = abs(p);
                float halfThickness = size * thickness * 0.5;
                
                // Horizontal bar of plus symbol with smooth edges
                float horizontal = smoothstep(halfThickness + 0.01, halfThickness - 0.005, absP.y) * 
                                  smoothstep(size + 0.01, size - 0.01, absP.x);
                
                // Vertical bar of plus symbol with smooth edges
                float vertical = smoothstep(halfThickness + 0.01, halfThickness - 0.005, absP.x) * 
                                smoothstep(size + 0.01, size - 0.01, absP.y);
                
                // Combine horizontal and vertical bars
                return max(horizontal, vertical);
            }

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // Main fragment shader - generates floating plus symbols rising from healing point
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
                float2 center = float2(0.5, 0.5);
                
                // Initialize color accumulation
                float3 finalColor = float3(0, 0, 0);
                float finalAlpha = 0.0;
                
                // === LIFETIME FADE CALCULATION ===
                // Smooth sine-based fade in and out over particle lifetime
                float lifeFade = sin(effectiveAge * 3.14159);
                lifeFade = pow(lifeFade, 0.7);
                
                // === UNIQUE SEED GENERATION ===
                // Generate unique seed per particle instance using touch point
                float particleSeed = frac(_StartTime * 12.9898 + _TouchPoint.x * 78.233 + _TouchPoint.y * 43.544);
                
                // === PRECOMPUTE COMMON VALUES ===
                // Optimize by calculating shared values before loop
                int plusCount = int(_PlusCount);
                float scaledPlusSize = _PlusSize * _Scale;
                float spreadDouble = _SpreadRadius * 2.0;
                float riseSpeedFactor = effectiveAge * _RiseSpeed;
                float glowSizeFactor = scaledPlusSize * 0.9;
                float glowIntensityScaled = _GlowIntensity * 0.6;
                
                // === FLOATING PLUS SYMBOLS GENERATION ===
                // Create multiple rising plus symbols with individual trajectories
                for (int p = 0; p < 20; p++) {
                    if (p >= plusCount) break;
                    
                    float plusId = float(p);
                    float2 plusSeed = float2(plusId * 0.753 + particleSeed, plusId * 0.621 + particleSeed * 0.5);
                    
                    // === PLUS PROPERTIES ===
                    // Generate unique properties for each plus symbol
                    float plusSpeed = hash(plusSeed) * 0.5 + 0.75;
                    float plusPhase = hash(plusSeed * 1.3) * 6.28318;
                    float plusSize = scaledPlusSize * (0.8 + hash(plusSeed * 2.0) * 0.4);
                    
                    // === STARTING POSITION CALCULATION ===
                    // Random horizontal and vertical offsets for natural spread
                    float horizontalOffset = (hash(plusSeed * 2.3) - 0.5) * spreadDouble;
                    float verticalOffset = hash(plusSeed * 2.7) * _VerticalSpread;
                    
                    // === RISING MOTION ===
                    // Plus symbols float upward over time
                    float riseProgress = riseSpeedFactor * plusSpeed;
                    float plusY = 0.35 + verticalOffset + riseProgress * 0.5;
                    float plusX = center.x + horizontalOffset;
                    
                    float2 plusPos = float2(plusX, plusY);
                    
                    // === VISIBILITY BOUNDS CHECK ===
                    // Only render pluses within visible radius for performance
                    float distFromCenter = length(plusPos - center);
                    if (distFromCenter < 0.35) {
                        float2 toPlus = i.uv - plusPos;
                        
                        // === PLUS SHAPE GENERATION ===
                        // Draw plus symbol without rotation for clean appearance
                        float plusCore = softPlus(toPlus, plusSize, _PlusThickness);
                        
                        // === SOFT GLOW EFFECT ===
                        // Add compact glow around plus symbol
                        float glowDist = length(toPlus);
                        float plusGlow = exp(-glowDist / glowSizeFactor) * 0.3;
                        
                        // === PULSING ANIMATION ===
                        // Gentle brightness oscillation for living healing effect
                        float pulseTime = _TimeNow * _PulseSpeed + plusPhase;
                        pulseTime = lerp(pulseTime, effectiveAge * 6.0 + plusPhase, previewMode);
                        float pulse = sin(pulseTime) * 0.5 + 0.5;
                        pulse = pulse * pulse * 0.3 + 0.7;
                        
                        // === NATURAL FADE SYSTEM ===
                        // Fade based on distance from center and rise progress
                        float naturalFade = 1.0 - smoothstep(0.18, 0.32, distFromCenter);
                        naturalFade *= smoothstep(0.0, 0.12, riseProgress) * 
                                      (1.0 - smoothstep(0.45, 0.65, riseProgress));
                        
                        // === BRIGHTNESS CALCULATION ===
                        // Combine core plus and glow with pulsing and fading
                        float plusBrightness = (plusCore * 1.2 + plusGlow) * pulse * naturalFade;
                        
                        // === PLUS CONTRIBUTION ===
                        // Add plus colors to final output
                        finalColor += _PlusColor.rgb * plusCore * pulse * naturalFade * _Brightness;
                        finalColor += _GlowColor.rgb * plusGlow * pulse * naturalFade * glowIntensityScaled;
                        finalAlpha += plusBrightness;
                    }
                }
                
                // === EDGE FADE EFFECTS ===
                // Aggressive fade at texture boundaries for clean containment
                float2 edgeDist = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.25, min(edgeDist.x, edgeDist.y));
                
                // === TEMPORAL FADE SYSTEM ===
                // Natural fade-out in final 25% of lifetime
                float timeFade = 1.0 - smoothstep(0.75, 1.0, age);
                
                // === FINAL COMPOSITING ===
                // Apply all fade effects to color and alpha channels
                finalAlpha *= lifeFade * edgeFade * timeFade;
                finalColor *= lifeFade * edgeFade * timeFade;
                
                // === BRIGHTNESS NORMALIZATION ===
                // Clamp values to prevent over-brightness with additive blending
                finalAlpha = saturate(finalAlpha * 0.5);
                finalColor = saturate(finalColor * 0.95);
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}