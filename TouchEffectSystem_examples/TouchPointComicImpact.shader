Shader "UI/TouchPointComicImpact"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 1.2
        
        // Core animation properties
        [Toggle] _Scaling ("Disappearing Scaling", Float) = 0
        [Toggle] _Fading ("Disappearing Fading", Float) = 1
        
        // Impact wave color properties - dual color gradient system
        _WaveColor ("Wave Color", Color) = (1, 1, 1, 1)
        _EdgeColor ("Edge Color", Color) = (0.8, 0.9, 1, 1)
        
        // Wave structure properties - control multiple expanding rings
        _WaveCount ("Wave Count", Range(2, 8)) = 4
        _WaveThickness ("Wave Thickness", Range(0.01, 0.15)) = 0.06
        _WaveIntensity ("Wave Intensity", Range(0.5, 2.0)) = 1.0
        _Sharpness ("Sharpness", Range(1, 10)) = 4
        _PolygonSides ("Polygon Sides", Range(4, 12)) = 6
        
        // Animation properties - expansion and distortion effects
        _ExpandSpeed ("Expand Speed", Range(1, 5)) = 2.5
        _Distortion ("Distortion", Range(0, 0.5)) = 0.2
        
        // Platform optimization and touch behavior properties
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0.2
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 0
    }
    
    SubShader
    {
        // UI transparency rendering configuration
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
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

            struct appdata { 
                float4 vertex : POSITION; 
                float2 uv : TEXCOORD0; 
            };
            
            struct v2f { 
                float4 pos : SV_POSITION; 
                float2 uv : TEXCOORD0;
            };

            // Shader property declarations
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _TimeNow, _StartTime, _Lifetime;
            float4 _WaveColor, _EdgeColor;
            float _WaveCount, _WaveThickness, _WaveIntensity, _Sharpness, _PolygonSides;
            float _ExpandSpeed, _Distortion;
            float _Scaling, _Fading;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            // Convert cartesian coordinates to polar system
            // Returns (radius, angle) for radial effects
            float2 toPolar(float2 uv) {
                float2 centered = uv - 0.5;
                float radius = length(centered) * 2.0;
                float angle = atan2(centered.y, centered.x);
                return float2(radius, angle);
            }

            // Create polygon shape with comic-style sharp edges
            // Applies animated distortion for dynamic visual interest
            float polygonShape(float radius, float angle, float sides, float time) {
                float distortion = sin(angle * 3.0 + time * 5.0) * _Distortion;
                radius += distortion * 0.1;
                
                float segment = 6.28318 / sides;
                float polygon = cos(floor(0.5 + angle / segment) * segment - angle) * radius;
                return polygon;
            }

            // Sharp wave with comic book aesthetic
            // Creates high-contrast expanding rings with configurable sharpness
            float comicWave(float radius, float waveProgress, float thickness, float sharpness) {
                float waveFront = waveProgress;
                float waveBack = waveProgress - thickness;
                
                float front = 1.0 - smoothstep(0.0, 0.05 / sharpness, abs(radius - waveFront));
                float back = smoothstep(0.0, 0.1, radius - waveBack);
                
                return front * back;
            }

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                // === PARTICLE LIFETIME MANAGEMENT ===
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                // Preview mode - show static effect when no animation
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.3, previewMode);
                
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === HOLDING BEHAVIOR CHECK ===
                // Terminate particle if holding is forbidden and age exceeds hold threshold
                if (_HoldingForbidden > 0.5 && age >= _OneTouchHoldAge) {
                    return float4(0, 0, 0, 0);
                }
                
                // === COORDINATE SYSTEM SETUP ===
                float2 polar = toPolar(i.uv);
                float radius = polar.x;
                float angle = polar.y;
                
                // === SIZE SCALING OVER LIFETIME ===
                float sizeScale = 1.0;
                if (_Scaling > 0.5) {
                    sizeScale = 1.0 - age * 0.3;
                }
                
                float time = _TimeNow * 3.0;
                
                // === POLYGON SHAPE GENERATION ===
                // Apply scaling to radius for uniform effect scaling
                float scaledRadius = radius / max(sizeScale, 0.001);
                float polygon = polygonShape(scaledRadius, angle, _PolygonSides, time);
                
                // === ANIMATED IMPACT WAVES ===
                // Multiple expanding waves with sequential delays
                float impactEffect = 0.0;
                
                for (int wave = 0; wave < _WaveCount; wave++) {
                    // Sequential wave delays for cascading effect
                    float waveOffset = float(wave) / _WaveCount * 0.3;
                    float waveProgress = (age * _ExpandSpeed - waveOffset);
                    
                    if (waveProgress > 0.0) {
                        // Each wave has increasing thickness and decreasing sharpness
                        float waveThickness = _WaveThickness * (0.8 + wave * 0.15);
                        float waveSharpness = _Sharpness * (1.0 - wave * 0.1);
                        
                        // Generate comic-style sharp wave
                        float waveValue = comicWave(polygon, waveProgress, waveThickness, waveSharpness);
                        
                        // Fade wave as it expands
                        float waveFade = 1.0 - smoothstep(0.0, 0.9, waveProgress);
                        impactEffect += waveValue * waveFade * _WaveIntensity;
                    }
                }
                
                impactEffect = saturate(impactEffect);
                
                // === TEMPORAL FADE SYSTEM ===
                float timeFade = 1.0;
                if (_Fading > 0.5) {
                    timeFade = 1.0 - pow(age, 1.2);
                }
                
                // === EDGE FADE EFFECTS ===
                // Prevent visual artifacts at texture boundaries
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.1, min(edgeDistance.x, edgeDistance.y));
                
                // === FINAL COMPOSITION ===
                // Color gradient based on wave intensity
                float3 finalColor = lerp(_WaveColor.rgb, _EdgeColor.rgb, pow(impactEffect, 2.0));
                float finalAlpha = impactEffect * timeFade * edgeFade;
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    Fallback "UI/Default"
}