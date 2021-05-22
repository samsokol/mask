#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "Fog.hlsl"  
#line 5  

#define MAXPOINTS 15
//#define DEBUG_MODE

uniform float2 cAspectRatio;

uniform float4 cCenterAndDirection[MAXPOINTS];    // Center (x, y) and direction(z, w).
uniform float4 cRadiusAndType[MAXPOINTS];         // We use only x and y, z for type
uniform float4 cScaleUMinUMax[MAXPOINTS];         // It is: Scale, UMin, UMax  

uniform float cCount;
uniform float cProgress;

#ifdef DEBUG_MODE
float DistToLine(float2 pt1, float2 pt2, float2 testPt)
{
    float2 lineDir = pt2 - pt1;
    float2 perpDir = float2(lineDir.y, -lineDir.x);
    float2 dirToPt1 = pt1 - testPt;
    return abs(dot(normalize(perpDir), dirToPt1));
}

float4 ColorForPoint(float2 uv, float2 center, float2 direction)
{
    float4 res = float4(0.7, 0.7, 0.7, 1.0);
    if (length((uv - center) / cAspectRatio) < 0.01)
    {
        res = float4(1.0, 0.0, 0.0, 1.0);
    }

    // draw vector
    float2 v = uv - center;
    if (dot(float2(direction), float2(v)) > 0.0 && DistToLine(center, center + direction, uv) < 0.01)
    {
        res = float4(0.0, 1.0, 0.0, 1.0);
    }

    return res;
}
#endif

void VS(float4 iPos : POSITION,
        float2 iTexCoord : TEXCOORD0,
    out float2 oTexCoord : TEXCOORD0,
    out float4 oWorldPos : TEXCOORD2,
    out float4 oPos : OUTPOSITION
#ifdef DEBUG_MODE
    ,
    out float4 oColor : COLOR0
#endif
)
{
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos      = GetWorldPos(modelMatrix);
    oPos      = GetClipPos(worldPos);
    oTexCoord = GetTexCoord(iTexCoord);
    oWorldPos = float4(worldPos, GetDepth(oPos));

    float2 uv = oTexCoord.xy;
#ifdef DEBUG_MODE
    oColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

    for (int i = 0; i < int(cCount); i++)
    {            
        float scale = cScaleUMinUMax[i].x;
        float type  = cRadiusAndType[i].z;
        float2 center = cCenterAndDirection[i].xy;
        float2 radius = cRadiusAndType[i].xy;
        float  debug  = cRadiusAndType[i].w;
        float  u_min  = cScaleUMinUMax[i].z;
        float  u_max  = cScaleUMinUMax[i].w;
        float2 direction = cCenterAndDirection[i].zw;
        
        float2 currentUV = uv;

        float2 e = (currentUV - center) / (radius * cAspectRatio);
        float d = dot(e, e);

        float actualScale   = scale;

        if (d < 1.0)
        {
#ifdef DEBUG_MODE
            if (debug == 0.0)
            {
                continue;
            }

            oColor = ColorForPoint(uv, center, direction);
#else
            if (type == 1.0) {
                // zoom
                float2 dist = float2(d * radius.x, d * radius.y);
                currentUV -= center;
                
                float2 delta = ((radius - dist) / radius);
                float deltaScale = actualScale;
                if(deltaScale > 0.0) {
                    deltaScale = smoothstep(u_min, u_max, deltaScale);
                }
                
                float2 percent = 1.0 - ((delta * deltaScale) * cProgress);
                currentUV = currentUV * percent;
                uv = currentUV + center;
            } else if (type == 2.0) {
                // shift
                float dist = 1.0 - d;
                float delta = actualScale * dist * cProgress;

                float deltaScale = smoothstep(u_min, u_max, dist);
                float2 direction2 = direction * deltaScale * cAspectRatio;
                uv = currentUV - delta * direction2;
            }
#endif
        }
    }

    oTexCoord.xy = uv;
}

void PS(float2 iTexCoord : TEXCOORD0,
    float4 iWorldPos: TEXCOORD2,
#ifdef DEBUG_MODE
    float4 iColor : COLOR0,
#endif
    out float4 oColor : OUTCOLOR0)
{
#ifdef DEBUG_MODE
    oColor     = Sample2D(EnvMap, iTexCoord) * iColor;
#else
    oColor = Sample2D(EnvMap, iTexCoord);
#endif
    //oColor = float4(iTexCoord.x, iTexCoord.y, 0.0, 1.0);
}
