/**
 *  This is simple plug-in factory to use them in main script.
 *
 */

/**
 * Inheritance your plugin from this base class.
 */
class BasePlugin
{
    void init() { 
        Print("Error: Base pluing inited");
        /* Inheritance and past init code here*/ 
    }
};


/**
 * This factory holds all plugins.
 *
 */
class PluginsFactory
{
    private Array<BasePlugin@> plugins;

    void addPlugin(BasePlugin@ pluging)
    {
        plugins.Push(pluging);
    }

    void initPlugins()
    {
        Print("Init " + plugins.length + " plugins");
        for (uint i = 0; i < plugins.length; i ++)
        {
            plugins[i].init();
        }
    }
};

PluginsFactory g_PluginsFactory;