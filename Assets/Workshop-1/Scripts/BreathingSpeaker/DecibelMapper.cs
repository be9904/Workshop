using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Audio;

[RequireComponent(typeof(AudioSource))]
public class DecibelMapper : MonoBehaviour
{
    private AudioSource _audioSource;
    private AudioClip _audioClip;
    public float updateStep = 0.1f;
    private int sampleDataLength = 1024;

    private float _currentUpdateTime = 0f;

    public float musicVolume;
    private float _prevVolume;
    private float[] clipSampleData;
    
    public static readonly int MusicVolume = Shader.PropertyToID("_MusicVolume");
    
    [Range(.1f, 5f)]
    public float multiplier = 1f;

    [Range(0f, 1f)] public float minThreshold = 0f;

    private void Awake()
    {
        clipSampleData = new float[sampleDataLength];
        _audioSource = GetComponent<AudioSource>();
        _audioClip = _audioSource.clip;
        Shader.SetGlobalFloat(MusicVolume, 0);
    }

    private void Update()
    {
        _currentUpdateTime += Time.deltaTime;
        
        if (_currentUpdateTime >= updateStep)
            UpdateVolume();
    }

    private void UpdateVolume()
    {
        _currentUpdateTime = 0f;
        _audioClip.GetData(clipSampleData, _audioSource.timeSamples);
        musicVolume = 0f;

        foreach (var sample in clipSampleData)
        {
            musicVolume += Mathf.Abs(sample);
        }

        musicVolume /= sampleDataLength;

        musicVolume *= multiplier;

        if (Mathf.Abs(musicVolume - _prevVolume) > minThreshold * multiplier)
        {
            if (musicVolume > minThreshold * multiplier)
                Shader.SetGlobalFloat(MusicVolume, musicVolume);
            else
                Shader.SetGlobalFloat(MusicVolume, 0);
        }

        _prevVolume = musicVolume;
    }
}
