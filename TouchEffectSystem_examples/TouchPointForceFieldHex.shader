Shader "UI/TouchPointForceFieldHex"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 2.0
        
        // Visual appearance properties - configurable by designers
        _LineColor ("Line Color", Color) = (1, 1, 1, 1)
        _HexSize ("Hex Size", Range(3, 15)) = 6
        _LineThickness ("Line Thickness", Range(0.01, 0.08)) = 0.03
        _LineOpacity ("Line Opacity", Range(0.0, 1.0)) = 0.8
        _WaveWidth ("Wave Width", Range(0.05, 0.2)) = 0.1
        
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
            fixed4 _LineColor;
            float _HexSize;
            float _LineThickness;
            float _LineOpacity;
            float _WaveWidth;
            float _UseMobileOptimization;

            // Optimized hexagonal grid pattern generator
            // Creates force field style hexagonal cells with clean edges
            float hexGrid(float2 uv)
            {
                // Scale UV coordinates by hex density
                float2 hexUV = uv * _HexSize;
                
                // Offset every second row for proper hexagonal tiling
                float2 c = hexUV;
                c.y += 0.5 * (int(c.x) % 2);
                
                // Get fractional part for cell-relative coordinates
                float2 f = frac(c);
                float2 h = abs(f - 0.5);
                
                // Calculate distance to hexagon edge using optimized formula
                // 1.732 is sqrt(3) for hexagonal geometry
                float hexEdge = max(h.x * 1.732 + h.y, h.y * 2.0) - 1.0;
                
                // Convert edge distance to line visibility with smooth transition
                return 1.0 - smoothstep(0.0, _LineThickness, abs(hexEdge));
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

            // Main fragment shader - generates animated hexagonal force field effect
            fixed4 frag (v2f i) : SV_Target
            {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                // Early exit prevents rendering expired particles
                float age = (_TimeNow - _StartTime) / _Lifetime;
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === COORDINATE SYSTEM SETUP ===
                // Precompute distance from particle center for wave calculations
                float distance = length(i.uv - 0.5);
                
                // === HEXAGONAL PATTERN GENERATION ===
                // Generate hexagonal grid pattern and early exit if not on hex lines
                float hexPattern = hexGrid(i.uv);
                if (hexPattern < 0.01) return float4(0, 0, 0, 0);
                
                // === EXPANDING WAVE SYSTEM ===
                // Create outward-expanding wave that reveals hexagonal pattern
                float wavePosition = age * 0.4;  // Wave travels from center to edge
                
                // Calculate bright wave ring at current wave position
                float waveDistance = abs(distance - wavePosition);
                float waveRing = 1.0 - smoothstep(0.0, _WaveWidth * 1.5, waveDistance);
                
                // === TRAILING FADE EFFECT ===
                // Create smooth fade behind the expanding wave for visual continuity
                // Use optimized calculation without conditional branching
                float fadeProgress = saturate((wavePosition - distance) / max(wavePosition, 0.001));
                fadeProgress = pow(fadeProgress, 0.5);  // Gradual fade curve
                float behindWaveFade = saturate(step(distance, wavePosition) * (1.0 - smoothstep(0.0, 1.0, fadeProgress)));
                
                // === WAVE VISIBILITY COMBINATION ===
                // Combine wave ring and trailing fade for complete wave effect
                float waveVisibility = max(waveRing, behindWaveFade);
                
                // === TEMPORAL FADE SYSTEM ===
                // Create gradual fade-out over particle lifetime with smooth curve
                float timeFade = 1.0 - smoothstep(0.4, 1.0, age);
                timeFade = pow(timeFade, 0.7);  // Smooth fade curve
                
                // === PARTICLE BOUNDARY DEFINITION ===
                // Define circular particle boundaries to contain the effect
                float boundary = 1.0 - smoothstep(0.35, 0.45, distance);
                
                // === EDGE ARTIFACT PREVENTION ===
                // Prevent visual artifacts at texture boundaries
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.05, min(edgeDistance.x, edgeDistance.y));
                
                // === FINAL COMPOSITING ===
                // Combine all effects to produce final pixel alpha
                float finalAlpha = hexPattern * waveVisibility * timeFade * boundary * _LineOpacity * edgeFade;
                
                return float4(_LineColor.rgb, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}