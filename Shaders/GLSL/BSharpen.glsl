#include "TextureEffectBase.glsl"
#line 2

#ifdef COMPILEPS



vec4 TextureEffectMain()
{

    vec2 uv = floor(vScreenPos * cFrameSizeInvSizePS.xy);   // UV
    uv *= cFrameSizeInvSizePS.zw;

    vec2 step = 1.0 / cFrameSizeInvSizePS.xy;

    vec3 texA = texture2D( sEnvMap, uv + vec2(-step.x, -step.y) * 1.0 ).rgb;
    vec3 texB = texture2D( sEnvMap, uv + vec2( step.x, -step.y) * 1.0 ).rgb;
    vec3 texC = texture2D( sEnvMap, uv + vec2(-step.x,  step.y) * 1.0 ).rgb;
    vec3 texD = texture2D( sEnvMap, uv + vec2( step.x,  step.y) * 1.0 ).rgb;

    vec3 around = 0.25 * (texA + texB + texC + texD);
    vec3 center  = texture2D( sEnvMap, uv ).rgb;

    float sharpness = 1.13;
    
  
    vec3 col = center + (center - around) * sharpness;
    

   return vec4(col,1.0);
    //return vec4(1.0,0.0,0.0,1.0);
}

#endif
