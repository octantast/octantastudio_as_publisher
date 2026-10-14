# Shader Development Assistant

## Main Goal

Create a high-quality, animated, procedurally generated VFX effect using a shader, in the style of my project and according to my descriptions.

## Workflow

1. I send you sample shaders that control the animation of a particle in my system. Read them as samples only: do not go deep, just grasp the general structure. The new shader is built on their basis.
2. I describe the visual I need.
3. You build a base version that follows my technical specification exactly, with no additions.
4. We iterate on it together.

## Visual Freedom

The new visual does not have to resemble the samples. Everything is written from scratch: the direction of the animation's movement, the colors, the overall vibe and style (vector, aura, the appearance and fade-out animation, and so on). Only the structure below is carried over from the samples.

## Mandatory Structure

Whatever the visual is, preserve the structure of the samples. These requirements take priority over the visual design:

- Lifetime cycle
- Transparent background
- Effect stays inside the particle bounds

## Constraints

- Syntax must be flawless. Be especially careful with the declaration of properties and the use of headers.
- Avoid overly complex elements, such as `line`.

---

# Sample Shaders

The following shaders are reference samples only. They define the structural conventions used in my project (property layout, lifetime handling, additive/alpha blending, edge fade, etc.). Do not copy their visual design — only the structure.

---

## Sample 1 — `Fireflies.shader`

```hlsl
Shader "UI/Fireflies"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 2.5
        [HideInInspector] _Scale ("Scale", Float) = 1
        
        _FireflyColor ("Firefly Color", Color) = (1, 0.95, 0.7, 1)
        _GlowColor ("Glow Color", Color) = (0.9, 0.8, 0.5, 1)
        _FireflyCount ("Firefly Count", Range(8, 24)) = 16
        _FireflySize ("Firefly Size", Range(0.015, 0.08)) = 0.035
        
        _FlightRadius ("Flight Radius", Range(0.2, 0.8)) = 0.5
        _FlightSpeed ("Flight Speed", Range(0.3, 2)) = 0.8
        _FloatAmplitude ("Float Amplitude", Range(0.05, 0.3)) = 0.15
        
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

            float _TimeNow, _StartTime, _Lifetime;
            float _Scale;
            
            float4 _FireflyColor, _GlowColor;
            float _FireflyCount, _FireflySize;
            
            float _FlightRadius, _FlightSpeed, _FloatAmplitude;
            
            float _PulseSpeed, _GlowIntensity;

            float hash(float n) {
                return frac(sin(n * 12.9898) * 43758.5453);
            }

            float softCircle(float2 uv, float2 center, float radius) {
                float2 d = uv - center;
                float dist2 = dot(d, d);
                return exp(-dist2 / (radius * radius * 0.3));
            }

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float2 center = float2(0.5, 0.5);
                float3 finalColor = float3(0, 0, 0);
                float finalAlpha = 0.0;
                
                float lifeFade = sin(age * 3.14159);
                lifeFade = lifeFade * lifeFade;
                
                float distFromCenter = length(i.uv - center);
                float radialFade = 1.0 - smoothstep(0.3, 0.5, distFromCenter);
                
                for (int f = 0; f < _FireflyCount; f++) {
                    float fireflyId = float(f);
                    
                    float speed = hash(fireflyId) * 0.5 + 0.7;
                    float size = hash(fireflyId + 1.0) * 0.4 + 0.7;
                    float angleOffset = hash(fireflyId + 2.0) * 6.28318;
                    float pulseOffset = hash(fireflyId + 3.0) * 6.28318;
                    
                    float currentAngle = angleOffset + age * _FlightSpeed * 6.0 * speed;
                    float currentRadius = _FlightRadius * age;
                    
                    float floatY = sin(_TimeNow * 1.5 + angleOffset) * _FloatAmplitude;
                    
                    float2 fireflyPos = center;
                    fireflyPos.x += cos(currentAngle) * currentRadius;
                    fireflyPos.y += sin(currentAngle) * currentRadius + floatY;
                    
                    float pulse = (sin(_TimeNow * _PulseSpeed + pulseOffset) * 0.5 + 0.5);
                    pulse = pulse * pulse * 0.7 + 0.3;
                    
                    float coreRadius = _FireflySize * size * _Scale;
                    float glowRadius = coreRadius * 2.0;
                    
                    float core = softCircle(i.uv, fireflyPos, coreRadius) * pulse;
                    float glow = softCircle(i.uv, fireflyPos, glowRadius) * pulse * 0.3 * _GlowIntensity;
                    
                    finalColor += _FireflyColor.rgb * core * 1.2;
                    finalColor += _GlowColor.rgb * glow;
                    finalAlpha += core + glow;
                }
                
                float2 edgeDist = min(i.uv, 1.0 - i.uv);
                float edgeFade = min(edgeDist.x, edgeDist.y) * 6.0;
                edgeFade = saturate(edgeFade);
                
                float timeFade = 1.0 - smoothstep(0.7, 1.0, age);
                float combinedFade = lifeFade * edgeFade * radialFade * timeFade;
                
                finalColor *= combinedFade * 0.8;
                finalAlpha *= combinedFade * 0.5;
                
                return float4(finalColor, saturate(finalAlpha));
            }
            ENDHLSL
        }
    }
    Fallback "UI/Default"
}
```

---

## Sample 2 — `HealingAura.shader`

```hlsl
Shader "UI/HealingAura"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 3.0
        [HideInInspector] _TouchPoint ("Touch Point", Vector) = (0, 0, 0, 0)
        [HideInInspector] _CanMove ("Can Move", Float) = 0
        [HideInInspector] _Scale ("Scale", Float) = 1
        [HideInInspector] _Resolution ("Resolution", Vector) = (1920, 1080, 0, 0)
        
        _WaveColor ("Wave Color", Color) = (0.4, 1, 0.6, 1)
        _CoreColor ("Core Color", Color) = (0.8, 1, 0.9, 1)
        _WaveCount ("Wave Count", Range(0, 6)) = 2
        _WaveThickness ("Wave Thickness", Range(0, 0.1)) = 0.02
        
        _ExpansionSpeed ("Expansion Speed", Range(0.3, 2)) = 1.0
        _RotationSpeed ("Rotation Speed", Range(0.5, 3)) = 1.5
        _FlowSpeed ("Flow Speed", Range(0.5, 3)) = 1.8
        _Turbulence ("Turbulence", Range(0, 0.3)) = 0.12
        
        _Brightness ("Brightness", Range(0.5, 3)) = 1.8
        _GlowIntensity ("Glow Intensity", Range(0.3, 2)) = 1.0
        
        _BurstIntensity ("Burst Intensity", Range(0.5, 3)) = 2.0
        _BurstSize ("Burst Size", Range(0.05, 0.2)) = 0.1
        
        _SparkleCount ("Sparkle Count", Range(4, 15)) = 8
        _SparkleSize ("Sparkle Size", Range(0.01, 0.04)) = 0.02
        
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        
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

            float hash(float2 p) {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

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

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.5, previewMode);
                
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float effectiveAge = age;
                if (_HoldingForbidden == 0) {
                    effectiveAge = min(age, _OneTouchHoldAge);
                }
                
                float2 center = float2(0.5, 0.5);
                float2 toCenter = i.uv - center;
                float distFromCenter = length(toCenter);
                float angle = atan2(toCenter.y, toCenter.x);
                
                float3 finalColor = float3(0, 0, 0);
                float finalAlpha = 0.0;
                
                float lifeFade = sin(effectiveAge * 3.14159);
                lifeFade = pow(lifeFade, 0.6);
                
                float scaledBurstSize = _BurstSize * _Scale;
                float scaledSparkleSize = _SparkleSize * _Scale;
                
                float burstProgress = smoothstep(0.0, 0.3, effectiveAge);
                float burstFade = 1.0 - smoothstep(0.2, 0.8, effectiveAge);
                float burstCore = exp(-distFromCenter / scaledBurstSize) * burstFade * burstProgress;
                
                float2 flareCoords = abs(toCenter);
                float burstHalfSize = scaledBurstSize * 0.5;
                float burstTripleSize = scaledBurstSize * 3.0;
                
                float horizontalFlare = exp(-flareCoords.y / burstHalfSize) * 
                                       smoothstep(burstTripleSize, 0.0, flareCoords.x);
                float verticalFlare = exp(-flareCoords.x / burstHalfSize) * 
                                     smoothstep(burstTripleSize, 0.0, flareCoords.y);
                float crossFlare = (horizontalFlare + verticalFlare) * burstFade * burstProgress * 0.6;
                
                float burst = (burstCore + crossFlare) * _BurstIntensity;
                finalColor += _CoreColor.rgb * burst;
                finalAlpha += burst;
                
                float flowTime = _TimeNow * _FlowSpeed;
                flowTime = lerp(flowTime, effectiveAge * 5.0, previewMode);
                
                int waveCount = int(_WaveCount);
                float waveRadiusBase = effectiveAge * _ExpansionSpeed * 0.5;
                float turbulenceFactor = _Turbulence * 6.28318;
                
                for (int w = 0; w < 6; w++) {
                    if (w >= waveCount) break;
                    
                    float waveId = float(w);
                    float wavePhase = waveId * 2.094;
                    
                    float waveRadius = waveRadiusBase;
                    
                    float spiralAngle = angle + distFromCenter * 8.0 - flowTime + wavePhase;
                    
                    float turbulence = noise(float2(angle * 3.0, distFromCenter * 5.0 + flowTime)) * turbulenceFactor;
                    spiralAngle += turbulence;
                    
                    float spiralWave = sin(spiralAngle * 2.0) * 0.5 + 0.5;
                    spiralWave = spiralWave * spiralWave * spiralWave;
                    
                    float waveRange = smoothstep(waveRadius - 0.2, waveRadius - 0.1, distFromCenter) *
                                     (1.0 - smoothstep(waveRadius, waveRadius + 0.15, distFromCenter));
                    
                    float waveCore = spiralWave * waveRange;
                    float waveGlow = waveCore * 0.5;
                    
                    float shimmer = noise(float2(angle * 5.0, distFromCenter * 8.0 - flowTime * 2.0));
                    shimmer = shimmer * 0.4 + 0.6;
                    waveCore *= shimmer;
                    
                    finalColor += _WaveColor.rgb * waveCore * _Brightness;
                    finalColor += _CoreColor.rgb * waveGlow * _GlowIntensity;
                    finalAlpha += waveCore * _Brightness + waveGlow * _GlowIntensity;
                }
                
                int sparkleCount = int(_SparkleCount);
                float sparkleHalfSize = scaledSparkleSize * 0.5;
                float sparkleRayLength = scaledSparkleSize * 2.5;
                float rotationFactor = effectiveAge * _RotationSpeed;
                
                for (int s = 0; s < 15; s++) {
                    if (s >= sparkleCount) break;
                    
                    float sparkleId = float(s);
                    float2 sparkleSeed = float2(sparkleId * 0.743, sparkleId * 0.617);
                    
                    float sparkleAngle = hash(sparkleSeed) * 6.28318 + rotationFactor;
                    float sparkleRadius = 0.15 + hash(sparkleSeed * 1.3) * 0.15;
                    
                    float2 sparklePos = center + float2(cos(sparkleAngle), sin(sparkleAngle)) * sparkleRadius;
                    
                    float twinklePhase = hash(sparkleSeed * 1.7) * 6.28318;
                    float twinkleTime = _TimeNow * 3.0 + twinklePhase;
                    twinkleTime = lerp(twinkleTime, effectiveAge * 10.0 + twinklePhase, previewMode);
                    float twinkle = sin(twinkleTime) * 0.5 + 0.5;
                    twinkle = twinkle * twinkle;
                    
                    float2 toSparkle = i.uv - sparklePos;
                    float sparkleCore = exp(-length(toSparkle) / sparkleHalfSize);
                    
                    float2 absCoords = abs(toSparkle);
                    float hRay = exp(-absCoords.y / scaledSparkleSize) * 
                                smoothstep(sparkleRayLength, 0.0, absCoords.x);
                    float vRay = exp(-absCoords.x / scaledSparkleSize) * 
                                smoothstep(sparkleRayLength, 0.0, absCoords.y);
                    
                    float sparkle = (sparkleCore + hRay * 0.4 + vRay * 0.4) * twinkle;
                    
                    finalColor += _CoreColor.rgb * sparkle;
                    finalAlpha += sparkle * 0.8;
                }
                
                float radialFade = 1.0 - smoothstep(0.3, 0.45, distFromCenter);
                
                float2 edgeDist = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.1, min(edgeDist.x, edgeDist.y));
                
                float timeFade = 1.0 - smoothstep(0.7, 1.0, age);
                
                finalAlpha *= lifeFade * radialFade * edgeFade * timeFade;
                finalColor *= lifeFade * radialFade * edgeFade * timeFade;
                
                finalAlpha = saturate(finalAlpha * 0.5);
                finalColor = saturate(finalColor * 0.85);
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    Fallback "UI/Default"
}
```

---

## Sample 3 — `HealingPluses.shader`

```hlsl
Shader "UI/HealingPluses"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 2.5
        [HideInInspector] _TouchPoint ("Touch Point", Vector) = (0, 0, 0, 0)
        [HideInInspector] _CanMove ("Can Move", Float) = 0
        [HideInInspector] _Scale ("Scale", Float) = 1
        [HideInInspector] _Resolution ("Resolution", Vector) = (1920, 1080, 0, 0)
        
        _PlusColor ("Plus Color", Color) = (0.4, 1, 0.6, 1)
        _GlowColor ("Glow Color", Color) = (0.6, 1, 0.8, 1)
        _PlusCount ("Plus Count", Range(5, 20)) = 5
        _PlusSize ("Plus Size", Range(0.02, 0.08)) = 0.04
        _PlusThickness ("Plus Thickness", Range(0.3, 0.7)) = 0.5
        
        _RiseSpeed ("Rise Speed", Range(0.5, 2.5)) = 1
        _SpreadRadius ("Spread Radius", Range(0.05, 0.5)) = 0.2
        _VerticalSpread ("Vertical Spread", Range(0, 0.5)) = 0.3
        
        _Brightness ("Brightness", Range(0.5, 3)) = 1.5
        _GlowIntensity ("Glow Intensity", Range(0.5, 2)) = 1.0
        _PulseSpeed ("Pulse Speed", Range(0, 4)) = 2.0
        
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        
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

            float hash(float2 p) {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            float softPlus(float2 p, float size, float thickness) {
                float2 absP = abs(p);
                float halfThickness = size * thickness * 0.5;
                
                float horizontal = smoothstep(halfThickness + 0.01, halfThickness - 0.005, absP.y) * 
                                  smoothstep(size + 0.01, size - 0.01, absP.x);
                
                float vertical = smoothstep(halfThickness + 0.01, halfThickness - 0.005, absP.x) * 
                                smoothstep(size + 0.01, size - 0.01, absP.y);
                
                return max(horizontal, vertical);
            }

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.5, previewMode);
                
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float effectiveAge = age;
                if (_HoldingForbidden == 0) {
                    effectiveAge = min(age, _OneTouchHoldAge);
                }
                
                float2 center = float2(0.5, 0.5);
                
                float3 finalColor = float3(0, 0, 0);
                float finalAlpha = 0.0;
                
                float lifeFade = sin(effectiveAge * 3.14159);
                lifeFade = pow(lifeFade, 0.7);
                
                float particleSeed = frac(_StartTime * 12.9898 + _TouchPoint.x * 78.233 + _TouchPoint.y * 43.544);
                
                int plusCount = int(_PlusCount);
                float scaledPlusSize = _PlusSize * _Scale;
                float spreadDouble = _SpreadRadius * 2.0;
                float riseSpeedFactor = effectiveAge * _RiseSpeed;
                float glowSizeFactor = scaledPlusSize * 0.9;
                float glowIntensityScaled = _GlowIntensity * 0.6;
                
                for (int p = 0; p < 20; p++) {
                    if (p >= plusCount) break;
                    
                    float plusId = float(p);
                    float2 plusSeed = float2(plusId * 0.753 + particleSeed, plusId * 0.621 + particleSeed * 0.5);
                    
                    float plusSpeed = hash(plusSeed) * 0.5 + 0.75;
                    float plusPhase = hash(plusSeed * 1.3) * 6.28318;
                    float plusSize = scaledPlusSize * (0.8 + hash(plusSeed * 2.0) * 0.4);
                    
                    float horizontalOffset = (hash(plusSeed * 2.3) - 0.5) * spreadDouble;
                    float verticalOffset = hash(plusSeed * 2.7) * _VerticalSpread;
                    
                    float riseProgress = riseSpeedFactor * plusSpeed;
                    float plusY = 0.35 + verticalOffset + riseProgress * 0.5;
                    float plusX = center.x + horizontalOffset;
                    
                    float2 plusPos = float2(plusX, plusY);
                    
                    float distFromCenter = length(plusPos - center);
                    if (distFromCenter < 0.35) {
                        float2 toPlus = i.uv - plusPos;
                        
                        float plusCore = softPlus(toPlus, plusSize, _PlusThickness);
                        
                        float glowDist = length(toPlus);
                        float plusGlow = exp(-glowDist / glowSizeFactor) * 0.3;
                        
                        float pulseTime = _TimeNow * _PulseSpeed + plusPhase;
                        pulseTime = lerp(pulseTime, effectiveAge * 6.0 + plusPhase, previewMode);
                        float pulse = sin(pulseTime) * 0.5 + 0.5;
                        pulse = pulse * pulse * 0.3 + 0.7;
                        
                        float naturalFade = 1.0 - smoothstep(0.18, 0.32, distFromCenter);
                        naturalFade *= smoothstep(0.0, 0.12, riseProgress) * 
                                      (1.0 - smoothstep(0.45, 0.65, riseProgress));
                        
                        float plusBrightness = (plusCore * 1.2 + plusGlow) * pulse * naturalFade;
                        
                        finalColor += _PlusColor.rgb * plusCore * pulse * naturalFade * _Brightness;
                        finalColor += _GlowColor.rgb * plusGlow * pulse * naturalFade * glowIntensityScaled;
                        finalAlpha += plusBrightness;
                    }
                }
                
                float2 edgeDist = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.25, min(edgeDist.x, edgeDist.y));
                
                float timeFade = 1.0 - smoothstep(0.75, 1.0, age);
                
                finalAlpha *= lifeFade * edgeFade * timeFade;
                finalColor *= lifeFade * edgeFade * timeFade;
                
                finalAlpha = saturate(finalAlpha * 0.5);
                finalColor = saturate(finalColor * 0.95);
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    Fallback "UI/Default"
}
```

---

## Sample 4 — `RadialSparks.shader`

```hlsl
Shader "UI/RadialSparks"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 0.8
        [HideInInspector] _Scale ("Scale", Float) = 1.0
        [HideInInspector] _AllowMovement ("Allow Movement", Float) = 1.0
        
        _SparkColor ("Spark Color", Color) = (1.0, 0.7, 0.2, 1)
        _GlowColor ("Glow Color", Color) = (1.0, 0.85, 0.5, 1)
        
        _SparkCount ("Spark Count", Range(8, 40)) = 20
        _SparkLength ("Spark Length", Range(0.02, 0.15)) = 0.08
        _SparkWidth ("Spark Width", Range(0.001, 0.008)) = 0.003
        _SparkSpeed ("Spark Speed", Range(0.5, 2.5)) = 1.2
        _SparkSpread ("Spark Spread", Range(0.1, 0.5)) = 0.35
        _SparkTaper ("Spark Taper", Range(0.0, 1.0)) = 0.6
        
        _GlowIntensity ("Glow Intensity", Range(0.0, 5.0)) = 2
        _CenterFlash ("Center Flash", Range(0.0, 1.0)) = 0.5
        
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0.5
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
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

            sampler2D _MainTex;
            float _TimeNow, _StartTime, _Lifetime, _Scale, _AllowMovement;
            float4 _SparkColor, _GlowColor;
            float _SparkCount, _SparkLength, _SparkWidth, _SparkSpeed, _SparkSpread, _SparkTaper;
            float _GlowIntensity, _CenterFlash;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            float hash(float2 p) {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

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

            float lineSegment(float2 p, float2 a, float2 b, float width, float taper) {
                float2 pa = p - a;
                float2 ba = b - a;
                float h = saturate(dot(pa, ba) / dot(ba, ba));
                float dist = length(pa - ba * h);
                
                float taperWidth = width * (1.0 - h * taper);
                
                return 1.0 - smoothstep(0.0, taperWidth, dist);
            }

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float2 edgeDist = min(i.uv, 1.0 - i.uv);
                float edgeMask = smoothstep(0.0, 0.03, min(edgeDist.x, edgeDist.y));
                if (edgeMask <= 0.0) return float4(0, 0, 0, 0);
                
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.4, previewMode);
                
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float2 center = float2(0.5, 0.5);
                float2 uv = i.uv - center;
                uv /= _Scale;
                
                float fadeIn = smoothstep(0.0, 0.08, age);
                float fadeOut = smoothstep(1.0, 0.75, age);
                float totalFade = fadeIn * fadeOut;
                
                float absTime = _TimeNow * 2.0;
                absTime = lerp(absTime, 1.5, previewMode);
                
                float sparksEffect = 0.0;
                float glowEffect = 0.0;
                
                for (int s = 0; s < 40; s++) {
                    if (s >= _SparkCount) break;
                    
                    float sparkId = float(s);
                    float2 sparkSeed = float2(sparkId * 0.741, sparkId * 0.569);
                    
                    float angleOffset = hash(sparkSeed) * 0.3 - 0.15;
                    float sparkAngle = (sparkId / _SparkCount) * 6.28318 + angleOffset;
                    float sinAngle = sin(sparkAngle);
                    float cosAngle = cos(sparkAngle);
                    float2 sparkDir = float2(cosAngle, sinAngle);
                    
                    float sparkTime = absTime * _SparkSpeed + hash(sparkSeed * 2.0) * 2.0;
                    float sparkProgress = frac(sparkTime);
                    float sparkDist = sparkProgress * _SparkSpread;
                    
                    float startOffset = 0.01;
                    float currentLength = _SparkLength * (0.3 + sparkProgress * 0.7);
                    float2 sparkEnd = sparkDir * (startOffset + sparkDist);
                    float2 sparkStart = sparkEnd - sparkDir * currentLength;
                    
                    float spark = lineSegment(uv, sparkStart, sparkEnd, _SparkWidth, _SparkTaper);
                    
                    float sparkFade = (1.0 - sparkProgress) * (0.5 + sparkProgress * 0.5);
                    
                    float flicker = noise(float2(sparkId * 10.0, absTime * 5.0)) * 0.4 + 0.6;
                    
                    float2 sparkMid = (sparkStart + sparkEnd) * 0.5;
                    float distToSpark = length(uv - sparkMid);
                    float sparkGlow = exp(-distToSpark * 30.0) * sparkFade * 0.5;
                    
                    sparksEffect += spark * sparkFade * flicker;
                    glowEffect += sparkGlow * flicker;
                }
                
                float centerDist = length(uv);
                float flash = exp(-centerDist * 20.0) * _CenterFlash;
                float flashFade = 1.0 - smoothstep(0.0, 0.3, age);
                flash *= flashFade;
                
                float radialGlow = exp(-centerDist * 8.0) * 0.4 * _GlowIntensity;
                
                float3 finalColor = _SparkColor.rgb * sparksEffect +
                                  _GlowColor.rgb * (glowEffect * _GlowIntensity + flash + radialGlow);
                
                float finalAlpha = (sparksEffect * 0.9 + glowEffect * _GlowIntensity * 0.6 + 
                                  flash * 0.8 + radialGlow * 0.5) * 
                                  totalFade * edgeMask;
                
                finalAlpha = saturate(finalAlpha);
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    Fallback "UI/Default"
}
```

---

## Sample 5 — `TouchPointForceFieldHex.shader`

```hlsl
Shader "UI/TouchPointForceFieldHex"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 2.0
        
        _LineColor ("Line Color", Color) = (1, 1, 1, 1)
        _HexSize ("Hex Size", Range(3, 15)) = 6
        _LineThickness ("Line Thickness", Range(0.01, 0.08)) = 0.03
        _LineOpacity ("Line Opacity", Range(0.0, 1.0)) = 0.8
        _WaveWidth ("Wave Width", Range(0.05, 0.2)) = 0.1
        
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType"="Transparent" 
            "Queue"="Transparent" 
            "IgnoreProjector"="True"
        }
        
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

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

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

            float hexGrid(float2 uv)
            {
                float2 hexUV = uv * _HexSize;
                
                float2 c = hexUV;
                c.y += 0.5 * (int(c.x) % 2);
                
                float2 f = frac(c);
                float2 h = abs(f - 0.5);
                
                float hexEdge = max(h.x * 1.732 + h.y, h.y * 2.0) - 1.0;
                
                return 1.0 - smoothstep(0.0, _LineThickness, abs(hexEdge));
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float age = (_TimeNow - _StartTime) / _Lifetime;
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float distance = length(i.uv - 0.5);
                
                float hexPattern = hexGrid(i.uv);
                if (hexPattern < 0.01) return float4(0, 0, 0, 0);
                
                float wavePosition = age * 0.4;
                
                float waveDistance = abs(distance - wavePosition);
                float waveRing = 1.0 - smoothstep(0.0, _WaveWidth * 1.5, waveDistance);
                
                float fadeProgress = saturate((wavePosition - distance) / max(wavePosition, 0.001));
                fadeProgress = pow(fadeProgress, 0.5);
                float behindWaveFade = saturate(step(distance, wavePosition) * (1.0 - smoothstep(0.0, 1.0, fadeProgress)));
                
                float waveVisibility = max(waveRing, behindWaveFade);
                
                float timeFade = 1.0 - smoothstep(0.4, 1.0, age);
                timeFade = pow(timeFade, 0.7);
                
                float boundary = 1.0 - smoothstep(0.35, 0.45, distance);
                
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.05, min(edgeDistance.x, edgeDistance.y));
                
                float finalAlpha = hexPattern * waveVisibility * timeFade * boundary * _LineOpacity * edgeFade;
                
                return float4(_LineColor.rgb, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    Fallback "UI/Default"
}
```

---

## Sample 6 — `VibroImpact.shader`

```hlsl
Shader "UI/VibroImpact"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 1.2
                
        _WaveColor ("Wave Color", Color) = (1, 1, 1, 1)
        _EdgeColor ("Edge Color", Color) = (0.8, 0.9, 1, 1)
        
        _WaveCount ("Wave Count", Range(2, 8)) = 4
        _WaveThickness ("Wave Thickness", Range(0.01, 0.15)) = 0.06
        _WaveIntensity ("Wave Intensity", Range(0.5, 2.0)) = 1.0
        _Sharpness ("Sharpness", Range(1, 10)) = 4
        _PolygonSides ("Polygon Sides", Range(4, 12)) = 6
        
        _ExpandSpeed ("Expand Speed", Range(1, 5)) = 2.5
        _Distortion ("Distortion", Range(0, 0.5)) = 0.2
        
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0.3
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 0
    }
    
    SubShader
    {
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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _TimeNow, _StartTime, _Lifetime;
            float4 _WaveColor, _EdgeColor;
            float _WaveCount, _WaveThickness, _WaveIntensity, _Sharpness, _PolygonSides;
            float _ExpandSpeed, _Distortion;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            float2 toPolar(float2 uv) {
                float2 centered = uv - 0.5;
                float radius = length(centered) * 2.0;
                float angle = atan2(centered.y, centered.x);
                return float2(radius, angle);
            }

            float polygonShape(float radius, float angle, float sides, float time) {
                float distortion = sin(angle * 3.0 + time * 5.0) * _Distortion;
                radius += distortion * 0.1;
                
                float segment = 6.28318 / sides;
                float polygon = cos(floor(0.5 + angle / segment) * segment - angle) * radius;
                return polygon;
            }

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
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.3, previewMode);
                
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                if (_HoldingForbidden > 0.5 && age >= _OneTouchHoldAge) {
                    return float4(0, 0, 0, 0);
                }
                
                float2 polar = toPolar(i.uv);
                float radius = polar.x;
                float angle = polar.y;
                
                float sizeScale = 1.0;
                
                float time = _TimeNow * 3.0;
                
                float scaledRadius = radius / max(sizeScale, 0.001);
                float polygon = polygonShape(scaledRadius, angle, _PolygonSides, time);
                
                float impactEffect = 0.0;
                
                for (int wave = 0; wave < 8; wave++) {
                    if (wave >= _WaveCount) break;
                    
                    float waveOffset = float(wave) / _WaveCount * 0.3;
                    float waveProgress = (age * _ExpandSpeed - waveOffset);
                    
                    if (waveProgress > 0.0) {
                        float waveThickness = _WaveThickness * (0.8 + float(wave) * 0.15);
                        
                        float waveSharpness = _Sharpness * (1.0 - float(wave) * 0.1);
                        
                        float waveValue = comicWave(polygon, waveProgress, waveThickness, waveSharpness);
                        
                        float waveFade = 1.0 - smoothstep(0.0, 0.9, waveProgress);
                        
                        impactEffect += waveValue * waveFade * _WaveIntensity;
                    }
                }
                
                impactEffect = saturate(impactEffect);
                
                float timeFade = 1.0;
                
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.1, min(edgeDistance.x, edgeDistance.y));
                
                float3 finalColor = lerp(_WaveColor.rgb, _EdgeColor.rgb, pow(impactEffect, 2.0));
                float finalAlpha = impactEffect * timeFade * edgeFade;
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    Fallback "UI/Default"
}
```

---

## Sample 7 — `ComicImpactLayers.shader`

```hlsl
Shader "UI/ComicImpactLayers"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 0.8
        
        [Toggle] _Scaling ("Disappearing Scaling", Float) = 1
        [Toggle] _Fading ("Disappearing Fading", Float) = 1

        _FlashColor ("Flash Color", Color) = (1, 1, 1, 1)
        _Layer1Color ("Layer 1 Color", Color) = (1, 1, 1, 1)
        _Layer2Color ("Layer 2 Color", Color) = (1, 0.75, 0.2, 1)
        _Layer3Color ("Layer 3 Color", Color) = (0.9, 0.5, 0.1, 1)
        _OutlineColor ("Outline Color", Color) = (0.3, 0.15, 0.05, 1)

        
        _FlashRadius ("Flash Radius", Range(0, 0.5)) = 0.05
        
        _Layer1Radius ("Layer 1 Radius", Range(0, 0.25)) = 0.1
        _Layer1SpikeCount ("Layer 1 Spike Count", Range(4, 16)) = 8
        _Layer1SpikeLength ("Layer 1 Spike Length", Range(0.05, 0.5)) = 0.25
        
        _Layer2Radius ("Layer 2 Radius", Range(0, 0.5)) = 0.15
        _Layer2SpikeCount ("Layer 2 Spike Count", Range(4, 16)) = 4
        _Layer2SpikeLength ("Layer 2 Spike Length", Range(0.05, 0.2)) = 0.1
        
        _Layer3Radius ("Layer 3 Radius", Range(0, 0.5)) = 0.2
        _Layer3SpikeCount ("Layer 3 Spike Count", Range(0, 16)) = 0
        _Layer3SpikeLength ("Layer 3 Spike Length", Range(0.05, 0.2)) = 0.05
        
        _SpikeSharpness ("Spike Sharpness", Range(0.01, 0.8)) = 0.1
        
        _OutlineWidth ("Outline Width", Range(0.008, 0.025)) = 0.012
        _OutlineCoverage ("Outline Coverage", Range(0.3, 1.0)) = 0.7
        
        _DetailCount ("Detail Count", Range(4, 16)) = 10
        _DetailSize ("Detail Size", Range(0.005, 0.02)) = 0.01
        
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _TimeNow, _StartTime, _Lifetime;
            float4 _FlashColor, _Layer1Color, _Layer2Color, _Layer3Color, _OutlineColor;
            float _FlashRadius;
            float _Layer1Radius, _Layer1SpikeCount, _Layer1SpikeLength;
            float _Layer2Radius, _Layer2SpikeCount, _Layer2SpikeLength;
            float _Layer3Radius, _Layer3SpikeCount, _Layer3SpikeLength;
            float _SpikeSharpness;
            float _OutlineWidth, _OutlineCoverage;
            float _DetailCount, _DetailSize;
            float _Scaling, _Fading;
            float _UseMobileOptimization;
            float _OneTouchHoldAge, _HoldingForbidden;

            float rand(float2 co) {
                return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
            }

            float spikyCircle(float2 p, float baseRadius, int spikeCount, float spikeLength, float layerSeed) {
                float angle = atan2(p.y, p.x);
                float dist = length(p);
                
                float finalRadius = baseRadius;
                
                for (int s = 0; s < 16; s++) {
                    if (s >= spikeCount) break;
                    
                    float spikeSeed = layerSeed + float(s) * 47.3;
                    
                    float spikeAngle = rand(float2(spikeSeed, 0)) * 6.28318;
                    
                    float spikeLen = spikeLength * (0.6 + rand(float2(spikeSeed, 1)) * 0.8);
                    
                    float angleDiff = angle - spikeAngle;
                    angleDiff = atan2(sin(angleDiff), cos(angleDiff));
                    
                    float spikeHalfAngle = _SpikeSharpness * (0.8 + rand(float2(spikeSeed, 2)) * 0.4);
                    
                    if (abs(angleDiff) < spikeHalfAngle) {
                        float normalizedAngle = abs(angleDiff) / spikeHalfAngle;
                        float spikeExtension = spikeLen * (1.0 - normalizedAngle);
                        finalRadius = max(finalRadius, baseRadius + spikeExtension);
                    }
                }
                
                return dist - finalRadius;
            }

            float shouldDrawOutline(float angle, float seed) {
                float segments = 8.0;
                float segmentIndex = floor((angle + 3.14159) / 6.28318 * segments);
                float segmentSeed = seed + segmentIndex * 67.8;
                return step(rand(float2(segmentSeed, 0)), _OutlineCoverage);
            }

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.3, previewMode);
                
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float effectiveAge = age;
                if (_HoldingForbidden == 0 && age > _OneTouchHoldAge)
                {
                    effectiveAge = _OneTouchHoldAge;
                }
                
                float2 uv = i.uv - 0.5;
                float angle = atan2(uv.y, uv.x);
                
                float particleSeed = frac(_StartTime * 12.9898);
                
                float sizeScale = 1.0;
                if (_Scaling > 0.5) {
                    sizeScale = 1.0 - effectiveAge * 0.4;
                }
                
                int layer3Count = int(_Layer3SpikeCount);
                float layer3Dist = spikyCircle(uv, _Layer3Radius * sizeScale, layer3Count, _Layer3SpikeLength * sizeScale, particleSeed + 300.0);
                float layer3Mask = step(layer3Dist, 0.0);
                
                int layer2Count = int(_Layer2SpikeCount);
                float layer2Dist = spikyCircle(uv, _Layer2Radius * sizeScale, layer2Count, _Layer2SpikeLength * sizeScale, particleSeed + 200.0);
                float layer2Mask = step(layer2Dist, 0.0);
                
                int layer1Count = int(_Layer1SpikeCount);
                float layer1Dist = spikyCircle(uv, _Layer1Radius * sizeScale, layer1Count, _Layer1SpikeLength * sizeScale, particleSeed + 100.0);
                float layer1Mask = step(layer1Dist, 0.0);
                
                float flashDist = length(uv) - _FlashRadius * sizeScale;
                float flashMask = step(flashDist, 0.0);
                
                float drawOutline3 = shouldDrawOutline(angle, particleSeed + 30.0);
                float drawOutline2 = shouldDrawOutline(angle, particleSeed + 20.0);
                float drawOutline1 = shouldDrawOutline(angle, particleSeed + 10.0);
                
                float outline3 = 0.0;
                if (drawOutline3 > 0.5) {
                    float outlineDist3 = spikyCircle(uv, _Layer3Radius * sizeScale + _OutlineWidth, layer3Count, _Layer3SpikeLength * sizeScale, particleSeed + 300.0);
                    outline3 = step(outlineDist3, 0.0) * (1.0 - layer3Mask);
                }
                
                float outline2 = 0.0;
                if (drawOutline2 > 0.5) {
                    float outlineDist2 = spikyCircle(uv, _Layer2Radius * sizeScale + _OutlineWidth, layer2Count, _Layer2SpikeLength * sizeScale, particleSeed + 200.0);
                    outline2 = step(outlineDist2, 0.0) * (1.0 - layer2Mask);
                }
                
                float outline1 = 0.0;
                if (drawOutline1 > 0.5) {
                    float outlineDist1 = spikyCircle(uv, _Layer1Radius * sizeScale + _OutlineWidth, layer1Count, _Layer1SpikeLength * sizeScale, particleSeed + 100.0);
                    outline1 = step(outlineDist1, 0.0) * (1.0 - layer1Mask);
                }
                
                float details = 0.0;
                int detailCountInt = int(_DetailCount);
                
                for (int d = 0; d < 16; d++) {
                    if (d >= detailCountInt) break;
                    
                    float detailSeed = float(d) * 456.789 + particleSeed * 123.456;
                    
                    float detailAngle = rand(float2(detailSeed, 0)) * 6.28318;
                    float detailDist = _Layer3Radius * sizeScale * (1.4 + rand(float2(detailSeed, 1)) * 0.4);
                    float2 detailPos = float2(cos(detailAngle), sin(detailAngle)) * detailDist;
                    
                    float detailRadius = _DetailSize * (0.5 + rand(float2(detailSeed, 2)) * 0.5) * sizeScale;
                    float shapeType = rand(float2(detailSeed, 3));
                    
                    float distToDetail = length(uv - detailPos);
                    
                    if (shapeType < 0.6) {
                        details = max(details, step(distToDetail, detailRadius));
                    } else {
                        float2 dashDir = float2(cos(detailAngle), sin(detailAngle));
                        float2 toDetail = uv - detailPos;
                        float alongDash = dot(toDetail, dashDir);
                        float perpDash = length(toDetail - dashDir * alongDash);
                        
                        float dashMask = step(abs(alongDash), detailRadius * 2.0) * step(perpDash, detailRadius * 0.4);
                        details = max(details, dashMask);
                    }
                }
                
                float3 finalColor = float3(0, 0, 0);
                float finalAlpha = 0.0;
                
                if (outline3 > 0.5) {
                    finalColor = _OutlineColor.rgb;
                    finalAlpha = 1.0;
                }
                
                if (layer3Mask > 0.5) {
                    finalColor = _Layer3Color.rgb;
                    finalAlpha = 1.0;
                }
                
                if (outline2 > 0.5) {
                    finalColor = _OutlineColor.rgb;
                    finalAlpha = 1.0;
                }
                
                if (layer2Mask > 0.5) {
                    finalColor = _Layer2Color.rgb;
                    finalAlpha = 1.0;
                }
                
                if (outline1 > 0.5) {
                    finalColor = _OutlineColor.rgb;
                    finalAlpha = 1.0;
                }
                
                if (layer1Mask > 0.5) {
                    finalColor = _Layer1Color.rgb;
                    finalAlpha = 1.0;
                }
                
                if (flashMask > 0.5) {
                    finalColor = _FlashColor.rgb;
                    finalAlpha = 1.0;
                }
                
                if (details > 0.5) {
                    finalColor = _OutlineColor.rgb;
                    finalAlpha = 1.0;
                }
                
                float timeFade = 1.0;
                if (_Fading > 0.5) {
                    timeFade = 1.0 - smoothstep(0.6, 1.0, age);
                }
                
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.05, min(edgeDistance.x, edgeDistance.y));
                
                finalAlpha *= timeFade * edgeFade;
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    Fallback "UI/Default"
}
```

---

## Sample 8 — `ComicPuff.shader`

```hlsl
Shader "UI/ComicPuff"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 1.2
        
        [Toggle] _Scaling ("Disappearing Scaling", Float) = 1
        [Toggle] _Fading ("Disappearing Fading", Float) = 1
        
        _PuffColor ("Puff Color", Color) = (1, 0.95, 0.9, 1)
        _OutlineColor ("Outline Color", Color) = (0.7, 0.65, 0.6, 1)
        _OutlineWidth ("Outline Width", Range(0.0, 0.05)) = 0.01
        
        _BubbleCount ("Bubble Count", Range(3, 12)) = 9
        _BubbleSize ("Bubble Size", Range(0.05, 0.2)) = 0.1
        _BubbleSoftness ("Bubble Softness", Range(0.01, 0.1)) = 0.01
        
        _ExpansionSpeed ("Expansion Speed", Range(0.5, 3.0)) = 2
        _FloatSpeed ("Float Speed", Range(0.0, 2.0)) = 2
        
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _TimeNow, _StartTime, _Lifetime;
            float4 _PuffColor, _OutlineColor;
            float _OutlineWidth;
            float _BubbleCount, _BubbleSize, _BubbleSoftness;
            float _ExpansionSpeed, _FloatSpeed;
            float _Scaling, _Fading;
            float _OneTouchHoldAge, _HoldingForbidden;
            float _UseMobileOptimization;

            float rand(float2 co) {
                return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
            }

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float age = (_TimeNow - _StartTime) / _Lifetime;
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float effectiveAge = age;
                if (_HoldingForbidden == 0 && age > _OneTouchHoldAge)
                {
                    effectiveAge = _OneTouchHoldAge;
                }
                
                float2 uv = i.uv - 0.5;
                float centerDistance = length(uv);
                
                float sizeScale = 1.0;
                if (_Scaling > 0.5) {
                    sizeScale = 1.0 + effectiveAge * _ExpansionSpeed;
                }
                
                float puffShape = 0.0;
                float outlineShape = 0.0;
                
                float particleSeed = frac(_StartTime * 12.9898);
                
                int bubbleClusterCount = int(_BubbleCount);
                
                for (int cluster = 0; cluster < 12; cluster++) {
                    if (cluster >= bubbleClusterCount) break;
                    
                    float clusterSeed = float(cluster) * 123.456 + particleSeed * 789.012;
                    float clusterAngle = rand(float2(clusterSeed, 0)) * 6.28318;
                    
                    float ringRadius = 0.20 + rand(float2(clusterSeed, 1)) * 0.08;
                    
                    float floatPhase = effectiveAge * _FloatSpeed + clusterSeed;
                    float floatX = sin(floatPhase) * 0.02;
                    float floatY = cos(floatPhase * 0.7) * 0.02;
                    
                    float2 clusterCenter = float2(cos(clusterAngle), sin(clusterAngle)) * ringRadius;
                    clusterCenter += float2(floatX, floatY);
                    
                    int bubblesInCluster = 2 + int(rand(float2(clusterSeed, 3)) * 3.0);
                    
                    for (int bubble = 0; bubble < 4; bubble++) {
                        if (bubble >= bubblesInCluster) break;
                        
                        float bubbleSeed = clusterSeed + float(bubble) * 45.678;
                        
                        float bubbleAngleOffset = rand(float2(bubbleSeed, 0)) * 6.28318;
                        float bubbleDistOffset = rand(float2(bubbleSeed, 1)) * 0.06;
                        float2 bubbleOffset = float2(cos(bubbleAngleOffset), sin(bubbleAngleOffset)) * bubbleDistOffset;
                        
                        float2 bubblePos = clusterCenter + bubbleOffset;
                        
                        float bubbleSizeVariation = 0.6 + rand(float2(bubbleSeed, 2)) * 0.8;
                        float scaledBubbleSize = _BubbleSize * bubbleSizeVariation / sizeScale;
                        
                        float2 toBubble = uv - bubblePos;
                        float bubbleDistance = length(toBubble);
                        
                        float bubbleShape = 1.0 - smoothstep(scaledBubbleSize - _BubbleSoftness, 
                                                        scaledBubbleSize, 
                                                        bubbleDistance);
                        
                        float outlineInner = scaledBubbleSize - _OutlineWidth;
                        float outline = smoothstep(outlineInner - 0.01, outlineInner, bubbleDistance) *
                                       (1.0 - smoothstep(scaledBubbleSize, scaledBubbleSize + 0.01, bubbleDistance));
                        
                        puffShape = max(puffShape, bubbleShape);
                        outlineShape = max(outlineShape, outline);
                    }
                }
                
                float maxRadius = 0.5;
                float boundaryFade = 1.0 - smoothstep(maxRadius - 0.1, maxRadius, centerDistance);
                puffShape *= boundaryFade;
                outlineShape *= boundaryFade;
                
                float timeFade = 1.0;
                if (_Fading > 0.5) {
                    timeFade = 1.0 - smoothstep(0.6, 1.0, age);
                }
                
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.05, min(edgeDistance.x, edgeDistance.y));
                
                float3 finalColor = _PuffColor.rgb;
                float finalAlpha = puffShape;
                
                float outlineOnly = outlineShape * (1.0 - puffShape);
                finalColor = lerp(finalColor, _OutlineColor.rgb, outlineOnly);
                finalAlpha = max(finalAlpha, outlineOnly);
                
                finalAlpha *= timeFade * edgeFade;
                
                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    
    Fallback "UI/Default"
}
```

---

## Sample 9 — `Explosion.shader`

```hlsl
Shader "UI/Explosion"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [HideInInspector] _TimeNow ("Time Now", Float) = 0
        [HideInInspector] _StartTime ("Start Time", Float) = 0
        [HideInInspector] _Lifetime ("Lifetime", Float) = 1.0
        
        [Toggle] _Scaling ("Disappearing Scaling", Float) = 1
        [Toggle] _Fading ("Disappearing Fading", Float) = 1

        _ColorCore ("Core Color", Color) = (1.0, 1.0, 0.95, 1)
        _ColorHot ("Hot Color", Color) = (1.0, 0.8, 0.3, 1)
        _ColorWarm ("Warm Color", Color) = (1.0, 0.5, 0.15, 1)
        
        _FlashIntensity ("Flash Intensity", Range(0.0, 3.0)) = 2.0
        _FlashSize ("Flash Size", Range(0.02, 0.15)) = 0.15
        _FlashDuration ("Flash Duration", Range(0.05, 0.3)) = 0.12
        
        _FireballSize ("Fireball Size", Range(0.1, 1)) = 0.47
        _FireballComplexity ("Fireball Complexity", Range(2.0, 10.0)) = 5.0
        _FireballDistortion ("Fireball Distortion", Range(0.0, 5.0)) = 2.0
        
        _DebrisCount ("Debris Count", Range(10, 40)) = 25
        _DebrisMinSize ("Debris Min Size", Range(0.003, 0.01)) = 0.005
        _DebrisMaxSize ("Debris Max Size", Range(0.008, 0.02)) = 0.012
        _DebrisSpeed ("Debris Speed", Range(0.3, 1.5)) = 0.8
        
        [HideInInspector] _UseMobileOptimization ("Use Mobile Optimization", Float) = 0
        _OneTouchHoldAge ("OneTouch Hold Age", Range(0.0, 1.0)) = 0
        [Toggle] _HoldingForbidden ("Holding Forbidden", Float) = 1
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        
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

            float rand(float2 co) {
                return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
            }

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

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float age = (_TimeNow - _StartTime) / _Lifetime;
                
                float previewMode = step(abs(_TimeNow), 0.001);
                age = lerp(age, 0.25, previewMode);
                
                if (age < 0.0 || age >= 1.0) return float4(0, 0, 0, 0);
                
                float effectiveAge = age;
                if (_HoldingForbidden == 0 && age > _OneTouchHoldAge)
                {
                    effectiveAge = _OneTouchHoldAge;
                }
                
                float2 uv = i.uv - 0.5;
                float centerDistance = length(uv);
                
                float particleSeed = frac(_StartTime * 12.9898);
                
                float sizeScale = 1.0;
                if (_Scaling > 0.5) {
                    sizeScale = 1.0 - effectiveAge * 0.5;
                }
                
                float scaledFlashSize = _FlashSize * sizeScale;
                float flashMask = 1.0 - smoothstep(0.0, scaledFlashSize, centerDistance);
                
                float flashIntensity = smoothstep(0.0, 0.05, effectiveAge) * 
                                      (1.0 - smoothstep(0.0, _FlashDuration, effectiveAge));
                float flash = flashMask * flashIntensity * _FlashIntensity;
                
                float fireballRadius = _FireballSize * sizeScale;
                
                float2 fireCoord = uv * 8.0;
                int octaves = int(_FireballComplexity);
                
                float fireNoise1 = fbm(fireCoord + float2(effectiveAge * 2.0, particleSeed * 10.0), octaves);
                float fireNoise2 = fbm(fireCoord * 1.3 - float2(particleSeed * 5.0, effectiveAge * 3.0), octaves);
                
                float firePattern = fireNoise1 * 0.6 + fireNoise2 * 0.4;
                
                float distortion = (firePattern - 0.5) * _FireballDistortion * 0.2;
                float distortedDistance = centerDistance + distortion;
                
                float fireballCore = 1.0 - smoothstep(fireballRadius * 0.4, fireballRadius * 0.7, distortedDistance);
                float fireballEdge = 1.0 - smoothstep(fireballRadius * 0.7, fireballRadius, distortedDistance);
                
                float debrisLayer = 0.0;
                int debrisCount = int(_DebrisCount);
                
                for (int debris = 0; debris < 40; debris++) {
                    if (debris >= debrisCount) break;
                    
                    float debrisSeed = float(debris) * 456.789 + particleSeed * 321.654;
                    
                    float debrisAngle = rand(float2(debrisSeed, 0)) * 6.28318;
                    float2 direction = float2(cos(debrisAngle), sin(debrisAngle));
                    
                    float speed = (rand(float2(debrisSeed, 1)) * 0.6 + 0.4) * _DebrisSpeed;
                    float size = lerp(_DebrisMinSize, _DebrisMaxSize, rand(float2(debrisSeed, 2)));
                    float delay = rand(float2(debrisSeed, 3)) * 0.1;
                    
                    float debrisAge = max(0.0, effectiveAge - delay);
                    float2 debrisPos = direction * (fireballRadius * 0.5 + speed * debrisAge);
                    
                    float debrisLife = 1.0 - smoothstep(0.3, 0.9, debrisAge);
                    
                    float scaledDebrisSize = size * sizeScale;
                    float distToDebris = length(uv - debrisPos);
                    float debrisMask = 1.0 - smoothstep(scaledDebrisSize * 0.5, scaledDebrisSize, distToDebris);
                    debrisMask *= debrisLife;
                    
                    debrisLayer = max(debrisLayer, debrisMask);
                }
                
                float temperature = fireballCore + fireballEdge * 0.5;
                
                float hotBlend = smoothstep(0.6, 1.0, temperature);
                float warmBlend = smoothstep(0.2, 0.6, temperature) * (1.0 - hotBlend);
                float coolBlend = (1.0 - hotBlend - warmBlend) * smoothstep(0.0, 0.2, temperature);
                
                float3 heatColor = _ColorCore.rgb * hotBlend + 
                                  _ColorHot.rgb * warmBlend + 
                                  _ColorWarm.rgb * coolBlend;
                
                float fireballIntensity = fireballCore * 1.2 + fireballEdge * 0.4;
                
                float3 finalColor = heatColor * fireballIntensity;
                
                finalColor += _ColorCore.rgb * flash;
                
                finalColor += _ColorHot.rgb * debrisLayer;
                
                float totalIntensity = max(fireballIntensity * 0.8, flash);
                totalIntensity = max(totalIntensity, debrisLayer * 0.6);
                
                float timeFade = 1.0;
                if (_Fading > 0.5) {
                    timeFade = 1.0 - smoothstep(0.7, 1.0, age);
                }
                
                float maxRadius = 0.45;
                float boundaryFade = 1.0 - smoothstep(maxRadius - 0.05, maxRadius, centerDistance);
                
                float2 edgeDistance = min(i.uv, 1.0 - i.uv);
                float edgeFade = smoothstep(0.0, 0.08, min(edgeDistance.x, edgeDistance.y));
                
                finalColor *= timeFade * edgeFade * boundaryFade;
                
                return float4(finalColor, totalIntensity * timeFade * edgeFade * boundaryFade);
            }
            ENDHLSL
        }
    }
    
    Fallback "UI/Default"
}
```

---