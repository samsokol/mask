#include "Scripts/src/Plugins.as"

class PerspectivePlugin : BasePlugin
{
    Scene@  scene;

    Node@ persCameraNode;
    Node@ persFaceNode;

    void init() override
    {
        Print("PerspectivePlugin init");

        scene = script.defaultScene;

        // Create AR camera
        persCameraNode = scene.CreateChild("CameraPerspective");
        persFaceNode   = scene.CreateChild("FacePerspective");

        Camera@ cameraPerspective = persCameraNode.CreateComponent("Camera");
        persCameraNode.position = Vector3(0.0f, 0.0f, 0.0f); 
        persFaceNode.position   = Vector3(0.0f, 0.0f, 0.0f); 
        cameraPerspective.orthographic = false;
        cameraPerspective.nearClip = 0.0;
        cameraPerspective.farClip  = 1000;

        // Edit render patch.
        RenderPath@ defaultAR = renderer.viewports[0].renderPath;

        RenderPath@ currentRenderPath = RenderPath();
        bool isCurrent3D = (defaultAR.commands[0].tag == "3dStart");
        currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_texture.xml"));
        currentRenderPath.AddCommand(defaultAR.commands[0]);

        Array<RenderPath@>  renderPaths;
        Array<bool>  renderPathsCamera;

        for (uint i = 1; i < defaultAR.numCommands; i++)
        {
             RenderPathCommand command = defaultAR.commands[i];

             if ((isCurrent3D && (command.tag == "3dFinish" || command.pass =="viewportblend")) || (!isCurrent3D && (command.tag == "3dStart" || command.pass =="cull")))
             {
                if (isCurrent3D)
                {
                  currentRenderPath.AddCommand(command);
                }
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_viewport_to_texture.xml"));
                renderPaths.Push(currentRenderPath);                
                renderPathsCamera.Push(isCurrent3D);

                @currentRenderPath = RenderPath();
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_texture.xml"));
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_texture_to_viewport.xml"));
                if (!isCurrent3D)
                {
                  currentRenderPath.AddCommand(command);
                }
                isCurrent3D = !isCurrent3D;
                continue;
             }
             else if (!isCurrent3D && command.tag.StartsWith("3dStartFinish"))
             {
                // Push old
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_viewport_to_texture.xml"));
                renderPaths.Push(currentRenderPath);                
                renderPathsCamera.Push(isCurrent3D);

                // Push one command
                @currentRenderPath = RenderPath();
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_texture.xml"));
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_texture_to_viewport.xml"));
                currentRenderPath.AddCommand(command);
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_viewport_to_texture.xml"));
                renderPaths.Push(currentRenderPath);                
                renderPathsCamera.Push(true);

                // Push new
                @currentRenderPath = RenderPath();
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_texture.xml"));
                currentRenderPath.Append(cache.GetResource("XMLFile", "RenderPaths/copy_texture_to_viewport.xml"));
                continue;
             }   

             currentRenderPath.AddCommand(command);
        }

        renderPaths.Push(currentRenderPath);
        renderPathsCamera.Push(isCurrent3D);

        renderer.numViewports = renderPaths.length + 1; 

        Camera@ orthoCamera = scene.GetChild("Camera").GetComponent("Camera");
        renderer.viewports[0].renderPath = renderPaths[0];
        for (uint i = 1; i < renderPaths.length; i++)
        {
            Viewport@ viewport   = Viewport(scene, renderPathsCamera[i] ? cameraPerspective : orthoCamera);
            viewport.renderPath  = renderPaths[i];
            renderer.viewports[i] = viewport;
        }

        Node@ faceNode = scene.GetChild("Face");
        Array<Node@> children =  faceNode.GetChildren();
        for (uint i = 0; i < children.length; i ++)
        {
            if (children[i].name == "anchor_model3d")
            {
              children[i].parent = persFaceNode;
            }
        }

        SubscribeToEvent("PostUpdate", "HandlePostUpdate");
        SubscribeToEvent("SrcFrameUpdate", "HandleUpdateSrc");
    }

	Vector2 srcSize = Vector2(1280, 720);
        float  angle = 0.0;

	void HandlePostUpdate(StringHash eventType, VariantMap& eventData)
        {
            Node@ cameraNode = persCameraNode;
            Node@ node       = persFaceNode;
	    Camera@ camera   = cameraNode.GetComponent("Camera");

            Node@ origCameraNode = scene.GetChild("Camera");
            Node@ origNode       = scene.GetChild("face");
            Camera@ origCamera   = origCameraNode.GetComponent("Camera");

            cameraNode.rotation = origCameraNode.rotation;
///            camera.flipVertical = origCamera.flipVertical;
            camera.orthoSize = origCamera.orthoSize;
            camera.aspectRatio = origCamera.aspectRatio;

            node.enabled  = origNode.enabled;
            cameraNode.enabled = true;
            node.rotation = origNode.rotation;

            Vector2 frustrumSize = srcSize / Vector2(origNode.scale.x, origNode.scale.y);
        
            camera.orthographic = false;
            camera.aspectRatio  = frustrumSize.x / frustrumSize.y;
            camera.fov = 35;
        
	    float d= 1.0;
            if (angle == 0)
            {
	        d = 0.5 * frustrumSize.y / Tan(camera.fov / 2.0);
                camera.projectionOffset = Vector2(origNode.position.x / srcSize.x, origNode.position.y / srcSize.y);
            }
            else if (angle == 90)
	    {
                d = 0.5 * frustrumSize.y / Tan(camera.fov / 2.0);
                camera.projectionOffset = Vector2(- origNode.position.y / srcSize.x, origNode.position.x / srcSize.y);
            }
            else if (angle == 270)
            {
                d = 0.5 * frustrumSize.y / Tan(camera.fov / 2.0);
                camera.projectionOffset = Vector2(origNode.position.y / srcSize.x, -origNode.position.x / srcSize.y);
            }
        
            d = d;// + 700;
        
            float z = d;// + (node.position.z - 500.0);
            camera.farClip  = Max(origCamera.farClip, d + 500);
            camera.nearClip = Max(0.0, d - 500);
            node.position = Vector3(0, 0, d);
            float scale = 1.0;
            node.scale    = Vector3(scale, scale, scale);
        }

        void HandleUpdateSrc(StringHash eventType, VariantMap& eventData)
        {
             srcSize = eventData["Size"].GetVector2(); 
             angle   = eventData["Angle"].GetFloat(); 
        }
};

class PerspectivePluginToFactory
{
    PerspectivePluginToFactory()
    {
        g_PluginsFactory.addPlugin(PerspectivePlugin());
    }
};

PerspectivePluginToFactory g_perspectivePluginToFactory;
