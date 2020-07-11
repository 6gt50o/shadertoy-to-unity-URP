﻿Shader "UmutBebek/URP/ShaderToy/Perspex Web Lattice Mld3Rn"
{
    Properties
    {
        _Channel0("Channel0 (RGB)", 2D) = "" {}
        _Channel1("Channel1 (RGB)", 2D) = "" {}
        _Channel2("Channel2 (RGB)", 2D) = "" {}
        _Channel3("Channel3 (RGB)", 2D) = "" {}
        [HideInInspector]iMouse("Mouse", Vector) = (0,0,0,0)

        FAR("FAR", float) = 2.
id("id", int) = 0 // Object ID - Red perspex: 0 ; Black lattice: 1. 

    }

        SubShader
    {
        // With SRP we introduce a new "RenderPipeline" tag in Subshader. This allows to create shaders
        // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
        // any render pipeline. In case you want your subshader to only run in LWRP set the tag to
        // "UniversalRenderPipeline"
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}
        LOD 300

        // ------------------------------------------------------------------
        // Forward pass. Shades GI, emission, fog and all lights in a single pass.
        // Compared to Builtin pipeline forward renderer, LWRP forward renderer will
        // render a scene with multiple lights with less drawcalls and less overdraw.
        Pass
        {
            // "Lightmode" tag must be "UniversalForward" or not be defined in order for
            // to render objects.
            Name "StandardLit"
            //Tags{"LightMode" = "UniversalForward"}

            //Blend[_SrcBlend][_DstBlend]
            //ZWrite Off ZTest Always
            //ZWrite[_ZWrite]
            //Cull[_Cull]

            HLSLPROGRAM
        // Required to compile gles 2.0 with standard SRP library
        // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
        #pragma prefer_hlslcc gles
        #pragma exclude_renderers d3d11_9x
        #pragma target 2.0

        //--------------------------------------
        // GPU Instancing
        #pragma multi_compile_instancing

        #pragma vertex LitPassVertex
        #pragma fragment LitPassFragment

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        //do not add LitInput, it has already BaseMap etc. definitions, we do not need them (manually described below)
        //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

        float4 _Channel0_ST;
        TEXTURE2D(_Channel0);       SAMPLER(sampler_Channel0);
        float4 _Channel1_ST;
        TEXTURE2D(_Channel1);       SAMPLER(sampler_Channel1);
        float4 _Channel2_ST;
        TEXTURE2D(_Channel2);       SAMPLER(sampler_Channel2);
        float4 _Channel3_ST;
        TEXTURE2D(_Channel3);       SAMPLER(sampler_Channel3);

        float4 iMouse;
        float FAR;
int id;


                    struct Attributes
                    {
                        float4 positionOS   : POSITION;
                        float2 uv           : TEXCOORD0;
                        UNITY_VERTEX_INPUT_INSTANCE_ID
                    };

                    struct Varyings
                    {
                        float2 uv                       : TEXCOORD0;
                        float4 positionCS               : SV_POSITION;
                        float4 screenPos                : TEXCOORD1;
                        UNITY_VERTEX_INPUT_INSTANCE_ID
                        UNITY_VERTEX_OUTPUT_STEREO
                    };

                    Varyings LitPassVertex(Attributes input)
                    {
                        Varyings output = (Varyings)0;

                        UNITY_SETUP_INSTANCE_ID(input);
                        UNITY_TRANSFER_INSTANCE_ID(input, output);
                        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                        // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
                        // Our compiler will strip all unused references (say you don't use view space).
                        // Therefore there is more flexibility at no additional cost with this struct.
                        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                        // TRANSFORM_TEX is the same as the old shader library.
                        output.uv = TRANSFORM_TEX(input.uv, _Channel0);
                        // We just use the homogeneous clip position from the vertex input
                        output.positionCS = vertexInput.positionCS;
                        output.screenPos = ComputeScreenPos(vertexInput.positionCS);
                        return output;
                    }

                    #define FLT_MAX 3.402823466e+38
                    #define FLT_MIN 1.175494351e-38
                    #define DBL_MAX 1.7976931348623158e+308
                    #define DBL_MIN 2.2250738585072014e-308

                     #define iTimeDelta unity_DeltaTime.x
                    // float;

                    #define iFrame ((int)(_Time.y / iTimeDelta))
                    // int;

                   #define clamp(x,minVal,maxVal) min(max(x, minVal), maxVal)

                   float mod(float a, float b)
                   {
                       return a - floor(a / b) * b;
                   }
                   float2 mod(float2 a, float2 b)
                   {
                       return a - floor(a / b) * b;
                   }
                   float3 mod(float3 a, float3 b)
                   {
                       return a - floor(a / b) * b;
                   }
                   float4 mod(float4 a, float4 b)
                   {
                       return a - floor(a / b) * b;
                   }

                   float4 pointSampleTex2D(Texture2D sam, SamplerState samp, float2 uv)//, float4 st) st is aactually screenparam because we use screenspace
                   {
                       //float2 snappedUV = ((float2)((int2)(uv * st.zw + float2(1, 1))) - float2(0.5, 0.5)) * st.xy;
                       float2 snappedUV = ((float2)((int2)(uv * _ScreenParams.zw + float2(1, 1))) - float2(0.5, 0.5)) * _ScreenParams.xy;
                       return  SAMPLE_TEXTURE2D(sam, samp, float4(snappedUV.x, snappedUV.y, 0, 0));
                   }

                   /*
   Perspex Web Lattice
    -- -- -- -- -- -- -- -- -- -

   I felt that Shadertoy didn't have enough Voronoi examples , so I made another one. : ) I'm
   not exactly sure what it's supposed to be... My best guess is that an Alien race with no
   common sense designed a monitor system with physics defying materials. : )

   Technically speaking , there's not much to it. It's just some raymarched 2nd order Voronoi.
   The dark perspex - looking web lattice is created by manipulating the Voronoi value slightly
   and giving the effected region an ID value so as to color it differently , but that's about
   it. The details are contained in the "heightMap" function.

   There's also some subtle edge detection in order to give the example a slight comic look.
   3D geometric edge detection doesn't really differ a great deal in concept from 2D pixel
   edge detection , but it obviously involves more processing power. However , it's possible to
   combine the edge detection with the normal calculation and virtually get it for free. Kali
   uses it to great effect in his "Fractal Land" example. It's also possible to do a
   tetrahedral version... I think Nimitz and some others may have done it already. Anyway ,
   you can see how it's done in the "nr" ( normal ) function.

   Geometric edge related examples:

   Fractal Land - Kali
   https: // www.shadertoy.com / view / XsBXWt

   Rotating Cubes - Shau
   https: // www.shadertoy.com / view / 4sGSRc

   Voronoi mesh related:

   // I haven't really looked into this , but it's interesting.
   Weaved Voronoi - FabriceNeyret2
  https: // www.shadertoy.com / view / ltsXRM

*/






// Tri - Planar blending function. Based on an old Nvidia writeup: 
// GPU Gems 3 - Ryan Geiss: https: // developer.nvidia.com / gpugems / GPUGems3 / gpugems3_ch01.html 
float3 tex3D(Texture2D tex, SamplerState samp, in float3 p , in float3 n) {

    n = max((abs(n) - .2) , .001);
    n /= (n.x + n.y + n.z); // Roughly normalized. 

     p = (SAMPLE_TEXTURE2D(tex , samp,p.yz) * n.x + SAMPLE_TEXTURE2D(tex , samp,p.zx) * n.y + SAMPLE_TEXTURE2D(tex ,samp, p.xy) * n.z).xyz;

     // Loose sRGB to RGB conversion to counter final value gamma correction... 
     // in case you're wondering. 
    return p * p;
 }


// Compact , self - contained version of IQ's 3D value noise function. I have a transparent noise 
// example that explains it , if you require it. 
float n3D(float3 p) {

     const float3 s = float3 (7 , 157 , 113);
     float3 ip = floor(p); p -= ip;
    float4 h = float4 (0. , s.yz , s.y + s.z) + dot(ip , s);
    p = p * p * (3. - 2. * p); // p *= p * p * ( p * ( p * 6. - 15. ) + 10. ) ; 
    h = lerp(frac(sin(h) * 43758.5453) , frac(sin(h + s.x) * 43758.5453) , p.x);
    h.xy = lerp(h.xz , h.yw , p.y);
    return lerp(h.x , h.y , p.z); // Range: [0 , 1]. 
 }

// float2 to float2 hash. 
float2 hash22(float2 p) {

    // Faster , but doesn't disperse things quite as nicely. However , when framerate 
    // is an issue , and it often is , this is a good one to use. Basically , it's a tweaked 
    // amalgamation I put together , based on a couple of other random algorithms I've 
    // seen around... so use it with caution , because I make a tonne of mistakes. : ) 
   float n = sin(dot(p , float2 (41 , 289)));
   // return frac ( float2 ( 262144 , 32768 ) * n ) ; 

   // Animated. 
  p = frac(float2 (262144 , 32768) * n);
  // Note the ".45 , " insted of ".5" that you'd expect to see. When edging , it can open 
  // up the cells ever so slightly for a more even spread. In fact , lower numbers work 
  // even better , but then the random movement would become too restricted. Zero would 
  // give you square cells. 
 return sin(p * 6.2831853 + _Time.y) * .45 + .5;

}

// 2D 2nd - order Voronoi: Obviously , this is just a rehash of IQ's original. I've tidied 
// up those if - statements. Since there's less writing , it should go faster. That's how 
// it works , right? : ) 
// 
float Voronoi(in float2 p) {

     float2 g = floor(p) , o; p -= g;

     float3 d = float3 (1 , 1 , 1); // 1.4 , etc. "d.z" holds the distance comparison value. 

     for (int y = -1; y <= 1; y++) {
          for (int x = -1; x <= 1; x++) {

               o = float2 (x , y);
            o += hash22(g + o) - p;

               d.z = dot(o , o);
               // More distance metrics. 
               // o = abs ( o ) ; 
               // d.z = max ( o.x * .8666 + o.y * .5 , o.y ) ; // 
               // d.z = max ( o.x , o.y ) ; 
               // d.z = ( o.x * .7 + o.y * .7 ) ; 

              d.y = max(d.x , min(d.y , d.z));
              d.x = min(d.x , d.z);

             }
        }

      return max(d.y / 1.2 - d.x * 1. , 0.) / 1.2;
      // return d.y - d.x ; // return 1. - d.x ; // etc. 

  }

// The height map values. In this case , it's just a Voronoi variation. By the way , I could 
// optimize this a lot further , but it's not a particularly taxing distance function , so 
// I've left it in a more readable state. 
float heightMap(float3 p) {

    id = 0;
    float c = Voronoi(p.xy * 4.); // The fiery bit. 

     // For lower values , reverse the surface direction , smooth , then 
     // give it an ID value of one. Ie: this is the black web - like 
     // portion of the surface. 
    if (c < .07) { c = smoothstep(0.7 , 1. , 1. - c) * .2; id = 1; }

    return c;
 }

// Standard back plane height map. Put the plane at float3 ( 0 , 0 , 1 ) , then add some height values. 
// Obviously , you don't want the values to be too large. The one's here account for about 10% 
// of the distance between the plane and the camera. 
float m(float3 p) {

    float h = heightMap(p); // SAMPLE_TEXTURE2D ( _Channel0 , sampler_Channel0 , p.xy / 2. ) .x ; // Texture work too. 

    return 1. - p.z - h * .1;

 }

/*
// Tetrahedral normal , to save a couple of "map" calls. Courtesy of IQ.
float3 nr ( in float3 p ) {

     // Note the slightly increased sampling distance , to alleviate artifacts due to hit pointExtended inaccuracies.
    float2 e = float2 ( 0.005 , - 0.005 ) ;
    return normalize ( e.xyy * m ( p + e.xyy ) + e.yyx * m ( p + e.yyx ) + e.yxy * m ( p + e.yxy ) + e.xxx * m ( p + e.xxx ) ) ;
 }
 */

 /*
 // Standard normal function - for comparison with the one below.
float3 nr ( in float3 p ) {
     const float2 e = float2 ( 0.005 , 0 ) ;
     return normalize ( float3 ( m ( p + e.xyy ) - m ( p - e.xyy ) , m ( p + e.yxy ) - m ( p - e.yxy ) , m ( p + e.yyx ) - m ( p - e.yyx ) ) ) ;
 }
 */

 // The normal function with some edge detection rolled into it. 
float3 nr(float3 p , inout float edge) {

    float2 e = float2 (.005 , 0);

    // Take some distance function measurements from either side of the hit pointExtended on all three axes. 
    float d1 = m(p + e.xyy) , d2 = m(p - e.xyy);
    float d3 = m(p + e.yxy) , d4 = m(p - e.yxy);
    float d5 = m(p + e.yyx) , d6 = m(p - e.yyx);
    float d = m(p) * 2.; // The hit pointExtended itself - Doubled to cut down on calculations. See below. 

    // Edges - Take a geometry measurement from either side of the hit point. Average them , then see how 
    // much the value differs from the hit pointExtended itself. Do this for X , Y and Z directions. Here , the sum 
    // is used for the overall difference , but there are other ways. Note that it's mainly sharp surface 
    // curves that register a discernible difference. 
   edge = abs(d1 + d2 - d) + abs(d3 + d4 - d) + abs(d5 + d6 - d);
   // edge = max ( max ( abs ( d1 + d2 - d ) , abs ( d3 + d4 - d ) ) , abs ( d5 + d6 - d ) ) ; // Etc. 

   // Once you have an edge value , it needs to normalized , and smoothed if possible. How you 
   // do that is up to you. This is what I came up with for now , but I might tweak it later. 
  edge = smoothstep(0. , 1. , sqrt(edge / e.x * 2.));

  // Return the normal. 
  // Standard , normalized gradient mearsurement. 
 return normalize(float3 (d1 - d2 , d3 - d4 , d5 - d6));
}

/*
// I keep a collection of occlusion routines... OK , that sounded really nerdy. : )
// Anyway , I like this one. I'm assuming it's based on IQ's original.
float cAO ( in float3 p , in float3 n )
 {
     float sca = 3. , occ = 0. ;
    for ( float i = 0. ; i < 5. ; i ++ ) {

        float hr = .01 + i * .5 / 4. ;
        float dd = m ( n * hr + p ) ;
        occ += ( hr - dd ) * sca ;
        sca *= 0.7 ;
     }
    return clamp ( 1.0 - occ , 0. , 1. ) ;
 }
 */

 /*
 // Standard hue rotation formula... compacted down a bit.
float3 rotHue ( float3 p , float a ) {

    float2 cs = sin ( float2 ( 1.570796 , 0 ) + a ) ;

    float3x3 hr = float3x3 ( 0.299 , 0.587 , 0.114 , 0.299 , 0.587 , 0.114 , 0.299 , 0.587 , 0.114 ) +
               float3x3 ( 0.701 , - 0.587 , - 0.114 , - 0.299 , 0.413 , - 0.114 , - 0.300 , - 0.588 , 0.886 ) * cs.x +
               float3x3 ( 0.168 , 0.330 , - 0.497 , - 0.328 , 0.035 , 0.292 , 1.250 , - 1.050 , - 0.203 ) * cs.y ;

    return clamp ( p * hr , 0. , 1. ) ;
 }
 */

 // Simple environment mapping. Pass the reflected vector in and create some 
 // colored noise with it. The normal is redundant here , but it can be used 
 // to pass into a 3D SAMPLE_TEXTURE2D mapping function to produce some interesting 
 // environmental reflections. 
 // 
 // More sophisticated environment mapping: 
 // UI easy to integrate - XT95 
 // https: // www.shadertoy.com / view / ldKSDm 
float3 eMap(float3 rd , float3 sn) {

    float3 sRd = rd; // Save rd , just for some mixing at the end. 

     // Add a time component , scale , then pass into the noise function. 
    rd.xy -= _Time.y * .25;
    rd *= 3.;

    // float3 tx = tex3D ( _Channel0 , sampler_Channel0 , rd / 3. , sn ) ; 
    // float c = dot ( tx * tx , float3 ( .299 , .587 , .114 ) ) ; 

   float c = n3D(rd) * .57 + n3D(rd * 2.) * .28 + n3D(rd * 4.) * .15; // Noise value. 
   c = smoothstep(0.5 , 1. , c); // Darken and add contast for more of a spotlight look. 

    // float3 col = float3 ( c , c * c , c * c * c * c ) .zyx ; // Simple , warm coloring. 
   float3 col = float3 (min(c * 1.5 , 1.) , pow(c , 2.5) , pow(c , 12.)).zyx; // More color. 

    // Mix in some more redExtended to tone it down and return. 
   return lerp(col , col.yzx , sRd * .25 + .25);

}

half4 LitPassFragment(Varyings input) : SV_Target  {
UNITY_SETUP_INSTANCE_ID(input);
UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
 half4 c = half4 (1 , 1 , 1 , 1);
 float2 u= ((input.screenPos.xy) / (input.screenPos.w + FLT_MIN)) * _ScreenParams.xy;

 // Unit direction ray , camera origin and light position. 
float3 r = normalize(float3 (u - _ScreenParams.xy * .5 , _ScreenParams.y)) ,
     o = float3 (0 , 0 , 0) , l = o + float3 (0 , 0 , -1);

// Rotate the canvas. Note that sine and cosine are kind of rolled into one. 
float2 a = sin(float2 (1.570796 , 0) + _Time.y / 8.); // Fabrice's observation. 
r.xy = mul(float2x2 (a , -a.y , a.x) , r.xy);


// Standard raymarching routine. Raymarching a slightly perturbed back plane front - on 
// doesn't usually require many iterations. Unless you rely on your GPU for warmth , 
// this is a good thing. : ) 
float d , t = 0.;

for (int i = 0; i < 32; i++) {

    d = m(o + r * t);
    // There isn't really a far plane to go beyond , but it's there anyway. 
   if (abs(d) < 0.001 || t > FAR) break;
   t += d * .7;

}

t = min(t , FAR);

// Set the initial scene color to black. 
c = float4 (0 , 0 , 0 , 0);

float edge = 0.; // Edge value - to be passed into the normal. 

if (t < FAR) {

    float3 p = o + r * t , n = nr(p , edge);

    l -= p; // Light to surface vector. Ie: Light direction vector. 
    d = max(length(l) , 0.001); // Light to surface distance. 
    l /= d; // Normalizing the light direction vector. 



     // Obtain the height map ( destorted Voronoi ) value , and use it to slightly 
     // shade the surface. Gives a more shadowy appearance. 
    float hm = heightMap(p);

    // Texture value at the surface. Use the heighmap value above to distort the 
    // SAMPLE_TEXTURE2D a bit. 
   float3 tx = tex3D(_Channel0 , sampler_Channel0 , (p * 2. + hm * .2) , n);
   // tx = floor ( tx * 15.999 ) / 15. ; // Quantized cartoony colors , if you get bored enough. 

  c.xyz = float3 (1. , 1. , 1.) * (hm * .8 + .2); // Applying the shading to the final color. 

  c.xyz *= float3 (1.5, 1.5, 1.5) * tx; // Multiplying by the SAMPLE_TEXTURE2D value and lightening. 


   // Color the cell part with a fiery ( I incorrectly spell it firey all the time ) 
   // palette and the latticey web thing a very dark color. 
   // 
  c.x = dot(c.xyz , float3 (.299 , .587 , .114)); // Grayscale. 
  if (id == 0) c.xyz *= float3 (min(c.x * 1.5 , 1.) , pow(c.x , 5.) , pow(c.x , 24.)) * 2.;
  else c.xyz *= .1;

  // Hue rotation , for anyone who's interested. 
  // c.xyz = rotHue ( c.xyz , mod ( _Time.y / 16. , 6.283 ) ) ; 


 float df = max(dot(l , n) , 0.); // Diffuse. 
 float sp = pow(max(dot(reflect(-l , n) , -r) , 0.) , 32.); // Specular. 

 if (id == 1) sp *= sp; // Increase specularity on the dark lattice. 

    // Applying some diffuse and specular lighting to the surface. 
 c.xyz = c.xyz * (df + .75) + float3 (1 , .97 , .92) * sp + float3 (.5 , .7 , 1) * pow(sp , 32.);

 // Add the fake environmapping. Give the dark surface less reflectivity. 
float3 em = eMap(reflect(r , n) , n); // Fake environment mapping. 
if (id == 1) em *= .5;
c.xyz += em;

// Edges. 
// if ( id == 0 ) c.xyz += edge * .1 ; // Lighter edges. 
c.xyz *= 1. - edge * .8; // Darker edges. 

 // Attenuation , based on light to surface distance. 
c.xyz *= 1. / (1. + d * d * .125);

// AO - The effect is probably too subtle , in this case , so we may as well 
// save some cycles. 
// c.xyz *= cAO ( p , n ) ; 

}


// Vignette. 
// float2 uv = u / _ScreenParams.xy ; 
// c.xyz = lerp ( c.xyz , float3 ( 0 , 0 , .5 ) , .1 - pow ( 16. * uv.x * uv.y * ( 1. - uv.x ) * ( 1. - uv.y ) , 0.25 ) * .1 ) ; 

// Apply some statistically unlikely ( but close enough ) 2.0 gamma correction. : ) 
c = float4 (sqrt(clamp(c.xyz , 0. , 1.)) , 1.);
c.xyz -= 0.1;

return c;
}

//half4 LitPassFragment(Varyings input) : SV_Target
//{
//    [FRAGMENT]
//    //float2 uv = input.uv;
//    //SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_BaseMap, uv + float2(-onePixelX, -onePixelY), _Lod);
//    //_ScreenParams.xy 
//    //half4 color = half4(1, 1, 1, 1);
//    //return color;
//}
ENDHLSL
}
    }
}