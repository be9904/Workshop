using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class NoiseTexture : MonoBehaviour
{
    [SerializeField] ComputeShader computeShader;

    public RenderTexture renderTexture;
    public Texture precomputedTexture;
    public static readonly int PseudoRandomNoise = Shader.PropertyToID("_NoiseTex");

    private void OnEnable()
    {
        renderTexture = new RenderTexture(512, 512, 24);
        renderTexture.enableRandomWrite = true;
        renderTexture.Create();
        
        computeShader.SetTexture(0, "Result", renderTexture);
        computeShader.Dispatch(
            0, 
            renderTexture.width/8, 
            renderTexture.height/8,
            1);

        precomputedTexture = ToTexture2D(renderTexture);
        
        Shader.SetGlobalTexture(PseudoRandomNoise, precomputedTexture);
    }
    
    Texture2D ToTexture2D(RenderTexture rTex)
    {
        Texture2D tex = new Texture2D(512, 512, TextureFormat.RGBA32, false);
        // ReadPixels looks at the active RenderTexture.
        RenderTexture.active = rTex;
        tex.ReadPixels(new Rect(0, 0, rTex.width, rTex.height), 0, 0);
        tex.Apply();
        return tex;
    }
}
