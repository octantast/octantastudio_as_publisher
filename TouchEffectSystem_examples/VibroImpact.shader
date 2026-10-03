Shader "UI/VibroImpact"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 1.2
                
        // Impact wave color properties - configurable by designers
        _WaveColor ("Wave Color", Color) = (1, 1, 1, 1)
        _EdgeColor ("Edge Color", Color) = (0.8, 0.9, 1, 1)
        
        // Wave structure properties
        _WaveCount ("Wave Count", Range(2, 8)) = 4
        _WaveThickness ("Wave Thickness", Range(0.01, 0.15)) = 0.06
        _WaveIntensity ("Wave Intensity", Range(0.5, 2.0)) = 1.0
        _Sharpness ("Sharpness", Range(1, 10)) = 4
        _PolygonSides ("Polygon Sides", Range(4, 12)) = 6
        
        // Animation properties
        _ExpandSpeed ("Expand Speed", Range(1, 5)) = 2.5
        _Distortion ("Distortion", Range(0, 0.5)) = 0.2
        
        // Platform optimization and touch behavior properties
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0.3
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
            float4 _WaveColor, _EdgeColor;
            float _WaveCount, _WaveThickness, _WaveIntensity, _Sharpness, _PolygonSides;
            float _ExpandSpeed, _Distortion;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            // Convert cartesian UV coordinates to polar coordinate system
            // Returns (radius, angle) for radial wave calculations
            // Radius is normalized to [0, 1] range with center at 0.5
            float2 toPolar(float2 uv) {
                float2 centered = uv - 0.5;
                float radius = length(centered) * 2.0;
                float angle = atan2(centered.y, centered.x);
                return float2(radius, angle);
            }

            // Create polygon shape with animated distortion for comic-style impact
            // Uses angular segmentation to create sharp geometric edges
            // Parameters: radius (distance), angle (direction), sides (polygon edges), time (animation)
            float polygonShape(float radius, float angle, float sides, float time) {
                // Apply sinusoidal distortion for dynamic wave effect
                float distortion = sin(angle * 3.0 + time * 5.0) * _Distortion;
                radius += distortion * 0.1;
                
                // Convert circular distance to polygon distance using angular segmentation
                float segment = 6.28318 / sides;
                float polygon = cos(floor(0.5 + angle / segment) * segment - angle) * radius;
                return polygon;
            }

            // Generate sharp high-contrast wave ring with comic book aesthetic
            // Creates expanding ring with crisp edges and controllable sharpness
            // Parameters: radius (distance from center), waveProgress (expansion), thickness (ring width), sharpness (edge crispness)
            float comicWave(float radius, float waveProgress, float thickness, float sharpness) {
                // Calculate wave ring boundaries
                float waveFront = waveProgress;
                float waveBack = waveProgress - thickness;
                
                // Sharp front edge with configurable sharpness
                float front = 1.0 - smoothstep(0.0, 0.05 / sharpness, abs(radius - waveFront));
                
                // Soft back edge for natural falloff
                float back = smoothstep(0.0, 0.1, radius - waveBack);
                
                // Combine front and back to form ring
                return front * back;
            }

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // Main fragment shader - generates vibration impact effect with expanding polygonal waves
            // Creates comic book style impact with multiple cascading sharp-edged rings
            fixed4 frag (v2f i) : SV_Target {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                // Preview mode - display effect at mid-cycle in material inspector
                // Allows designers to see animation without play mode
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.3, previewMode);
                
                // Early exit prevents rendering expired particles
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === HOLDING BEHAVIOR SYSTEM ===
                // Terminate particle if holding is forbidden and age exceeds hold threshold
                // This creates pulsating effect when touch is held
                if (_HoldingForbidden > 0.5 && age >= _OneTouchHoldAge) {
                    return float4(0, 0, 0, 0);
                }
                
                // === COORDINATE SYSTEM SETUP ===
                // Convert to polar coordinates for radial wave generation
                float2 polar = toPolar(i.uv);
                float radius = polar.x;
                float angle = polar.y;
                
                // === SIZE SCALING OVER LIFETIME ===
                // Apply optional scaling animation that shrinks effect over time
                float sizeScale = 1.0;
                
                // Animated time for distortion effects
                float time = _TimeNow * 3.0;
                
                // === POLYGON SHAPE GENERATION ===
                // Convert circular radius to polygonal distance with scaling
                float scaledRadius = radius / max(sizeScale, 0.001);
                float polygon = polygonShape(scaledRadius, angle, _PolygonSides, time);
                
                // === ANIMATED IMPACT WAVES SYSTEM ===
                // Generate multiple expanding waves with sequential delays
                float impactEffect = 0.0;
                
                for (int wave = 0; wave < 8; wave++) {
                    if (wave >= _WaveCount) break;
                    
                    // Sequential wave delays create cascading ripple effect
                    float waveOffset = float(wave) / _WaveCount * 0.3;
                    float waveProgress = (age * _ExpandSpeed - waveOffset);
                    
                    // Only render waves that have started
                    if (waveProgress > 0.0) {
                        // Each successive wave has increasing thickness
                        float waveThickness = _WaveThickness * (0.8 + float(wave) * 0.15);
                        
                        // Each successive wave has decreasing sharpness for softer appearance
                        float waveSharpness = _Sharpness * (1.0 - float(wave) * 0.1);
                        
                        // Generate sharp comic-style wave ring
                        float waveValue = comicWave(polygon, waveProgress, waveThickness, waveSharpness);
                        
                        // Fade wave as it expands outward
                        float waveFade = 1.0 - smoothstep(0.0, 0.9, waveProgress);
                        
                        // Accumulate wave contribution
                        impactEffect += waveValue * waveFade * _WaveIntensity;
                    }
                }
                
                // Clamp accumulated wave intensity
                impactEffect = saturate(impactEffect);
                
                // === TEMPORAL FADE SYSTEM ===
                // Create natural particle death animation
                float timeFade = 1.0;
                
                // === EDGE FADE EFFECTS ===
                // Prevent artifacts at texture boundaries
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.1, min(edgeDistance.x, edgeDistance.y));
                
                // === FINAL COMPOSITING ===
                // Blend wave and edge colors based on impact intensity
                float3 finalColor = lerp(_WaveColor.rgb, _EdgeColor.rgb, pow(impactEffect, 2.0));
                float finalAlpha = impactEffect * timeFade * edgeFade;
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}