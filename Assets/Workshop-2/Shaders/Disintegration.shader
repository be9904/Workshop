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

            #include "Disintegration.hlsl"
            
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

            #include "Disintegration.hlsl"

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