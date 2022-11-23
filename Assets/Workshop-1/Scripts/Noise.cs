using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Noise : MonoBehaviour
{
    public ComputeShader computeShader;
    
    public RenderTexture renderTexture;

    public static readonly int NoiseProperty = Shader.PropertyToID("_Noise");

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
        
        Shader.SetGlobalTexture(NoiseProperty, renderTexture);
    }
}
