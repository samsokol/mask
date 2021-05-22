#include "Scripts/src/Plugins.as"

class Face
{
    Node@ _face;

    Vector3 _oldRot;
    Vector3 _newRot;
    Vector3 _secRot;
    Vector3 _oldSecRot;

    Vector3 _oldPos;

    float k_rot_l = 1.4f;
    float k_rot_r = 1.35f;

    float ROTATION = 110.0f;   

    Face(String face_tag)
    {
        _face = scene.GetChild(face_tag);
        SubscribeToEvent("Update", "HandleUpdate");  
    }

    void HandleUpdate(StringHash eventType, VariantMap& eventData)
    {
        float timeStep = eventData["TimeStep"].GetFloat();
        _face.position = Vector3(BihFilterP(_face.position.x, _oldPos.x), BihFilterP(_face.position.y, _oldPos.y), BihFilterP(_face.position.z, _oldPos.z));
        _oldPos = Vector3(_face.position.x, _face.position.y, _face.position.z);
        float k;
        if(_face.rotation.y < 0) k = k_rot_r;
        else k = k_rot_l;
        _newRot = Vector3(_face.rotation.x * ROTATION, _face.rotation.y * ROTATION*k, _face.rotation.z * ROTATION);
        _oldRot = _newRot;
        _oldSecRot = _secRot;
        _secRot = Vector3(BihFilterR(_newRot.x, _oldSecRot.x, 0.45), BihFilterR(_newRot.y, _oldSecRot.y, 0.4), BihFilterR(_newRot.z, _oldSecRot.z, 0.65));
        _face.rotation = Quaternion(_secRot.x, _secRot.y, _secRot.z);
    }

    float BihFilterR(float new, float old, float k)
    {
        return k*new + (1-k)*old;
    }

    float BihFilterP(float new, float old)
    {
        float k = 0.7f;
        return k*new + (1-k)*old;
    }
}

class DetectionSmoothingPlugin : BasePlugin
{
    Face@ face;
    String faceName;

    DetectionSmoothingPlugin(String _faceName)
    {
        faceName = _faceName;
    }

    void init() override
    { 
        face = Face(faceName);
    }
};

class DetectionSmoothingPluginToFactory
{
    DetectionSmoothingPluginToFactory()
    {
        JSONFile settings;
        settings.Load(cache.GetFile("mask.json"));  
        JSONValue jsonSettigns = settings.GetRoot();
        int jsonFaces = jsonSettigns.Get("num_faces").GetInt();

        g_PluginsFactory.addPlugin(DetectionSmoothingPlugin("Face"));

        if(jsonFaces == 2)
        {
            g_PluginsFactory.addPlugin(DetectionSmoothingPlugin("Face1"));
        }      
    }
};

DetectionSmoothingPluginToFactory g_DetectionSmoothingPluginToFactory;