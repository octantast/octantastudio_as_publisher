Shader "UI/TouchPointMatrixGrid"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 2.0
        
        // Visual appearance properties - configurable by designers
        _GridColor ("Grid Color", Color) = (1, 1, 1, 1)
        _GridSize ("Grid Size", Range(4, 20)) = 8
        _GridThickness ("Grid Thickness", Range(0.01, 0.1)) = 0.02
        _GridOpacity ("Grid Opacity", Range(0.01, 1.0)) = 0.6
        
        // Animation control properties
        _IlluminationRadius ("Illumination Radius", Range(0.1, 0.8)) = 0.3
        _WaveIntensity ("Wave Intensity", Range(0, 2.0)) = 1.0
        _WaveSpeed ("Wave Speed", Range(0, 2)) = 1
        _TransparencyDelay ("Transparency Delay", Range(0, 0.8)) = 0.1
        _TransparencySpeed ("Transparency Speed", Range(0, 2.0)) = 1
        
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
            fixed4 _GridColor;
            float _GridSize;
            float _GridThickness;
            float _GridOpacity;
            float _IlluminationRadius;
            float _WaveIntensity;
            float _WaveSpeed;
            float _TransparencyDelay;
            float _TransparencySpeed;
            float _UseMobileOptimization;

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // Main fragment shader - generates animated grid effect for touch particles
            fixed4 frag (v2f i) : SV_Target
            {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                // Early exit prevents rendering expired particles
                float age = (_TimeNow - _StartTime) / _Lifetime;
                if (age <= 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                // === COORDINATE SYSTEM SETUP ===
                // Precompute frequently used coordinate transformations for performance
                float2 centerOffset = i.uv - 0.5;  // Center-based coordinates for distance calculations
                float distance = length(centerOffset);  // Distance from particle center
                float2 gridUV = i.uv * _GridSize;  // Scaled coordinates for grid pattern
                float2 gridFrac = frac(gridUV);  // Fractional part for grid line detection
                
                // === GRID PATTERN GENERATION ===
                // Create matrix-style grid lines using optimized vector operations
                // Grid lines appear at cell boundaries based on thickness parameter
                float2 gridLines = step(gridFrac, _GridThickness) + step(1.0 - _GridThickness, gridFrac);
                float grid = max(gridLines.x, gridLines.y);  // Combine horizontal and vertical lines
                
                // === EXPANDING WAVE EFFECT ===
                // Generate outward-expanding wave ring that travels from touch point
                float waveRadius = age * _WaveSpeed;  // Wave position based on time
                float wave = saturate(1.0 - abs(distance - waveRadius));  // Ring-shaped wave pattern
                wave = smoothstep(0.8, 1.0, wave) * _WaveIntensity;  // Sharp wave edge with intensity control
                
                // === BASE ILLUMINATION SYSTEM ===
                // Create expanding area of illumination that grows over particle lifetime
                float illuminationRadius = _IlluminationRadius * (1.0 + age * 0.5);  // Radius grows with age
                float illuminationMask = saturate(1.0 - distance / illuminationRadius);  // Normalized distance mask
                illuminationMask *= illuminationMask;  // Squared falloff for softer gradient
                
                // === PARTICLE BOUNDARY DEFINITION ===
                // Define circular particle boundaries with smooth edge transition
                float particleBoundary = smoothstep(0.45, 0.1, distance);  // Circular fade from edge to center
                
                // === ILLUMINATION COMBINATION ===
                // Combine wave and base illumination effects within particle boundaries
                float totalIllumination = (wave + illuminationMask * 0.3) * particleBoundary;
                float illuminatedGrid = grid * totalIllumination;  // Apply illumination to grid pattern
                
                // === TRANSPARENCY WAVE SYSTEM ===
                // Create secondary expanding transparency effect for visual depth
                // Removes previously illuminated areas to create following transparency wave
                float transparencyAge = saturate((age - _TransparencyDelay) / (1.0 - _TransparencyDelay));
                float transparencyRadius = transparencyAge * _TransparencySpeed * 0.6;
                float transparencyMask = smoothstep(transparencyRadius - 0.1, transparencyRadius + 0.05, distance);
                
                // === EDGE AND TEMPORAL FADE EFFECTS ===
                // Prevent visual artifacts at texture boundaries and provide natural fade-out
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);  // Distance to nearest edge
                float edgeFade = smoothstep(0.0, 0.05, min(edgeDistance.x, edgeDistance.y));  // Fade near edges
                float timeFade = 1.0 - age;  // Linear fade over particle lifetime
                
                // === FINAL COMPOSITING ===
                // Combine all effects to produce final pixel color and alpha
                float gridAlpha = illuminatedGrid * _GridOpacity * timeFade * edgeFade * transparencyMask;
                
                return float4(_GridColor.rgb, gridAlpha);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}