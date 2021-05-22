#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "Fog.glsl"
#include "ScreenPos.glsl"
#line 5  

#define MAXPOINTS 15
//#define DEBUG_MODE

varying vec2 vTexCoord;
varying vec3 vNormal;
varying vec4 vWorldPos;
varying vec2 vScreenPos;


uniform vec2 cAspectRatio;

uniform vec4 cCenterAndDirection[MAXPOINTS];    // Center (x, y) and direction(z, w).
uniform vec4 cRadiusAndType[MAXPOINTS];         // We use only x and y, z for type
uniform vec4 cScaleUMinUMax[MAXPOINTS];         // It is: Scale, UMin, UMax  

uniform float cCount;
uniform float cProgress;

uniform vec2 cTexCoordX;
uniform vec2 cTexCoordY;
uniform vec2 cTexCoordOffset;

#ifdef DEBUG_MODE

varying vec4 vColor;

float DistToLine(vec2 pt1, vec2 pt2, vec2 testPt)
{
    vec2 lineDir = pt2 - pt1;
    vec2 perpDir = vec2(lineDir.y, -lineDir.x);
    vec2 dirToPt1 = pt1 - testPt;
    return abs(dot(normalize(perpDir), dirToPt1));
}

vec4 ColorForPoint(vec2 uv, vec2 center, vec2 direction)
{
    vec4 res = vec4(0.7, 0.7, 0.7, 1.0);
    if (length((uv - center) / cAspectRatio) < 0.01)
    {
        res = vec4(1.0, 0.0, 0.0, 1.0);
    }

    // draw vector
    vec2 v = uv - center;
    if (dot(vec2(direction), vec2(v)) > 0.0 && DistToLine(center, center + direction, uv) < 0.01)
    {
        res = vec4(0.0, 1.0, 0.0, 1.0);
    }

    return res;
}
#endif

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vNormal = GetWorldNormal(modelMatrix);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    vTexCoord = GetTexCoord(iTexCoord);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
	
    vec2 uv = cTexCoordOffset + vec2(dot(cTexCoordX, vTexCoord), dot(cTexCoordY, vTexCoord));
	uv.y    = 1.0 - uv.y;

#ifdef DEBUG_MODE
    vColor = vec4(1.0, 1.0, 1.0, 1.0);
#endif

    for (int i = 0; i < int(cCount); i++)
    {
        float scale = cScaleUMinUMax[i].x;
        float type  = cRadiusAndType[i].z;
        vec2 center = cCenterAndDirection[i].xy;
        vec2 radius = cRadiusAndType[i].xy;
		float  debug  = cRadiusAndType[i].w;
        float  u_min  = cScaleUMinUMax[i].z;
        float  u_max  = cScaleUMinUMax[i].w;
        vec2 direction = cCenterAndDirection[i].zw;
        
        vec2 currentUV = uv;
        
        vec2 e = (currentUV - center) / (radius * cAspectRatio);
        float d = dot(e, e);

        // Fix border case. TODO: works wrong under S5 Android 7.
        float actualScale = scale;//min(min(scale, min(uv.x, uv.y)), min(1.0 - uv.x, 1.0 - uv.y));

        if (d < 1.0 && actualScale > 0.0)
        {
#ifdef DEBUG_MODE
            if (debug == 1.0)
            {
                vColor = ColorForPoint(uv, center, direction);
            }
#endif
            if (type == 1.0) {
                // zoom
                vec2 dist = vec2(d * radius.x, d * radius.y);
                currentUV -= center;
                
                vec2 delta = ((radius - dist) / radius);
                float deltaScale = actualScale;
                if(deltaScale > 0.0) {
                    deltaScale = smoothstep(u_min, u_max, deltaScale);
                }
                
                vec2 percent = 1.0 - ((delta * deltaScale) * cProgress);
                currentUV = currentUV * percent;
                uv = currentUV + center;
            } else if (type == 2.0) {
                // shift
                float dist = 1.0 - d;
                float delta = actualScale * dist * cProgress;

                float deltaScale = smoothstep(u_min, u_max, dist);
                vec2 direction2 = direction * deltaScale * cAspectRatio;
                uv = currentUV - delta * direction2;
            }
        }
    }

	uv.y    = 1.0 - uv.y;
    vTexCoord.xy = uv;
}

void PS()
{
	vec2 uv = vTexCoord;

#ifdef DEBUG_MODE
    gl_FragColor = texture2D(sEnvMap, uv) * vColor;
    // Indicate debug mode. 
    if (uv.x < 0.05 && uv.y < 0.05)
    {
        gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
    }
#else
    gl_FragColor = texture2D(sEnvMap, uv);
#endif
}
