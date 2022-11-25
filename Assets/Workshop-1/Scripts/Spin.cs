using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Spin : MonoBehaviour
{
    public float speed = 50f;
    void Update ()
    {
        //rotates 50 degrees per second around z axis
        transform.Rotate (0,0,speed * Time.deltaTime); 
    }
}
