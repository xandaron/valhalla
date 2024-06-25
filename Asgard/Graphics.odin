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
shaderStages : []vk.ShaderStageFlag = { vk.ShaderStageFlag.VERTEX, vk.ShaderStageFlag.FRAGMENT, /*vk.ShaderStageFlag.COMPUTE,*/ }

@(private="file")
shaderFiles : []string = { "./assets/shaders/test_vert.spv", "./assets/shaders/test_frag.spv", /*"./assets/shaders/comp.spv",*/ }

@(private="file")
triangleVertices : [3]Vector2 : {
    { 0.0, -0.5 },
    { 0.5, 0.5 },
    { -0.5, 0.5 },
} 

@(private="file")
PipelineType :: enum {
    STANDARD,
    COUNT,
}

// Data structs
@(private="file")
QueueFamilyIndices :: struct {
    graphicsFamily : u32,
    presentFamily  : u32,
}

@(private="file")
SwapchainSupportDetails :: struct {
    capabilities : vk.SurfaceCapabilitiesKHR,
    formats      : []vk.SurfaceFormatKHR,
    modes        : []vk.PresentModeKHR,
}

GraphicsContext :: struct {
    window                : glfw.WindowHandle,
    instance              : vk.Instance,
    debugMessenger        : vk.DebugUtilsMessengerEXT,
    surface               : vk.SurfaceKHR,
    physicalDevice        : vk.PhysicalDevice,
    device                : vk.Device,
    queueFamilies         : QueueFamilyIndices,
    graphicsQueue         : vk.Queue,
    presentQueue          : vk.Queue,
    swapchain             : vk.SwapchainKHR,
    swapchainFormat       : vk.SurfaceFormatKHR,
    swapchainMode         : vk.PresentModeKHR,
    swapchainExtent       : vk.Extent2D,
    swapchainImages       : []vk.Image,
    swapchainImageViews   : []vk.ImageView,
    swapchainFrameBuffers : []vk.Framebuffer,
    pipelines             : []vk.Pipeline,
    pipelineLayouts       : []vk.PipelineLayout,
    renderPasses          : []vk.RenderPass,
    commandPool           : vk.CommandPool,
    commandBuffer         : vk.CommandBuffer,
    imageAvailable        : vk.Semaphore,
    renderFinished        : vk.Semaphore,
    inFlightFrame         : vk.Fence, 
}

// Methods
initVkGraphics :: proc(graphicsContext : ^GraphicsContext) {
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
    createRenderPass(graphicsContext)
    createPipeline(graphicsContext)
    createFramebuffers(graphicsContext)
    createCommandPool(graphicsContext)
    createCommandBuffer(graphicsContext)
    createSyncObjects(graphicsContext)
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
createRenderPass :: proc(graphicsContext : ^GraphicsContext) {
    colourAttachment : vk.AttachmentDescription = {
        flags          = {},
        format         = graphicsContext^.swapchainFormat.format,
        samples        = { vk.SampleCountFlag._1 },
        loadOp         = vk.AttachmentLoadOp.CLEAR,
        storeOp        = vk.AttachmentStoreOp.STORE,
        stencilLoadOp  = vk.AttachmentLoadOp.DONT_CARE,
        stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
        initialLayout  = vk.ImageLayout.UNDEFINED,
        finalLayout    = vk.ImageLayout.PRESENT_SRC_KHR,
    }

    colourAttachmentRef : vk.AttachmentReference = {
        attachment = 0,
        layout     = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
    }

    subpass : vk.SubpassDescription = {
        flags                   = {},
        pipelineBindPoint       = vk.PipelineBindPoint.GRAPHICS,
        inputAttachmentCount    = 0,
        pInputAttachments       = nil,
        colorAttachmentCount    = 1,
        pColorAttachments       = &colourAttachmentRef,
        pResolveAttachments     = nil,
        pDepthStencilAttachment = nil,
        preserveAttachmentCount = 0,
        pPreserveAttachments    = nil,
    }

    renderPassInfo : vk.RenderPassCreateInfo = {
        sType           = vk.StructureType.RENDER_PASS_CREATE_INFO,
        pNext           = nil,
        flags           = {},
        attachmentCount = 1,
        pAttachments    = &colourAttachment,
        subpassCount    = 1,
        pSubpasses      = &subpass,
        dependencyCount = 1,
        pDependencies   = raw_data([]vk.SubpassDependency{ {
                srcSubpass      = vk.SUBPASS_EXTERNAL,
                dstSubpass      = 0,
                srcStageMask    = { vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT },
                dstStageMask    = { vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT },
                srcAccessMask   = {},
                dstAccessMask   = { vk.AccessFlag.COLOR_ATTACHMENT_WRITE },
                dependencyFlags = {},
        }, } ),
    }

    graphicsContext^.renderPasses = make([]vk.RenderPass, PipelineType.COUNT)
    if vk.CreateRenderPass(graphicsContext^.device, &renderPassInfo, nil, &graphicsContext^.renderPasses[0]) != vk.Result.SUCCESS {
        log(.ERROR, "Unable to create render pass!")
        panic("Unable to create render pass!")
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
                sType    = vk.StructureType.SHADER_MODULE_CREATE_INFO,
                pNext    = nil,
                flags    = {},
                codeSize = len(code),
                pCode    = (^u32)(raw_data(code)),
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
            sType               = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext               = nil,
            flags               = {},
            stage               = { shaderStages[index] },
            module              = shaderModules[index],
            pName               = "main",
            pSpecializationInfo = nil
        }
        shaderStagesInfo[index] = shaderStageInfo
    }

    dynamicStates : []vk.DynamicState = { vk.DynamicState.VIEWPORT, vk.DynamicState.SCISSOR }
    dynamicStateInfo : vk.PipelineDynamicStateCreateInfo = {
        sType             = vk.StructureType.PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        pNext             = nil,
        flags             = {},
        dynamicStateCount = (u32)(len(dynamicStates)),
        pDynamicStates    = raw_data(dynamicStates)
    }

    vertexInputInfo : vk.PipelineVertexInputStateCreateInfo = {
        sType                           = vk.StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        pNext                           = nil,
        flags                           = {},
        vertexBindingDescriptionCount   = 0,
        pVertexBindingDescriptions      = nil,
        vertexAttributeDescriptionCount = 0,
        pVertexAttributeDescriptions    = nil,
    }

    inputAssembly : vk.PipelineInputAssemblyStateCreateInfo = {
        sType                  = vk.StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        pNext                  = nil,
        flags                  = {},
        topology               = vk.PrimitiveTopology.TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    viewportState : vk.PipelineViewportStateCreateInfo = {
        sType         = vk.StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        pNext         = nil,
        flags         = {},
        viewportCount = 1,
        pViewports    = nil,
        scissorCount  = 1,
        pScissors     = nil,
    }

    rasterizer : vk.PipelineRasterizationStateCreateInfo = {
        sType                   = vk.StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        pNext                   = nil,
        flags                   = {},
        depthClampEnable        = false,
        rasterizerDiscardEnable = false,
        polygonMode             = vk.PolygonMode.FILL,
        cullMode                = { vk.CullModeFlag.BACK },
        frontFace               = vk.FrontFace.CLOCKWISE,
        depthBiasEnable         = false,
        depthBiasConstantFactor = 0.0,
        depthBiasClamp          = 0.0,
        depthBiasSlopeFactor    = 0.0,
        lineWidth               = 1.0,
    }

    multisampling : vk.PipelineMultisampleStateCreateInfo = {
        sType                 = vk.StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        pNext                 = nil,
        flags                 = {},
        rasterizationSamples  = { vk.SampleCountFlag._1 },
        sampleShadingEnable   = false,
        minSampleShading      = 1.0,
        pSampleMask           = nil,
        alphaToCoverageEnable = false,
        alphaToOneEnable      = false,
    }

    depthStencil : vk.PipelineDepthStencilStateCreateInfo

    colourBlendAttachment : vk.PipelineColorBlendAttachmentState = {
        blendEnable         = false,
        srcColorBlendFactor = vk.BlendFactor.ONE,
        dstColorBlendFactor = vk.BlendFactor.ZERO,
        colorBlendOp        = vk.BlendOp.ADD,
        srcAlphaBlendFactor = vk.BlendFactor.ONE,
        dstAlphaBlendFactor = vk.BlendFactor.ZERO,
        alphaBlendOp        = vk.BlendOp.ADD,
        colorWriteMask      = { vk.ColorComponentFlag.R, vk.ColorComponentFlag.G, vk.ColorComponentFlag.B, vk.ColorComponentFlag.A },
    }

    colourBlending : vk.PipelineColorBlendStateCreateInfo = {
        sType           = vk.StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        pNext           = nil,
        flags           = {},
        logicOpEnable   = false,
        logicOp         = vk.LogicOp.COPY,
        attachmentCount = 1,
        pAttachments    = &colourBlendAttachment,
        blendConstants  = { 0, 0, 0, 0 },
    }

    PipelineLayoutInfo : vk.PipelineLayoutCreateInfo = {
        sType                  = vk.StructureType.PIPELINE_LAYOUT_CREATE_INFO,
        pNext                  = nil,
        flags                  = {},
        setLayoutCount         = 0,
        pSetLayouts            = nil,
        pushConstantRangeCount = 0,
        pPushConstantRanges    = nil,
    }

    graphicsContext^.pipelineLayouts = make([]vk.PipelineLayout, PipelineType.COUNT)
    if vk.CreatePipelineLayout(graphicsContext^.device, &PipelineLayoutInfo, nil, &graphicsContext^.pipelineLayouts[0]) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to create pipeline layout!")
        panic("Failed to create pipeline layout!")
    }

    pipelineInfo : vk.GraphicsPipelineCreateInfo = {
        sType               = vk.StructureType.GRAPHICS_PIPELINE_CREATE_INFO,
        pNext               = nil,
        flags               = {},
        stageCount          = (u32)(len(shaderStages)),
        pStages             = raw_data(shaderStagesInfo),
        pVertexInputState   = &vertexInputInfo,
        pInputAssemblyState = &inputAssembly,
        pTessellationState  = nil,
        pViewportState      = &viewportState,
        pRasterizationState = &rasterizer,
        pMultisampleState   = &multisampling,
        pDepthStencilState  = nil,
        pColorBlendState    = &colourBlending,
        pDynamicState       = &dynamicStateInfo,
        layout              = graphicsContext^.pipelineLayouts[0],
        renderPass          = graphicsContext^.renderPasses[0],
        subpass             = 0,
        basePipelineHandle  = {},
        basePipelineIndex   = -1,
    }

    graphicsContext^.pipelines = make([]vk.Pipeline, PipelineType.COUNT)
    if vk.CreateGraphicsPipelines(graphicsContext^.device, {}, 1, &pipelineInfo, nil, raw_data(graphicsContext^.pipelines)) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to create pipeline!")
        panic("Failed to create pipeline!")
    }
}

@(private="file")
createFramebuffers :: proc(graphicsContext : ^GraphicsContext) {
    imageViewCount : u32 = (u32)(len(graphicsContext^.swapchainImageViews))
    graphicsContext^.swapchainFrameBuffers = make([]vk.Framebuffer, imageViewCount)
    for index in 0..<imageViewCount {
        frameBufferInfo : vk.FramebufferCreateInfo = {
            sType           = vk.StructureType.FRAMEBUFFER_CREATE_INFO,
            pNext           = nil,
            flags           = {},
            renderPass      = graphicsContext^.renderPasses[0],
            attachmentCount = 1,
            pAttachments    = raw_data([]vk.ImageView{ graphicsContext^.swapchainImageViews[index] }),
            width           = graphicsContext^.swapchainExtent.width,
            height          = graphicsContext^.swapchainExtent.height,
            layers          = 1,
        }
        if vk.CreateFramebuffer(graphicsContext^.device, &frameBufferInfo, nil, &graphicsContext^.swapchainFrameBuffers[index]) != vk.Result.SUCCESS {
            log(.ERROR, "Failed to create frame buffer!")
            panic("Failed to create frame buffer!")
        }
    }
}

@(private="file")
createCommandPool :: proc(graphicsContext : ^GraphicsContext) {
    poolInfo : vk.CommandPoolCreateInfo = {
        sType            = vk.StructureType.COMMAND_POOL_CREATE_INFO,
        pNext            = nil,
        flags            = { vk.CommandPoolCreateFlag.RESET_COMMAND_BUFFER },
        queueFamilyIndex = graphicsContext^.queueFamilies.graphicsFamily,
    }
    if vk.CreateCommandPool(graphicsContext^.device, &poolInfo, nil, &graphicsContext^.commandPool) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to create command pool!")
        panic("Failed to create command pool!")
    }
}

@(private="file")
createCommandBuffer :: proc(graphicsContext : ^GraphicsContext) {
    allocInfo : vk.CommandBufferAllocateInfo = {
        sType              = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO,
        pNext              = nil,
        commandPool        = graphicsContext^.commandPool,
        level              = vk.CommandBufferLevel.PRIMARY,
        commandBufferCount = 1,
    }
    if vk.AllocateCommandBuffers(graphicsContext^.device, &allocInfo, &graphicsContext^.commandBuffer) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to allocate command buffer!")
        panic("Failed to allocate command buffer!")
    }
}

@(private="file")
createSyncObjects :: proc(graphicsContext : ^GraphicsContext) {
    semaphoreInfo : vk.SemaphoreCreateInfo = {
        sType = vk.StructureType.SEMAPHORE_CREATE_INFO,
        pNext = nil,
        flags = {},
    }
    fenceInfo : vk.FenceCreateInfo = {
        sType = vk.StructureType.FENCE_CREATE_INFO,
        pNext = nil,
        flags = { vk.FenceCreateFlag.SIGNALED },
    }

    if ((vk.CreateSemaphore(graphicsContext^.device, &semaphoreInfo, nil, &graphicsContext^.imageAvailable) 
    | vk.CreateSemaphore(graphicsContext^.device, &semaphoreInfo, nil, &graphicsContext^.renderFinished) 
    | vk.CreateFence(graphicsContext^.device, &fenceInfo, nil, &graphicsContext^.inFlightFrame)) != vk.Result.SUCCESS)  {
        log(.ERROR, "Failed to create sync objects!")
        panic("Failed to create sync objects!")
    }
}

drawFrame :: proc(graphicsContext : ^GraphicsContext) {
    vk.WaitForFences(graphicsContext^.device, 1, &graphicsContext^.inFlightFrame, true, max(u64))
    vk.ResetFences(graphicsContext^.device, 1, &graphicsContext^.inFlightFrame)

    imageIndex : u32
    vk.AcquireNextImageKHR(graphicsContext^.device, graphicsContext^.swapchain, max(u64), graphicsContext^.imageAvailable, {}, &imageIndex)

    vk.ResetCommandBuffer(graphicsContext^.commandBuffer, {})
    recordCommandBuffer(graphicsContext, &graphicsContext^.commandBuffer, imageIndex)

    submitInfo : vk.SubmitInfo = {
        sType                = vk.StructureType.SUBMIT_INFO,
        pNext                = nil,
        waitSemaphoreCount   = 1,
        pWaitSemaphores      = raw_data([]vk.Semaphore{ graphicsContext^.imageAvailable }),
        pWaitDstStageMask    = raw_data([]vk.PipelineStageFlags{ { vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT } }),
        commandBufferCount   = 1,
        pCommandBuffers      = &graphicsContext^.commandBuffer,
        signalSemaphoreCount = 1,
        pSignalSemaphores    = raw_data([]vk.Semaphore{ graphicsContext^.renderFinished }),
    }

    if vk.QueueSubmit(graphicsContext^.graphicsQueue, 1, &submitInfo, graphicsContext^.inFlightFrame) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to submit draw command buffer!")
        panic("Failed to submit draw command buffer!")
    }

    presentInfo : vk.PresentInfoKHR = {
        sType              = vk.StructureType.PRESENT_INFO_KHR,
        pNext              = nil,
        waitSemaphoreCount = 1,
        pWaitSemaphores    = raw_data([]vk.Semaphore{ graphicsContext^.renderFinished }),
        swapchainCount     = 1,
        pSwapchains        = raw_data([]vk.SwapchainKHR{ graphicsContext^.swapchain }),
        pImageIndices      = &imageIndex,
        pResults           = nil,
    }

    vk.QueuePresentKHR(graphicsContext^.presentQueue, &presentInfo)
}

@(private="file")
recordCommandBuffer :: proc(graphicsContext : ^GraphicsContext, commandBuffer : ^vk.CommandBuffer, imageIndex : u32) {
    beginInfo : vk.CommandBufferBeginInfo = {
        sType            = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO,
        pNext            = nil,
        flags            = {},
        pInheritanceInfo = nil,
    }
    if vk.BeginCommandBuffer(commandBuffer^, &beginInfo) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to being recording command buffer!")
        panic("Failed to being recording command buffer!")
    }

    renderPassInfo : vk.RenderPassBeginInfo = {
        sType           = vk.StructureType.RENDER_PASS_BEGIN_INFO,
        pNext           = nil,
        renderPass      = graphicsContext^.renderPasses[0],
        framebuffer     = graphicsContext^.swapchainFrameBuffers[imageIndex],
        renderArea      = vk.Rect2D{
            offset = {0, 0},
	        extent = graphicsContext^.swapchainExtent,
        },
        clearValueCount = 1,
        pClearValues    = &vk.ClearValue{
            color        = vk.ClearColorValue{
                float32 = { 0, 0, 0, 1 },
            },
        },
    }
    vk.CmdBeginRenderPass(commandBuffer^, &renderPassInfo, vk.SubpassContents.INLINE)
    vk.CmdBindPipeline(commandBuffer^, vk.PipelineBindPoint.GRAPHICS, graphicsContext.pipelines[0])

    viewport : vk.Viewport = {
        x        = 0,
        y        = 0,
        width    = (f32)(graphicsContext^.swapchainExtent.width),
        height   = (f32)(graphicsContext^.swapchainExtent.height),
        minDepth = 0,
        maxDepth = 1,
    }
    vk.CmdSetViewport(commandBuffer^, 0, 1, &viewport)

    scissor : vk.Rect2D = {
        offset = { 0, 0 },
        extent = graphicsContext^.swapchainExtent,
    }
    vk.CmdSetScissor(commandBuffer^, 0, 1, &scissor)

    vk.CmdDraw(commandBuffer^, 3, 1, 0, 0)

    vk.CmdEndRenderPass(commandBuffer^)
    if vk.EndCommandBuffer(commandBuffer^) != vk.Result.SUCCESS {
        log(.ERROR, "Failed to record command buffer!")
        panic("Failed to record command buffer!")
    }
}

clanupVkGraphics :: proc(graphicsContext : ^GraphicsContext) {
    vk.DeviceWaitIdle(graphicsContext^.device)
    vk.DestroySemaphore(graphicsContext^.device, graphicsContext^.imageAvailable, nil)
    vk.DestroySemaphore(graphicsContext^.device, graphicsContext^.renderFinished, nil)
    vk.DestroyFence(graphicsContext^.device, graphicsContext^.inFlightFrame, nil)
    vk.DestroyCommandPool(graphicsContext^.device, graphicsContext^.commandPool, nil)
    for frameBuffer in graphicsContext^.swapchainFrameBuffers {
        vk.DestroyFramebuffer(graphicsContext^.device, frameBuffer, nil)
    }
    for index in 0..<len(graphicsContext^.pipelines) {
        vk.DestroyPipeline(graphicsContext^.device, graphicsContext^.pipelines[index], nil)
        vk.DestroyPipelineLayout(graphicsContext^.device, graphicsContext^.pipelineLayouts[index], nil)
        vk.DestroyRenderPass(graphicsContext^.device, graphicsContext^.renderPasses[0], nil)
    }
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
