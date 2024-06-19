package Asgard

import "core:c"
import "vendor:glfw"
import vk "vendor:vulkan"

// Consts
@(private="file")
ENGINE_VERSION : u32 : (0<<22) | (0<<12) | (1)

@(private="file")
requestedLayers : [1]cstring = { "VK_LAYER_KHRONOS_validation" }

// Data structs
QueueFamilyIndices :: struct {
    graphicsFamily : u32,
    logicalFamily  : u32
}

GraphicsContext :: struct {
    instance       : vk.Instance,
    debugMessenger : vk.DebugUtilsMessengerEXT,
    physicalDevice : vk.PhysicalDevice,
    device         : vk.Device,
    queueFamily    : QueueFamilyIndices
}

// Methods
initVkGraphics :: proc(engineContext : ^GraphicsContext) {
    // Calls:
    // load_proc_addresses_global :: proc(vk_get_instance_proc_addr: rawptr)
    vk.load_proc_addresses((rawptr)(glfw.GetInstanceProcAddress));

    createInstance(engineContext)
    when ODIN_DEBUG {
        vkSetupDebugMessenger(engineContext)
    }
    pickPhysicalDevice(engineContext)
    createLogicalDevice(engineContext)
}

@(private="file") 
createInstance :: proc(engineContext : ^GraphicsContext) {
    appInfo : vk.ApplicationInfo = {
        sType              = .APPLICATION_INFO,
        pNext              = nil,
        pApplicationName   = "Asgard",
        applicationVersion = APP_VERSION,
        pEngineName        = "Asgard Graphics",
        engineVersion      = ENGINE_VERSION,
        apiVersion         = vk.API_VERSION_1_0
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
        log(.ERROR, "Failed to find required extension: {}", name)
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
            log(.WARNING, "Failed to find requested extension: {}", name)
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

    debugMessengerCreateInfo : vk.DebugUtilsMessengerCreateInfoEXT
    when ODIN_DEBUG {
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
            log(.WARNING, "Failed to find requested layer: {}", name)
        }
        instanceInfo.enabledLayerCount = (u32)(len(supportedLayers))
        instanceInfo.ppEnabledLayerNames = raw_data(supportedLayers)

        debugMessengerCreateInfo = vkPopulateDebugMessengerCreateInfo()
        instanceInfo.pNext = &debugMessengerCreateInfo
    }

    if (vk.CreateInstance(&instanceInfo, nil, &engineContext^.instance) != .SUCCESS) {
        log(.ERROR, "Failed to create vulkan instance.")
        panic("Failed to create vulkan instance.")
    }

    // Calls:
    // load_proc_addresses_instance :: proc(instance: Instance)
    vk.load_proc_addresses(engineContext^.instance)
}

@(private="file")
findQueueFamilies :: proc(physicalDevice : vk.PhysicalDevice) -> (indices : QueueFamilyIndices, err : b32 = false) {
    queueFamilyCount : u32;
    
    vk.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, nil);
    queueFamilies := make([]vk.QueueFamilyProperties, queueFamilyCount);
    vk.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, raw_data(queueFamilies));

    for queueFamily, index in queueFamilies {
        if (vk.QueueFlag.GRAPHICS in queueFamily.queueFlags) {
            indices.graphicsFamily = (u32)(index)
            return
        }
    }
    return indices, true
}

@(private="file")
pickPhysicalDevice :: proc(engineContext : ^GraphicsContext) {
    scorePhysicalDevice :: proc(physicalDevice : vk.PhysicalDevice) -> (score : u32 = 0) {
        physicalDeviceProperties : vk.PhysicalDeviceProperties
        physicalDeviceFeatures : vk.PhysicalDeviceFeatures
        
        vk.GetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties)
        vk.GetPhysicalDeviceFeatures(physicalDevice, &physicalDeviceFeatures)

        indices, err := findQueueFamilies(physicalDevice)
        if (!physicalDeviceFeatures.geometryShader || err) {
            return
        }

        if physicalDeviceProperties.deviceType == vk.PhysicalDeviceType.DISCRETE_GPU {
            score += 1000
        }

        if (indices.graphicsFamily == indices.logicalFamily) {
            score += 100
        }

        score += physicalDeviceProperties.limits.maxImageDimension2D
        return
    }

    deviceCount : u32
    vk.EnumeratePhysicalDevices(engineContext^.instance, &deviceCount, nil)

    if deviceCount == 0 {
        log(.ERROR, "No devices with Vulkan support!")
        panic("No devices with Vulkan support!")
    }

    physicalDevices := make([]vk.PhysicalDevice, deviceCount)
    vk.EnumeratePhysicalDevices(engineContext^.instance, &deviceCount, raw_data(physicalDevices))

    {
        physicalDeviceMap : map[^vk.PhysicalDevice]u32
        defer delete(physicalDeviceMap)
        for &physicalDevice in physicalDevices {
            physicalDeviceMap[&physicalDevice] = scorePhysicalDevice(physicalDevice)
        }

        bestScore : u32
        for physicalDevice, score in physicalDeviceMap {
            if (score > bestScore) {
                engineContext^.physicalDevice = (^vk.PhysicalDevice)(physicalDevice)^
                bestScore = score
            }
        }
    }

    if (engineContext^.physicalDevice == nil) {
        log(.ERROR, "No suitable physical device found!")
        panic("No suitable physical device found!")
    }
}

@(private="file")
createLogicalDevice :: proc(engineContext : ^GraphicsContext) {
    indices, _ := findQueueFamilies(engineContext^.physicalDevice)
    queuePriority : f32 = 1.0
    queueCreateInfo : vk.DeviceQueueCreateInfo = {
        sType            = .DEVICE_QUEUE_CREATE_INFO,
        pNext            = nil,
        flags            = { vk.DeviceQueueCreateFlag.PROTECTED },
        queueFamilyIndex = indices.graphicsFamily,
        queueCount       = 1,
        pQueuePriorities = &queuePriority
    }

    deviceFeatures : vk.PhysicalDeviceFeatures

    createInfo : vk.DeviceCreateInfo = {
        sType                   = .DEVICE_CREATE_INFO,
        pNext                   = nil,
        flags                   = {},
        queueCreateInfoCount    = 1,
        pQueueCreateInfos       = &queueCreateInfo,
        enabledLayerCount       = 0,
        ppEnabledLayerNames     = nil,
        enabledExtensionCount   = 0,
        ppEnabledExtensionNames = nil,
        pEnabledFeatures        = &deviceFeatures
    }

    when ODIN_DEBUG {
        createInfo.enabledLayerCount = (u32)(len(requestedLayers))
        createInfo.ppEnabledLayerNames = raw_data(requestedLayers[:])
    }

    if vk.CreateDevice(engineContext^.physicalDevice, &createInfo, nil, &engineContext^.device) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to create logical device!")
        panic("Failed to create logical device!")
    }

    // Calls:
    // load_proc_addresses_device :: proc(device: Device)
    vk.load_proc_addresses(engineContext^.device)
}

clanupVkGraphics :: proc(engineContext : ^GraphicsContext) {
    vk.DestroyDevice(engineContext^.device, nil)
    when ODIN_DEBUG {
        vk.DestroyDebugUtilsMessengerEXT(engineContext^.instance, engineContext^.debugMessenger, nil)
    }
    vk.DestroyInstance(engineContext^.instance, nil)
}