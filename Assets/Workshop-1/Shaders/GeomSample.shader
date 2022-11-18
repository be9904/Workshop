Shader "Custom/GeomSample"
{
    Properties
    {
        [HDR] _OuterColor ("Outer Color", Color) = (1,1,1,1)
        [HDR] _InnerColor ("Inner Color", Color) = (0,0,0,1)
        _RimPower("Rim Power", Range(1, 5)) = 1
        
        [HDR] _WireframeColor ("Wireframe Color", Color) = (1,0,0,0)
        _BreatheFrequency("Breathe Frequency", Range(0.1, 5)) = 1
        _Offset("Offset", Range(0,10)) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }
        Pass{
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            
            HLSLPROGRAM
            // Physically based Standard lighting model, and enable shadows on all light types
            #pragma vertex vert
            #pragma require geometry
            #pragma geometry geom
            #pragma fragment frag
            
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            Texture2D _NoiseTex;
            SamplerState sampler_NoiseTex;

            CBUFFER_START(UnityPerMaterial)
            half4 _OuterColor;
            half4 _InnerColor;
            float _RimPower;

            half4 _WireframeColor;
            float _BreatheFrequency;
            float _Offset;
            CBUFFER_END

            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2g
            {
                float4 cpos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 wpos : TEXCOORD1;
                float3 opos : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float3 normal : NORMAL;
                float noise : TEXCOORD4;
            };

            struct g2f
            {
                v2g data;
                float2 barycentricCoord : TEXCOORD9;
            };
            
            v2g vert(Attributes i)
            {
                v2g o;
                o.cpos = TransformObjectToHClip(i.vertex);
                o.uv = i.uv;
                o.wpos = TransformObjectToWorld(i.vertex);
                o.opos = i.vertex.xyz;
                o.viewDir = normalize(_WorldSpaceCameraPos.xyz - TransformObjectToWorld(i.vertex.xyz));
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.noise = _NoiseTex.SampleLevel(sampler_NoiseTex, i.uv, 0).a;
                
                return o;
            }

            float3 GetWireframe(g2f g)
            {
                float3 albedo = float3(0,0,0);
	            float3 barys;
	            barys.xy = g.barycentricCoord;
	            barys.z = 1 - barys.x - barys.y;
	            float3 deltas = fwidth(barys);
	            float3 smoothing = deltas * .5f;
	            float3 thickness = deltas * .1f;
	            barys = smoothstep(thickness, thickness + smoothing, barys);
	            float minBary = min(barys.x, min(barys.y, barys.z));
	            return lerp(_WireframeColor, albedo, minBary);
            }

            [maxvertexcount(3)]
            void geom(triangle v2g i[3], inout TriangleStream<g2f> stream)
            {
                float3 vert0 = i[0].wpos.xyz;
                float3 vert1 = i[1].wpos.xyz;
                float3 vert2 = i[2].wpos.xyz;

                float3 faceNormal = normalize(cross(vert1-vert0, vert2-vert0));

                i[0].normal = faceNormal;
                i[1].normal = faceNormal;
                i[2].normal = faceNormal;

                float avgNoise = 0.05f * (i[0].noise + i[1].noise + i[2].noise) / 3;
                float sinTime = 1 + sin(_BreatheFrequency * _Time.z / 2);

                i[0].wpos.xyz += sinTime * avgNoise * _Offset * faceNormal;
                i[1].wpos.xyz += sinTime * avgNoise * _Offset * faceNormal;
                i[2].wpos.xyz += sinTime * avgNoise * _Offset * faceNormal;

                i[0].cpos = TransformWorldToHClip(i[0].wpos);
                i[1].cpos = TransformWorldToHClip(i[1].wpos);
                i[2].cpos = TransformWorldToHClip(i[2].wpos);

                g2f g0, g1, g2;
                g0.data = i[0];
                g1.data = i[1];
                g2.data = i[2];

                g0.barycentricCoord = float2(1, 0);
                g1.barycentricCoord = float2(0, 1);
                g2.barycentricCoord = float2(0, 0);

                stream.Append(g0);
                stream.Append(g1);
                stream.Append(g2);
            }

            half4 frag(g2f i) : SV_Target
            {
                float rimlight = pow(1 - dot(i.data.normal, i.data.viewDir), _RimPower);
                half4 color = lerp(_InnerColor, _OuterColor, rimlight);
                half3 wire = GetWireframe(i);
                return color + half4(wire, 1);
            }
            ENDHLSL
        }
    }
}
