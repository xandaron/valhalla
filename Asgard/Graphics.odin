package Asgard

import "core:c"
import "vendor:glfw"
import vk "vendor:vulkan"

ENIGNE_VERSION : u32 : (0<<22) | (0<<12) | (1)

GraphicsContext :: struct {
    instance       : vk.Instance,
    device         : vk.Device,
    physicalDevice : vk.PhysicalDevice
}

initVkGraphics :: proc(engineContext : ^GraphicsContext) {
    // Calls:
    // load_proc_addresses_global :: proc(vk_get_instance_proc_addr: rawptr)
    vk.load_proc_addresses((rawptr)(glfw.GetInstanceProcAddress));

    createInstance(engineContext)
}

@(private="file") 
createInstance :: proc(engineContext : ^GraphicsContext) {
    appInfo : vk.ApplicationInfo = {
        sType              = .APPLICATION_INFO,
        pNext              = nil,
        pApplicationName   = "Asgard",
        applicationVersion = APP_VERSION,
        pEngineName        = "Asgard Graphics",
        engineVersion      = ENIGNE_VERSION,
        apiVersion         = vk.API_VERSION_1_3
    }

    glfwExtensions := glfw.GetRequiredInstanceExtensions()
    supportedExtensions : [dynamic]cstring

    extensionCount : u32
    vk.EnumerateInstanceExtensionProperties(nil, &extensionCount, nil)
    availableExtensions := make([]vk.ExtensionProperties, extensionCount)
    vk.EnumerateInstanceExtensionProperties(nil, &extensionCount, raw_data(availableExtensions))
    required_extension_loop: for name in glfwExtensions {
        for &extension in availableExtensions {
            if  name == cstring(&extension.extensionName[0]) {
                append(&supportedExtensions, name)
                continue required_extension_loop
            }
        }
        debugMessage(.ERROR, "Failed to find required extension: {}", name)
        panic("Failed to find required extension")
    }

    when ODIN_DEBUG {
        requestedExtensions := [?]cstring{ "VK_EXT_debug_utils" }
        requested_extension_loop: for name in requestedExtensions {
            for &extension in availableExtensions {
                if (name == cstring(&extension.extensionName[0])) {
                    append(&supportedExtensions, name)
                    continue requested_extension_loop
                }
            }
            debugMessage(.WARNING, "Failed to find requested extension: {}", name)
        }
    }

    instanceInfo : vk.InstanceCreateInfo = {
        sType                   = .INSTANCE_CREATE_INFO,
        pNext                   = nil,
        flags                   = nil,
        pApplicationInfo        = &appInfo,
        enabledLayerCount       = 0,
        ppEnabledLayerNames     = nil,
        enabledExtensionCount   = (u32)(len(supportedExtensions)),
        ppEnabledExtensionNames = raw_data(supportedExtensions),
    }

    when ODIN_DEBUG {
        requestedLayers := [?]cstring{ "VK_LAYER_KHRONOS_validation" }
        supportedLayers : [dynamic]cstring
        layerCount : u32 
        vk.EnumerateInstanceLayerProperties(&layerCount, nil)
        layers := make([]vk.LayerProperties, layerCount)
        vk.EnumerateInstanceLayerProperties(&layerCount, raw_data(layers))
        layer_loop: for name in requestedLayers {
            for &layer in layers {
                if name == cstring(&layer.layerName[0]) {
                    append(&supportedLayers, name)
                    continue layer_loop
                }
            }
            debugMessage(.WARNING, "Failed to find requested layer: {}", name)
        }
        instanceInfo.enabledLayerCount = (u32)(len(supportedLayers))
        instanceInfo.ppEnabledLayerNames = raw_data(supportedLayers)
    }

    if (vk.CreateInstance(&instanceInfo, nil, &engineContext^.instance) != .SUCCESS) {
        debugMessage(.ERROR, "Failed to create vulkan instance.")
        panic("Failed to create vulkan instance.")
    }

    // Calls:
    // load_proc_addresses_instance :: proc(instance: Instance)
    vk.load_proc_addresses(engineContext^.instance)
}

clanupVkGraphics :: proc(graphicsContext : ^GraphicsContext) {
    vk.DestroyInstance(graphicsContext^.instance, nil)
}