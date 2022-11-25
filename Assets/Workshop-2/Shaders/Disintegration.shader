Shader "Custom/Disintegration"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [HDR] _Color("Color", Color) = (1, 1, 1, 1)
        _Metallic("Metallic", Range(0, 1)) = 0
        _Roughness("Roughness", Range(0, 1)) = 0
 
        _FlowMap("Flow (RG)", 2D) = "black" {}
        _DissolveTexture("Dissolve Texutre", 2D) = "white" {}
        [HDR]_DissolveColor("Dissolve Color Border", Color) = (1, 1, 1, 1) 
        _DissolveBorder("Dissolve Border", float) =  0.05


        _Expand("Expand", float) = 1
        _Weight("Weight", Range(0,1)) = 0
        _Direction("Direction", Vector) = (0, 0, 0, 0)
        [HDR]_DisintegrationColor("Disintegration Color", Color) = (1, 1, 1, 1)
        _Glow("Glow", float) = 1

        _Shape("Shape Texture", 2D) = "white" {} 
        _R("Radius", float) = .1
    }

    // geometry shader logic written global to access in forward lit pass & shadow caster
    // depth pass WIP
    HLSLINCLUDE

    #define UNITY_MATRIX_TEXTURE0 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    sampler2D _MainTex;
    float4 _MainTex_ST;
    float4 _Color;
    float _Metallic;
    float _Roughness;

    sampler2D _FlowMap;
    float4 _FlowMap_ST;
    sampler2D _DissolveTexture;
    float4 _DissolveTexture_ST;
    float4 _DissolveColor;
    float _DissolveBorder;


    float _Expand;
    float _Weight;
    float4 _Direction;
    float4 _DisintegrationColor;
    float _Glow;
    sampler2D _Shape;
    float _R;

    struct GeomAttributes{
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;
        // UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct v2g{
        float4 objPos : SV_POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;
        float3 worldPos : TEXCOORD1;
        float3 viewDir : TEXCOORD3;
        // UNITY_VERTEX_INPUT_INSTANCE_ID
        // UNITY_VERTEX_OUTPUT_STEREO
    };

    struct g2f{
        float4 worldPos : SV_POSITION;
        float2 uv : TEXCOORD0;
        float4 color : COLOR;
        float3 normal : NORMAL;
        float3 viewDir : TEXCOORD3;
        // UNITY_VERTEX_INPUT_INSTANCE_ID
        // UNITY_VERTEX_OUTPUT_STEREO
    };


    v2g vert (GeomAttributes v){
        v2g o = (v2g)0;
        // UNITY_SETUP_INSTANCE_ID(v);
        // UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
        
        o.objPos = v.vertex;
        o.uv = v.uv;
        o.normal = TransformObjectToWorldNormal(v.normal);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
        o.viewDir = normalize(_WorldSpaceCameraPos.xyz - o.worldPos.xyz);
        return o;
    }

    float random (float2 uv){
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123);
    }

    float remap (float value, float from1, float to1, float from2, float to2) {
        return (value - from1) / (to1 - from1) * (to2 - from2) + from2;
    }

    float randomMapped(float2 uv, float from, float to){
        return remap(random(uv), 0, 1, from, to);
    }

    float4 remapFlowTexture(float4 tex){
        return float4(
            remap(tex.x, 0, 1, -1, 1),
            remap(tex.y, 0, 1, -1, 1),
            0,
            remap(tex.w, 0, 1, -1, 1)
        );
    }

    float2 MultiplyUV (float4x4 mat, float2 inUV) {
        float4 temp = float4 (inUV.x, inUV.y, 0, 0);
        temp = mul (mat, temp);
        return temp.xy;
    }
    
    [maxvertexcount(7)]
    void geom(triangle v2g IN[3], inout TriangleStream<g2f> triStream){
        float2 avgUV = (IN[0].uv + IN[1].uv + IN[2].uv) / 3;
        float3 avgPos = (IN[0].objPos + IN[1].objPos + IN[2].objPos) / 3;
        float3 avgNormal = (IN[0].normal + IN[1].normal + IN[2].normal) / 3;
        float3 avgViewDir = (IN[0].viewDir + IN[1].viewDir + IN[2].viewDir) / 3;

        float dissolve_value = tex2Dlod(_DissolveTexture, float4(avgUV, 0, 0)).r;
        float t = clamp(_Weight * 2 - dissolve_value, 0 , 1);

        float2 flowUV = TRANSFORM_TEX(mul(unity_ObjectToWorld, avgPos).xz, _FlowMap);
        float4 flowVector = remapFlowTexture(tex2Dlod(_FlowMap, float4(flowUV, 0, 0)));

        float3 pseudoRandomPos = (avgPos) + _Direction;
        pseudoRandomPos += (flowVector.xyz * _Expand);

        float3 p =  lerp(avgPos, pseudoRandomPos, t);
        float radius = lerp(_R, 0, t);
        

        if(t > 0){
            float3 look = _WorldSpaceCameraPos - p;
            look = normalize(look);

            float3 right = UNITY_MATRIX_IT_MV[0].xyz;
            float3 up = UNITY_MATRIX_IT_MV[1].xyz;

            float halfS = 0.5f * radius;

            float4 v[4];
            v[0] = float4(p + halfS * right - halfS * up, 1.0f);
            v[1] = float4(p + halfS * right + halfS * up, 1.0f);
            v[2] = float4(p - halfS * right - halfS * up, 1.0f);
            v[3] = float4(p - halfS * right + halfS * up, 1.0f);
            

            g2f vert;
            vert.worldPos = TransformObjectToHClip(v[0]);
            vert.uv = MultiplyUV(UNITY_MATRIX_TEXTURE0, float2(1.0f, 0.0f));
            vert.color = float4(1, 1, 1, 1);
            vert.normal = avgNormal;
            vert.viewDir = avgViewDir;
            triStream.Append(vert);

            vert.worldPos = TransformObjectToHClip(v[1]);
            vert.uv = MultiplyUV(UNITY_MATRIX_TEXTURE0, float2(1.0f, 1.0f));
            vert.color = float4(1, 1, 1, 1);
            vert.normal = avgNormal;
            vert.viewDir = avgViewDir;
            triStream.Append(vert);

            vert.worldPos =TransformObjectToHClip(v[2]);
            vert.uv = MultiplyUV(UNITY_MATRIX_TEXTURE0, float2(0.0f, 0.0f));
            vert.color = float4(1, 1, 1, 1);
            vert.normal = avgNormal;
            vert.viewDir = avgViewDir;
            triStream.Append(vert);

            vert.worldPos = TransformObjectToHClip(v[3]);
            vert.uv = MultiplyUV(UNITY_MATRIX_TEXTURE0, float2(0.0f, 1.0f));
            vert.color = float4(1, 1, 1, 1);
            vert.normal = avgNormal;
            vert.viewDir = avgViewDir;
            triStream.Append(vert);

            triStream.RestartStrip();
        }

        for(int j = 0; j<3; j++){
            g2f o;
            o.worldPos = TransformObjectToHClip(IN[j].objPos);
            o.uv = TRANSFORM_TEX(IN[j].uv, _MainTex);
            o.color = float4(0, 0, 0, 0);
            o.normal = IN[j].normal;
            o.viewDir = IN[j].viewDir;
            triStream.Append(o); 
        }
        
        triStream.RestartStrip();
    }
    ENDHLSL

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        Cull Off

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            #pragma multi_compile_fwdbase
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            
            float4 frag (g2f i) : SV_Target{
                // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                
                // sample main tex
                float4 col = tex2D(_MainTex, i.uv) * _Color;

                // calculate normals
                float3 normal = normalize(i.normal);

                // lighting
                float NdotL = saturate(dot(_MainLightPosition.xyz, normal));
                float4 light = NdotL * _MainLightColor;
                col *= light;

                // add emission
                float brightness = i.color.w  * _Glow;
                col = lerp(col, _DisintegrationColor,  i.color.x);
                if(brightness > 0){
                    col *= brightness + _Weight;
                }

                // sample dissolve tex
                float2 dissolveUV = i.uv.xy * _DissolveTexture_ST.xy + _DissolveTexture_ST.zw; 
                float dissolve = tex2D(_DissolveTexture, dissolveUV).r;

                // clip fragments
                if(i.color.w == 0){
                    clip(dissolve - 2 * _Weight);
                    if(_Weight > 0){
                        col +=  _DissolveColor * _Glow * step( dissolve - 2 * _Weight, _DissolveBorder);
                    }
                }else{
                    float s = tex2D(_Shape, dissolveUV).r;
                    if(s < .5) {
                        discard;
                    }
                }

                 // Get BRDF
		        BRDFData brdfData;
		        InitializeBRDFData(col.rgb, _Metallic, 0.5, 1-_Roughness, col.a, brdfData);
                half3 reflectVector = reflect(-i.viewDir, normal);
                half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, 1);

                float3 GI = EnvironmentBRDF(brdfData, col, indirectSpecular, 0);
                float3 pbr = LightingPhysicallyBased(brdfData, GetMainLight(), normal, i.viewDir);

                pbr.rgb += GI;

                #ifdef _ADDITIONAL_LIGHTS
			        uint pixelLightCount = GetAdditionalLightsCount();
			        for(uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex){
					        Light addLight = GetAdditionalLight(lightIndex, i.worldPos);
					        float3 addLightResult = 
						        LightingPhysicallyBased(brdfData, addLight, normal, i.viewDir);
					        pbr.rgb += addLightResult;
			        }
		        #endif
                
                return float4(pbr, 1);
            }
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 4.6
            #pragma multi_compile_shadowcaster

            float4 frag(g2f i) : SV_Target{
                // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                
                float2 dissolveUV = i.uv.xy * _DissolveTexture_ST.xy + _DissolveTexture_ST.zw;
                float dissolve = tex2D(_DissolveTexture, dissolveUV).r;

                if(i.color.w == 0){
                    clip(dissolve - 2 * _Weight);
                }else{
                    float s = tex2D(_Shape, dissolveUV).r;
                    if(s < .5) {
                        discard;
                    }
                }

                return 0;
            }
            ENDHLSL
        }
    }
}