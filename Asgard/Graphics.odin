package Asgard

import "core:c"
import "core:os"
import "vendor:glfw"
import vk "vendor:vulkan"

// Consts
@(private="file")
ENGINE_VERSION : u32 : (0<<22) | (0<<12) | (1)

@(private="file")
requestedLayers : []cstring = { "VK_LAYER_KHRONOS_validation" }

@(private="file")
requiredDeviceExtensions : []cstring = { vk.KHR_SWAPCHAIN_EXTENSION_NAME }

@(private="file")
shaderStages : []vk.ShaderStageFlag = { vk.ShaderStageFlag.VERTEX, vk.ShaderStageFlag.FRAGMENT, vk.ShaderStageFlag.COMPUTE }
@(private="file")
shaderFiles : []string = { "./assets/shaders/vert.spv", "./assets/shaders/frag.spv"/*, "./assets/shaders/comp.spv"*/ }

@(private="file")
triangleVertices : [3]Vector2 : {
    { 0.0, -0.5 },
    { 0.5, 0.5 },
    { -0.5, 0.5 }
} 

// Data structs
QueueFamilyIndices :: struct {
    graphicsFamily : u32,
    presentFamily  : u32
}

SwapchainSupportDetails :: struct {
    capabilities : vk.SurfaceCapabilitiesKHR,
    formats      : []vk.SurfaceFormatKHR,
    modes        : []vk.PresentModeKHR
}

GraphicsContext :: struct {
    window              : glfw.WindowHandle,
    instance            : vk.Instance,
    debugMessenger      : vk.DebugUtilsMessengerEXT,
    surface             : vk.SurfaceKHR,
    physicalDevice      : vk.PhysicalDevice,
    device              : vk.Device,
    queueFamilies       : QueueFamilyIndices,
    graphicsQueue       : vk.Queue,
    presentQueue        : vk.Queue,
    swapchain           : vk.SwapchainKHR,
    swapchainFormat     : vk.SurfaceFormatKHR,
    swapchainMode       : vk.PresentModeKHR,
    swapchainExtent     : vk.Extent2D,
    swapchainImages     : []vk.Image,
    swapchainImageViews : []vk.ImageView
}

// Methods
initVkGraphics :: proc(graphicsContext : ^GraphicsContext) {
    // Calls:
    // load_proc_addresses_global :: proc(vk_get_instance_proc_addr: rawptr)
    vk.load_proc_addresses((rawptr)(glfw.GetInstanceProcAddress));

    createInstance(graphicsContext)
    when ODIN_DEBUG {
        vkSetupDebugMessenger(graphicsContext)
    }
    createSurface(graphicsContext)
    pickPhysicalDevice(graphicsContext)
    createLogicalDevice(graphicsContext)
    createSwapchain(graphicsContext)
    createImageViews(graphicsContext)
}

@(private="file") 
createInstance :: proc(graphicsContext : ^GraphicsContext) {
    appInfo : vk.ApplicationInfo = {
        sType              = .APPLICATION_INFO,
        pNext              = nil,
        pApplicationName   = "Asgard",
        applicationVersion = APP_VERSION,
        pEngineName        = "Asgard Graphics",
        engineVersion      = ENGINE_VERSION,
        apiVersion         = vk.API_VERSION_1_3
    }

    glfwExtensions := glfw.GetRequiredInstanceExtensions()
    supportedExtensions : [dynamic]cstring

    extensionCount : u32
    vk.EnumerateInstanceExtensionProperties(nil, &extensionCount, nil)
    availableExtensions := make([]vk.ExtensionProperties, extensionCount)
    vk.EnumerateInstanceExtensionProperties(nil, &extensionCount, raw_data(availableExtensions))
    instance_extension_outer_loop: for name in glfwExtensions {
        for &extension in availableExtensions {
            if  name == cstring(&extension.extensionName[0]) {
                append(&supportedExtensions, name)
                continue instance_extension_outer_loop
            }
        }
        log(.ERROR, "Failed to find required extension: {}", name)
        panic("Failed to find required extension")
    }
    
    when ODIN_DEBUG {
        requestedExtensions := [?]cstring{ "VK_EXT_debug_utils" }
        instance_extension2_outer_loop: for name in requestedExtensions {
            for &extension in availableExtensions {
                if (name == cstring(&extension.extensionName[0])) {
                    append(&supportedExtensions, name)
                    continue instance_extension2_outer_loop
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
        instance_layers_outer_loop: for name in requestedLayers {
            for &layer in layers {
                if name == cstring(&layer.layerName[0]) {
                    append(&supportedLayers, name)
                    continue instance_layers_outer_loop
                }
            }
            log(.WARNING, "Failed to find requested layer: {}", name)
        }
        instanceInfo.enabledLayerCount = (u32)(len(supportedLayers))
        instanceInfo.ppEnabledLayerNames = raw_data(supportedLayers)

        debugMessengerCreateInfo = vkPopulateDebugMessengerCreateInfo()
        instanceInfo.pNext = &debugMessengerCreateInfo
    }

    if (vk.CreateInstance(&instanceInfo, nil, &graphicsContext^.instance) != .SUCCESS) {
        log(.ERROR, "Failed to create vulkan instance.")
        panic("Failed to create vulkan instance.")
    }

    // Calls:
    // load_proc_addresses_instance :: proc(instance: Instance)
    vk.load_proc_addresses(graphicsContext^.instance)
}

@(private="file")
createSurface :: proc(graphicsContext : ^GraphicsContext) {
    if glfw.CreateWindowSurface(graphicsContext^.instance, graphicsContext^.window, nil, &graphicsContext^.surface) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to create surface!")
        panic("Failed to create surface!")
    }
}

@(private="file")
querySwapchainSupport :: proc(physicalDevice : vk.PhysicalDevice, graphicsContext : ^GraphicsContext) -> (swapchainSupport : SwapchainSupportDetails) {
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, graphicsContext^.surface, &swapchainSupport.capabilities);
    
    formatCount : u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, graphicsContext^.surface, &formatCount, nil);
    if (formatCount != 0) {
        swapchainSupport.formats = make([]vk.SurfaceFormatKHR, formatCount);
        vk.GetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, graphicsContext^.surface, &formatCount, raw_data(swapchainSupport.formats));
    }
    
    modeCount : u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, graphicsContext^.surface, &modeCount, nil);
    if (modeCount != 0) {
        swapchainSupport.modes = make([]vk.PresentModeKHR, modeCount);
        vk.GetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, graphicsContext^.surface, &modeCount, raw_data(swapchainSupport.modes));
    }
    
    return
}

@(private="file")
findQueueFamilies :: proc(physicalDevice : vk.PhysicalDevice, graphicsContext : ^GraphicsContext) -> (indices : QueueFamilyIndices, err : b32 = false) {
    queueFamilyCount : u32;
    vk.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, nil);
    queueFamilies := make([]vk.QueueFamilyProperties, queueFamilyCount);
    vk.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, raw_data(queueFamilies));

    foundPresentFamily := false
    foundGraphicsFamily := false

    for queueFamily, index in queueFamilies {
        if (vk.QueueFlag.GRAPHICS in queueFamily.queueFlags) {
            indices.graphicsFamily = (u32)(index)
            foundGraphicsFamily = true
        }

        presentSupport : b32 = false;
        vk.GetPhysicalDeviceSurfaceSupportKHR(physicalDevice, (u32)(index), graphicsContext^.surface, &presentSupport);
        if presentSupport {
            indices.presentFamily = (u32)(index);
            foundPresentFamily = true
        }

        if foundGraphicsFamily && foundPresentFamily {
            return
        }
    }
    return indices, true
}

@(private="file")
pickPhysicalDevice :: proc(graphicsContext : ^GraphicsContext) {
    checkDeviceExtensionSupport :: proc(physicalDevice : vk.PhysicalDevice) -> b32 {
        extensionCount : u32
        vk.EnumerateDeviceExtensionProperties(physicalDevice, nil, &extensionCount, nil)
        availableExtensions := make([]vk.ExtensionProperties, extensionCount)
        vk.EnumerateDeviceExtensionProperties(physicalDevice, nil, &extensionCount, raw_data(availableExtensions))

        outer_loop: for name in requiredDeviceExtensions {
            for &extension in availableExtensions {
                if (name == cstring(&extension.extensionName[0])) {
                    continue outer_loop
                }
            }
            return false
        }
        return true
    }
    swapchainAdequate :: proc(physicalDevice : vk.PhysicalDevice, graphicsContext : ^GraphicsContext) -> b32 {
        support : SwapchainSupportDetails = querySwapchainSupport(physicalDevice, graphicsContext)
        return len(support.formats) != 0 && len(support.modes) != 0
    }
    scorePhysicalDevice :: proc(physicalDevice : vk.PhysicalDevice, graphicsContext : ^GraphicsContext) -> (score : u32 = 0) {
        physicalDeviceProperties : vk.PhysicalDeviceProperties
        physicalDeviceFeatures : vk.PhysicalDeviceFeatures
        
        vk.GetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties)
        vk.GetPhysicalDeviceFeatures(physicalDevice, &physicalDeviceFeatures)

        indices, err := findQueueFamilies(physicalDevice, graphicsContext)
        if (!physicalDeviceFeatures.geometryShader || err || !checkDeviceExtensionSupport(physicalDevice) || !swapchainAdequate(physicalDevice, graphicsContext)) {
            return
        }

        if physicalDeviceProperties.deviceType == vk.PhysicalDeviceType.DISCRETE_GPU {
            score += 1000
        }

        if (indices.graphicsFamily == indices.presentFamily) {
            score += 100
        }

        score += physicalDeviceProperties.limits.maxImageDimension2D
        return
    }

    deviceCount : u32
    vk.EnumeratePhysicalDevices(graphicsContext^.instance, &deviceCount, nil)

    if deviceCount == 0 {
        log(.ERROR, "No devices with Vulkan support!")
        panic("No devices with Vulkan support!")
    }

    physicalDevices := make([]vk.PhysicalDevice, deviceCount)
    vk.EnumeratePhysicalDevices(graphicsContext^.instance, &deviceCount, raw_data(physicalDevices))

    {
        physicalDeviceMap : map[^vk.PhysicalDevice]u32
        defer delete(physicalDeviceMap)
        for &physicalDevice in physicalDevices {
            physicalDeviceMap[&physicalDevice] = scorePhysicalDevice(physicalDevice, graphicsContext)
        }

        bestScore : u32
        for physicalDevice, score in physicalDeviceMap {
            if (score > bestScore) {
                graphicsContext^.physicalDevice = (^vk.PhysicalDevice)(physicalDevice)^
                bestScore = score
            }
        }
    }

    if (graphicsContext^.physicalDevice == nil) {
        log(.ERROR, "No suitable physical device found!")
        panic("No suitable physical device found!")
    }
}

@(private="file")
createLogicalDevice :: proc(graphicsContext : ^GraphicsContext) {
    graphicsContext^.queueFamilies, _ = findQueueFamilies(graphicsContext^.physicalDevice, graphicsContext)

    queuePriority : f32 = 1.0
    queueCreateInfos : [dynamic]vk.DeviceQueueCreateInfo
    queueCreateInfo : vk.DeviceQueueCreateInfo = {
        sType            = .DEVICE_QUEUE_CREATE_INFO,
        pNext            = nil,
        flags            = {},
        queueFamilyIndex = graphicsContext^.queueFamilies.graphicsFamily,
        queueCount       = 1,
        pQueuePriorities = &queuePriority
    }
    append(&queueCreateInfos, queueCreateInfo)

    if (graphicsContext^.queueFamilies.graphicsFamily != graphicsContext^.queueFamilies.presentFamily) {
        queueCreateInfo = {
            sType            = .DEVICE_QUEUE_CREATE_INFO,
            pNext            = nil,
            flags            = {},
            queueFamilyIndex = graphicsContext^.queueFamilies.presentFamily,
            queueCount       = 1,
            pQueuePriorities = &queuePriority
        }
        append(&queueCreateInfos, queueCreateInfo)
    }

    deviceFeatures : vk.PhysicalDeviceFeatures

    createInfo : vk.DeviceCreateInfo = {
        sType                   = .DEVICE_CREATE_INFO,
        pNext                   = nil,
        flags                   = {},
        queueCreateInfoCount    = (u32)(len(queueCreateInfos)),
        pQueueCreateInfos       = raw_data(queueCreateInfos[:]),
        enabledLayerCount       = 0,
        ppEnabledLayerNames     = nil,
        enabledExtensionCount   = (u32)(len(requiredDeviceExtensions)),
        ppEnabledExtensionNames = raw_data(requiredDeviceExtensions[:]),
        pEnabledFeatures        = &deviceFeatures
    }

    when ODIN_DEBUG {
        createInfo.enabledLayerCount = (u32)(len(requestedLayers))
        createInfo.ppEnabledLayerNames = raw_data(requestedLayers[:])
    }

    if vk.CreateDevice(graphicsContext^.physicalDevice, &createInfo, nil, &graphicsContext^.device) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to create logical device!")
        panic("Failed to create logical device!")
    }

    // Calls:
    // load_proc_addresses_device :: proc(device: Device)
    vk.load_proc_addresses(graphicsContext^.device)

    vk.GetDeviceQueue(graphicsContext^.device, graphicsContext^.queueFamilies.graphicsFamily, 0, &graphicsContext^.graphicsQueue)
    vk.GetDeviceQueue(graphicsContext^.device, graphicsContext^.queueFamilies.presentFamily, 0, &graphicsContext^.presentQueue)
}

@(private="file")
createSwapchain :: proc(graphicsContext : ^GraphicsContext) {
    chooseFormat :: proc(formats : []vk.SurfaceFormatKHR) -> (format : vk.SurfaceFormatKHR) {
        for format in formats {
            if format.format == vk.Format.R8G8B8A8_SRGB && format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
                return format;
            }
        }
        return formats[0]
    }
    choosePresentMode :: proc(modes : []vk.PresentModeKHR) -> (mode : vk.PresentModeKHR) {
        for mode in modes {
            if mode == vk.PresentModeKHR.MAILBOX {
                return mode
            }
        }
        return vk.PresentModeKHR.FIFO
    }
    chooseExtent :: proc(capabilities : vk.SurfaceCapabilitiesKHR, graphicsContext : ^GraphicsContext) -> (extent : vk.Extent2D) {
        if capabilities.currentExtent.width != max(u32) {
            return capabilities.currentExtent
        }
        width, height := glfw.GetFramebufferSize(graphicsContext^.window)
        extent.width = clamp((u32)(width), capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
        extent.height = clamp((u32)(height), capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
        return
    }

    swapchainSupport : SwapchainSupportDetails = querySwapchainSupport(graphicsContext^.physicalDevice, graphicsContext)
    graphicsContext^.swapchainFormat = chooseFormat(swapchainSupport.formats)
    graphicsContext^.swapchainMode = choosePresentMode(swapchainSupport.modes)
    graphicsContext^.swapchainExtent = chooseExtent(swapchainSupport.capabilities, graphicsContext)

    ideal : u32 = swapchainSupport.capabilities.minImageCount + 1
    max : u32 = swapchainSupport.capabilities.maxImageCount
    imageCount := max if max > 0 && ideal > max else ideal
    
    oneQueueFamily : b32 = graphicsContext^.queueFamilies.graphicsFamily == graphicsContext^.queueFamilies.presentFamily
    createInfo : vk.SwapchainCreateInfoKHR = {
        sType                 = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR,
        pNext                 = nil,
        flags                 = {},
        surface               = graphicsContext^.surface,
        minImageCount         = imageCount,
        imageFormat           = graphicsContext^.swapchainFormat.format,
        imageColorSpace       = graphicsContext^.swapchainFormat.colorSpace,
        imageExtent           = graphicsContext^.swapchainExtent,
        imageArrayLayers      = 1,
        imageUsage            = { vk.ImageUsageFlag.COLOR_ATTACHMENT },
        imageSharingMode      = vk.SharingMode.EXCLUSIVE if oneQueueFamily else vk.SharingMode.CONCURRENT,
        queueFamilyIndexCount = 0 if oneQueueFamily else 2,
        pQueueFamilyIndices   = nil if oneQueueFamily else raw_data([]u32{ graphicsContext^.queueFamilies.graphicsFamily, graphicsContext^.queueFamilies.graphicsFamily }),
        preTransform          = swapchainSupport.capabilities.currentTransform,
        compositeAlpha        = { vk.CompositeAlphaFlagKHR.OPAQUE },
        presentMode           = graphicsContext^.swapchainMode,
        clipped               = true,
        oldSwapchain          = {}
    }

    if vk.CreateSwapchainKHR(graphicsContext^.device, &createInfo, nil, &graphicsContext^.swapchain) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to create swapchain!")
        panic("Failed to create swapchain!")
    }

    vk.GetSwapchainImagesKHR(graphicsContext^.device, graphicsContext^.swapchain, &imageCount, nil);
    graphicsContext^.swapchainImages = make([]vk.Image, imageCount)
    vk.GetSwapchainImagesKHR(graphicsContext^.device, graphicsContext^.swapchain, &imageCount, raw_data(graphicsContext^.swapchainImages));
}

@(private="file")
createImageViews :: proc(graphicsContext : ^GraphicsContext) {
    graphicsContext^.swapchainImageViews = make([]vk.ImageView, len(graphicsContext^.swapchainImages))
    for index in 0..<len(graphicsContext^.swapchainImages) {
        createInfo : vk.ImageViewCreateInfo = {
            sType            = vk.StructureType.IMAGE_VIEW_CREATE_INFO,
            pNext            = nil,
            flags            = {},
            image            = graphicsContext^.swapchainImages[index],
            viewType         = vk.ImageViewType.D2,
            format           = graphicsContext^.swapchainFormat.format,
            components       = { 
                r = vk.ComponentSwizzle.IDENTITY,
                g = vk.ComponentSwizzle.IDENTITY,
                b = vk.ComponentSwizzle.IDENTITY, 
                a = vk.ComponentSwizzle.IDENTITY 
            },
            subresourceRange = {
                aspectMask     = { vk.ImageAspectFlag.COLOR },
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1,
            },
        }
        if vk.CreateImageView(graphicsContext^.device, &createInfo, nil, &graphicsContext^.swapchainImageViews[index]) != vk.Result.SUCCESS {
            log(.ERROR, "Failed to create image view {}", index)
            panic("Failed to create image view")
        }
    }
}

@(private="file")
createPipeline :: proc(graphicsContext : ^GraphicsContext) {
    createShaderModules :: proc(graphicsContext : ^GraphicsContext, filenames : []string) -> (shaderModules : []vk.ShaderModule, count : u32 = 0) {
        loadShaderFile :: proc(filepath : string) -> (data : []byte) {
            fileHandle : os.Handle
            err : os.Errno
            if fileHandle, err = os.open(filepath, mode=(os.O_RDONLY|os.O_APPEND)); err != 0 {
            log(.ERROR, "Shader file couldn't be opened!")
            panic("Shader file couldn't be opened!")
            }
            defer os.close(fileHandle)
            success : bool
            if data, success = os.read_entire_file_from_handle(fileHandle); !success {
                log(.ERROR, "Shader file couldn't be read!")
                panic("Shader file couldn't be read!")
            }
            return
        }
        shaderModules = make([]vk.ShaderModule, len(filenames))
        for filename, index in filenames {
            code := loadShaderFile(filename)
            createInfo : vk.ShaderModuleCreateInfo = {
                sType = vk.StructureType.SHADER_MODULE_CREATE_INFO,
                pNext = nil,
                flags = {},
                codeSize = len(code),
                pCode = (^u32)(raw_data(code)),
            }
            if vk.CreateShaderModule(graphicsContext^.device, &createInfo, nil, &shaderModules[index]) != vk.Result.SUCCESS {
                log(.ERROR, "Failed to create shader module")
                panic("Failed to create shader module")
            }
            count += 1
        }
        return
    }
    shaderModules, shaderModulesCount := createShaderModules(graphicsContext, shaderFiles)
    defer for shaderModule in shaderModules {
        vk.DestroyShaderModule(graphicsContext^.device, shaderModule, nil)
    }

    shaderStagesInfo := make([]vk.PipelineShaderStageCreateInfo, shaderModulesCount)
    for index in 0..<shaderModulesCount {
        shaderStageInfo : vk.PipelineShaderStageCreateInfo = {
            sType = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext = nil,
            flags = {},
            stage = { shaderStages[index] },
            module = shaderModules[index],
            pName = "main",
            pSpecializationInfo = nil
        }
        shaderStagesInfo[index] = shaderStageInfo
    }
}

clanupVkGraphics :: proc(graphicsContext : ^GraphicsContext) {
    for index in 0..<len(graphicsContext^.swapchainImageViews) {
        vk.DestroyImageView(graphicsContext^.device, graphicsContext^.swapchainImageViews[index], nil)
    }
    vk.DestroySwapchainKHR(graphicsContext^.device, graphicsContext^.swapchain, nil);
    vk.DestroyDevice(graphicsContext^.device, nil)
    when ODIN_DEBUG {
        vk.DestroyDebugUtilsMessengerEXT(graphicsContext^.instance, graphicsContext^.debugMessenger, nil)
    }
    vk.DestroySurfaceKHR(graphicsContext^.instance, graphicsContext^.surface, nil)
    vk.DestroyInstance(graphicsContext^.instance, nil)
}