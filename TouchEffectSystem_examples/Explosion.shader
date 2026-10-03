Shader "UI/Explosion"
{
    Properties
    {
        // Core system properties - managed by TouchGlowUI script
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 1.0
        
        // Core animation properties
        [Toggle] _Scaling ("Disappearing Scaling", Float) = 1
        [Toggle] _Fading ("Disappearing Fading", Float) = 1

        // Explosion heat gradient color properties - configurable by designers
        _ColorCore ("Core Color", Color) = (1.0, 1.0, 0.95, 1)
        _ColorHot ("Hot Color", Color) = (1.0, 0.8, 0.3, 1)
        _ColorWarm ("Warm Color", Color) = (1.0, 0.5, 0.15, 1)
        
        // Flash core properties - initial impact brightness
        _FlashIntensity ("Flash Intensity", Range(0.0, 3.0)) = 2.0
        _FlashSize ("Flash Size", Range(0.02, 0.15)) = 0.15
        _FlashDuration ("Flash Duration", Range(0.05, 0.3)) = 0.12
        
        // Fireball properties - main explosion body control
        _FireballSize ("Fireball Size", Range(0.1, 1)) = 0.47
        _FireballComplexity ("Fireball Complexity", Range(2.0, 10.0)) = 5.0
        _FireballDistortion ("Fireball Distortion", Range(0.0, 5.0)) = 2.0
        
        // Debris properties - flying spark particles
        _DebrisCount ("Debris Count", Range(10, 40)) = 25
        _DebrisMinSize ("Debris Min Size", Range(0.003, 0.01)) = 0.005
        _DebrisMaxSize ("Debris Max Size", Range(0.008, 0.02)) = 0.012
        _DebrisSpeed ("Debris Speed", Range(0.3, 1.5)) = 0.8
        
        // Platform optimization and touch behavior properties
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
        // UI transparency rendering configuration
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        
        // Additive blending for bright explosion glow effect
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
            float4 _MainTex_ST;
            float _TimeNow, _StartTime, _Lifetime;
            float4 _ColorCore, _ColorHot, _ColorWarm;
            float _FlashIntensity, _FlashSize, _FlashDuration;
            float _FireballSize, _FireballComplexity, _FireballDistortion;
            float _DebrisCount, _DebrisMinSize, _DebrisMaxSize, _DebrisSpeed;
            float _Scaling, _Fading;
            float _UseMobileOptimization;
            float _OneTouchHoldAge, _HoldingForbidden;

            // Optimized pseudo-random number generator for procedural variation
            // Uses fast mathematical properties for consistent cross-platform results
            float rand(float2 co) {
                return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Smooth noise interpolation for organic fire patterns
            // Bilinear interpolation between noise values for continuous gradients
            float noise(float2 p) {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                
                float a = rand(i);
                float b = rand(i + float2(1.0, 0.0));
                float c = rand(i + float2(0.0, 1.0));
                float d = rand(i + float2(1.0, 1.0));
                
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            // Fractal Brownian Motion for complex fire patterns
            // Combines multiple octaves of noise at different frequencies for natural appearance
            float fbm(float2 p, int octaves) {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                
                for(int i = 0; i < octaves; i++) {
                    value += amplitude * noise(p * frequency);
                    frequency *= 2.1;
                    amplitude *= 0.5;
                }
                
                return value;
            }

            // Standard vertex shader for UI elements
            // Transforms vertex positions to clip space and passes UV coordinates
            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // Main fragment shader - generates explosion effect with flash, fireball, and debris
            fixed4 frag (v2f i) : SV_Target {
                // === PARTICLE LIFETIME MANAGEMENT ===
                // Calculate normalized age (0.0 = birth, 1.0 = death)
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                // Preview mode - show explosion at 25% lifecycle for inspector
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.25, previewMode);
                
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
                // Convert to center-based coordinates for radial explosion generation
                float2 uv = i.uv - 0.5;
                float centerDistance = length(uv);
                
                // Generate unique seed per particle for variation
                float particleSeed = frac(_StartTime * 12.9898);
                
                // === SIZE SCALING OVER LIFETIME ===
                // Apply shrinking animation as explosion dissipates
                float sizeScale = 1.0;
                if (_Scaling > 0.5) {
                    sizeScale = 1.0 - effectiveAge * 0.5;
                }
                
                // === INITIAL FLASH CORE GENERATION ===
                // Create bright center flash at explosion start
                float scaledFlashSize = _FlashSize * sizeScale;
                float flashMask = 1.0 - smoothstep(0.0, scaledFlashSize, centerDistance);
                
                // Flash intensity peaks early then fades based on duration parameter
                float flashIntensity = smoothstep(0.0, 0.05, effectiveAge) * 
                                      (1.0 - smoothstep(0.0, _FlashDuration, effectiveAge));
                float flash = flashMask * flashIntensity * _FlashIntensity;
                
                // === FIREBALL GENERATION ===
                // Create main explosion body with organic fire shape
                float fireballRadius = _FireballSize * sizeScale;
                
                // === PROCEDURAL FIRE PATTERN ===
                // Generate multi-layered noise for irregular fire boundaries
                float2 fireCoord = uv * 8.0;
                int octaves = int(_FireballComplexity);
                
                // Two noise layers with different movement directions for turbulence
                float fireNoise1 = fbm(fireCoord + float2(effectiveAge * 2.0, particleSeed * 10.0), octaves);
                float fireNoise2 = fbm(fireCoord * 1.3 - float2(particleSeed * 5.0, effectiveAge * 3.0), octaves);
                
                // Combine noise layers with weighted contribution
                float firePattern = fireNoise1 * 0.6 + fireNoise2 * 0.4;
                
                // === BOUNDARY DISTORTION ===
                // Add irregular edges to fireball using noise pattern
                float distortion = (firePattern - 0.5) * _FireballDistortion * 0.2;
                float distortedDistance = centerDistance + distortion;
                
                // === FIREBALL SHAPE LAYERS ===
                // Create hot core and warm edge zones with smooth transitions
                float fireballCore = 1.0 - smoothstep(fireballRadius * 0.4, fireballRadius * 0.7, distortedDistance);
                float fireballEdge = 1.0 - smoothstep(fireballRadius * 0.7, fireballRadius, distortedDistance);
                
                // === FLYING DEBRIS GENERATION ===
                // Create spark particles radiating outward from explosion center
                float debrisLayer = 0.0;
                int debrisCount = int(_DebrisCount);
                
                // === DEBRIS LOOP ===
                // Generate individual debris particles with random trajectories
                for (int debris = 0; debris < 40; debris++) {
                    if (debris >= debrisCount) break;
                    
                    // Unique seed per debris particle for variation
                    float debrisSeed = float(debris) * 456.789 + particleSeed * 321.654;
                    
                    // === DEBRIS TRAJECTORY ===
                    // Random outward direction from explosion center
                    float debrisAngle = rand(float2(debrisSeed, 0)) * 6.28318;
                    float2 direction = float2(cos(debrisAngle), sin(debrisAngle));
                    
                    // Random speed and size for natural variation
                    float speed = (rand(float2(debrisSeed, 1)) * 0.6 + 0.4) * _DebrisSpeed;
                    float size = lerp(_DebrisMinSize, _DebrisMaxSize, rand(float2(debrisSeed, 2)));
                    float delay = rand(float2(debrisSeed, 3)) * 0.1;
                    
                    // === DEBRIS MOTION ===
                    // Particles launch from fireball edge and travel outward
                    float debrisAge = max(0.0, effectiveAge - delay);
                    float2 debrisPos = direction * (fireballRadius * 0.5 + speed * debrisAge);
                    
                    // === DEBRIS LIFETIME ===
                    // Fade out debris as it travels and cools
                    float debrisLife = 1.0 - smoothstep(0.3, 0.9, debrisAge);
                    
                    // === DEBRIS SHAPE ===
                    // Create small circular particle with soft edges
                    float scaledDebrisSize = size * sizeScale;
                    float distToDebris = length(uv - debrisPos);
                    float debrisMask = 1.0 - smoothstep(scaledDebrisSize * 0.5, scaledDebrisSize, distToDebris);
                    debrisMask *= debrisLife;
                    
                    // Accumulate debris particles using maximum for proper overlap
                    debrisLayer = max(debrisLayer, debrisMask);
                }
                
                // === HEAT GRADIENT SYSTEM ===
                // Calculate temperature based on distance from explosion center
                float temperature = fireballCore + fireballEdge * 0.5;
                
                // === OPTIMIZED COLOR BLENDING ===
                // Blend between heat gradient colors using smoothstep for transitions
                float hotBlend = smoothstep(0.6, 1.0, temperature);
                float warmBlend = smoothstep(0.2, 0.6, temperature) * (1.0 - hotBlend);
                float coolBlend = (1.0 - hotBlend - warmBlend) * smoothstep(0.0, 0.2, temperature);
                
                float3 heatColor = _ColorCore.rgb * hotBlend + 
                                  _ColorHot.rgb * warmBlend + 
                                  _ColorWarm.rgb * coolBlend;
                
                // === FIREBALL INTENSITY CALCULATION ===
                // Combine core and edge contributions for final brightness
                float fireballIntensity = fireballCore * 1.2 + fireballEdge * 0.4;
                
                // === COLOR COMPOSITION ===
                // Build final color from fireball, flash, and debris layers
                float3 finalColor = heatColor * fireballIntensity;
                
                // Add bright flash overlay
                finalColor += _ColorCore.rgb * flash;
                
                // Add hot debris spark colors
                finalColor += _ColorHot.rgb * debrisLayer;
                
                // === INTENSITY ACCUMULATION ===
                // Calculate total brightness for alpha channel
                float totalIntensity = max(fireballIntensity * 0.8, flash);
                totalIntensity = max(totalIntensity, debrisLayer * 0.6);
                
                // === TEMPORAL FADE SYSTEM ===
                // Natural explosion fade-out in final 30% of lifetime
                float timeFade = 1.0;
                if (_Fading > 0.5) {
                    timeFade = 1.0 - smoothstep(0.7, 1.0, age);
                }
                
                // === BOUNDARY CONTAINMENT ===
                // Keep explosion within particle texture bounds
                float maxRadius = 0.45;
                float boundaryFade = 1.0 - smoothstep(maxRadius - 0.05, maxRadius, centerDistance);
                
                // === EDGE FADE EFFECTS ===
                // Prevent visual artifacts at texture boundaries
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.08, min(edgeDistance.x, edgeDistance.y));
                
                // === FINAL COMPOSITING ===
                // Apply all fade effects to color and alpha channels
                finalColor *= timeFade * edgeFade * boundaryFade;
                
                return float4(finalColor, totalIntensity * timeFade * edgeFade * boundaryFade);
            }
            ENDHLSL
        }
    }
    
    // Fallback for systems that don't support this shader
    Fallback "UI/Default"
}