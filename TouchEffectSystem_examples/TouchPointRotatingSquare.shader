Shader "UI/TouchPointRotatingSquare"
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

        // Square structure properties - configurable by designers
        _SquareColor ("Square Color", Color) = (1, 1, 1, 1)
        _SquareSize ("Square Size", Range(0.1, 0.4)) = 0.25
        _LineThickness ("Line Thickness", Range(0.003, 0.02)) = 0.008
        _SquareOpacity ("Square Opacity", Range(0.0, 1.0)) = 0.9
        
        // Animation properties for rotation and scaling effects
        _RotationSpeed ("Rotation Speed", Range(0.0, 1.0)) = 0.5
        _StartScale ("Start Scale", Range(0.1, 1.0)) = 0.5
        
        // Glow properties for electrical outline effect
        _GlowIntensity ("Glow Intensity", Range(0.0, 3.0)) = 1.5
        _GlowSize ("Glow Size", Range(0.01, 0.06)) = 0.025
        
        // Platform optimization and touch behavior properties
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
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

            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };

            // Shader property declarations
            sampler2D _MainTex; float4 _MainTex_ST;
            float _TimeNow, _StartTime, _Lifetime;
            fixed4 _SquareColor;
            float _SquareSize, _LineThickness, _SquareOpacity;
            float _Scaling, _Fading;
            float _RotationSpeed, _StartScale;
            float _GlowIntensity, _GlowSize;
            float _UseMobileOptimization;

            // Optimized 2D rotation function using precomputed sin/cos values
            // Rotates point around origin for animated square orientation
            float2 rotatePoint(float2 p, float angle) {
                float cosA = cos(angle);
                float sinA = sin(angle);
                return float2(
                    p.x * cosA - p.y * sinA,
                    p.x * sinA + p.y * cosA
                );
            }

            // Calculate distance to square outline border using Chebyshev distance
            // Creates clean square geometry with precise edge definition
            float squareLineDistance(float2 p, float size) {
                // Calculate distance to square edge using maximum of coordinate absolute values
                float2 absP = abs(p);
                float distanceToSquareEdge = max(absP.x, absP.y);
                
                // Return distance from square outline (0 = on line, positive = away from line)
                return abs(distanceToSquareEdge - size);
            }

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // Main fragment shader - generates animated rotating square with electrical glow
            fixed4 frag (v2f i) : SV_Target {
                // === PARTICLE LIFETIME MANAGEMENT ===
                float age = (_TimeNow - _StartTime) / _Lifetime;
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === COORDINATE SYSTEM SETUP ===
                float2 offset = i.uv - 0.5;
                
                // === ANIMATION CALCULATIONS ===
                // Size animation: smooth growth from start scale to full size over particle lifetime
                float animatedScale = lerp(_StartScale, 1.0, age);
                if(_Scaling == 0)
                {
                    animatedScale = 1;
                }      

                float animatedSize = _SquareSize * animatedScale;
                
                // Rotation animation: continuous rotation based on age and configurable speed
                float rotationAngle = age * _RotationSpeed * 6.28318; // Full rotation = 2*PI
                float2 rotatedOffset = rotatePoint(offset, rotationAngle);
                
                // === SQUARE OUTLINE GENERATION ===
                // Calculate distance to the animated rotating square outline
                float distanceToLine = squareLineDistance(rotatedOffset, animatedSize);
                
                // === SQUARE CORE LINE ===
                // Sharp square outline with anti-aliased edges using configurable thickness
                float squareLine = 1.0 - smoothstep(0.0, _LineThickness, distanceToLine);
                
                // === OPTIMIZED GLOW SYSTEM ===
                // Soft electrical glow extending around the square outline
                float glowDistance = distanceToLine;
                float glowFalloff = glowDistance / max(_GlowSize, 0.001); // Prevent division by zero
                float glow = exp(-glowFalloff) * _GlowIntensity * 
                            smoothstep(_GlowSize * 5.0, 0.0, glowDistance);
                
                // === EFFECT COMPOSITION ===
                // Combine sharp square line with soft glow using maximum for proper layering
                float totalEffect = max(squareLine * _SquareOpacity, glow);
                
                // === EDGE AND TEMPORAL FADE EFFECTS ===
                // Prevent visual artifacts at texture boundaries
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.05, min(edgeDistance.x, edgeDistance.y));
                
                // Natural particle fade-out in final 40% of lifetime
                float timeFade = 1.0 - smoothstep(0.6, 1.0, age);
                
                 if(_Fading == 0)
                {
                    timeFade = 1;
                }       

                // === FINAL COMPOSITING ===
                // Apply all fade effects to final alpha
                float finalAlpha = totalEffect * edgeFade * timeFade;
                
                return float4(_SquareColor.rgb, finalAlpha);
            }
            ENDHLSL
        }
    }
    Fallback "UI/Default"
}