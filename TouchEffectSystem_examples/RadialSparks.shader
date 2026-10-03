Shader "UI/RadialSparks"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 0.8
        [HideInInspector] _Scale ("Scale", Float) = 1.0
        [HideInInspector] _AllowMovement ("Allow Movement", Float) = 1.0
        
        // Visual appearance properties - configurable by designers
        _SparkColor ("Spark Color", Color) = (1.0, 0.7, 0.2, 1)
        _GlowColor ("Glow Color", Color) = (1.0, 0.85, 0.5, 1)
        
        // Spark generation properties
        _SparkCount ("Spark Count", Range(8, 40)) = 20
        _SparkLength ("Spark Length", Range(0.02, 0.15)) = 0.08
        _SparkWidth ("Spark Width", Range(0.001, 0.008)) = 0.003
        _SparkSpeed ("Spark Speed", Range(0.5, 2.5)) = 1.2
        _SparkSpread ("Spark Spread", Range(0.1, 0.5)) = 0.35
        _SparkTaper ("Spark Taper", Range(0.0, 1.0)) = 0.6
        
        // Visual effect properties
        _GlowIntensity ("Glow Intensity", Range(0.0, 5.0)) = 2
        _CenterFlash ("Center Flash", Range(0.0, 1.0)) = 0.5
        
        // Platform optimization and touch behavior properties
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0.5
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
            float _TimeNow, _StartTime, _Lifetime, _Scale, _AllowMovement;
            float4 _SparkColor, _GlowColor;
            float _SparkCount, _SparkLength, _SparkWidth, _SparkSpeed, _SparkSpread, _SparkTaper;
            float _GlowIntensity, _CenterFlash;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            // Deterministic pseudo-random hash function for 2D input
            // Returns value in range [0, 1] based on coordinate input
            float hash(float2 p) {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            // Smooth Perlin-style noise function for organic variation
            // Creates continuous random patterns for spark flicker effect
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

            // Line segment with tapering width along its length
            // Creates sharp spark trail that narrows toward the tip
            // Parameters: p (position), a (start), b (end), width (thickness), taper (width reduction)
            float lineSegment(float2 p, float2 a, float2 b, float width, float taper) {
                float2 pa = p - a;
                float2 ba = b - a;
                float h = saturate(dot(pa, ba) / dot(ba, ba));
                float dist = length(pa - ba * h);
                
                // Taper width along length for natural spark appearance
                float taperWidth = width * (1.0 - h * taper);
                
                return 1.0 - smoothstep(0.0, taperWidth, dist);
            }

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // Main fragment shader - generates radial spark burst effect
            fixed4 frag (v2f i) : SV_Target {
                // === EDGE FADE EFFECTS ===
                // Prevent artifacts at texture boundaries with early clip
                float2 edgeDist = min(i.uv, 1.0 - i.uv);
                float edgeMask = smoothstep(0.0, 0.03, min(edgeDist.x, edgeDist.y));
                if (edgeMask <= 0.0) return float4(0, 0, 0, 0);
                
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                // Preview mode - display effect at mid-cycle in material inspector
                // Allows designers to see animation without play mode
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.4, previewMode);
                
                // Early exit prevents rendering expired particles
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === COORDINATE SYSTEM SETUP ===
                // Convert to center-based coordinates and apply scale
                float2 center = float2(0.5, 0.5);
                float2 uv = i.uv - center;
                uv /= _Scale;
                
                // === LIFETIME FADE SYSTEM ===
                // Smooth fade in at start and fade out at end
                float fadeIn = smoothstep(0.0, 0.08, age);
                float fadeOut = smoothstep(1.0, 0.75, age);
                float totalFade = fadeIn * fadeOut;
                
                // === ABSOLUTE TIME CALCULATION ===
                // Time value for continuous animation independent of particle age
                float absTime = _TimeNow * 2.0;
                absTime = lerp(absTime, 1.5, previewMode);
                
                // === RADIAL SPARKS GENERATION ===
                // Multiple sparks shoot outward from center in all directions
                float sparksEffect = 0.0;
                float glowEffect = 0.0;
                
                for (int s = 0; s < 40; s++) {
                    if (s >= _SparkCount) break;
                    
                    float sparkId = float(s);
                    float2 sparkSeed = float2(sparkId * 0.741, sparkId * 0.569);
                    
                    // Calculate spark direction with slight random variation
                    float angleOffset = hash(sparkSeed) * 0.3 - 0.15;
                    float sparkAngle = (sparkId / _SparkCount) * 6.28318 + angleOffset;
                    float sinAngle = sin(sparkAngle);
                    float cosAngle = cos(sparkAngle);
                    float2 sparkDir = float2(cosAngle, sinAngle);
                    
                    // === SPARK MOTION CALCULATION ===
                    // Spark continuously shoots outward with cycling animation
                    float sparkTime = absTime * _SparkSpeed + hash(sparkSeed * 2.0) * 2.0;
                    float sparkProgress = frac(sparkTime);
                    float sparkDist = sparkProgress * _SparkSpread;
                    
                    // Calculate spark trail start and end positions
                    float startOffset = 0.01;
                    float currentLength = _SparkLength * (0.3 + sparkProgress * 0.7);
                    float2 sparkEnd = sparkDir * (startOffset + sparkDist);
                    float2 sparkStart = sparkEnd - sparkDir * currentLength;
                    
                    // === SPARK RENDERING ===
                    // Draw spark as tapered line segment
                    float spark = lineSegment(uv, sparkStart, sparkEnd, _SparkWidth, _SparkTaper);
                    
                    // Fade spark based on travel distance
                    float sparkFade = (1.0 - sparkProgress) * (0.5 + sparkProgress * 0.5);
                    
                    // Add flickering animation for dynamic energy effect
                    float flicker = noise(float2(sparkId * 10.0, absTime * 5.0)) * 0.4 + 0.6;
                    
                    // === SPARK GLOW EFFECT ===
                    // Soft glow around spark midpoint
                    float2 sparkMid = (sparkStart + sparkEnd) * 0.5;
                    float distToSpark = length(uv - sparkMid);
                    float sparkGlow = exp(-distToSpark * 30.0) * sparkFade * 0.5;
                    
                    // Accumulate spark and glow contributions
                    sparksEffect += spark * sparkFade * flicker;
                    glowEffect += sparkGlow * flicker;
                }
                
                // === CENTER FLASH EFFECT ===
                // Initial bright flash at touch point that fades quickly
                float centerDist = length(uv);
                float flash = exp(-centerDist * 20.0) * _CenterFlash;
                float flashFade = 1.0 - smoothstep(0.0, 0.3, age);
                flash *= flashFade;
                
                // === RADIAL GLOW LAYER ===
                // Soft radial glow emanating from center
                float radialGlow = exp(-centerDist * 8.0) * 0.4 * _GlowIntensity;
                
                // === COLOR COMPOSITION ===
                // Blend spark color with glow and flash effects
                float3 finalColor = _SparkColor.rgb * sparksEffect +
                                  _GlowColor.rgb * (glowEffect * _GlowIntensity + flash + radialGlow);
                
                // === ALPHA COMPOSITION ===
                // Combine all effect layers with appropriate opacity weights
                float finalAlpha = (sparksEffect * 0.9 + glowEffect * _GlowIntensity * 0.6 + 
                                  flash * 0.8 + radialGlow * 0.5) * 
                                  totalFade * edgeMask;
                
                finalAlpha = saturate(finalAlpha);
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}