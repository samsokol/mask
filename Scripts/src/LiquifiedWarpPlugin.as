#include "Scripts/src/Plugins.as"
#include "Scripts/src/Models3DGenerators.as"


enum LiquifiedWarpPointType {LPT_UNKNOWN = 0, LPT_ZOOM, LPT_SHIFT};

class LiquifiedWarpPoint
{
    String  anchor;
    Vector2 offset;
    Vector2 radius;
    float   scale;
    Vector2 direction; // in radian
    Vector2 uMinMax;
    LiquifiedWarpPointType type;
    int faceIndex;
    bool debug;
}

class LiquifiedWarpPlugin : BasePlugin
{
    Node@ liquifiedwarpNode;
    StaticModel@ object;
    Scene@  scene;
    Array<Node@> lenseScaleNode;
    Array<Node@> faceNode;
    Array<VariantMap> detectData;

    Array<LiquifiedWarpPoint> points;
    float aspect = 720.0f / 1280.0f;
    float progress = 1.0f;
    float angle = 0.0f;
    String liquifiedwarpNodeName;
    String liquifiedwarpFileSettings;

    LiquifiedWarpPlugin (String liquifiedwarpNodeName_, String liquifiedwarpFileSettings_)
    {
        liquifiedwarpNodeName     = liquifiedwarpNodeName_;
        liquifiedwarpFileSettings = liquifiedwarpFileSettings_;
    }

    void init() override
    {
        Print("LiquifiedWarpPlugin init");

        scene = script.defaultScene;

        liquifiedwarpNode = scene.GetChildrenWithTag(liquifiedwarpNodeName, true)[0];
        BillboardSet@ bbs = liquifiedwarpNode.GetComponent("BillboardSet");
        Model@ model = CreateModelPlane(100, 200);
        object = liquifiedwarpNode.CreateComponent("StaticModel");
        object.model = model;
        object.material = bbs.material.Clone();        
        liquifiedwarpNode.RemoveComponent(bbs);
        liquifiedwarpNode.parent.RemoveChild(liquifiedwarpNode);
        scene.AddChild(liquifiedwarpNode);

        // Create Node to recalculate scale.
        faceNode.Push(scene.GetChild("Face"));
        lenseScaleNode.Push(faceNode[0].CreateChild("LiquifiedWarpUnit0"));
        lenseScaleNode[0].position = Vector3(0.707, 0.707, 0.0);

        faceNode.Push(scene.GetChild("Face1"));
        lenseScaleNode.Push(faceNode[1].CreateChild("LiquifiedWarpUnit1"));
        lenseScaleNode[1].position = Vector3(0.707, 0.707, 0.0);

        for (uint i = 0; i < lenseScaleNode.length; i++)
        {
            detectData.Push(VariantMap());
        }

        loadSetup();

        SubscribeToEvent("SrcFrameUpdate", "handleUpdateSrc");
        SubscribeToEvent("UpdateFacePOI", "UpdateFacePOI");
        SubscribeToEvent("Update", "HandleUpdate");
    }

    void handleUpdateSrc(StringHash eventType, VariantMap& eventData)
    {
        Vector2 size = eventData["Size"].GetVector2();
        angle = eventData["Angle"].GetFloat();
        Vector2 sizeTarget = eventData["TargetSize"].GetVector2();

        if (angle == 90 || angle == 270)
        {
            size = Vector2(size.y, size.x);
            //sizeTarget = Vector2(sizeTarget.y, sizeTarget.x);
            //aspect = sizeTarget.y / sizeTarget.x;
        }
        //else
        //{
            //size = Vector2(size.x, size.y);
            //aspect = sizeTarget.x / sizeTarget.y;   
        //}       

        aspect = sizeTarget.x / sizeTarget.y;
        liquifiedwarpNode.scale = Vector3(size.x / 2.0, size.y / 2.0, 1.0);        
        //liquifiedwarpNode.SetTransform2D(Vector2(0.0, 0.0), -angle);
    }

    void UpdateFacePOI(StringHash eventType, VariantMap& eventData)
    {
        uint faceIndex = eventData["NFace"].GetUInt();
        detectData[faceIndex] = eventData;
    }

    void HandleUpdate(StringHash eventType, VariantMap& eventData)
    {
        //loadSetup();
        applySetup();
    }

    void loadSetup()
    {
        JSONFile settings;
        settings.Load(cache.GetFile(liquifiedwarpFileSettings));
        JSONValue jsonSettigns = settings.GetRoot();

        if (jsonSettigns.Contains("progress"))
        {
            progress = jsonSettigns.Get("progress").GetFloat();
        }

        points.Clear();

        JSONValue jsonPoints = jsonSettigns.Get("points");

        bool debug = false;

        if (jsonPoints.isArray)
        {            
            for (uint i = 0; i < jsonPoints.size; i++)
            {
                LiquifiedWarpPoint point;
                JSONValue jsonPoint = jsonPoints[i];

                point.type = (jsonPoint.Get("type").GetString() == "shift" ? LPT_SHIFT :
                    jsonPoint.Get("type").GetString() == "zoom" ? LPT_ZOOM : LPT_UNKNOWN);

                if (point.type != LPT_UNKNOWN)
                {
                    point.anchor = jsonPoint.Get("anchor").GetString();
                    point.offset = Vector2(jsonPoint.Get("offset")[0].GetFloat(), 
                        jsonPoint.Get("offset")[1].GetFloat());
                    point.radius = Vector2(jsonPoint.Get("radius")[0].GetFloat(), 
                        jsonPoint.Get("radius")[1].GetFloat());
                    float angle  = jsonPoint.Get("angle").GetFloat();
                    point.direction = Vector2(Cos(angle), Sin(angle));
                    point.scale  = jsonPoint.Get("scale").GetFloat();
                    point.uMinMax = Vector2(jsonPoint.Get("minMax")[0].GetFloat(), 
                        jsonPoint.Get("minMax")[1].GetFloat());
                    point.faceIndex = jsonPoint.Contains("faceIndex") ? jsonPoint.Get("faceIndex").GetInt() : 0;
                    point.debug = jsonPoint.Contains("debug") ? jsonPoint.Get("debug").GetBool() : false;
                    debug = point.debug || debug;

                    points.Push(point);
                }                
            }
        }

        object.materials[0].techniques[0].passes[0].vertexShaderDefines = debug ? " DEBUG_MODE" : "";
        object.materials[0].techniques[0].passes[0].pixelShaderDefines  = debug ? " DEBUG_MODE" : "";
    }

    void applySetup()
    {
        VectorBuffer buf;
        Camera@ camera = script.defaultScene.GetChild("Camera").GetComponent("Camera");
        //uniform float4 cCenter[MAXPOINTS];
        //uniform float4 cRadiusAndType[MAXPOINTS];       // We use only x and y, z for type
        //uniform float4 cScaleAngelUMinUMax[MAXPOINTS];  //It is: Scale, Angel, UMin, UMax  
        VectorBuffer centerBuffer;
        VectorBuffer radiusAndTypeAndDebug;
        VectorBuffer scaleAngelUMinUMax;

        Vector2 aspectVector;
        if (aspect > 1.0)
        {
            aspectVector = Vector2(1.0, 1.0 / aspect);
        }
        else
        {
            aspectVector = Vector2(aspect, 1.0);
        }


        Array<float> scaleFactor;
        for (uint i = 0; i < faceNode.length; i++)
        {
            Vector3 deltaInGlobalSpace = lenseScaleNode[i].worldPosition - faceNode[i].worldPosition;

            Vector2 scaleInScreenSpace = camera.WorldToScreenPoint(Vector3(deltaInGlobalSpace.length * 0.707,
                deltaInGlobalSpace.length * 0.707, 500.0)) - camera.WorldToScreenPoint(Vector3(0.0, 0.0, 500.0));
            float scaleFactorValue = scaleInScreenSpace.length;
            scaleFactor.Push(scaleFactorValue);
        }

        uint pointsCount = 0;
        for (uint i = 0; i < points.length; i ++)
        {
            LiquifiedWarpPoint@ point = points[i];
            if (detectData[point.faceIndex]["PoiMap"].GetVariantMap().Contains(point.anchor))
            {
                bool faceEnabled = detectData[point.faceIndex]["Detected"].GetBool();

                Vector3 centerLocal = detectData[point.faceIndex]["PoiMap"].GetVariantMap()[point.anchor].GetVector3() 
                    + Vector3(point.offset.x, point.offset.y, 0.0);
                Vector3 center = faceNode[point.faceIndex].LocalToWorld(centerLocal);
                Vector2 centerInScreen = camera.WorldToScreenPoint(center);

                Vector3 direction2 = Vector3(centerLocal.x, centerLocal.y, centerLocal.z) 
                    + Vector3(point.direction.x, point.direction.y, 0.0);
                Vector3 direction2World = faceNode[point.faceIndex].LocalToWorld(direction2);
                Vector2 directionInScreen2 = camera.WorldToScreenPoint(direction2World);
                Vector2 directionInScreen  = (directionInScreen2 - centerInScreen).Normalized();

                centerBuffer.WriteVector4(Vector4(centerInScreen.x, centerInScreen.y,
                   directionInScreen.x, directionInScreen.y));
                radiusAndTypeAndDebug.WriteVector4(Vector4(point.radius.x * scaleFactor[point.faceIndex],
                    point.radius.y * scaleFactor[point.faceIndex], (faceEnabled ? float(point.type) : 0.0), 
                    float(point.debug ? 1.0 : 0.0)));
                scaleAngelUMinUMax.WriteVector4(Vector4(point.scale * scaleFactor[point.faceIndex], 0.0,
                    float(point.uMinMax.x), float(point.uMinMax.y)));
                pointsCount++;
            }
            else
            {
                centerBuffer.WriteVector4(Vector4(0.0, 0.0, 0.0, 0.0));
                radiusAndTypeAndDebug.WriteVector4(Vector4(0.0, 0.0, 0.0, 0.0));
                scaleAngelUMinUMax.WriteVector4(Vector4(0.0, 0.0, 0.0, 0.0));
            }
        }
       
        object.materials[0].shaderParameters["CenterAndDirection"] = Variant(centerBuffer);
        object.materials[0].shaderParameters["RadiusAndType"]      = Variant(radiusAndTypeAndDebug);
        object.materials[0].shaderParameters["ScaleUMinUMax"] = Variant(scaleAngelUMinUMax);

        object.materials[0].shaderParameters["AspectRatio"] = Variant(Vector2(1.0, 1.0) / aspectVector);
        object.materials[0].shaderParameters["Count"]       = float(points.length);
        object.materials[0].shaderParameters["Progress"]    = progress;

        Vector2 textCoordX;
        Vector2 textCoordY;
        Vector2 textCoordOffset = Vector2(0.0, 0.0);
        if (angle == 0.0)
        {
            textCoordX = Vector2(1.0, 0.0);
            textCoordY = Vector2(0.0, 1.0);
        }
        else if (angle == 90.0)
        {
            textCoordX = Vector2(0.0, 1.0);
            textCoordY = Vector2(-1.0, 0.0);
            textCoordOffset.y = 1.0;
        }
        else if (angle == 180.0)
        {
            textCoordX = Vector2(-1.0, 0.0);
            textCoordY = Vector2(0.0, -1.0);
            textCoordOffset.y = 1.0;
            textCoordOffset.x = 1.0;
        }
        else if (angle == 270.0)
        {
            textCoordX = Vector2(0.0, -1.0);
            textCoordY = Vector2(1.0, 0.0);
            textCoordOffset = Vector2(1.0, 0.0);
        }

        object.materials[0].shaderParameters["TexCoordX"] = Variant(textCoordX);
        object.materials[0].shaderParameters["TexCoordY"] = Variant(textCoordY);
        object.materials[0].shaderParameters["TexCoordOffset"] = Variant(textCoordOffset);
    }
};

class LiquifiedWarpPluginToFactory
{
    LiquifiedWarpPluginToFactory()
    {
        g_PluginsFactory.addPlugin(LiquifiedWarpPlugin("liquifiedwarp", "Scripts/PointsLiquifiedWarp.json"));
        //g_PluginsFactory.addPlugin(LiquifiedWarpPlugin("liquifiedwarp1", "Scripts/PointsLiquifiedWarp1.json"));
    }
};

LiquifiedWarpPluginToFactory g_liquifiedwarpPluginToFactory;