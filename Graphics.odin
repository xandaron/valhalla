package Valhalla

import "core:c"
import "core:os"
import "core:mem"
import "core:fmt"
import t "core:time"

import "vendor:glfw"
import vk "vendor:vulkan"
import im "vendor:stb/image"

import fbx "ufbx"

// Data structs
@(private="file")
Vertex :: struct {
    position : Vec3,
    texCoord : Vec2,
}

@(private="file")
Bone :: struct {
    name      : string,
    parent    : ^Bone,
    transform : Mat4
}

@(private="file")
Model :: struct {
    id       : u32,
    vertices : []Vertex,
    indices  : []u32,
    bones    : []Bone,
}

@(private="file")
PipelineType :: enum {
    STANDARD,
    COUNT,
}

@(private="file")
UniformBufferObject :: struct #align(16) {
    model      : Mat4,
    view       : Mat4,
    projection : Mat4,
}

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

Camera :: struct {
    eye, center, up : Vec3,
    distance : f32,
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
    descriptorSetLayout   : vk.DescriptorSetLayout,
    pipelineLayouts       : []vk.PipelineLayout,
    renderPasses          : []vk.RenderPass,

    commandPool           : vk.CommandPool,
    commandBuffers        : []vk.CommandBuffer,

    imagesAvailable       : []vk.Semaphore,
    rendersFinished       : []vk.Semaphore,
    inFlightFrames        : []vk.Fence,

    currentFrame          : u32,
    framebufferResized    : b8,

    //To-Do: All buffers should be combined into a singular buffer using offsets
    vertices              : []Vertex,
    vertexBuffer          : vk.Buffer,
    vertexBufferMemory    : vk.DeviceMemory,
    indices               : []u32,
    indexBuffer           : vk.Buffer,
    indexBufferMemory     : vk.DeviceMemory,

    //Not including these ones
    uniformBuffers        : [MAX_FRAMES_IN_FLIGHT]vk.Buffer,
    uniformBuffersMemory  : [MAX_FRAMES_IN_FLIGHT]vk.DeviceMemory,
    uniformBuffersMapped  : [MAX_FRAMES_IN_FLIGHT]rawptr,
    descriptorPool        : vk.DescriptorPool,
    descriptorSets        : []vk.DescriptorSet,

    mipLevels             : u32,
    texture               : vk.Image,
    textureMemory         : vk.DeviceMemory,
    textureView           : vk.ImageView,
    textureSampler        : vk.Sampler,

    depthImage            : vk.Image,
    depthImageMemory      : vk.DeviceMemory,
    depthImageView        : vk.ImageView,
    depthFormat           : vk.Format,

    msaaSamples           : vk.SampleCountFlags,
    colourImage           : vk.Image,
    colourImageMemory     : vk.DeviceMemory,
    colourImageView       : vk.ImageView,
}

// Consts
@(private="file")
ENGINE_VERSION : u32 : (0<<22) | (0<<12) | (1)

@(private="file")
requestedLayers : []cstring = { "VK_LAYER_KHRONOS_validation" }

@(private="file")
requiredDeviceExtensions : []cstring = { vk.KHR_SWAPCHAIN_EXTENSION_NAME }

@(private="file")
shaderStages : []vk.ShaderStageFlag = { .VERTEX, .FRAGMENT, /*.COMPUTE,*/ }

@(private="file")
shaderFiles : []string = { "./assets/shaders/test_vert.spv", "./assets/shaders/test_frag.spv", /*"./assets/shaders/comp.spv",*/ }

@(private="file")
MAX_FRAMES_IN_FLIGHT : u32 : 2

@(private="file")
vertexBindingDescription : vk.VertexInputBindingDescription = {
	binding   = 0,
	stride    = size_of(Vertex),
	inputRate = .VERTEX,
}

@(private="file")
vertexInputAttributeDescriptions : []vk.VertexInputAttributeDescription = {
    {
        location = 0,
        binding  = 0,
        format   = .R32G32B32_SFLOAT,
        offset   = u32(offset_of(Vertex, position)),
    },
    {
        location = 1,
        binding  = 0,
        format   = .R32G32_SFLOAT,
        offset   = u32(offset_of(Vertex, texCoord)),
    },
}

@(private="file")
MODEL_PATH : cstring : "./assets/models/claudia.fbx"

@(private="file")
TEXTURE_PATH : cstring : "./assets/textures/claudia.jpg"


// Methods
initVkGraphics :: proc(graphicsContext : ^GraphicsContext) {
    // load_proc_addresses_global :: proc(vk_get_instance_proc_addr: rawptr)
    vk.load_proc_addresses(rawptr(glfw.GetInstanceProcAddress));

    graphicsContext^.framebufferResized = false
    graphicsContext^.currentFrame = 0
    graphicsContext^.msaaSamples = { ._1 }

    createInstance(graphicsContext)
    when ODIN_DEBUG {
        vkSetupDebugMessenger(graphicsContext)
    }
    createSurface(graphicsContext)
    pickPhysicalDevice(graphicsContext)
    createLogicalDevice(graphicsContext)

    createSwapchain(graphicsContext)
    createImageViews(graphicsContext)

    createCommandPool(graphicsContext)

    createColourResources(graphicsContext)
    createDepthResources(graphicsContext)

    createTexture(graphicsContext)
    createTextureView(graphicsContext)
    createTextureSampler(graphicsContext)

    loadModel(graphicsContext)

    createVertexBuffer(graphicsContext)
    createIndexBuffer(graphicsContext)

    createUniformBuffer(graphicsContext)
    createDescriptorPool(graphicsContext)
    createDescriptionSetLayout(graphicsContext)
    createDescriptorSets(graphicsContext)

    createRenderPass(graphicsContext)
    createFramebuffers(graphicsContext)

    createPipeline(graphicsContext)

    createCommandBuffers(graphicsContext)
    createSyncObjects(graphicsContext)
}

@(private="file") 
createInstance :: proc(graphicsContext : ^GraphicsContext) {
    appInfo : vk.ApplicationInfo = {
        sType              = .APPLICATION_INFO,
        pNext              = nil,
        pApplicationName   = "Valhalla",
        applicationVersion = APP_VERSION,
        pEngineName        = "Asgardina Graphics",
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
        log(.ERROR, fmt.aprintf("Failed to find required extension: {}", name))
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
            log(.WARNING, fmt.aprintf("Failed to find requested extension: {}", name))
        }
    }

    instanceInfo : vk.InstanceCreateInfo = {
        sType                   = .INSTANCE_CREATE_INFO,
        pNext                   = nil,
        flags                   = nil,
        pApplicationInfo        = &appInfo,
        enabledLayerCount       = 0,
        ppEnabledLayerNames     = nil,
        enabledExtensionCount   = u32(len(supportedExtensions)),
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
            log(.WARNING, fmt.aprintf("Failed to find requested layer: {}", name))
        }
        instanceInfo.enabledLayerCount = u32(len(supportedLayers))
        instanceInfo.ppEnabledLayerNames = raw_data(supportedLayers)

        debugMessengerCreateInfo = vkPopulateDebugMessengerCreateInfo()
        instanceInfo.pNext = &debugMessengerCreateInfo
    }

    if vk.CreateInstance(&instanceInfo, nil, &graphicsContext^.instance) != .SUCCESS {
        log(.ERROR, "Failed to create vulkan instance.")
        panic("Failed to create vulkan instance.")
    }

    // load_proc_addresses_instance :: proc(instance: Instance)
    vk.load_proc_addresses(graphicsContext^.instance)
}

@(private="file")
createSurface :: proc(graphicsContext : ^GraphicsContext) {
    if glfw.CreateWindowSurface(graphicsContext^.instance, graphicsContext^.window, nil, &graphicsContext^.surface) != .SUCCESS {
        log(.ERROR, "Failed to create surface!")
        panic("Failed to create surface!")
    }
}

@(private="file")
querySwapchainSupport :: proc(physicalDevice : vk.PhysicalDevice, graphicsContext : ^GraphicsContext) -> (swapchainSupport : SwapchainSupportDetails) {
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, graphicsContext^.surface, &swapchainSupport.capabilities);
    
    formatCount : u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, graphicsContext^.surface, &formatCount, nil);
    if formatCount != 0 {
        swapchainSupport.formats = make([]vk.SurfaceFormatKHR, formatCount);
        vk.GetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, graphicsContext^.surface, &formatCount, raw_data(swapchainSupport.formats));
    }
    
    modeCount : u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, graphicsContext^.surface, &modeCount, nil);
    if modeCount != 0 {
        swapchainSupport.modes = make([]vk.PresentModeKHR, modeCount);
        vk.GetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, graphicsContext^.surface, &modeCount, raw_data(swapchainSupport.modes));
    }
    return
}

@(private="file")
findQueueFamilies :: proc(physicalDevice : vk.PhysicalDevice, graphicsContext : ^GraphicsContext) -> (indices : QueueFamilyIndices, err : b32 = false) {
    queueFamilyCount : u32
    vk.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, nil)
    queueFamilies := make([]vk.QueueFamilyProperties, queueFamilyCount)
    vk.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, raw_data(queueFamilies))

    foundPresentFamily := false
    foundGraphicsFamily := false
    for queueFamily, index in queueFamilies {
        if .GRAPHICS in queueFamily.queueFlags {
            indices.graphicsFamily = u32(index)
            foundGraphicsFamily = true
        }

        presentSupport : b32
        if vk.GetPhysicalDeviceSurfaceSupportKHR(physicalDevice, (u32)(index), graphicsContext^.surface, &presentSupport); presentSupport {
            indices.presentFamily = u32(index)
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
    scorePhysicalDevice :: proc(physicalDevice : vk.PhysicalDevice, graphicsContext : ^GraphicsContext) -> (score : u32 = 0) {
        physicalDeviceProperties : vk.PhysicalDeviceProperties
        physicalDeviceFeatures : vk.PhysicalDeviceFeatures
        
        vk.GetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties)
        vk.GetPhysicalDeviceFeatures(physicalDevice, &physicalDeviceFeatures)

        indices, err := findQueueFamilies(physicalDevice, graphicsContext)
        if err || !physicalDeviceFeatures.geometryShader || !physicalDeviceFeatures.samplerAnisotropy ||
            !checkDeviceExtensionSupport(physicalDevice) || !swapchainAdequate(physicalDevice, graphicsContext)
        {
            return
        }

        if physicalDeviceProperties.deviceType == .DISCRETE_GPU {
            score += 1000
        }

        if (indices.graphicsFamily == indices.presentFamily) {
            score += 100
        }

        score += physicalDeviceProperties.limits.maxImageDimension2D
        return
    }

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

    getMaxUsableSampleCount :: proc(physicalDevice : vk.PhysicalDevice) -> vk.SampleCountFlags {
        physicalDeviceProperties : vk.PhysicalDeviceProperties
        vk.GetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties)

        counts := physicalDeviceProperties.limits.framebufferColorSampleCounts & physicalDeviceProperties.limits.framebufferDepthSampleCounts
        if ._64 in counts do return { ._64 }
        if ._32 in counts do return { ._32 }
        if ._16 in counts do return { ._16 }
        if ._8 in counts do return { ._8 }
        if ._4 in counts do return { ._4 }
        if ._2 in counts do return { ._2 }
        return { ._1 }
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

    if graphicsContext^.physicalDevice == nil {
        log(.ERROR, "No suitable physical device found!")
        panic("No suitable physical device found!")
    }
    graphicsContext^.msaaSamples = getMaxUsableSampleCount(graphicsContext^.physicalDevice)
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

    if graphicsContext^.queueFamilies.graphicsFamily != graphicsContext^.queueFamilies.presentFamily {
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

    deviceFeatures : vk.PhysicalDeviceFeatures = {
        robustBufferAccess                      = false,
        fullDrawIndexUint32                     = false,
        imageCubeArray                          = false,
        independentBlend                        = false,
        geometryShader                          = false,
        tessellationShader                      = false,
        sampleRateShading                       = false,
        dualSrcBlend                            = false,
        logicOp                                 = false,
        multiDrawIndirect                       = false,
        drawIndirectFirstInstance               = false,
        depthClamp                              = false,
        depthBiasClamp                          = false,
        fillModeNonSolid                        = false,
        depthBounds                             = false,
        wideLines                               = false,
        largePoints                             = false,
        alphaToOne                              = false,
        multiViewport                           = false,
        samplerAnisotropy                       = true,
        textureCompressionETC2                  = false,
        textureCompressionASTC_LDR              = false,
        textureCompressionBC                    = false,
        occlusionQueryPrecise                   = false,
        pipelineStatisticsQuery                 = false,
        vertexPipelineStoresAndAtomics          = false,
        fragmentStoresAndAtomics                = false,
        shaderTessellationAndGeometryPointSize  = false,
        shaderImageGatherExtended               = false,
        shaderStorageImageExtendedFormats       = false,
        shaderStorageImageMultisample           = false,
        shaderStorageImageReadWithoutFormat     = false,
        shaderStorageImageWriteWithoutFormat    = false,
        shaderUniformBufferArrayDynamicIndexing = false,
        shaderSampledImageArrayDynamicIndexing  = false,
        shaderStorageBufferArrayDynamicIndexing = false,
        shaderStorageImageArrayDynamicIndexing  = false,
        shaderClipDistance                      = false,
        shaderCullDistance                      = false,
        shaderFloat64                           = false,
        shaderInt64                             = false,
        shaderInt16                             = false,
        shaderResourceResidency                 = false,
        shaderResourceMinLod                    = false,
        sparseBinding                           = false,
        sparseResidencyBuffer                   = false,
        sparseResidencyImage2D                  = false,
        sparseResidencyImage3D                  = false,
        sparseResidency2Samples                 = false,
        sparseResidency4Samples                 = false,
        sparseResidency8Samples                 = false,
        sparseResidency16Samples                = false,
        sparseResidencyAliased                  = false,
        variableMultisampleRate                 = false,
        inheritedQueries                        = false,
    }

    createInfo : vk.DeviceCreateInfo = {
        sType                   = .DEVICE_CREATE_INFO,
        pNext                   = nil,
        flags                   = {},
        queueCreateInfoCount    = u32(len(queueCreateInfos)),
        pQueueCreateInfos       = raw_data(queueCreateInfos[:]),
        enabledLayerCount       = 0,
        ppEnabledLayerNames     = nil,
        enabledExtensionCount   = u32(len(requiredDeviceExtensions)),
        ppEnabledExtensionNames = raw_data(requiredDeviceExtensions[:]),
        pEnabledFeatures        = &deviceFeatures
    }

    when ODIN_DEBUG {
        createInfo.enabledLayerCount = u32(len(requestedLayers))
        createInfo.ppEnabledLayerNames = raw_data(requestedLayers[:])
    }

    if vk.CreateDevice(graphicsContext^.physicalDevice, &createInfo, nil, &graphicsContext^.device) != .SUCCESS {
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
            if format.format == .R8G8B8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
                return format;
            }
        }
        return formats[0]
    }

    choosePresentMode :: proc(modes : []vk.PresentModeKHR) -> (mode : vk.PresentModeKHR) {
        for mode in modes {
            if mode == .MAILBOX {
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
        extent.width = clamp(u32(width), capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
        extent.height = clamp(u32(height), capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
        return
    }

    swapchainSupport := querySwapchainSupport(graphicsContext^.physicalDevice, graphicsContext)
    graphicsContext^.swapchainFormat = chooseFormat(swapchainSupport.formats)
    graphicsContext^.swapchainMode = choosePresentMode(swapchainSupport.modes)
    graphicsContext^.swapchainExtent = chooseExtent(swapchainSupport.capabilities, graphicsContext)

    ideal := swapchainSupport.capabilities.minImageCount + 1
    max := swapchainSupport.capabilities.maxImageCount
    imageCount := max if max > 0 && ideal > max else ideal
    
    oneQueueFamily := graphicsContext^.queueFamilies.graphicsFamily == graphicsContext^.queueFamilies.presentFamily
    createInfo : vk.SwapchainCreateInfoKHR = {
        sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
        pNext                 = nil,
        flags                 = {},
        surface               = graphicsContext^.surface,
        minImageCount         = imageCount,
        imageFormat           = graphicsContext^.swapchainFormat.format,
        imageColorSpace       = graphicsContext^.swapchainFormat.colorSpace,
        imageExtent           = graphicsContext^.swapchainExtent,
        imageArrayLayers      = 1,
        imageUsage            = { .COLOR_ATTACHMENT },
        imageSharingMode      = .EXCLUSIVE if oneQueueFamily else .CONCURRENT,
        queueFamilyIndexCount = 0 if oneQueueFamily else 2,
        pQueueFamilyIndices   = nil if oneQueueFamily else raw_data([]u32{ graphicsContext^.queueFamilies.graphicsFamily, graphicsContext^.queueFamilies.graphicsFamily }),
        preTransform          = swapchainSupport.capabilities.currentTransform,
        compositeAlpha        = { .OPAQUE },
        presentMode           = graphicsContext^.swapchainMode,
        clipped               = true,
        oldSwapchain          = {}
    }

    if vk.CreateSwapchainKHR(graphicsContext^.device, &createInfo, nil, &graphicsContext^.swapchain) != .SUCCESS {
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
        graphicsContext^.swapchainImageViews[index] = createImageView(
            graphicsContext, graphicsContext^.swapchainImages[index], graphicsContext^.swapchainFormat.format, { .COLOR }, 1
        )
    }
}

@(private="file")
createRenderPass :: proc(graphicsContext : ^GraphicsContext) {
    colourAttachment : vk.AttachmentDescription = {
        flags          = {},
        format         = graphicsContext^.swapchainFormat.format,
        samples        = graphicsContext^.msaaSamples,
        loadOp         = .CLEAR,
        storeOp        = .STORE,
        stencilLoadOp  = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout  = .UNDEFINED,
        finalLayout    = .COLOR_ATTACHMENT_OPTIMAL,
    }

    depthAttachment : vk.AttachmentDescription = {
        flags          = {},
        format         = graphicsContext^.depthFormat,
        samples        = graphicsContext^.msaaSamples,
        loadOp         = .CLEAR,
        storeOp        = .DONT_CARE,
        stencilLoadOp  = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout  = .UNDEFINED,
        finalLayout    = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    }

    colourAttachmentResolve : vk.AttachmentDescription = {
        flags          = {},
        format         = graphicsContext^.swapchainFormat.format,
        samples        = { ._1 },
        loadOp         = .DONT_CARE,
        storeOp        = .STORE,
        stencilLoadOp  = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout  = .UNDEFINED,
        finalLayout    = .PRESENT_SRC_KHR,
    }

    colourAttachmentRef : vk.AttachmentReference = {
        attachment = 0,
        layout     = .COLOR_ATTACHMENT_OPTIMAL,
    }

    depthAttachmentRef : vk.AttachmentReference  = {
        attachment = 1,
        layout     = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    }

    colourAttachmentResolveRef : vk.AttachmentReference = {
        attachment = 2,
        layout     = .COLOR_ATTACHMENT_OPTIMAL,
    }

    subpass : vk.SubpassDescription = {
        flags                   = {},
        pipelineBindPoint       = .GRAPHICS,
        inputAttachmentCount    = 0,
        pInputAttachments       = nil,
        colorAttachmentCount    = 1,
        pColorAttachments       = &colourAttachmentRef,
        pResolveAttachments     = &colourAttachmentResolveRef,
        pDepthStencilAttachment = &depthAttachmentRef,
        preserveAttachmentCount = 0,
        pPreserveAttachments    = nil,
    }

    renderPassInfo : vk.RenderPassCreateInfo = {
        sType           = .RENDER_PASS_CREATE_INFO,
        pNext           = nil,
        flags           = {},
        attachmentCount = 3,
        pAttachments    = raw_data([]vk.AttachmentDescription{ colourAttachment, depthAttachment, colourAttachmentResolve }),
        subpassCount    = 1,
        pSubpasses      = &subpass,
        dependencyCount = 1,
        pDependencies   = &vk.SubpassDependency{
            srcSubpass      = vk.SUBPASS_EXTERNAL,
            dstSubpass      = 0,
            srcStageMask    = { .COLOR_ATTACHMENT_OUTPUT, .LATE_FRAGMENT_TESTS },
            dstStageMask    = { .COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS },
            srcAccessMask   = { .COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE },
            dstAccessMask   = { .COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE },
            dependencyFlags = {},
        },
    }

    graphicsContext^.renderPasses = make([]vk.RenderPass, PipelineType.COUNT)
    if vk.CreateRenderPass(graphicsContext^.device, &renderPassInfo, nil, &graphicsContext^.renderPasses[0]) != .SUCCESS {
        log(.ERROR, "Unable to create render pass!")
        panic("Unable to create render pass!")
    }
}

@(private="file")
createDescriptionSetLayout :: proc(graphicsContext : ^GraphicsContext) {
    uboLayoutBinding : vk.DescriptorSetLayoutBinding = {
        binding            = 0,
        descriptorType     = .UNIFORM_BUFFER,
        descriptorCount    = 1,
        stageFlags         = { .VERTEX },
        pImmutableSamplers = nil,
    }
    samplerLayoutBinding : vk.DescriptorSetLayoutBinding = {
        binding            = 1,
        descriptorType     = .COMBINED_IMAGE_SAMPLER,
        descriptorCount    = 1,
        stageFlags         = { .FRAGMENT },
        pImmutableSamplers = nil,
    }
    layoutInfo : vk.DescriptorSetLayoutCreateInfo = {
        sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        pNext        = nil,
        flags        = {},
        bindingCount = 2,
        pBindings    = raw_data([]vk.DescriptorSetLayoutBinding{ uboLayoutBinding, samplerLayoutBinding }),
    }
    if vk.CreateDescriptorSetLayout(graphicsContext^.device, &layoutInfo, nil, &graphicsContext^.descriptorSetLayout) != .SUCCESS {
        log(.ERROR, "Failed to create descriptor set layout!")
        panic("Failed to create descriptor set layout!")
    }
}

@(private="file")
createPipeline :: proc(graphicsContext : ^GraphicsContext) {
    createShaderModules :: proc(graphicsContext : ^GraphicsContext, filenames : []string) -> (shaderModules : []vk.ShaderModule, count : u32 = 0) {
        loadShaderFile :: proc(filepath : string) -> (data : []byte) {
            fileHandle, err := os.open(filepath, mode=(os.O_RDONLY|os.O_APPEND))
            if err != 0 {
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
                sType    = .SHADER_MODULE_CREATE_INFO,
                pNext    = nil,
                flags    = {},
                codeSize = len(code),
                pCode    = (^u32)(raw_data(code)),
            }
            if vk.CreateShaderModule(graphicsContext^.device, &createInfo, nil, &shaderModules[index]) != .SUCCESS {
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
            sType               = .PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext               = nil,
            flags               = {},
            stage               = { shaderStages[index] },
            module              = shaderModules[index],
            pName               = "main",
            pSpecializationInfo = nil
        }
        shaderStagesInfo[index] = shaderStageInfo
    }

    dynamicStates : []vk.DynamicState = { .VIEWPORT, .SCISSOR }
    dynamicStateInfo : vk.PipelineDynamicStateCreateInfo = {
        sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        pNext             = nil,
        flags             = {},
        dynamicStateCount = u32(len(dynamicStates)),
        pDynamicStates    = raw_data(dynamicStates)
    }

    vertexInputInfo : vk.PipelineVertexInputStateCreateInfo = {
        sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        pNext                           = nil,
        flags                           = {},
        vertexBindingDescriptionCount   = 1,
        pVertexBindingDescriptions      = &vertexBindingDescription,
        vertexAttributeDescriptionCount = u32(len(vertexInputAttributeDescriptions)),
        pVertexAttributeDescriptions    = raw_data(vertexInputAttributeDescriptions),
    }

    inputAssembly : vk.PipelineInputAssemblyStateCreateInfo = {
        sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        pNext                  = nil,
        flags                  = {},
        topology               = .TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    viewportState : vk.PipelineViewportStateCreateInfo = {
        sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        pNext         = nil,
        flags         = {},
        viewportCount = 1,
        pViewports    = nil,
        scissorCount  = 1,
        pScissors     = nil,
    }

    rasterizer : vk.PipelineRasterizationStateCreateInfo = {
        sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        pNext                   = nil,
        flags                   = {},
        depthClampEnable        = false,
        rasterizerDiscardEnable = false,
        polygonMode             = .FILL,
        cullMode                = { .BACK },
        frontFace               = .COUNTER_CLOCKWISE,
        depthBiasEnable         = false,
        depthBiasConstantFactor = 0.0,
        depthBiasClamp          = 0.0,
        depthBiasSlopeFactor    = 0.0,
        lineWidth               = 1.0,
    }

    multisampling : vk.PipelineMultisampleStateCreateInfo = {
        sType                 = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        pNext                 = nil,
        flags                 = {},
        rasterizationSamples  = graphicsContext^.msaaSamples,
        sampleShadingEnable   = false,
        minSampleShading      = 1.0,
        pSampleMask           = nil,
        alphaToCoverageEnable = false,
        alphaToOneEnable      = false,
    }

    depthStencil : vk.PipelineDepthStencilStateCreateInfo = {
        sType                 = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        pNext                 = nil,
        flags                 = {},
        depthTestEnable       = true,
        depthWriteEnable      = true,
        depthCompareOp        = .LESS,
        depthBoundsTestEnable = false,
        stencilTestEnable     = false,
        front                 = {},
        back                  = {},
        minDepthBounds        = 0,
        maxDepthBounds        = 1,
    }

    colourBlendAttachment : vk.PipelineColorBlendAttachmentState = {
        blendEnable         = false,
        srcColorBlendFactor = .ONE,
        dstColorBlendFactor = .ZERO,
        colorBlendOp        = .ADD,
        srcAlphaBlendFactor = .ONE,
        dstAlphaBlendFactor = .ZERO,
        alphaBlendOp        = .ADD,
        colorWriteMask      = { .R, .G, .B, .A },
    }

    colourBlending : vk.PipelineColorBlendStateCreateInfo = {
        sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        pNext           = nil,
        flags           = {},
        logicOpEnable   = false,
        logicOp         = .COPY,
        attachmentCount = 1,
        pAttachments    = &colourBlendAttachment,
        blendConstants  = { 0, 0, 0, 0 },
    }

    PipelineLayoutInfo : vk.PipelineLayoutCreateInfo = {
        sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
        pNext                  = nil,
        flags                  = {},
        setLayoutCount         = 1,
        pSetLayouts            = &graphicsContext^.descriptorSetLayout,
        pushConstantRangeCount = 0,
        pPushConstantRanges    = nil,
    }

    graphicsContext^.pipelineLayouts = make([]vk.PipelineLayout, PipelineType.COUNT)
    if vk.CreatePipelineLayout(graphicsContext^.device, &PipelineLayoutInfo, nil, &graphicsContext^.pipelineLayouts[0]) != .SUCCESS {
        log(.ERROR, "Failed to create pipeline layout!")
        panic("Failed to create pipeline layout!")
    }

    pipelineInfo : vk.GraphicsPipelineCreateInfo = {
        sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
        pNext               = nil,
        flags               = {},
        stageCount          = u32(len(shaderStages)),
        pStages             = raw_data(shaderStagesInfo),
        pVertexInputState   = &vertexInputInfo,
        pInputAssemblyState = &inputAssembly,
        pTessellationState  = nil,
        pViewportState      = &viewportState,
        pRasterizationState = &rasterizer,
        pMultisampleState   = &multisampling,
        pDepthStencilState  = &depthStencil,
        pColorBlendState    = &colourBlending,
        pDynamicState       = &dynamicStateInfo,
        layout              = graphicsContext^.pipelineLayouts[0],
        renderPass          = graphicsContext^.renderPasses[0],
        subpass             = 0,
        basePipelineHandle  = {},
        basePipelineIndex   = -1,
    }

    graphicsContext^.pipelines = make([]vk.Pipeline, PipelineType.COUNT)
    if vk.CreateGraphicsPipelines(graphicsContext^.device, {}, 1, &pipelineInfo, nil, raw_data(graphicsContext^.pipelines)) != .SUCCESS {
        log(.ERROR, "Failed to create pipeline!")
        panic("Failed to create pipeline!")
    }
}

@(private="file")
createFramebuffers :: proc(graphicsContext : ^GraphicsContext) {
    imageViewCount := u32(len(graphicsContext^.swapchainImageViews))
    graphicsContext^.swapchainFrameBuffers = make([]vk.Framebuffer, imageViewCount)
    for index in 0..<imageViewCount {
        frameBufferInfo : vk.FramebufferCreateInfo = {
            sType           = .FRAMEBUFFER_CREATE_INFO,
            pNext           = nil,
            flags           = {},
            renderPass      = graphicsContext^.renderPasses[0],
            attachmentCount = 3,
            pAttachments    = raw_data([]vk.ImageView{ graphicsContext^.colourImageView, graphicsContext^.depthImageView, graphicsContext^.swapchainImageViews[index] }),
            width           = graphicsContext^.swapchainExtent.width,
            height          = graphicsContext^.swapchainExtent.height,
            layers          = 1,
        }
        if vk.CreateFramebuffer(graphicsContext^.device, &frameBufferInfo, nil, &graphicsContext^.swapchainFrameBuffers[index]) != .SUCCESS {
            log(.ERROR, "Failed to create frame buffer!")
            panic("Failed to create frame buffer!")
        }
    }
}

@(private="file")
createCommandPool :: proc(graphicsContext : ^GraphicsContext) {
    poolInfo : vk.CommandPoolCreateInfo = {
        sType            = .COMMAND_POOL_CREATE_INFO,
        pNext            = nil,
        flags            = { .RESET_COMMAND_BUFFER },
        queueFamilyIndex = graphicsContext^.queueFamilies.graphicsFamily,
    }
    if vk.CreateCommandPool(graphicsContext^.device, &poolInfo, nil, &graphicsContext^.commandPool) != .SUCCESS {
        log(.ERROR, "Failed to create command pool!")
        panic("Failed to create command pool!")
    }
}

@(private="file")
createColourResources :: proc(graphicsContext : ^GraphicsContext) {
    createImage(
        graphicsContext,
        graphicsContext^.swapchainExtent.width,
        graphicsContext^.swapchainExtent.height,
        1,
        graphicsContext^.msaaSamples,
        graphicsContext^.swapchainFormat.format,
        .OPTIMAL,
        { .TRANSIENT_ATTACHMENT, .COLOR_ATTACHMENT },
        { .DEVICE_LOCAL },
        &graphicsContext^.colourImage,
        &graphicsContext^.colourImageMemory,
    )
    graphicsContext^.colourImageView = createImageView(graphicsContext, graphicsContext^.colourImage, graphicsContext^.swapchainFormat.format, { .COLOR }, 1)
}

@(private="file")
createDepthResources :: proc(graphicsContext : ^GraphicsContext) {
    findSupportedFormat :: proc(graphicsContext : ^GraphicsContext, candidates : []vk.Format, tiling : vk.ImageTiling, features : vk.FormatFeatureFlags) -> vk.Format {
        for format in candidates {
            props : vk.FormatProperties
            vk.GetPhysicalDeviceFormatProperties(graphicsContext^.physicalDevice, format, &props)
            if tiling == .LINEAR && (props.linearTilingFeatures & features) == features {
                return format;
            } 
            else if tiling == .OPTIMAL && (props.optimalTilingFeatures & features) == features {
                return format;
            }
        }
        log(.ERROR, "Failed to find supported format!")
        panic("Failed to find supported format!")
    }

    hasStencilComponent :: proc(format : vk.Format) -> bool {
        return format == .D32_SFLOAT_S8_UINT || format == .D24_UNORM_S8_UINT
    }

    graphicsContext^.depthFormat = findSupportedFormat(
        graphicsContext, {.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT}, .OPTIMAL, { .DEPTH_STENCIL_ATTACHMENT }
    )
    createImage(
        graphicsContext, graphicsContext^.swapchainExtent.width, graphicsContext^.swapchainExtent.height, 1, graphicsContext^.msaaSamples, graphicsContext^.depthFormat,
        .OPTIMAL, { .DEPTH_STENCIL_ATTACHMENT }, { .DEVICE_LOCAL }, &graphicsContext^.depthImage, &graphicsContext^.depthImageMemory
    )
    graphicsContext^.depthImageView = createImageView(graphicsContext, graphicsContext^.depthImage, graphicsContext^.depthFormat, { .DEPTH }, 1)
}

@(private="file")
createTexture :: proc(graphicsContext : ^GraphicsContext) {
    transitionImageLayout :: proc(graphicsContext : ^GraphicsContext, image : vk.Image, format : vk.Format, oldLayout, newLayout : vk.ImageLayout, mipLevel : u32) {
        commandBuffer := beginSingleTimeCommands(graphicsContext)
        barrier : vk.ImageMemoryBarrier = {
            sType               = .IMAGE_MEMORY_BARRIER,
            pNext               = nil,
            srcAccessMask       = {},
            dstAccessMask       = {},
            oldLayout           = oldLayout,
            newLayout           = newLayout,
            srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            image               = image,
            subresourceRange    = vk.ImageSubresourceRange{
                aspectMask     = { .COLOR },
                baseMipLevel   = 0,
                levelCount     = mipLevel,
                baseArrayLayer = 0,
                layerCount     = 1,
            },
        }
        sourceStage, destinationStage : vk.PipelineStageFlags
        if oldLayout == .UNDEFINED && newLayout == .TRANSFER_DST_OPTIMAL {
            barrier.srcAccessMask = {}
            barrier.dstAccessMask = { .TRANSFER_WRITE }
            sourceStage = { .TOP_OF_PIPE }
            destinationStage = { .TRANSFER }
        } else if oldLayout == .TRANSFER_DST_OPTIMAL && newLayout == .SHADER_READ_ONLY_OPTIMAL {
            barrier.srcAccessMask = { .TRANSFER_WRITE }
            barrier.dstAccessMask = { .SHADER_READ }
            sourceStage = { .TRANSFER }
            destinationStage = { .FRAGMENT_SHADER }
        } else {
            log(.ERROR, "Unsupported layout transition!")
            panic("Unsupported layout transition!")
        }
        vk.CmdPipelineBarrier(commandBuffer, sourceStage, destinationStage, {}, 0, nil, 0, nil, 1, &barrier)
        endSingleTimeCommands(graphicsContext, commandBuffer)
    }

    copyBufferToImage :: proc(graphicsContext : ^GraphicsContext, buffer : vk.Buffer, image : vk.Image, width, height : i32) {
        commandBuffer := beginSingleTimeCommands(graphicsContext)
        region : vk.BufferImageCopy = {
            bufferOffset      = 0,
            bufferRowLength   = 0,
            bufferImageHeight = 0,
            imageSubresource  = vk.ImageSubresourceLayers{
                aspectMask     = { .COLOR },
                mipLevel       = 0,
                baseArrayLayer = 0,
                layerCount     = 1,
            },
            imageOffset       = vk.Offset3D{
                x = 0,
                y = 0,
                z = 0,
            },
            imageExtent       = vk.Extent3D{
                width  = u32(width),
                height = u32(height),
                depth  = 1,
            },
        }
        vk.CmdCopyBufferToImage(commandBuffer, buffer, image, .TRANSFER_DST_OPTIMAL, 1, &region)
        endSingleTimeCommands(graphicsContext, commandBuffer)
    }

    generateMipmaps :: proc(graphicsContext : ^GraphicsContext, image : vk.Image, format : vk.Format, width, height, mipLevels : u32) {
        formatProperties : vk.FormatProperties
        vk.GetPhysicalDeviceFormatProperties(graphicsContext^.physicalDevice, format, &formatProperties);

        if !(.SAMPLED_IMAGE_FILTER_LINEAR in formatProperties.optimalTilingFeatures) {
            log(.ERROR, "Texture image format does not support linear blitting!")
            panic("Texture image format does not support linear blitting!");
        }
        
        commandBuffer := beginSingleTimeCommands(graphicsContext)
        barrier : vk.ImageMemoryBarrier = {
            sType               = .IMAGE_MEMORY_BARRIER,
            pNext               = nil,
            srcAccessMask       = {},
            dstAccessMask       = {},
            oldLayout           = .UNDEFINED,
            newLayout           = .UNDEFINED,
            srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            image               = image,
            subresourceRange    = {
                aspectMask     = { .COLOR },
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1,
            },
        }
        mipWidth := i32(width)
        mipHeight := i32(height)
        for i in 1..<mipLevels {
            barrier.subresourceRange.baseMipLevel = i - 1
            barrier.oldLayout = .TRANSFER_DST_OPTIMAL
            barrier.newLayout = .TRANSFER_SRC_OPTIMAL
            barrier.srcAccessMask = { .TRANSFER_WRITE }
            barrier.dstAccessMask = { .TRANSFER_READ }
    
            vk.CmdPipelineBarrier(commandBuffer, { .TRANSFER }, { .TRANSFER }, {}, 0, nil, 0, nil, 1, &barrier)
            blit : vk.ImageBlit = {
                srcSubresource = vk.ImageSubresourceLayers{
                    aspectMask     = { .COLOR },
                    mipLevel       = i - 1,
                    baseArrayLayer = 0,
                    layerCount     = 1,
                },
                srcOffsets     = [2]vk.Offset3D{
                    {
                        x = 0,
                        y = 0,
                        z = 0,
                    },
                    {
                        x = mipWidth,
                        y = mipHeight,
                        z = 1,
                    },
                },
                dstSubresource = vk.ImageSubresourceLayers{
                    aspectMask     = { .COLOR },
                    mipLevel       = i,
                    baseArrayLayer = 0,
                    layerCount     = 1,
                },
                dstOffsets     = [2]vk.Offset3D{
                    {
                        x = 0,
                        y = 0,
                        z = 0,
                    },
                    {
                        x = mipWidth > 1 ? mipWidth / 2 : 1,
                        y = mipHeight > 1 ? mipHeight / 2 : 1,
                        z = 1
                    },
                },
            }
            vk.CmdBlitImage(commandBuffer, image, .TRANSFER_SRC_OPTIMAL, image, .TRANSFER_DST_OPTIMAL, 1, &blit, .LINEAR)
            
            barrier.oldLayout = .TRANSFER_SRC_OPTIMAL
            barrier.newLayout = .SHADER_READ_ONLY_OPTIMAL
            barrier.srcAccessMask = { .TRANSFER_READ }
            barrier.dstAccessMask = { .SHADER_READ }
    
            vk.CmdPipelineBarrier(commandBuffer, { .TRANSFER }, { .FRAGMENT_SHADER }, {}, 0, nil, 0, nil, 1, &barrier)
    
            if mipWidth > 1 do mipWidth /= 2
            if mipHeight > 1 do mipHeight /= 2
        }
    
        barrier.subresourceRange.baseMipLevel = mipLevels - 1;
        barrier.oldLayout = .TRANSFER_DST_OPTIMAL;
        barrier.newLayout = .SHADER_READ_ONLY_OPTIMAL;
        barrier.srcAccessMask = { .TRANSFER_WRITE };
        barrier.dstAccessMask = { .SHADER_READ };
    
        vk.CmdPipelineBarrier(commandBuffer, { .TRANSFER }, { .FRAGMENT_SHADER }, {}, 0, nil, 0, nil, 1, &barrier)
        endSingleTimeCommands(graphicsContext, commandBuffer);
    }

    texWidth, texHeight, texChannels : i32
    pixels := im.load(TEXTURE_PATH, &texWidth, &texHeight, &texChannels, 4)
    defer im.image_free(pixels)
    imageSize := int(texWidth * texHeight * 4)
    if pixels == nil {
        log(.ERROR, "Failed to load texture!")
        panic("Failed to load texture!")
    }

    graphicsContext^.mipLevels = u32(floor(log2(f32(max(texWidth, texHeight))))) + 1

    stagingBuffer : vk.Buffer
    stagingBufferMemory : vk.DeviceMemory
    createBuffer(graphicsContext, imageSize, { .TRANSFER_SRC }, { .HOST_VISIBLE, .HOST_COHERENT }, &stagingBuffer, &stagingBufferMemory)

    data : rawptr
    vk.MapMemory(graphicsContext^.device, stagingBufferMemory, 0, vk.DeviceSize(imageSize), {}, &data)
    mem.copy(data, pixels, imageSize)
    vk.UnmapMemory(graphicsContext^.device, stagingBufferMemory)

    createImage(
        graphicsContext,
        u32(texWidth),
        u32(texHeight),
        graphicsContext^.mipLevels,
        { ._1 },
        .R8G8B8A8_SRGB,
        .OPTIMAL, 
        { .TRANSFER_DST, .TRANSFER_SRC, .SAMPLED },
        { .DEVICE_LOCAL },
        &graphicsContext^.texture,
        &graphicsContext^.textureMemory
    )
    transitionImageLayout(graphicsContext, graphicsContext^.texture, .R8G8B8A8_SRGB, .UNDEFINED, .TRANSFER_DST_OPTIMAL, graphicsContext^.mipLevels)
    copyBufferToImage(graphicsContext, stagingBuffer, graphicsContext^.texture, texWidth, texHeight)
    // transitionImageLayout(graphicsContext, graphicsContext^.texture, .R8G8B8A8_SRGB, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL, graphicsContext^.mipLevels)

    vk.DestroyBuffer(graphicsContext^.device, stagingBuffer, nil)
    vk.FreeMemory(graphicsContext^.device, stagingBufferMemory, nil)

    generateMipmaps(graphicsContext, graphicsContext^.texture, .R8G8B8A8_SRGB, u32(texWidth), u32(texHeight), graphicsContext^.mipLevels)
}

@(private="file")
createImage :: proc(
    graphicsContext : ^GraphicsContext, width, height, mipLevels : u32, sampleCount : vk.SampleCountFlags, format : vk.Format, tiling : vk.ImageTiling,
    usage : vk.ImageUsageFlags, properties : vk.MemoryPropertyFlags, image : ^vk.Image, imageMemory : ^vk.DeviceMemory
) {
    imageInfo : vk.ImageCreateInfo = {
        sType                 = .IMAGE_CREATE_INFO,
        pNext                 = nil,
        flags                 = {},
        imageType             = .D2,
        format                = format,
        extent                = { width, height, 1 },
        mipLevels             = mipLevels,
        arrayLayers           = 1,
        samples               = sampleCount,
        tiling                = tiling,
        usage                 = usage,
        sharingMode           = .EXCLUSIVE,
        queueFamilyIndexCount = 0,
        pQueueFamilyIndices   = nil,
        initialLayout         = .UNDEFINED,
    }
    if vk.CreateImage(graphicsContext^.device, &imageInfo, nil, image) != .SUCCESS {
        log(.ERROR, "Failed to create texture!")
        panic("Failed to create texture!")
    }

    memRequirements : vk.MemoryRequirements
    vk.GetImageMemoryRequirements(graphicsContext^.device, image^, &memRequirements)
    allocInfo : vk.MemoryAllocateInfo = {
        sType           = .MEMORY_ALLOCATE_INFO,
        pNext           = nil,
        allocationSize  = memRequirements.size,
        memoryTypeIndex = findMemoryType(graphicsContext, memRequirements.memoryTypeBits, properties),
    }
    if vk.AllocateMemory(graphicsContext^.device, &allocInfo, nil, imageMemory) != .SUCCESS {
        log(.ERROR, "Failed to allocate image memory!")
        panic("Failed to allocate image memory!")
    }
    vk.BindImageMemory(graphicsContext^.device, image^, imageMemory^, 0)
}

@(private="file")
createTextureView :: proc(graphicsContext : ^GraphicsContext) {
    graphicsContext^.textureView = createImageView(graphicsContext, graphicsContext^.texture, .R8G8B8A8_SRGB, { .COLOR }, graphicsContext^.mipLevels)
}

@(private="file")
createImageView :: proc(graphicsContext : ^GraphicsContext, image : vk.Image, format : vk.Format, aspectFlags : vk.ImageAspectFlags, mipLevels : u32) ->
    (imageView : vk.ImageView) 
{
    viewInfo : vk.ImageViewCreateInfo = {
        sType            = vk.StructureType.IMAGE_VIEW_CREATE_INFO,
        pNext            = nil,
        flags            = {},
        image            = image,
        viewType         = .D2,
        format           = format,
        components       = {
            r = .IDENTITY,
            g = .IDENTITY,
            b = .IDENTITY, 
            a = .IDENTITY,
        },
        subresourceRange = vk.ImageSubresourceRange{
            aspectMask     = aspectFlags,
            baseMipLevel   = 0,
            levelCount     = mipLevels,
            baseArrayLayer = 0,
            layerCount     = 1,
        },
    }
    if vk.CreateImageView(graphicsContext^.device, &viewInfo, nil, &imageView) != .SUCCESS {
        log(.ERROR, "Failed to create image view!")
        panic("Failed to create image view!")
    }
    return imageView;
}

@(private="file")
createTextureSampler :: proc(graphicsContext : ^GraphicsContext) {
    properties : vk.PhysicalDeviceProperties
    vk.GetPhysicalDeviceProperties(graphicsContext^.physicalDevice, &properties)
    samplerInfo : vk.SamplerCreateInfo = {
        sType                   = .SAMPLER_CREATE_INFO,
        pNext                   = nil,
        flags                   = {},
        magFilter               = .LINEAR,
        minFilter               = .LINEAR,
        mipmapMode              = .LINEAR,
        addressModeU            = .REPEAT,
        addressModeV            = .REPEAT,
        addressModeW            = .REPEAT,
        mipLodBias              = 0,
        anisotropyEnable        = true,
        maxAnisotropy           = properties.limits.maxSamplerAnisotropy,
        compareEnable           = false,
        compareOp               = .ALWAYS,
        minLod                  = 0,
        maxLod                  = vk.LOD_CLAMP_NONE,
        borderColor             = .INT_OPAQUE_BLACK,
        unnormalizedCoordinates = false,
    }
    if vk.CreateSampler(graphicsContext^.device, &samplerInfo, nil, &graphicsContext^.textureSampler) != .SUCCESS {
        log(.ERROR, "Failed to create texture sampler!")
        panic("Failed to create texture sampler!")
    }
}

@(private="file")
loadModel :: proc(graphicsContext : ^GraphicsContext) {
    loadFBX :: proc(filename : cstring) -> ([]u32, []Vertex) {
        // Load the .fbx file
        opts := fbx.Load_Opts{}
        err := fbx.Error{}
        scene := fbx.load_file(filename, &opts, &err)
        defer fbx.free_scene(scene)
        if scene == nil {
            log(.ERROR, fmt.aprintf("failed to load FBX file! Reason\n{}", err.description.data))
            panic("Failed to load FBX file!")
        }

        // Retrieve the first mesh
        mesh: ^fbx.Mesh
        for i in 0 ..< scene.nodes.count {
            node := scene.nodes.data[i]
            if node.is_root || node.mesh == nil { continue }
            mesh = node.mesh
            break
        }

        // Unpack / triangulate the index data
        index_count := 3 * mesh.num_triangles
        indices := make([]u32, index_count)
        off := u32(0)
        for i in 0 ..< mesh.faces.count {
                face := mesh.faces.data[i]
                tris := fbx.catch_triangulate_face(nil, &indices[off], uint(index_count), mesh, face)
                off += 3 * tris
        }

        // Unpack the vertex data
        vertex_count := mesh.num_indices
        vertices := make([]Vertex, vertex_count)

        for i in 0..< vertex_count {
                pos := mesh.vertex_position.values.data[mesh.vertex_position.indices.data[i]]
                //norm := mesh.vertex_normal.values.data[mesh.vertex_normal.indices.data[i]]
                uv := mesh.vertex_uv.values.data[mesh.vertex_uv.indices.data[i]]
                vertices[i] = {
                    position = {f32(pos.x), f32(pos.y), f32(pos.z)},
                    texCoord = {f32(uv.x), 1-f32(uv.y)},
                }
        }
        return indices[:], vertices[:]
    }

    graphicsContext^.indices, graphicsContext^.vertices = loadFBX(MODEL_PATH)
}

@(private="file")
createVertexBuffer :: proc(graphicsContext : ^GraphicsContext) {
    loadToGPUBuffer(
        graphicsContext, size_of(Vertex) * len(graphicsContext^.vertices), raw_data(graphicsContext^.vertices),
        &graphicsContext^.vertexBuffer, &graphicsContext^.vertexBufferMemory, .VERTEX_BUFFER
    )
}

@(private="file")
createIndexBuffer :: proc(graphicsContext : ^GraphicsContext) {
    loadToGPUBuffer(
        graphicsContext, size_of(u32) * len(graphicsContext^.indices), raw_data(graphicsContext^.indices),
        &graphicsContext^.indexBuffer, &graphicsContext^.indexBufferMemory, .INDEX_BUFFER
    )
}

//To-Do: Buffer allocation for both indexes and vertices should be done in one call (can be achieved by fussing buffers into one)
@(private="file")
loadToGPUBuffer :: proc(
    graphicsContext : ^GraphicsContext, bufferSize : int, srcData : rawptr, dstBuffer : ^vk.Buffer, dstBufferMemory : ^vk.DeviceMemory, bufferType : vk.BufferUsageFlag
) {
    copyBuffer :: proc(graphicsContext : ^GraphicsContext, srcBuffer, dstBuffer : vk.Buffer, size : int) {
        commandBuffer : vk.CommandBuffer = beginSingleTimeCommands(graphicsContext)
        copyRegion : vk.BufferCopy = {
            srcOffset = 0,
            dstOffset = 0,
            size      = vk.DeviceSize(size),
        }
        vk.CmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);
        endSingleTimeCommands(graphicsContext, commandBuffer);
    }
    stagingBuffer : vk.Buffer
    stagingBufferMemory : vk.DeviceMemory
    createBuffer(graphicsContext, bufferSize, { .TRANSFER_SRC }, { .HOST_VISIBLE, .HOST_COHERENT }, &stagingBuffer, &stagingBufferMemory)
    
    data : rawptr
    vk.MapMemory(graphicsContext^.device, stagingBufferMemory, 0, (vk.DeviceSize)(bufferSize), {}, &data)
    mem.copy(data, srcData, bufferSize)
    vk.UnmapMemory(graphicsContext^.device, stagingBufferMemory)

    createBuffer(graphicsContext, bufferSize, { .TRANSFER_DST, bufferType }, { .DEVICE_LOCAL }, dstBuffer, dstBufferMemory)

    copyBuffer(graphicsContext, stagingBuffer, dstBuffer^, bufferSize)
    vk.DestroyBuffer(graphicsContext^.device, stagingBuffer, nil)
    vk.FreeMemory(graphicsContext^.device, stagingBufferMemory, nil)
}

@(private="file")
beginSingleTimeCommands :: proc(graphicsContext : ^GraphicsContext) -> (commandBuffer : vk.CommandBuffer) {
    allocInfo : vk.CommandBufferAllocateInfo = {
        sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
        pNext              = nil,
        commandPool        = graphicsContext^.commandPool,
        level              = .PRIMARY,
        commandBufferCount = 1,
    }
    vk.AllocateCommandBuffers(graphicsContext^.device, &allocInfo, &commandBuffer)
    beginInfo : vk.CommandBufferBeginInfo = {
        sType            = .COMMAND_BUFFER_BEGIN_INFO,
        pNext            = nil,
        flags            = { .ONE_TIME_SUBMIT },
        pInheritanceInfo = nil,
    }
    vk.BeginCommandBuffer(commandBuffer, &beginInfo)
    return
}

@(private="file")
endSingleTimeCommands :: proc(graphicsContext : ^GraphicsContext, commandBuffer : vk.CommandBuffer) {
    commandBuffer := commandBuffer
    vk.EndCommandBuffer(commandBuffer)
    submitInfo : vk.SubmitInfo = {
        sType                = .SUBMIT_INFO,
        pNext                = nil,
        waitSemaphoreCount   = 0,
        pWaitSemaphores      = nil,
        pWaitDstStageMask    = nil,
        commandBufferCount   = 1,
        pCommandBuffers      = &commandBuffer,
        signalSemaphoreCount = 0,
        pSignalSemaphores    = nil,
    }
    vk.QueueSubmit(graphicsContext^.graphicsQueue, 1, &submitInfo, 0)
    vk.QueueWaitIdle(graphicsContext^.graphicsQueue)
    vk.FreeCommandBuffers(graphicsContext^.device, graphicsContext^.commandPool, 1, &commandBuffer)
}

@(private="file")
createUniformBuffer :: proc(graphicsContext : ^GraphicsContext) {
    for i in 0..<MAX_FRAMES_IN_FLIGHT {
        createBuffer(
            graphicsContext, size_of(UniformBufferObject), { .UNIFORM_BUFFER }, { .HOST_VISIBLE, .HOST_COHERENT },
            &graphicsContext^.uniformBuffers[i], &graphicsContext^.uniformBuffersMemory[i]
        )
        vk.MapMemory(graphicsContext^.device, graphicsContext^.uniformBuffersMemory[i], 0, size_of(UniformBufferObject), {}, &graphicsContext^.uniformBuffersMapped[i])
    }
}

@(private="file")
createBuffer :: proc(
    graphicsContext : ^GraphicsContext, size : int, usage : vk.BufferUsageFlags, properties : vk.MemoryPropertyFlags, buffer : ^vk.Buffer, bufferMemory : ^vk.DeviceMemory
) {
    bufferInfo : vk.BufferCreateInfo = {
        sType                 = .BUFFER_CREATE_INFO,
        pNext                 = nil,
        flags                 = {},
        size                  = vk.DeviceSize(size),
        usage                 = usage,
        sharingMode           = .EXCLUSIVE,
        queueFamilyIndexCount = 0,
        pQueueFamilyIndices   = nil,
    }
    if vk.CreateBuffer(graphicsContext^.device, &bufferInfo, nil, buffer) != .SUCCESS {
        log(.ERROR, "Failed to create vertex buffer!")
        panic("Failed to create vertex buffer!")
    }

    memRequirements : vk.MemoryRequirements
    vk.GetBufferMemoryRequirements(graphicsContext^.device, buffer^, &memRequirements)
    allocInfo : vk.MemoryAllocateInfo = {
        sType           = .MEMORY_ALLOCATE_INFO,
        pNext           = nil,
        allocationSize  = memRequirements.size,
        memoryTypeIndex = findMemoryType(graphicsContext, memRequirements.memoryTypeBits, properties),
    }
    if vk.AllocateMemory(graphicsContext^.device, &allocInfo, nil, bufferMemory) != .SUCCESS {
        log(.ERROR, "Failed to allocate vertex buffer memory!")
        panic("Failed to allocate vertex buffer memory!")
    }
    vk.BindBufferMemory(graphicsContext^.device, buffer^, bufferMemory^, 0)
}

@(private="file")
findMemoryType :: proc(graphicsContext : ^GraphicsContext, typeFilter : u32, properties : vk.MemoryPropertyFlags) -> u32 {
    memProperties : vk.PhysicalDeviceMemoryProperties
    vk.GetPhysicalDeviceMemoryProperties(graphicsContext^.physicalDevice, &memProperties)
    for i in 0..<memProperties.memoryTypeCount {
        if typeFilter & (1 << i) != 0 && (memProperties.memoryTypes[i].propertyFlags & properties) == properties {
            return i
        }
    }
    log(.ERROR, "Failed to find suitable memory type!")
    panic("Failed to find suitable memory type!")
}

@(private="file")
createDescriptorPool :: proc(graphicsContext : ^GraphicsContext) {
    poolSize : []vk.DescriptorPoolSize = {
        {
            type            = .UNIFORM_BUFFER,
            descriptorCount = MAX_FRAMES_IN_FLIGHT,
        },
        {
            type            = .COMBINED_IMAGE_SAMPLER,
            descriptorCount = MAX_FRAMES_IN_FLIGHT,
        },
    }
    poolInfo : vk.DescriptorPoolCreateInfo = {
        sType         = .DESCRIPTOR_POOL_CREATE_INFO,
        pNext         = nil,
        flags         = {},
        maxSets       = MAX_FRAMES_IN_FLIGHT,
        poolSizeCount = 2,
        pPoolSizes    = raw_data(poolSize),
    }
    if vk.CreateDescriptorPool(graphicsContext^.device, &poolInfo, nil, &graphicsContext^.descriptorPool) != .SUCCESS {
        log(.ERROR, "Failed to create descriptor pool!")
        panic("Failed to create descriptor pool!")
    }
}

@(private="file")
createDescriptorSets :: proc(graphicsContext : ^GraphicsContext) {
    layouts := make([]vk.DescriptorSetLayout, MAX_FRAMES_IN_FLIGHT)
    for &layout in layouts { 
        layout = graphicsContext^.descriptorSetLayout
    }
    allocInfo : vk.DescriptorSetAllocateInfo = {
        sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
        pNext              = nil,
        descriptorPool     = graphicsContext^.descriptorPool,
        descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
        pSetLayouts        = raw_data(layouts),
    }
    graphicsContext^.descriptorSets = make([]vk.DescriptorSet, MAX_FRAMES_IN_FLIGHT)
    if vk.AllocateDescriptorSets(graphicsContext^.device, &allocInfo, raw_data(graphicsContext^.descriptorSets)) != .SUCCESS {
        log(.ERROR, "Failed to allocate descriptor sets!")
        panic("Failed to allocate descriptor sets!")
    }

    for index in 0..<MAX_FRAMES_IN_FLIGHT {
        bufferInfo : vk.DescriptorBufferInfo = {
            buffer = graphicsContext^.uniformBuffers[index],
            offset = 0,
            range  = size_of(UniformBufferObject),
        }
        imageInfo : vk.DescriptorImageInfo = {
            sampler     = graphicsContext^.textureSampler,
            imageView   = graphicsContext^.textureView,
            imageLayout = .SHADER_READ_ONLY_OPTIMAL,
        }
        descriptorWrite : []vk.WriteDescriptorSet = {
            {
                sType            = .WRITE_DESCRIPTOR_SET,
                pNext            = nil,
                dstSet           = graphicsContext^.descriptorSets[index],
                dstBinding       = 0,
                dstArrayElement  = 0,
                descriptorCount  = 1,
                descriptorType   = .UNIFORM_BUFFER,
                pImageInfo       = nil,
                pBufferInfo      = &bufferInfo,
                pTexelBufferView = nil,
            },
            {
                sType            = .WRITE_DESCRIPTOR_SET,
                pNext            = nil,
                dstSet           = graphicsContext^.descriptorSets[index],
                dstBinding       = 1,
                dstArrayElement  = 0,
                descriptorCount  = 1,
                descriptorType   = .COMBINED_IMAGE_SAMPLER,
                pImageInfo       = &imageInfo,
                pBufferInfo      = nil,
                pTexelBufferView = nil,
            },
        }
        vk.UpdateDescriptorSets(graphicsContext^.device, 2, raw_data(descriptorWrite), 0, nil)
    }
}

@(private="file")
createCommandBuffers :: proc(graphicsContext : ^GraphicsContext) {
    graphicsContext^.commandBuffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
    allocInfo : vk.CommandBufferAllocateInfo = {
        sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
        pNext              = nil,
        commandPool        = graphicsContext^.commandPool,
        level              = .PRIMARY,
        commandBufferCount = MAX_FRAMES_IN_FLIGHT,
    }
    if vk.AllocateCommandBuffers(graphicsContext^.device, &allocInfo, raw_data(graphicsContext^.commandBuffers)) != .SUCCESS {
        log(.ERROR, "Failed to allocate command buffer!")
        panic("Failed to allocate command buffer!")
    }
}

@(private="file")
createSyncObjects :: proc(graphicsContext : ^GraphicsContext) {
    graphicsContext^.imagesAvailable = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
    graphicsContext^.rendersFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
    graphicsContext^.inFlightFrames = make([]vk.Fence, MAX_FRAMES_IN_FLIGHT)
    semaphoreInfo : vk.SemaphoreCreateInfo = {
        sType = .SEMAPHORE_CREATE_INFO,
        pNext = nil,
        flags = {},
    }
    fenceInfo : vk.FenceCreateInfo = {
        sType = .FENCE_CREATE_INFO,
        pNext = nil,
        flags = { .SIGNALED },
    }

    for index in 0..<MAX_FRAMES_IN_FLIGHT {
        if ((vk.CreateSemaphore(graphicsContext^.device, &semaphoreInfo, nil, &graphicsContext^.imagesAvailable[index]) |
            vk.CreateSemaphore(graphicsContext^.device, &semaphoreInfo, nil, &graphicsContext^.rendersFinished[index]) |
            vk.CreateFence(graphicsContext^.device, &fenceInfo, nil, &graphicsContext^.inFlightFrames[index])) != .SUCCESS)  {
            log(.ERROR, "Failed to create sync objects!")
            panic("Failed to create sync objects!")
        }
    }
}

drawFrame :: proc(graphicsContext : ^GraphicsContext, camera : Camera) {
    vk.WaitForFences(graphicsContext^.device, 1, &graphicsContext^.inFlightFrames[graphicsContext^.currentFrame], true, max(u64))
    
    imageIndex : u32
    result := vk.AcquireNextImageKHR(
        graphicsContext^.device, graphicsContext^.swapchain, max(u64), graphicsContext^.imagesAvailable[graphicsContext^.currentFrame], {}, &imageIndex
    )
    if result == .ERROR_OUT_OF_DATE_KHR {
        recreateSwapchain(graphicsContext)
        return
    }
    else if (result != .SUCCESS && result != .SUBOPTIMAL_KHR) {
        log(.ERROR, "Failed to aquire swapchain image!")
        panic("Failed to aquire swapchain image!")
    }
    vk.ResetFences(graphicsContext^.device, 1, &graphicsContext^.inFlightFrames[graphicsContext^.currentFrame])

    vk.ResetCommandBuffer(graphicsContext^.commandBuffers[graphicsContext^.currentFrame], {})
    updateUniformBuffer(graphicsContext, camera)
    recordCommandBuffer(graphicsContext, &graphicsContext^.commandBuffers[graphicsContext^.currentFrame], imageIndex)

    submitInfo : vk.SubmitInfo = {
        sType                = .SUBMIT_INFO,
        pNext                = nil,
        waitSemaphoreCount   = 1,
        pWaitSemaphores      = raw_data([]vk.Semaphore{ graphicsContext^.imagesAvailable[graphicsContext^.currentFrame] }),
        pWaitDstStageMask    = raw_data([]vk.PipelineStageFlags{ { .COLOR_ATTACHMENT_OUTPUT } }),
        commandBufferCount   = 1,
        pCommandBuffers      = &graphicsContext^.commandBuffers[graphicsContext^.currentFrame],
        signalSemaphoreCount = 1,
        pSignalSemaphores    = raw_data([]vk.Semaphore{ graphicsContext^.rendersFinished[graphicsContext^.currentFrame] }),
    }

    if vk.QueueSubmit(graphicsContext^.graphicsQueue, 1, &submitInfo, graphicsContext^.inFlightFrames[graphicsContext^.currentFrame]) != .SUCCESS {
        log(.ERROR, "Failed to submit draw command buffer!")
        panic("Failed to submit draw command buffer!")
    }

    presentInfo : vk.PresentInfoKHR = {
        sType              = .PRESENT_INFO_KHR,
        pNext              = nil,
        waitSemaphoreCount = 1,
        pWaitSemaphores    = raw_data([]vk.Semaphore{ graphicsContext^.rendersFinished[graphicsContext^.currentFrame] }),
        swapchainCount     = 1,
        pSwapchains        = raw_data([]vk.SwapchainKHR{ graphicsContext^.swapchain }),
        pImageIndices      = &imageIndex,
        pResults           = nil,
    }

    result = vk.QueuePresentKHR(graphicsContext^.presentQueue, &presentInfo)
    if result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR || graphicsContext^.framebufferResized {
        graphicsContext^.framebufferResized = false
        recreateSwapchain(graphicsContext)
    }
    else if result != .SUCCESS {
        log(.ERROR, "Failed to present swapchain image!")
        panic("Failed to present swapchain image!")
    }

    graphicsContext^.currentFrame += (graphicsContext^.currentFrame + 1) % 2
}

@(private="file")
recordCommandBuffer :: proc(graphicsContext : ^GraphicsContext, commandBuffer : ^vk.CommandBuffer, imageIndex : u32) {
    beginInfo : vk.CommandBufferBeginInfo = {
        sType            = .COMMAND_BUFFER_BEGIN_INFO,
        pNext            = nil,
        flags            = {},
        pInheritanceInfo = nil,
    }
    if vk.BeginCommandBuffer(commandBuffer^, &beginInfo) != .SUCCESS {
        log(.ERROR, "Failed to being recording command buffer!")
        panic("Failed to being recording command buffer!")
    }

    renderPassInfo : vk.RenderPassBeginInfo = {
        sType           = .RENDER_PASS_BEGIN_INFO,
        pNext           = nil,
        renderPass      = graphicsContext^.renderPasses[0],
        framebuffer     = graphicsContext^.swapchainFrameBuffers[imageIndex],
        renderArea      = vk.Rect2D{
            offset = {0, 0},
	        extent = graphicsContext^.swapchainExtent,
        },
        clearValueCount = 2,
        pClearValues    = raw_data([]vk.ClearValue{
            {
                color = vk.ClearColorValue{
                    float32 = { 0, 0, 0, 1 },
                },
            },
            {
                depthStencil = vk.ClearDepthStencilValue{
                    depth   = 1,
                    stencil = 0,
                },
            },
        }),
    }
    vk.CmdBeginRenderPass(commandBuffer^, &renderPassInfo, .INLINE)
    vk.CmdBindPipeline(commandBuffer^, .GRAPHICS, graphicsContext^.pipelines[0])

    vk.CmdBindVertexBuffers(commandBuffer^, 0, 1, raw_data([]vk.Buffer{ graphicsContext^.vertexBuffer }), raw_data([]vk.DeviceSize{ 0 }))
    vk.CmdBindIndexBuffer(commandBuffer^, graphicsContext^.indexBuffer, 0, .UINT32)

    viewport : vk.Viewport = {
        x        = 0,
        y        = 0,
        width    = f32(graphicsContext^.swapchainExtent.width),
        height   = f32(graphicsContext^.swapchainExtent.height),
        minDepth = 0,
        maxDepth = 1,
    }
    vk.CmdSetViewport(commandBuffer^, 0, 1, &viewport)

    scissor : vk.Rect2D = {
        offset = { 0, 0 },
        extent = graphicsContext^.swapchainExtent,
    }
    vk.CmdSetScissor(commandBuffer^, 0, 1, &scissor)

    vk.CmdBindDescriptorSets(
        commandBuffer^, .GRAPHICS, graphicsContext^.pipelineLayouts[0], 0, 1, &graphicsContext^.descriptorSets[graphicsContext^.currentFrame], 0, nil
    )
    vk.CmdDrawIndexed(commandBuffer^, u32(len(graphicsContext^.indices)), 1, 0, 0, 0)

    vk.CmdEndRenderPass(commandBuffer^)
    if vk.EndCommandBuffer(commandBuffer^) != .SUCCESS {
        log(.ERROR, "Failed to record command buffer!")
        panic("Failed to record command buffer!")
    }
}

@(private="file")
updateUniformBuffer :: proc(graphicsContext : ^GraphicsContext, camera : Camera) {
    ubo : UniformBufferObject = {
        model      = IMat4,
        view       = lookAt(camera.eye, camera.center, camera.up),
        projection = perspective(radians(f32(45.0)), f32(graphicsContext^.swapchainExtent.width) / f32(graphicsContext^.swapchainExtent.height), 0.1, 1000000),
    }
    mem.copy(graphicsContext^.uniformBuffersMapped[graphicsContext^.currentFrame], &ubo, size_of(UniformBufferObject))
}

@(private="file")
recreateSwapchain :: proc(graphicsContext : ^GraphicsContext) {
    width, height := glfw.GetFramebufferSize(graphicsContext^.window)
    for width == 0 && height == 0 {
        width, height = glfw.GetFramebufferSize(graphicsContext^.window)
        glfw.WaitEvents()
    }

    vk.DeviceWaitIdle(graphicsContext^.device)
    cleanupSwapchain(graphicsContext)

    createSwapchain(graphicsContext)
    createImageViews(graphicsContext)
    createColourResources(graphicsContext)
    createDepthResources(graphicsContext)
    createFramebuffers(graphicsContext)
}

clanupVkGraphics :: proc(graphicsContext : ^GraphicsContext) {
    vk.DeviceWaitIdle(graphicsContext^.device)
    vk.DestroyBuffer(graphicsContext^.device, graphicsContext^.indexBuffer, nil)
    vk.FreeMemory(graphicsContext^.device, graphicsContext^.indexBufferMemory, nil)
    vk.DestroyBuffer(graphicsContext^.device, graphicsContext^.vertexBuffer, nil)
    vk.FreeMemory(graphicsContext^.device, graphicsContext^.vertexBufferMemory, nil)
    vk.DestroySampler(graphicsContext^.device, graphicsContext^.textureSampler, nil)
    vk.DestroyImageView(graphicsContext^.device, graphicsContext^.textureView, nil)
    vk.DestroyImage(graphicsContext^.device, graphicsContext^.texture, nil)
    vk.FreeMemory(graphicsContext^.device, graphicsContext^.textureMemory, nil)
    for i in 0..<MAX_FRAMES_IN_FLIGHT {
        vk.DestroyBuffer(graphicsContext^.device, graphicsContext^.uniformBuffers[i], nil)
        vk.FreeMemory(graphicsContext^.device, graphicsContext^.uniformBuffersMemory[i], nil)
    }
    vk.DestroyDescriptorPool(graphicsContext^.device, graphicsContext^.descriptorPool, nil)
    vk.DestroyDescriptorSetLayout(graphicsContext^.device, graphicsContext^.descriptorSetLayout, nil)
    for index in 0..<len(graphicsContext^.pipelines) {
        vk.DestroyPipeline(graphicsContext^.device, graphicsContext^.pipelines[index], nil)
        vk.DestroyPipelineLayout(graphicsContext^.device, graphicsContext^.pipelineLayouts[index], nil)
        vk.DestroyRenderPass(graphicsContext^.device, graphicsContext^.renderPasses[index], nil)
    }
    for index in 0..<MAX_FRAMES_IN_FLIGHT {
        vk.DestroySemaphore(graphicsContext^.device, graphicsContext^.imagesAvailable[index], nil)
        vk.DestroySemaphore(graphicsContext^.device, graphicsContext^.rendersFinished[index], nil)
        vk.DestroyFence(graphicsContext^.device, graphicsContext^.inFlightFrames[index], nil)
    }
    cleanupSwapchain(graphicsContext)
    vk.DestroyCommandPool(graphicsContext^.device, graphicsContext^.commandPool, nil)
    vk.DestroyDevice(graphicsContext^.device, nil)
    when ODIN_DEBUG {
        vk.DestroyDebugUtilsMessengerEXT(graphicsContext^.instance, graphicsContext^.debugMessenger, nil)
    }
    vk.DestroySurfaceKHR(graphicsContext^.instance, graphicsContext^.surface, nil)
    vk.DestroyInstance(graphicsContext^.instance, nil)
}

@(private="file")
cleanupSwapchain :: proc(graphicsContext : ^GraphicsContext) {
    vk.DestroyImageView(graphicsContext^.device, graphicsContext^.colourImageView, nil)
    vk.DestroyImage(graphicsContext^.device, graphicsContext^.colourImage, nil)
    vk.FreeMemory(graphicsContext^.device, graphicsContext^.colourImageMemory, nil)
    vk.DestroyImageView(graphicsContext^.device, graphicsContext^.depthImageView, nil)
    vk.DestroyImage(graphicsContext^.device, graphicsContext^.depthImage, nil)
    vk.FreeMemory(graphicsContext^.device, graphicsContext^.depthImageMemory, nil)
    for frameBuffer in graphicsContext^.swapchainFrameBuffers {
        vk.DestroyFramebuffer(graphicsContext^.device, frameBuffer, nil)
    }
    for index in 0..<len(graphicsContext^.swapchainImageViews) {
        vk.DestroyImageView(graphicsContext^.device, graphicsContext^.swapchainImageViews[index], nil)
    }
    vk.DestroySwapchainKHR(graphicsContext^.device, graphicsContext^.swapchain, nil)
}
