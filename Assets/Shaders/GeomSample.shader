Shader "Custom/GeomSample"
{
    Properties
    {
        [HDR] _OuterColor ("Outer Color", Color) = (1,1,1,1)
        [HDR] _InnerColor ("Inner Color", Color) = (0,0,0,1)
        _RimPower("Rim Power", Range(1, 5)) = 1
        
        _Offset("Offset", Float) = 0
        
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
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

            Texture2D _MainTex;
            float _Offset;

            CBUFFER_START(UnityPerMaterial)
            half4 _OuterColor;
            half4 _InnerColor;
            float _RimPower;
            CBUFFER_END

            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 cpos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 wpos : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
                float3 normal : NORMAL;
                float offset : TEXCOORD3;
            };
            
            v2f vert(Attributes i)
            {
                v2f o;
                o.cpos = TransformObjectToHClip(i.vertex);
                o.uv = i.uv;
                o.wpos = TransformObjectToWorld(i.vertex);
                o.viewDir = normalize(_WorldSpaceCameraPos.xyz - TransformObjectToWorld(i.vertex.xyz));
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.offset = pow(1 - dot(o.normal, o.viewDir), _RimPower);
                
                return o;
            }

            [maxvertexcount(3)]
            void geom(triangle v2f i[3], inout TriangleStream<v2f> stream)
            {
                float3 vert0 = i[0].wpos.xyz;
                float3 vert1 = i[1].wpos.xyz;
                float3 vert2 = i[2].wpos.xyz;

                float3 faceNormal = normalize(cross(vert1-vert0, vert2-vert0));

                i[0].normal = faceNormal;
                i[1].normal = faceNormal;
                i[2].normal = faceNormal;

                i[0].wpos.xyz += .01f * _Offset * faceNormal;
                i[1].wpos.xyz += .01f * _Offset * faceNormal;
                i[2].wpos.xyz += .01f * _Offset * faceNormal;

                i[0].cpos = TransformWorldToHClip(i[0].wpos);
                i[1].cpos = TransformWorldToHClip(i[1].wpos);
                i[2].cpos = TransformWorldToHClip(i[2].wpos);

                stream.Append(i[0]);
                stream.Append(i[1]);
                stream.Append(i[2]);
            }

            half4 frag(v2f i) : SV_Target
            {
                float rimlight = pow(1 - dot(i.normal, i.viewDir), _RimPower);
                half4 color = lerp(_InnerColor, _OuterColor, rimlight);
                return color;
            }
            ENDHLSL
        }
    }
}
