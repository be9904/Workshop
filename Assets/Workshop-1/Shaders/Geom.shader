Shader "Custom/Geom"
{
    Properties
    {
        _RimLightPower("Rim Light Power", Range(1, 5)) = 2
        [HDR] _OuterColor("Outer Color", Color) = (1,1,1,1)
        [HDR] _InnerColor("Inner Color", Color) = (0,0,0,0)
        
        _Offset("Offset", Range(0,10)) = 0
        _Frequency("Frequency", Range(0.1, 10)) = 1
        }
    SubShader
    {
        Tags { 
            "RenderType"="UniversalPipeline" 
            "RenderType"="Transparent"
            "Queue"="Transparent"    
        }
        Pass
        {
            Tags {"LightMode"="UniversalForward"}
            Blend SrcAlpha OneMinusSrcAlpha
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            Texture2D _Noise;
            SamplerState sampler_Noise;
            
            float _RimLightPower;
            float4 _InnerColor;
            float4 _OuterColor;
            float _Offset;
            float _Frequency;
            
            struct Attributes
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                float2 uv       : TEXCOORD0;
            };

            struct v2g
            {
                float4 cpos     : SV_POSITION;
                float3 normal   : NORMAL;
                float2 uv       : TEXCOORD0;
                float3 wpos     : TEXCOORD1;
                float3 viewDir  : TEXCOORD2;
                float noise     : TEXCOORD3;
            };

            struct g2f
            {
                v2g data;
                float3 barycentricCoord : TEXCOORD9;
            };

            v2g vert(Attributes i)
            {
                v2g o;
                o.cpos = TransformObjectToHClip(i.vertex);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.uv = i.uv;
                o.wpos = TransformObjectToWorld(i.vertex);
                o.viewDir = normalize(_WorldSpaceCameraPos.xyz - TransformObjectToWorld(i.vertex.xyz));
                o.noise = _Noise.SampleLevel(sampler_Noise, i.uv, 0).a;
                
                return o;
            }

            [maxvertexcount(3)]
            void geom(triangle v2g i[3], inout TriangleStream<v2g> stream)
            {
                // flat shading
                float3 vert0 = i[0].wpos.xyz;
                float3 vert1 = i[1].wpos.xyz;
                float3 vert2 = i[2].wpos.xyz;

                float3 faceNormal = normalize(cross(vert1-vert0, vert2-vert0));

                i[0].normal = faceNormal;
                i[1].normal = faceNormal;
                i[2].normal = faceNormal;

                float avgNoise = 0.05f * (i[0].noise + i[1].noise + i[2].noise) / 3;
                float cosTime = (1 + cos(_Frequency * _Time.z / 2)) / 2;
                
                i[0].wpos += cosTime * _Offset * avgNoise * faceNormal;
                i[1].wpos += cosTime * _Offset * avgNoise * faceNormal;
                i[2].wpos += cosTime * _Offset * avgNoise * faceNormal;

                i[0].cpos = TransformWorldToHClip(i[0].wpos);
                i[1].cpos = TransformWorldToHClip(i[1].wpos);
                i[2].cpos = TransformWorldToHClip(i[2].wpos);
                
                stream.Append(i[0]);
                stream.Append(i[1]);
                stream.Append(i[2]);
            }
            
            half4 frag(v2g i) : SV_Target
            {
                float rimlight = pow(1-dot(i.viewDir, i.normal), _RimLightPower);
                half4 color = lerp(_InnerColor, _OuterColor, rimlight);
                color.a = 0.5;
                return color;
            }
            ENDHLSL
        }
    }
}
