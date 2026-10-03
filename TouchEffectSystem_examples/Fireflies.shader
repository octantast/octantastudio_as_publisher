Shader "UI/Fireflies"
{
    Properties
    {
        // Core system uniforms
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 2.5
        [HideInInspector] _Scale ("Scale", Float) = 1
        
        // Firefly appearance
        _FireflyColor ("Firefly Color", Color) = (1, 0.95, 0.7, 1)
        _GlowColor ("Glow Color", Color) = (0.9, 0.8, 0.5, 1)
        _FireflyCount ("Firefly Count", Range(8, 24)) = 16
        _FireflySize ("Firefly Size", Range(0.015, 0.08)) = 0.035
        
        // Movement behavior
        _FlightRadius ("Flight Radius", Range(0.2, 0.8)) = 0.5
        _FlightSpeed ("Flight Speed", Range(0.3, 2)) = 0.8
        _FloatAmplitude ("Float Amplitude", Range(0.05, 0.3)) = 0.15
        
        // Visual effects
        _PulseSpeed ("Pulse Speed", Range(0.5, 4)) = 2.0
        _GlowIntensity ("Glow Intensity", Range(0.5, 3)) = 1.5
    }
    
    SubShader
    {
        Tags { 
            "RenderType"="Transparent" 
            "Queue"="Transparent" 
            "IgnoreProjector"="True" 
            "PreviewType"="Plane" 
        }
        
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

            struct appdata { 
                float4 vertex : POSITION; 
                float2 uv : TEXCOORD0; 
            };
            
            struct v2f { 
                float4 pos : SV_POSITION; 
                float2 uv : TEXCOORD0;
            };

            // Time management
            float _TimeNow, _StartTime, _Lifetime;
            float _Scale;
            
            // Visual properties
            float4 _FireflyColor, _GlowColor;
            float _FireflyCount, _FireflySize;
            
            // Movement properties
            float _FlightRadius, _FlightSpeed, _FloatAmplitude;
            
            // Effect properties
            float _PulseSpeed, _GlowIntensity;

            // Deterministic random generator for consistent particle behavior
            float hash(float n) {
                return frac(sin(n * 12.9898) * 43758.5453);
            }

            // Optimized soft circle with exponential falloff for glow effect
            float softCircle(float2 uv, float2 center, float radius) {
                float2 d = uv - center;
                float dist2 = dot(d, d); // Use squared distance for performance
                return exp(-dist2 / (radius * radius * 0.3));
            }

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                // Early exit for particles outside lifetime range
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float2 center = float2(0.5, 0.5);
                float3 finalColor = float3(0, 0, 0);
                float finalAlpha = 0.0;
                
                // === FADE EFFECTS PRE-CALCULATION ===
                // Lifecycle fade (smooth in/out)
                float lifeFade = sin(age * 3.14159);
                lifeFade = lifeFade * lifeFade; // Optimized pow equivalent
                
                // Radial fade from center
                float distFromCenter = length(i.uv - center);
                float radialFade = 1.0 - smoothstep(0.3, 0.5, distFromCenter);
                
                // === FIREFLY PARTICLE SYSTEM ===
                for (int f = 0; f < _FireflyCount; f++) {
                    float fireflyId = float(f);
                    
                    // Generate unique properties per firefly
                    float speed = hash(fireflyId) * 0.5 + 0.7;
                    float size = hash(fireflyId + 1.0) * 0.4 + 0.7;
                    float angleOffset = hash(fireflyId + 2.0) * 6.28318;
                    float pulseOffset = hash(fireflyId + 3.0) * 6.28318;
                    
                    // === MOVEMENT CALCULATION ===
                    // Circular flight path with floating motion
                    float currentAngle = angleOffset + age * _FlightSpeed * 6.0 * speed;
                    float currentRadius = _FlightRadius * age;
                    
                    // Vertical floating animation
                    float floatY = sin(_TimeNow * 1.5 + angleOffset) * _FloatAmplitude;
                    
                    // Calculate final firefly position
                    float2 fireflyPos = center;
                    fireflyPos.x += cos(currentAngle) * currentRadius;
                    fireflyPos.y += sin(currentAngle) * currentRadius + floatY;
                    
                    // === VISUAL EFFECTS ===
                    // Smooth brightness pulsing
                    float pulse = (sin(_TimeNow * _PulseSpeed + pulseOffset) * 0.5 + 0.5);
                    pulse = pulse * pulse * 0.7 + 0.3; // Optimized curve
                    
                    // Firefly core and glow rendering
                    float coreRadius = _FireflySize * size * _Scale;
                    float glowRadius = coreRadius * 2.0;
                    
                    float core = softCircle(i.uv, fireflyPos, coreRadius) * pulse;
                    float glow = softCircle(i.uv, fireflyPos, glowRadius) * pulse * 0.3 * _GlowIntensity;
                    
                    // === COLOR ACCUMULATION ===
                    // Combine core and glow with respective colors
                    finalColor += _FireflyColor.rgb * core * 1.2;
                    finalColor += _GlowColor.rgb * glow;
                    finalAlpha += core + glow;
                }
                
                // === EDGE FADE MANAGEMENT ===
                // Prevent artifacts at texture boundaries
                float2 edgeDist = min(i.uv, 1.0 - i.uv);
                float edgeFade = min(edgeDist.x, edgeDist.y) * 6.0;
                edgeFade = saturate(edgeFade);
                
                // === FINAL COMPOSITING ===
                // Apply all fade effects
                float timeFade = 1.0 - smoothstep(0.7, 1.0, age);
                float combinedFade = lifeFade * edgeFade * radialFade * timeFade;
                
                // Apply fade to color and alpha
                finalColor *= combinedFade * 0.8;
                finalAlpha *= combinedFade * 0.5;
                
                // Ensure values are in valid range
                return float4(finalColor, saturate(finalAlpha));
            }
            ENDHLSL
        }
    }
    Fallback "UI/Default"
}