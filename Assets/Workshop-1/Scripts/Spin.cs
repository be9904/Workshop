using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Spin : MonoBehaviour
{
    void Update ()
    {
        //rotates 50 degrees per second around z axis
        transform.Rotate (0,0,50 * Time.deltaTime); 
    }
}
