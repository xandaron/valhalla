package Valhalla

import "core:c"
import "core:log"
import "core:mem"
import "core:os"
import "core:time"
import fbx "ufbx"
import "vendor:glfw"
import img "vendor:stb/image"
import vk "vendor:vulkan"

// ###################################################################
// #                          Constants                              #
// ###################################################################

@(private = "file")
requestedLayers: []cstring = {"VK_LAYER_KHRONOS_validation"}

@(private = "file")
requiredDeviceExtensions: []cstring = {vk.KHR_SWAPCHAIN_EXTENSION_NAME}

@(private = "file")
vertexBindingDescription: vk.VertexInputBindingDescription = {
	binding   = 0,
	stride    = size_of(Vertex),
	inputRate = .VERTEX,
}

@(private = "file")
vertexInputAttributeDescriptions: []vk.VertexInputAttributeDescription = {
	{
		location = 0,
		binding = 0,
		format = .R32G32B32_SFLOAT,
		offset = u32(offset_of(Vertex, position)),
	},
	{
		location = 1,
		binding = 0,
		format = .R32G32_SFLOAT,
		offset = u32(offset_of(Vertex, texCoord)),
	},
	{
		location = 2,
		binding = 0,
		format = .R32G32B32_SFLOAT,
		offset = u32(offset_of(Vertex, normal)),
	},
	{
		location = 3,
		binding = 0,
		format = .R32G32B32A32_UINT,
		offset = u32(offset_of(Vertex, bones)),
	},
	{
		location = 4,
		binding = 0,
		format = .R32G32B32A32_SFLOAT,
		offset = u32(offset_of(Vertex, weights)),
	},
}

@(private = "file")
ENGINE_VERSION: u32 : (0 << 22) | (0 << 12) | (1)

@(private = "file")
MODEL_PATH: cstring : "./assets/models/monster/jog.fbx"

@(private = "file")
TEXTURE_PATH: cstring : "./assets/models/monster/skeletonZombie_diffuse.png"

@(private = "file")
NORMALS_PATH: cstring : "./assets/models/monster/skeletonZombie_normal.png"

@(private = "file")
MAX_FRAMES_IN_FLIGHT: u32 : 2

@(private = "file")
RENDER_SIZE: Vec2 : {1980, 1080}

@(private = "file")
SHADOW_RESOLUTION: Vec2 : {2048, 2048}

@(private = "file")
CLEAR_COLOUR: Vec4 : {0.0 / 255.0, 0.0 / 255.0, 0.0 / 255.0, 0.0 / 255.0}

// ###################################################################
// #                         Data Structures                         #
// ###################################################################

@(private = "file")
Vertex :: struct {
	position: Vec3,
	texCoord: Vec2,
	normal:   Vec3,
	bones:    [4]u32,
	weights:  Vec4,
}

@(private = "file")
Bone :: struct {
	name:        cstring,
	isRoot:      bool,
	parentIndex: u32,
	inverseBind: Mat4,
}

@(private = "file")
Skeleton :: []Bone

@(private = "file")
KeyVector :: struct {
	time:  f64,
	value: Vec3,
}

@(private = "file")
KeyQuat :: struct {
	time:  f64,
	value: Quat,
}

@(private = "file")
AnimNode :: struct {
	bone:            u32,
	keyPositions:    []KeyVector,
	keyRotations:    []KeyQuat,
	keyScales:       []KeyVector,
	numKeyPositions: u32,
	numKeyRotations: u32,
	numKeyScales:    u32,
}

@(private = "file")
Anim :: struct {
	nodes:    []AnimNode,
	duration: f64,
}

@(private = "file")
Model :: struct {
	vertices:     []Vertex,
	vertexOffset: u32,
	indices:      []u32,
	indexOffset:  u32,
	indexCount:   u32,
	skeleton:     Skeleton,
	animations:   []Anim,
}

@(private = "file")
Image :: struct {
	image:   vk.Image,
	memory:  vk.DeviceMemory,
	view:    vk.ImageView,
	format:  vk.Format,
	sampler: vk.Sampler,
}

@(private = "file")
PointLight :: struct #align (16) {
	position:        Vec3,
	direction:       Vec3,
	fov:             f32,
	colourIntensity: Vec3,
}

@(private = "file")
Instance :: struct {
	modelID:       u32,
	animID:        u32,
	textureID:     u32,
	position:      Vec3,
	rotation:      Quat,
	scale:         Vec3,
	positionKeys:  []u32,
	rotationKeys:  []u32,
	scaleKeys:     []u32,
	animStartTime: time.Time,
}

@(private = "file")
PipelineIndex :: enum {
	MAIN   = 0,
	POST   = 1,
	SHADOW = 2,
}

@(private = "file")
ViewProjectionUniform :: struct #align (16) {
	view:           Mat4,
	projection:     Mat4,
	viewProjection: Mat4,
}

@(private = "file")
InstanceInfo :: struct #align (16) {
	model:         Mat4,
	boneOffset:    u32,
	samplerOffset: f32,
}

@(private = "file")
QueueFamilyIndices :: struct {
	graphicsFamily: u32,
	presentFamily:  u32,
	computeFamily:  u32,
}

@(private = "file")
SwapchainSupportDetails :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	formats:      []vk.SurfaceFormatKHR,
	modes:        []vk.PresentModeKHR,
}

@(private = "file")
Buffer :: struct {
	buffer: vk.Buffer,
	memory: vk.DeviceMemory,
	mapped: rawptr,
}

@(private = "file")
RenderPass :: struct {
	width, height:    u32,
	frameBuffers:     []vk.Framebuffer,
	colour:           Image,
	depth:            Image,
	vulkanRenderPass: vk.RenderPass,
	descriptor:       vk.DescriptorImageInfo,
}

@(private = "file")
Pipeline :: struct {
	using renderPass:    RenderPass,
	descriptorPool:      vk.DescriptorPool,
	descriptorSets:      [MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	pipeline:            vk.Pipeline,
	descriptorSetLayout: vk.DescriptorSetLayout,
	layout:              vk.PipelineLayout,
}

CameraMode :: enum {
	PERSPECTIVE,
	ORTHOGRAPHIC,
}

Camera :: struct {
	eye, center, up: Vec3,
	distance:        f32,
	mode:            CameraMode,
}

GraphicsContext :: struct {
	window:                 glfw.WindowHandle,
	instance:               vk.Instance,
	debugMessenger:         vk.DebugUtilsMessengerEXT,
	surface:                vk.SurfaceKHR,
	physicalDevice:         vk.PhysicalDevice,
	device:                 vk.Device,
	queueFamilies:          QueueFamilyIndices,
	graphicsQueue:          vk.Queue,
	presentQueue:           vk.Queue,
	computeQueue:           vk.Queue,

	// Swapchain
	swapchainImageCount:    u32,
	swapchainTransform:     vk.SurfaceTransformFlagsKHR,
	swapchain:              vk.SwapchainKHR,
	swapchainFormat:        vk.SurfaceFormatKHR,
	swapchainMode:          vk.PresentModeKHR,
	swapchainExtent:        vk.Extent2D,
	swapchainImages:        []vk.Image,
	swapchainImageViews:    []vk.ImageView,

	pipelines:              []Pipeline,

	// Frame Resources
	inImage:                Image,
	outImage:               Image,
	imagesAvailable:        []vk.Semaphore,
	rendersFinished:        []vk.Semaphore,
	computeFinished:        []vk.Semaphore,
	inFlightFrames:         []vk.Fence,

	// Commands
	graphicsCommandPool:    vk.CommandPool,
	graphicsCommandBuffers: []vk.CommandBuffer,
	computeCommandPool:     vk.CommandPool,
	computeCommandBuffers:  []vk.CommandBuffer,

	// Assets
	models:                 []Model,
	albidos:                Image,
	normals:                Image,
	vertices:               []Vertex,
	indices:                []u32,
	boneCount:              int,

	// Scene
	instances:              []Instance,
	lights:                 []PointLight,

	// Buffers
	// TODO: Vertex and Index buffers should be one buffer
	vertexBuffer:           Buffer,
	indexBuffer:            Buffer,
	// TODO: Combine into single buffer
	viewProjectionUniforms: [MAX_FRAMES_IN_FLIGHT]Buffer,
	instanceBuffers:        [MAX_FRAMES_IN_FLIGHT]Buffer,
	boneBuffers:            [MAX_FRAMES_IN_FLIGHT]Buffer,
	lightsBuffers:          [MAX_FRAMES_IN_FLIGHT]Buffer,

	// Util
	startTime:              time.Time,
	currentFrame:           u32,
	framebufferResized:     b8,
	hasAssetsLoaded:        b8,
}

// ###################################################################
// #                            Functions                            #
// ###################################################################

initVkGraphics :: proc(using graphicsContext: ^GraphicsContext) {
	vk.load_proc_addresses(rawptr(glfw.GetInstanceProcAddress))

	framebufferResized = false
	currentFrame = 0
	startTime = time.now()
	hasAssetsLoaded = false
	boneCount = 1

	createInstance(graphicsContext)
	when ODIN_DEBUG {
		vkSetupDebugMessenger(graphicsContext)
	}
	createSurface(graphicsContext)
	pickPhysicalDevice(graphicsContext)
	createLogicalDevice(graphicsContext)

	// Swapchain
	getSwapchainInfo(graphicsContext)
	swapchainImages = make([]vk.Image, swapchainImageCount)
	swapchainImageViews = make([]vk.ImageView, swapchainImageCount)
	createSwapchain(graphicsContext)

	// Commands
	createCommandBuffers(graphicsContext)

	// Assets
	loadAssets(graphicsContext)

	// Shader buffers
	createViewProjectionUniform(graphicsContext)

	// Frame Resources
	createStorageImage(graphicsContext)
	createSyncObjects(graphicsContext)

	// Pipeline
	pipelines = make([]Pipeline, 2)
	createDescriptorSets(graphicsContext)
	createRenderPass(graphicsContext)
	createFramebuffers(graphicsContext)
	createMainPipeline(graphicsContext)
	createPostPipeline(graphicsContext)
}

@(private = "file")
createInstance :: proc(using graphicsContext: ^GraphicsContext) {
	appInfo: vk.ApplicationInfo = {
		sType              = .APPLICATION_INFO,
		pNext              = nil,
		pApplicationName   = "Valhalla",
		applicationVersion = APP_VERSION,
		pEngineName        = "Asgardina Graphics",
		engineVersion      = ENGINE_VERSION,
		apiVersion         = vk.API_VERSION_1_3,
	}

	glfwExtensions := glfw.GetRequiredInstanceExtensions()
	supportedExtensions: [dynamic]cstring
	defer delete(supportedExtensions)

	extensionCount: u32
	vk.EnumerateInstanceExtensionProperties(nil, &extensionCount, nil)
	availableExtensions := make([]vk.ExtensionProperties, extensionCount)
	defer delete(availableExtensions)
	vk.EnumerateInstanceExtensionProperties(nil, &extensionCount, raw_data(availableExtensions))
	instance_extension_outer_loop: for name in glfwExtensions {
		for &extension in availableExtensions {
			if name == cstring(&extension.extensionName[0]) {
				append(&supportedExtensions, name)
				continue instance_extension_outer_loop
			}
		}
		log.logf(.Error, "Failed to find required extension: {}", name)
		panic("Failed to find required extension")
	}

	when ODIN_DEBUG {
		requestedExtensions := [?]cstring{"VK_EXT_debug_utils"}
		instance_extension2_outer_loop: for name in requestedExtensions {
			for &extension in availableExtensions {
				if (name == cstring(&extension.extensionName[0])) {
					append(&supportedExtensions, name)
					continue instance_extension2_outer_loop
				}
			}
			log.logf(.Warning, "Failed to find requested extension: {}", name)
		}
	}

	instanceInfo: vk.InstanceCreateInfo = {
		sType                   = .INSTANCE_CREATE_INFO,
		pNext                   = nil,
		flags                   = nil,
		pApplicationInfo        = &appInfo,
		enabledLayerCount       = 0,
		ppEnabledLayerNames     = nil,
		enabledExtensionCount   = u32(len(supportedExtensions)),
		ppEnabledExtensionNames = raw_data(supportedExtensions),
	}

	debugMessengerCreateInfo: vk.DebugUtilsMessengerCreateInfoEXT
	when ODIN_DEBUG {
		supportedLayers: [dynamic]cstring
		defer delete(supportedLayers)
		layerCount: u32
		vk.EnumerateInstanceLayerProperties(&layerCount, nil)
		layers := make([]vk.LayerProperties, layerCount)
		defer delete(layers)
		vk.EnumerateInstanceLayerProperties(&layerCount, raw_data(layers))
		instance_layers_outer_loop: for name in requestedLayers {
			for &layer in layers {
				if name == cstring(&layer.layerName[0]) {
					append(&supportedLayers, name)
					continue instance_layers_outer_loop
				}
			}
			log.logf(.Warning, "Failed to find requested layer: {}", name)
		}
		instanceInfo.enabledLayerCount = u32(len(supportedLayers))
		instanceInfo.ppEnabledLayerNames = raw_data(supportedLayers)

		debugMessengerCreateInfo = vkPopulateDebugMessengerCreateInfo()
		instanceInfo.pNext = &debugMessengerCreateInfo
	}

	if vk.CreateInstance(&instanceInfo, nil, &instance) != .SUCCESS {
		log.log(.Error, "Failed to create vulkan instance.")
		panic("Failed to create vulkan instance.")
	}

	// load_proc_addresses_instance :: proc(instance: Instance)
	vk.load_proc_addresses(instance)
}

@(private = "file")
createSurface :: proc(using graphicsContext: ^GraphicsContext) {
	if glfw.CreateWindowSurface(
		   instance,
		   window,
		   nil,
		   &surface,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create surface!")
		panic("Failed to create surface!")
	}
}

// ###################################################################
// #                              Device                             #
// ###################################################################

@(private = "file")
findQueueFamilies :: proc(
	physicalDevice: vk.PhysicalDevice,
	graphicsContext: ^GraphicsContext,
) -> (
	indices: QueueFamilyIndices,
	err: b32 = false,
) {
	queueFamilyCount: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, nil)
	queueFamilies := make([]vk.QueueFamilyProperties, queueFamilyCount)
	defer delete(queueFamilies)
	vk.GetPhysicalDeviceQueueFamilyProperties(
		physicalDevice,
		&queueFamilyCount,
		raw_data(queueFamilies),
	)

	foundPresentFamily := false
	foundGraphicsFamily := false
	foundComputeFamily := false
	for queueFamily, index in queueFamilies {
		if .GRAPHICS in queueFamily.queueFlags {
			indices.graphicsFamily = u32(index)
			foundGraphicsFamily = true
		}

		if .COMPUTE in queueFamily.queueFlags {
			indices.computeFamily = u32(index)
			foundComputeFamily = true
		}

		presentSupport: b32
		if vk.GetPhysicalDeviceSurfaceSupportKHR(
			   physicalDevice,
			   (u32)(index),
			   graphicsContext.surface,
			   &presentSupport,
		   ); presentSupport {
			indices.presentFamily = u32(index)
			foundPresentFamily = true
		}

		if foundGraphicsFamily && foundPresentFamily && foundComputeFamily {
			return
		}
	}
	return indices, true
}

@(private = "file")
querySwapchainSupport :: proc(
	physicalDevice: vk.PhysicalDevice,
	graphicsContext: ^GraphicsContext,
) -> (
	swapchainSupport: SwapchainSupportDetails,
) {
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
		physicalDevice,
		graphicsContext.surface,
		&swapchainSupport.capabilities,
	)

	formatCount: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(
		physicalDevice,
		graphicsContext.surface,
		&formatCount,
		nil,
	)
	if formatCount != 0 {
		swapchainSupport.formats = make([]vk.SurfaceFormatKHR, formatCount)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(
			physicalDevice,
			graphicsContext.surface,
			&formatCount,
			raw_data(swapchainSupport.formats),
		)
	}

	modeCount: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(
		physicalDevice,
		graphicsContext.surface,
		&modeCount,
		nil,
	)
	if modeCount != 0 {
		swapchainSupport.modes = make([]vk.PresentModeKHR, modeCount)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			physicalDevice,
			graphicsContext.surface,
			&modeCount,
			raw_data(swapchainSupport.modes),
		)
	}
	return
}

@(private = "file")
pickPhysicalDevice :: proc(graphicsContext: ^GraphicsContext) {
	scorePhysicalDevice :: proc(
		physicalDevice: vk.PhysicalDevice,
		graphicsContext: ^GraphicsContext,
	) -> (
		score: u32 = 0,
	) {
		physicalDeviceProperties: vk.PhysicalDeviceProperties
		physicalDeviceFeatures: vk.PhysicalDeviceFeatures

		vk.GetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties)
		vk.GetPhysicalDeviceFeatures(physicalDevice, &physicalDeviceFeatures)

		indices, err := findQueueFamilies(physicalDevice, graphicsContext)
		if err ||
		   !physicalDeviceFeatures.geometryShader ||
		   !physicalDeviceFeatures.samplerAnisotropy ||
		   !checkDeviceExtensionSupport(physicalDevice) ||
		   !swapchainAdequate(physicalDevice, graphicsContext) {
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

	checkDeviceExtensionSupport :: proc(physicalDevice: vk.PhysicalDevice) -> b32 {
		extensionCount: u32
		vk.EnumerateDeviceExtensionProperties(physicalDevice, nil, &extensionCount, nil)
		availableExtensions := make([]vk.ExtensionProperties, extensionCount)
		defer delete(availableExtensions)
		vk.EnumerateDeviceExtensionProperties(
			physicalDevice,
			nil,
			&extensionCount,
			raw_data(availableExtensions),
		)

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

	swapchainAdequate :: proc(
		physicalDevice: vk.PhysicalDevice,
		graphicsContext: ^GraphicsContext,
	) -> b32 {
		support := querySwapchainSupport(physicalDevice, graphicsContext)
		defer delete(support.formats)
		defer delete(support.modes)
		return len(support.formats) != 0 && len(support.modes) != 0
	}

	getMaxUsableSampleCount :: proc(physicalDevice: vk.PhysicalDevice) -> vk.SampleCountFlags {
		physicalDeviceProperties: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties)

		counts :=
			physicalDeviceProperties.limits.framebufferColorSampleCounts &
			physicalDeviceProperties.limits.framebufferDepthSampleCounts
		if ._64 in counts do return {._64}
		if ._32 in counts do return {._32}
		if ._16 in counts do return {._16}
		if ._8 in counts do return {._8}
		if ._4 in counts do return {._4}
		if ._2 in counts do return {._2}
		return {._1}
	}

	deviceCount: u32
	vk.EnumeratePhysicalDevices(graphicsContext.instance, &deviceCount, nil)

	if deviceCount == 0 {
		log.log(.Error, "No devices with Vulkan support!")
		panic("No devices with Vulkan support!")
	}

	physicalDevices := make([]vk.PhysicalDevice, deviceCount)
	defer delete(physicalDevices)
	vk.EnumeratePhysicalDevices(graphicsContext.instance, &deviceCount, raw_data(physicalDevices))

	{
		physicalDeviceMap: map[^vk.PhysicalDevice]u32
		defer delete(physicalDeviceMap)
		for &physicalDevice in physicalDevices {
			physicalDeviceMap[&physicalDevice] = scorePhysicalDevice(
				physicalDevice,
				graphicsContext,
			)
		}

		bestScore: u32
		for physicalDevice, score in physicalDeviceMap {
			if (score > bestScore) {
				graphicsContext.physicalDevice = (^vk.PhysicalDevice)(physicalDevice)^
				bestScore = score
			}
		}
	}

	if graphicsContext.physicalDevice == nil {
		log.log(.Error, "No suitable physical device found!")
		panic("No suitable physical device found!")
	}
}

@(private = "file")
createLogicalDevice :: proc(using graphicsContext: ^GraphicsContext) {
	queueFamilies, _ = findQueueFamilies(
		physicalDevice,
		graphicsContext,
	)

	queuePriority: f32 = 1.0
	queueCreateInfos: [dynamic]vk.DeviceQueueCreateInfo
	defer delete(queueCreateInfos)
	queueCreateInfo: vk.DeviceQueueCreateInfo = {
		sType            = .DEVICE_QUEUE_CREATE_INFO,
		pNext            = nil,
		flags            = {},
		queueFamilyIndex = queueFamilies.graphicsFamily,
		queueCount       = 1,
		pQueuePriorities = &queuePriority,
	}
	append(&queueCreateInfos, queueCreateInfo)

	if queueFamilies.graphicsFamily != queueFamilies.presentFamily {
		queueCreateInfo = {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			pNext            = nil,
			flags            = {},
			queueFamilyIndex = queueFamilies.presentFamily,
			queueCount       = 1,
			pQueuePriorities = &queuePriority,
		}
		append(&queueCreateInfos, queueCreateInfo)
	}

	if queueFamilies.graphicsFamily != queueFamilies.computeFamily {
		queueCreateInfo = {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			pNext            = nil,
			flags            = {},
			queueFamilyIndex = queueFamilies.computeFamily,
			queueCount       = 1,
			pQueuePriorities = &queuePriority,
		}
		append(&queueCreateInfos, queueCreateInfo)
	}

	deviceFeatures: vk.PhysicalDeviceFeatures = {
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
		samplerAnisotropy                       = false,
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

	createInfo: vk.DeviceCreateInfo = {
		sType                   = .DEVICE_CREATE_INFO,
		pNext                   = nil,
		flags                   = {},
		queueCreateInfoCount    = u32(len(queueCreateInfos)),
		pQueueCreateInfos       = raw_data(queueCreateInfos[:]),
		enabledLayerCount       = 0,
		ppEnabledLayerNames     = nil,
		enabledExtensionCount   = u32(len(requiredDeviceExtensions)),
		ppEnabledExtensionNames = raw_data(requiredDeviceExtensions[:]),
		pEnabledFeatures        = &deviceFeatures,
	}

	when ODIN_DEBUG {
		createInfo.enabledLayerCount = u32(len(requestedLayers))
		createInfo.ppEnabledLayerNames = raw_data(requestedLayers[:])
	}

	if vk.CreateDevice(
		   physicalDevice,
		   &createInfo,
		   nil,
		   &device,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create logical device!")
		panic("Failed to create logical device!")
	}

	// load_proc_addresses_device :: proc(device: Device)
	vk.load_proc_addresses(device)

	vk.GetDeviceQueue(
		device,
		queueFamilies.graphicsFamily,
		0,
		&graphicsQueue,
	)
	vk.GetDeviceQueue(
		device,
		queueFamilies.presentFamily,
		0,
		&presentQueue,
	)
	vk.GetDeviceQueue(
		device,
		queueFamilies.computeFamily,
		0,
		&computeQueue,
	)
}

// ###################################################################
// #                            Swapchain                            #
// ###################################################################

@(private = "file")
getSwapchainInfo :: proc(using graphicsContext: ^GraphicsContext) {
	swapchainSupport := querySwapchainSupport(physicalDevice, graphicsContext)
	delete(swapchainSupport.formats)
	delete(swapchainSupport.modes)

	ideal := swapchainSupport.capabilities.minImageCount + 1
	max := swapchainSupport.capabilities.maxImageCount
	swapchainImageCount = max if max > 0 && ideal > max else ideal
	swapchainTransform = swapchainSupport.capabilities.currentTransform
}

@(private = "file")
createSwapchain :: proc(using graphicsContext: ^GraphicsContext) {
	chooseFormat :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
		for format in formats {
			if format.format == .R8G8B8A8_UNORM && format.colorSpace == .SRGB_NONLINEAR {
				return format
			}
		}
		return formats[0]
	}

	choosePresentMode :: proc(modes: []vk.PresentModeKHR) -> (mode: vk.PresentModeKHR) {
		for mode in modes {
			if mode == .MAILBOX {
				return mode
			}
		}
		return vk.PresentModeKHR.FIFO
	}

	chooseExtent :: proc(
		capabilities: vk.SurfaceCapabilitiesKHR,
		using graphicsContext: ^GraphicsContext,
	) -> (
		extent: vk.Extent2D,
	) {
		if capabilities.currentExtent.width != max(u32) {
			return capabilities.currentExtent
		}
		width, height := glfw.GetFramebufferSize(window)
		extent.width = clamp(
			u32(width),
			capabilities.minImageExtent.width,
			capabilities.maxImageExtent.width,
		)
		extent.height = clamp(
			u32(height),
			capabilities.minImageExtent.height,
			capabilities.maxImageExtent.height,
		)
		return
	}

	swapchainSupport := querySwapchainSupport(physicalDevice, graphicsContext)
	swapchainFormat = chooseFormat(swapchainSupport.formats)
	swapchainMode = choosePresentMode(swapchainSupport.modes)
	swapchainExtent = chooseExtent(swapchainSupport.capabilities, graphicsContext)
	delete(swapchainSupport.formats)
	delete(swapchainSupport.modes)

	oneQueueFamily :=
		queueFamilies.graphicsFamily == queueFamilies.presentFamily &&
		queueFamilies.graphicsFamily == queueFamilies.computeFamily
	createInfo: vk.SwapchainCreateInfoKHR = {
		sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
		pNext                 = nil,
		flags                 = {},
		surface               = surface,
		minImageCount         = swapchainImageCount,
		imageFormat           = swapchainFormat.format,
		imageColorSpace       = swapchainFormat.colorSpace,
		imageExtent           = swapchainExtent,
		imageArrayLayers      = 1,
		imageUsage            = {.TRANSFER_DST, .COLOR_ATTACHMENT},
		imageSharingMode      = oneQueueFamily ? .EXCLUSIVE : .CONCURRENT,
		queueFamilyIndexCount = oneQueueFamily ? 0 : 2,
		pQueueFamilyIndices   = oneQueueFamily ? nil : raw_data([]u32{queueFamilies.graphicsFamily, queueFamilies.presentFamily, queueFamilies.computeFamily}),
		preTransform          = swapchainTransform,
		compositeAlpha        = {.OPAQUE},
		presentMode           = swapchainMode,
		clipped               = true,
		oldSwapchain          = {},
	}

	if vk.CreateSwapchainKHR(
		   device,
		   &createInfo,
		   nil,
		   &swapchain,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create swapchain!")
		panic("Failed to create swapchain!")
	}

	vk.GetSwapchainImagesKHR(
		device,
		swapchain,
		&swapchainImageCount,
		raw_data(swapchainImages),
	)

	for index in 0 ..< swapchainImageCount {
		swapchainImageViews[index] = createImageView(
			graphicsContext,
			swapchainImages[index],
			.D2,
			swapchainFormat.format,
			{.COLOR},
			1,
		)
	}
}

@(private = "file")
recreateSwapchain :: proc(using graphicsContext: ^GraphicsContext) {
	width, height := glfw.GetFramebufferSize(window)
	for width == 0 && height == 0 {
		width, height = glfw.GetFramebufferSize(window)
		glfw.WaitEvents()
	}

	vk.DeviceWaitIdle(device)
	cleanupSwapchain(graphicsContext)

	createSwapchain(graphicsContext)
	createFramebuffers(graphicsContext)
	createStorageImage(graphicsContext)
	createPostPipeline(graphicsContext)
}

// ###################################################################
// #                             Commands                            #
// ###################################################################

@(private = "file")
createCommandBuffers :: proc(using graphicsContext: ^GraphicsContext) {
	poolInfo: vk.CommandPoolCreateInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		pNext            = nil,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = queueFamilies.graphicsFamily,
	}
	if vk.CreateCommandPool(
		   device,
		   &poolInfo,
		   nil,
		   &graphicsCommandPool,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create command pool!")
		panic("Failed to create command pool!")
	}

	graphicsCommandBuffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
	allocInfo: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = graphicsCommandPool,
		level              = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}
	if vk.AllocateCommandBuffers(
		   device,
		   &allocInfo,
		   raw_data(graphicsCommandBuffers),
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to allocate command buffer!")
		panic("Failed to allocate command buffer!")
	}

	poolInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		pNext            = nil,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = queueFamilies.computeFamily,
	}
	if vk.CreateCommandPool(
		   device,
		   &poolInfo,
		   nil,
		   &computeCommandPool,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create command pool!")
		panic("Failed to create command pool!")
	}

	computeCommandBuffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
	allocInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = computeCommandPool,
		level              = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}
	if vk.AllocateCommandBuffers(
		   device,
		   &allocInfo,
		   raw_data(computeCommandBuffers),
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to allocate command buffer!")
		panic("Failed to allocate command buffer!")
	}
}

@(private = "file")
beginSingleTimeCommands :: proc(
	using graphicsContext: ^GraphicsContext,
	commandPool: vk.CommandPool,
) -> (
	commandBuffer: vk.CommandBuffer,
) {
	allocInfo: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = commandPool,
		level              = .PRIMARY,
		commandBufferCount = 1,
	}
	vk.AllocateCommandBuffers(device, &allocInfo, &commandBuffer)
	beginInfo: vk.CommandBufferBeginInfo = {
		sType            = .COMMAND_BUFFER_BEGIN_INFO,
		pNext            = nil,
		flags            = {.ONE_TIME_SUBMIT},
		pInheritanceInfo = nil,
	}
	vk.BeginCommandBuffer(commandBuffer, &beginInfo)
	return
}

@(private = "file")
endSingleTimeCommands :: proc(
	using graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	commandPool: vk.CommandPool,
) {
	commandBuffer := commandBuffer
	vk.EndCommandBuffer(commandBuffer)
	submitInfo: vk.SubmitInfo = {
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
	fence: vk.Fence
	fenceCreateInfo: vk.FenceCreateInfo = {
		sType = .FENCE_CREATE_INFO,
		pNext = nil,
		flags = {},
	}
	vk.QueueSubmit(graphicsQueue, 1, &submitInfo, fence)
	vk.QueueWaitIdle(graphicsQueue)
	vk.FreeCommandBuffers(device, commandPool, 1, &commandBuffer)
}

// ###################################################################
// #                             Buffers                             #
// ###################################################################

@(private = "file")
createBuffer :: proc(
	using graphicsContext: ^GraphicsContext,
	size: int,
	usage: vk.BufferUsageFlags,
	properties: vk.MemoryPropertyFlags,
	buffer: ^vk.Buffer,
	bufferMemory: ^vk.DeviceMemory,
) {
	bufferInfo: vk.BufferCreateInfo = {
		sType                 = .BUFFER_CREATE_INFO,
		pNext                 = nil,
		flags                 = {},
		size                  = vk.DeviceSize(size),
		usage                 = usage,
		sharingMode           = .EXCLUSIVE,
		queueFamilyIndexCount = 0,
		pQueueFamilyIndices   = nil,
	}
	if vk.CreateBuffer(device, &bufferInfo, nil, buffer) != .SUCCESS {
		log.log(.Error, "Failed to create buffer!")
		panic("Failed to create buffer!")
	}

	memRequirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(device, buffer^, &memRequirements)
	allocInfo: vk.MemoryAllocateInfo = {
		sType           = .MEMORY_ALLOCATE_INFO,
		pNext           = nil,
		allocationSize  = memRequirements.size,
		memoryTypeIndex = findMemoryType(
			graphicsContext,
			memRequirements.memoryTypeBits,
			properties,
		),
	}
	if vk.AllocateMemory(device, &allocInfo, nil, bufferMemory) != .SUCCESS {
		log.log(.Error, "Failed to allocate buffer memory!")
		panic("Failed to allocate buffer memory!")
	}
	vk.BindBufferMemory(device, buffer^, bufferMemory^, 0)
}

@(private = "file")
loadBufferToGPU :: proc(
	using graphicsContext: ^GraphicsContext,
	bufferSize: int,
	srcData: rawptr,
	dstBuffer: ^Buffer,
	bufferType: vk.BufferUsageFlag,
) {
	copyBuffer :: proc(
		using graphicsContext: ^GraphicsContext,
		srcBuffer, dstBuffer: vk.Buffer,
		size: int,
	) {
		commandBuffer: vk.CommandBuffer = beginSingleTimeCommands(
			graphicsContext,
			graphicsCommandPool,
		)
		copyRegion: vk.BufferCopy = {
			srcOffset = 0,
			dstOffset = 0,
			size      = vk.DeviceSize(size),
		}
		vk.CmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion)
		endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)
	}

	stagingBuffer: vk.Buffer
	stagingBufferMemory: vk.DeviceMemory
	createBuffer(
		graphicsContext,
		bufferSize,
		{.TRANSFER_SRC},
		{.HOST_VISIBLE, .HOST_COHERENT},
		&stagingBuffer,
		&stagingBufferMemory,
	)

	data: rawptr
	vk.MapMemory(
		device,
		stagingBufferMemory,
		0,
		(vk.DeviceSize)(bufferSize),
		{},
		&data,
	)
	mem.copy(data, srcData, bufferSize)
	vk.UnmapMemory(device, stagingBufferMemory)

	createBuffer(
		graphicsContext,
		bufferSize,
		{.TRANSFER_DST, bufferType},
		{.DEVICE_LOCAL},
		&dstBuffer^.buffer,
		&dstBuffer^.memory,
	)

	copyBuffer(graphicsContext, stagingBuffer, dstBuffer^.buffer, bufferSize)
	vk.DestroyBuffer(device, stagingBuffer, nil)
	vk.FreeMemory(device, stagingBufferMemory, nil)
}

@(private = "file")
createVertexBuffer :: proc(using graphicsContext: ^GraphicsContext) {
	loadBufferToGPU(
		graphicsContext,
		size_of(Vertex) * len(vertices),
		raw_data(vertices),
		&vertexBuffer,
		.VERTEX_BUFFER,
	)
	vertexBuffer.mapped = nil
}

@(private = "file")
createIndexBuffer :: proc(using graphicsContext: ^GraphicsContext) {
	loadBufferToGPU(
		graphicsContext,
		size_of(u32) * len(indices),
		raw_data(indices),
		&indexBuffer,
		.INDEX_BUFFER,
	)
	indexBuffer.mapped = nil
}

@(private = "file")
createViewProjectionUniform :: proc(using graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(ViewProjectionUniform),
			{.UNIFORM_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&viewProjectionUniforms[i].buffer,
			&viewProjectionUniforms[i].memory,
		)
		vk.MapMemory(
			device,
			viewProjectionUniforms[i].memory,
			0,
			size_of(ViewProjectionUniform),
			{},
			&viewProjectionUniforms[i].mapped,
		)
	}
}

@(private = "file")
createInstanceBuffer :: proc(using graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Instance) * len(instances),
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&instanceBuffers[i].buffer,
			&instanceBuffers[i].memory,
		)
		vk.MapMemory(
			device,
			instanceBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Instance) * len(instances)),
			{},
			&instanceBuffers[i].mapped,
		)
	}
}

@(private = "file")
createBoneBuffer :: proc(using graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Mat4) * boneCount,
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&boneBuffers[i].buffer,
			&boneBuffers[i].memory,
		)
		vk.MapMemory(
			device,
			boneBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Mat4) * boneCount),
			{},
			&boneBuffers[i].mapped,
		)
	}
}

@(private = "file")
createLightBuffer :: proc(using graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Mat4) * len(lightsBuffers),
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&lightsBuffers[i].buffer,
			&lightsBuffers[i].memory,
		)
		vk.MapMemory(
			device,
			lightsBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Mat4) * len(lightsBuffers)),
			{},
			&lightsBuffers[i].mapped,
		)
	}
}

// ###################################################################
// #                              Images                             #
// ###################################################################

@(private = "file")
findMemoryType :: proc(
	using graphicsContext: ^GraphicsContext,
	typeFilter: u32,
	properties: vk.MemoryPropertyFlags,
) -> u32 {
	memProperties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties)
	for i in 0 ..< memProperties.memoryTypeCount {
		if typeFilter & (1 << i) != 0 &&
		   (memProperties.memoryTypes[i].propertyFlags & properties) == properties {
			return i
		}
	}
	log.log(.Error, "Failed to find suitable memory type!")
	panic("Failed to find suitable memory type!")
}

@(private = "file")
createImage :: proc(
	using graphicsContext: ^GraphicsContext,
	image: ^Image,
	flags: vk.ImageCreateFlags,
	imageType: vk.ImageType,
	width, height, arrayLayers: u32,
	sampleCount: vk.SampleCountFlags,
	tiling: vk.ImageTiling,
	usage: vk.ImageUsageFlags,
	properties: vk.MemoryPropertyFlags,
	sharingMode: vk.SharingMode,
	queueFamilyIndexCount: u32,
	queueFamilyIndices: [^]u32,
) {
	imageInfo: vk.ImageCreateInfo = {
		sType                 = .IMAGE_CREATE_INFO,
		pNext                 = nil,
		flags                 = flags,
		imageType             = imageType,
		format                = image.format,
		extent                = {width, height, 1},
		mipLevels             = 1,
		arrayLayers           = arrayLayers,
		samples               = sampleCount,
		tiling                = tiling,
		usage                 = usage,
		sharingMode           = sharingMode,
		queueFamilyIndexCount = queueFamilyIndexCount,
		pQueueFamilyIndices   = queueFamilyIndices,
		initialLayout         = .UNDEFINED,
	}

	if vk.CreateImage(device, &imageInfo, nil, &image^.image) != .SUCCESS {
		log.log(.Error, "Failed to create texture!")
		panic("Failed to create texture!")
	}

	memRequirements: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(device, image^.image, &memRequirements)
	allocInfo: vk.MemoryAllocateInfo = {
		sType           = .MEMORY_ALLOCATE_INFO,
		pNext           = nil,
		allocationSize  = memRequirements.size,
		memoryTypeIndex = findMemoryType(
			graphicsContext,
			memRequirements.memoryTypeBits,
			properties,
		),
	}
	if vk.AllocateMemory(device, &allocInfo, nil, &image.memory) != .SUCCESS {
		log.log(.Error, "Failed to allocate image memory!")
		panic("Failed to allocate image memory!")
	}
	if vk.BindImageMemory(device, image.image, image.memory, 0) != .SUCCESS {
		log.log(.Error, "Failed to bind image memory!")
		panic("Failed to bind image memory!")
	}
}

@(private = "file")
createImageView :: proc(
	using graphicsContext: ^GraphicsContext,
	image: vk.Image,
	viewType: vk.ImageViewType,
	format: vk.Format,
	aspectFlags: vk.ImageAspectFlags,
	layerCount: u32,
) -> (
	imageView: vk.ImageView,
) {
	viewInfo: vk.ImageViewCreateInfo = {
		sType = vk.StructureType.IMAGE_VIEW_CREATE_INFO,
		pNext = nil,
		flags = {},
		image = image,
		viewType = viewType,
		format = format,
		components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
		subresourceRange = vk.ImageSubresourceRange {
			aspectMask = aspectFlags,
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = layerCount,
		},
	}
	if vk.CreateImageView(device, &viewInfo, nil, &imageView) != .SUCCESS {
		log.log(.Error, "Failed to create image view!")
		panic("Failed to create image view!")
	}
	return imageView
}

transitionImageLayout :: proc(
	using graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	image: vk.Image,
	oldLayout, newLayout: vk.ImageLayout,
	layerCount: u32,
) {
	barrier: vk.ImageMemoryBarrier = {
		sType = .IMAGE_MEMORY_BARRIER,
		pNext = nil,
		srcAccessMask = {},
		dstAccessMask = {},
		oldLayout = oldLayout,
		newLayout = newLayout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = vk.ImageSubresourceRange {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = layerCount,
		},
	}
	sourceStage, destinationStage: vk.PipelineStageFlags
	#partial switch oldLayout {
	case .UNDEFINED:
		barrier.srcAccessMask = {}
		sourceStage = {.TOP_OF_PIPE}
	case .TRANSFER_SRC_OPTIMAL:
		barrier.srcAccessMask = {.TRANSFER_READ}
		sourceStage = {.TRANSFER}
	case .TRANSFER_DST_OPTIMAL:
		barrier.srcAccessMask = {.TRANSFER_WRITE}
		sourceStage = {.TRANSFER}
	case:
		log.log(.Error, "Unsupported image layout transition!")
		panic("Unsupported image layout transition!")
	}

	#partial switch newLayout {
	case .TRANSFER_SRC_OPTIMAL:
		barrier.dstAccessMask = {.TRANSFER_READ}
		destinationStage = {.TRANSFER}
	case .TRANSFER_DST_OPTIMAL:
		barrier.dstAccessMask = {.TRANSFER_WRITE}
		destinationStage = {.TRANSFER}
	case .SHADER_READ_ONLY_OPTIMAL:
		if (barrier.srcAccessMask == {}) {
			barrier.srcAccessMask = {.HOST_WRITE, .TRANSFER_WRITE}
		}
		barrier.dstAccessMask = {.SHADER_READ}
		destinationStage = {.FRAGMENT_SHADER}
	case .GENERAL:
		if oldLayout == .TRANSFER_SRC_OPTIMAL {
			barrier.dstAccessMask = {.SHADER_WRITE}
		} else if oldLayout == .TRANSFER_DST_OPTIMAL {
			barrier.dstAccessMask = {.SHADER_READ}
		}
		destinationStage = {.COMPUTE_SHADER}
	case .PRESENT_SRC_KHR:
		barrier.dstAccessMask = {.SHADER_READ}
		destinationStage = {.COMPUTE_SHADER}
	case:
		log.log(.Error, "Unsupported image layout transition!")
		panic("Unsupported image layout transition!")
	}
	vk.CmdPipelineBarrier(
		commandBuffer,
		sourceStage,
		destinationStage,
		{},
		0,
		nil,
		0,
		nil,
		1,
		&barrier,
	)
}

copyBufferToImage :: proc(
	using graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	buffer: vk.Buffer,
	image: vk.Image,
	width, height: u32,
) {
	region: vk.BufferImageCopy = {
		bufferOffset = 0,
		bufferRowLength = 0,
		bufferImageHeight = 0,
		imageSubresource = vk.ImageSubresourceLayers {
			aspectMask = {.COLOR},
			mipLevel = 0,
			baseArrayLayer = 0,
			layerCount = 1,
		},
		imageOffset = vk.Offset3D{x = 0, y = 0, z = 0},
		imageExtent = vk.Extent3D{width = width, height = height, depth = 1},
	}
	vk.CmdCopyBufferToImage(commandBuffer, buffer, image, .TRANSFER_DST_OPTIMAL, 1, &region)
}

copyBufferToTextureArray :: proc(
	using graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	buffer: vk.Buffer,
	image: vk.Image,
	width, height, textureCount: u32,
) {
	regions := make([]vk.BufferImageCopy, textureCount)
	defer delete(regions)
	imageSize := width * height * 4
	for &region, index in regions {
		index := u32(index)
		region = {
			bufferOffset = vk.DeviceSize(imageSize * index),
			bufferRowLength = 0,
			bufferImageHeight = 0,
			imageSubresource = vk.ImageSubresourceLayers {
				aspectMask = {.COLOR},
				mipLevel = 0,
				baseArrayLayer = u32(index),
				layerCount = 1,
			},
			imageOffset = vk.Offset3D{x = 0, y = 0, z = 0},
			imageExtent = vk.Extent3D{width = width, height = height, depth = 1},
		}
	}
	vk.CmdCopyBufferToImage(
		commandBuffer,
		buffer,
		image,
		.TRANSFER_DST_OPTIMAL,
		u32(len(regions)),
		raw_data(regions),
	)
}

copyImage :: proc(
	commandBuffer: vk.CommandBuffer,
	extent: vk.Extent3D,
	srcImage, dstImage: vk.Image,
	srcLayout, dstLayout: vk.ImageLayout,
) {
	region: vk.ImageCopy = {
		srcSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		srcOffset = {x = 0, y = 0, z = 0},
		dstSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		dstOffset = {x = 0, y = 0, z = 0},
		extent = extent,
	}
	vk.CmdCopyImage(commandBuffer, srcImage, srcLayout, dstImage, dstLayout, 1, &region)
}

upscaleImage :: proc(
	commandBuffer: vk.CommandBuffer,
	src, dst: vk.Image,
	srcSize, dstSize: vk.Extent2D,
) {
	blit: vk.ImageBlit = {
		srcSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		srcOffsets = {
			{x = 0, y = 0, z = 0},
			{x = i32(srcSize.width), y = i32(srcSize.height), z = 1},
		},
		dstSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		dstOffsets = {
			{x = 0, y = 0, z = 0},
			{x = i32(dstSize.width), y = i32(dstSize.height), z = 1},
		},
	}

	vk.CmdBlitImage(
		commandBuffer,
		src,
		.TRANSFER_SRC_OPTIMAL,
		dst,
		.TRANSFER_DST_OPTIMAL,
		1,
		&blit,
		.NEAREST,
	)
}

// ###################################################################
// #                          Create Assets                          #
// ###################################################################

@(private = "file")
loadModels :: proc(using graphicsContext: ^GraphicsContext, modelPaths: []cstring) {
	loadFBX :: proc(graphicsContext: ^GraphicsContext, model: ^Model, filename: cstring) {
		loadMesh :: proc(
			mesh: ^fbx.Mesh,
			skeleton: ^Skeleton,
			vertices: ^[dynamic]Vertex,
			indices: ^[dynamic]u32,
		) -> (
			indexCount: u32,
		) {
			indexCount = u32(3 * mesh.num_triangles)
			offset := u32(len(indices))
			indexOffset := u32(len(vertices))
			resize(indices, offset + indexCount)
			for index in 0 ..< mesh.faces.count {
				face := mesh.faces.data[index]
				tris := fbx.catch_triangulate_face(
					nil,
					&indices[offset],
					uint(indexCount),
					mesh,
					face,
				)
				count := 3 * tris
				for &indice in indices[offset:offset + count] {
					indice += indexOffset
				}
				offset += count
			}

			vertexCount := mesh.num_indices
			reserve(vertices, uint(len(vertices)) + vertexCount)
			for index in 0 ..< vertexCount {
				vertexIndex := mesh.vertex_position.indices.data[index]
				pos := mesh.vertex_position.values.data[vertexIndex]
				uv := mesh.vertex_uv.values.data[mesh.vertex_uv.indices.data[index]]
				norm := mesh.vertex_normal.values.data[mesh.vertex_normal.indices.data[index]]

				vertex: Vertex = {
					position = {f32(pos.x), f32(pos.y), f32(pos.z)},
					texCoord = {f32(uv.x), 1 - f32(uv.y)},
					normal   = {f32(norm.x), f32(norm.y), f32(norm.z)},
					weights  = {1, 0, 0, 0},
					bones    = {0, 0, 0, 0},
				}
				if len(skeleton) != 0 && mesh.skin_deformers.count != 0 {
					deformer := mesh.skin_deformers.data[0]
					numWeights := deformer.vertices.data[vertexIndex].num_weights
					if numWeights > 4 {
						numWeights = 4
					}
					firstWeightIndex := deformer.vertices.data[vertexIndex].weight_begin
					totalWeight: f32 = 0
					for j in 0 ..< numWeights {
						skinWeight := deformer.weights.data[firstWeightIndex + j]
						boneName :=
							deformer.clusters.data[skinWeight.cluster_index].bone_node.element.name
						for bone, k in skeleton^ {
							if bone.name == boneName.data {
								vertex.bones[j] = u32(k)
								break
							}
						}
						vertex.weights[j] = f32(skinWeight.weight)
						totalWeight += f32(skinWeight.weight)
					}
					if totalWeight != 1.0 {
						for j in 0 ..< numWeights {
							vertex.weights[j] /= totalWeight
						}
					}
				}
				append(vertices, vertex)
			}
			return
		}

		loadBone :: proc(skeleton: ^[dynamic]Bone, node: ^fbx.Node) {
			parentIndex: u32 = 0
			if !node^.parent.is_root {
				for bone, index in skeleton {
					if bone.name == node^.parent^.element.name.data {
						parentIndex = u32(index)
						break
					}
				}
			}
			bone: Bone = {
				name        = node^.bone^.element.name.data,
				isRoot      = node^.parent^.is_root,
				parentIndex = parentIndex,
			}
			append(skeleton, bone)
		}

		opts: fbx.Load_Opts = {
			target_axes = fbx.Coordinate_Axes {
				right = .POSITIVE_X,
				up = .POSITIVE_Y,
				front = .NEGATIVE_Z,
			},
		}
		err: fbx.Error = {}
		scene := fbx.load_file(filename, &opts, &err)
		defer fbx.free_scene(scene)
		if scene == nil {
			log.logf(.Error, "Failed to load FBX file! Reason\n{}", err.description.data)
			panic("Failed to load FBX file!")
		}

		meshes: [dynamic]^fbx.Mesh
		defer delete(meshes)
		skeleton: [dynamic]Bone
		for index in 0 ..< scene.nodes.count {
			node := scene^.nodes.data[index]
			if node.is_root do continue
			if node.mesh != nil do append(&meshes, node.mesh)
			if node.bone != nil do loadBone(&skeleton, node)
		}
		model^.skeleton = skeleton[:]

		vertices: [dynamic]Vertex
		indices: [dynamic]u32
		indexCount: u32 = 0
		for mesh in meshes {
			indexCount += loadMesh(mesh, &model^.skeleton, &vertices, &indices)
		}
		model^.vertices = vertices[:]
		model^.indices = indices[:]
		model^.indexCount = indexCount

		for index in 0 ..< scene.skin_cluster.count {
			skinCluster := scene.skin_cluster.data[index]^
			for &bone, index in model^.skeleton {
				if bone.name != skinCluster.bone_node^.element.name.data {
					continue
				}
				m := skinCluster.geometry_to_bone.cols
				bone.inverseBind = {
					f32(m[0][0]),
					f32(m[1][0]),
					f32(m[2][0]),
					f32(m[3][0]),
					f32(m[0][1]),
					f32(m[1][1]),
					f32(m[2][1]),
					f32(m[3][1]),
					f32(m[0][2]),
					f32(m[1][2]),
					f32(m[2][2]),
					f32(m[3][2]),
					0,
					0,
					0,
					1,
				}
				break
			}
		}

		model^.animations = make([]Anim, scene^.anim_stacks.count)
		for animIndex in 0 ..< scene^.anim_stacks.count {
			stack := scene^.anim_stacks.data[animIndex]
			bakedAnim := fbx.bake_anim(scene, stack^.anim, nil, &err)
			defer fbx.free_baked_anim(bakedAnim)
			animation := &model^.animations[animIndex]
			animation^.duration = bakedAnim^.playback_duration
			animation^.nodes = make([]AnimNode, bakedAnim.nodes.count)
			for bakedIndex in 0 ..< bakedAnim.nodes.count {
				bakedNode := bakedAnim.nodes.data[bakedIndex]
				sceneNode := scene^.nodes.data[bakedNode.typed_id]
				for bone, index in model^.skeleton {
					if bone.name != sceneNode^.element.name.data {
						continue
					}
					animNode := AnimNode {
						bone            = u32(index),
						keyPositions    = make([]KeyVector, bakedNode.translation_keys.count),
						keyRotations    = make([]KeyQuat, bakedNode.rotation_keys.count),
						keyScales       = make([]KeyVector, bakedNode.scale_keys.count),
						numKeyPositions = bakedNode.translation_keys.count,
						numKeyRotations = bakedNode.rotation_keys.count,
						numKeyScales    = bakedNode.scale_keys.count,
					}
					for index in 0 ..< bakedNode.translation_keys.count {
						data := bakedNode.translation_keys.data[index]
						animNode.keyPositions[index].time = data.time
						animNode.keyPositions[index].value.x = f32(data.value[0])
						animNode.keyPositions[index].value.y = f32(data.value[1])
						animNode.keyPositions[index].value.z = f32(data.value[2])
					}
					for index in 0 ..< bakedNode.rotation_keys.count {
						data := bakedNode.rotation_keys.data[index]
						animNode.keyRotations[index].time = data.time
						animNode.keyRotations[index].value.x = f32(data.value[0])
						animNode.keyRotations[index].value.y = f32(data.value[1])
						animNode.keyRotations[index].value.z = f32(data.value[2])
						animNode.keyRotations[index].value.w = f32(data.value[3])
					}
					for index in 0 ..< bakedNode.scale_keys.count {
						data := bakedNode.scale_keys.data[index]
						animNode.keyScales[index].time = data.time
						animNode.keyScales[index].value.x = f32(data.value[0])
						animNode.keyScales[index].value.y = f32(data.value[1])
						animNode.keyScales[index].value.z = f32(data.value[2])
					}
					animation^.nodes[bakedIndex] = animNode
					break
				}
			}
		}
	}

	models = make([]Model, len(modelPaths))
	verticesDynamic: [dynamic]Vertex
	indicesDynamic: [dynamic]u32
	vertexCount: u32 = 0
	indexCount: u32 = 0
	for path, index in modelPaths {
		models[index].vertexOffset = vertexCount
		models[index].indexOffset = indexCount
		loadFBX(graphicsContext, &models[index], path)
		append(&verticesDynamic, ..models[index].vertices)
		append(&indicesDynamic, ..models[index].indices)
		vertexCount = u32(len(verticesDynamic))
		indexCount = u32(len(indicesDynamic))
	}
	vertices = verticesDynamic[:]
	indices = indicesDynamic[:]
}

@(private = "file")
loadTextures :: proc(using graphicsContext: ^GraphicsContext, texture: ^Image, texturePaths: []cstring) {
	textureWidth, textureHeight: i32
	pixels := img.load(texturePaths[0], &textureWidth, &textureHeight, nil, 4)
	if pixels == nil {
		log.log(.Error, "Failed to load texture!")
		panic("Failed to load texture!")
	}
	img.image_free(pixels)
	textureSize := int(textureWidth * textureHeight * 4)
	textureCount := len(texturePaths)

	stagingBuffer: vk.Buffer
	stagingBufferMemory: vk.DeviceMemory
	createBuffer(
		graphicsContext,
		textureSize * textureCount,
		{.TRANSFER_SRC},
		{.HOST_VISIBLE, .HOST_COHERENT},
		&stagingBuffer,
		&stagingBufferMemory,
	)

	for path, index in texturePaths {
		width, height: i32
		pixels := img.load(path, &width, &height, nil, 4)
		defer img.image_free(pixels)
		if pixels == nil {
			log.log(.Error, "Failed to load texture!")
			panic("Failed to load texture!")
		}

		if textureWidth != width || textureHeight != height {
			log.log(.Error, "Image of wrong dims!")
			panic("Image of wrong dims!")
		}

		data: rawptr
		vk.MapMemory(
			device,
			stagingBufferMemory,
			vk.DeviceSize(textureSize * index),
			vk.DeviceSize(textureSize),
			{},
			&data,
		)
		mem.copy(data, pixels, textureSize)
		vk.UnmapMemory(device, stagingBufferMemory)
	}

	texture.format = .R8G8B8A8_SRGB
	createImage(
		graphicsContext,
		texture,
		{},
		.D2,
		u32(textureWidth),
		u32(textureHeight),
		u32(textureCount),
		{._1},
		.OPTIMAL,
		{.TRANSFER_DST, .TRANSFER_SRC, .SAMPLED},
		{.DEVICE_LOCAL},
		.EXCLUSIVE,
		0,
		nil,
	)

	commandBuffer := beginSingleTimeCommands(graphicsContext, graphicsCommandPool)
	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		texture^.image,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		u32(textureCount),
	)

	copyBufferToTextureArray(
		graphicsContext,
		commandBuffer,
		stagingBuffer,
		texture^.image,
		u32(textureWidth),
		u32(textureHeight),
		u32(textureCount),
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		texture^.image,
		.TRANSFER_DST_OPTIMAL,
		.SHADER_READ_ONLY_OPTIMAL,
		u32(textureCount),
	)
	endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)

	vk.DestroyBuffer(device, stagingBuffer, nil)
	vk.FreeMemory(device, stagingBufferMemory, nil)

	texture.view = createImageView(
		graphicsContext,
		texture.image,
		.D2_ARRAY,
		texture.format,
		{.COLOR},
		u32(textureCount),
	)

	properties: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(physicalDevice, &properties)
	texture.sampler = createSampler(
		graphicsContext,
		.LINEAR,
		.LINEAR,
		.CLAMP_TO_EDGE,
		false,
		properties.limits.maxSamplerAnisotropy,
	)
}

@(private = "file")
createSampler :: proc(
	using graphicsContext: ^GraphicsContext,
	filter: vk.Filter,
	mipMode: vk.SamplerMipmapMode,
	addressMode: vk.SamplerAddressMode,
	anistropyEnabled: b32,
	maxAnistropy: f32,
) -> (
	sampler: vk.Sampler,
) {
	samplerInfo: vk.SamplerCreateInfo = {
		sType                   = .SAMPLER_CREATE_INFO,
		pNext                   = nil,
		flags                   = {},
		magFilter               = filter,
		minFilter               = filter,
		mipmapMode              = mipMode,
		addressModeU            = addressMode,
		addressModeV            = addressMode,
		addressModeW            = addressMode,
		mipLodBias              = 0,
		anisotropyEnable        = anistropyEnabled,
		maxAnisotropy           = maxAnistropy,
		compareEnable           = false,
		compareOp               = .ALWAYS,
		minLod                  = 0,
		maxLod                  = vk.LOD_CLAMP_NONE,
		borderColor             = .INT_OPAQUE_BLACK,
		unnormalizedCoordinates = false,
	}
	if vk.CreateSampler(device, &samplerInfo, nil, &sampler) != .SUCCESS {
		log.log(.Error, "Failed to create texture sampler!")
		panic("Failed to create texture sampler!")
	}
	return
}

@(private = "file")
loadAssets :: proc(using graphicsContext: ^GraphicsContext) {
	if hasAssetsLoaded {
		cleanupAssets(graphicsContext)
	}

	loadModels(graphicsContext, {MODEL_PATH})

	createVertexBuffer(graphicsContext)
	createIndexBuffer(graphicsContext)

	loadTextures(graphicsContext, &albidos, {TEXTURE_PATH})
	loadTextures(graphicsContext, &normals, {NORMALS_PATH})

	now := time.now()
	instances = make([]Instance, 1)
	instances[0] = {
		modelID       = 0,
		animID        = 0,
		textureID     = 0,
		position      = {0, 0, 0},
		rotation      = quatFromY(f32(radians(180.0))),
		scale         = {0.003, 0.003, 0.003},
		animStartTime = now,
	}
	skeletonLength := len(models[instances[0].modelID].skeleton)
	boneCount += skeletonLength
	instances[0].positionKeys = make([]u32, skeletonLength)
	instances[0].rotationKeys = make([]u32, skeletonLength)
	instances[0].scaleKeys = make([]u32, skeletonLength)

	createInstanceBuffer(graphicsContext)
	createBoneBuffer(graphicsContext)
	createLightBuffer(graphicsContext)

	hasAssetsLoaded = true
}

// ###################################################################
// #                        Shader Descriptors                       #
// ###################################################################

@(private = "file")
createDescriptorSets :: proc(using graphicsContext: ^GraphicsContext) {
	// MAIN
	{
		poolSizes: []vk.DescriptorPoolSize = {
			{type = .UNIFORM_BUFFER, descriptorCount = 1},
			{type = .STORAGE_BUFFER, descriptorCount = 2},
			{type = .COMBINED_IMAGE_SAMPLER, descriptorCount = 2},
		}

		poolInfo: vk.DescriptorPoolCreateInfo = {
			sType         = .DESCRIPTOR_POOL_CREATE_INFO,
			pNext         = nil,
			flags         = {},
			maxSets       = MAX_FRAMES_IN_FLIGHT,
			poolSizeCount = u32(len(poolSizes)),
			pPoolSizes    = raw_data(poolSizes),
		}

		if vk.CreateDescriptorPool(
			device,
			&poolInfo,
			nil,
			&pipelines[PipelineIndex.MAIN].descriptorPool,
		) !=
		.SUCCESS {
			log.log(.Error, "Failed to create descriptor pool!")
			panic("Failed to create descriptor pool!")
		}

		layoutBindings: []vk.DescriptorSetLayoutBinding = {
			{
				binding = 0,
				descriptorType = .UNIFORM_BUFFER,
				descriptorCount = 1,
				stageFlags = {.VERTEX},
				pImmutableSamplers = nil,
			},
			{
				binding = 1,
				descriptorType = .STORAGE_BUFFER,
				descriptorCount = 1,
				stageFlags = {.VERTEX},
				pImmutableSamplers = nil,
			},
			{
				binding = 2,
				descriptorType = .STORAGE_BUFFER,
				descriptorCount = 1,
				stageFlags = {.VERTEX},
				pImmutableSamplers = nil,
			},
			{
				binding = 3,
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				stageFlags = {.FRAGMENT},
				pImmutableSamplers = nil,
			},
			{
				binding = 4,
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				stageFlags = {.FRAGMENT},
				pImmutableSamplers = nil,
			},
		}

		layoutInfo: vk.DescriptorSetLayoutCreateInfo = {
			sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
			pNext        = nil,
			flags        = {},
			bindingCount = u32(len(layoutBindings)),
			pBindings    = raw_data(layoutBindings),
		}

		if vk.CreateDescriptorSetLayout(
			device,
			&layoutInfo,
			nil,
			&pipelines[PipelineIndex.MAIN].descriptorSetLayout,
		) !=
		.SUCCESS {
			log.log(.Error, "Failed to create descriptor set layout!")
			panic("Failed to create descriptor set layout!")
		}

		layouts := make([]vk.DescriptorSetLayout, MAX_FRAMES_IN_FLIGHT)
		defer delete(layouts)

		for &layout in layouts {
			layout = pipelines[PipelineIndex.MAIN].descriptorSetLayout
		}

		allocInfo: vk.DescriptorSetAllocateInfo = {
			sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
			pNext              = nil,
			descriptorPool     = pipelines[PipelineIndex.MAIN].descriptorPool,
			descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
			pSetLayouts        = raw_data(layouts),
		}

		if vk.AllocateDescriptorSets(
			device,
			&allocInfo,
			raw_data(pipelines[PipelineIndex.MAIN].descriptorSets[:]),
		) !=
		.SUCCESS {
			log.log(.Error, "Failed to allocate descriptor sets!")
			panic("Failed to allocate descriptor sets!")
		}

		textureInfo: vk.DescriptorImageInfo = {
			sampler     = albidos.sampler,
			imageView   = albidos.view,
			imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		}

		normalInfo: vk.DescriptorImageInfo = {
			sampler     = normals.sampler,
			imageView   = normals.view,
			imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		}

		for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
			uniformBufferInfo: vk.DescriptorBufferInfo = {
				buffer = viewProjectionUniforms[index].buffer,
				offset = 0,
				range  = size_of(ViewProjectionUniform),
			}

			instanceBufferInfo: vk.DescriptorBufferInfo = {
				buffer = instanceBuffers[index].buffer,
				offset = 0,
				range  = vk.DeviceSize(len(instances) * size_of(InstanceInfo)),
			}

			boneBufferInfo: vk.DescriptorBufferInfo = {
				buffer = boneBuffers[index].buffer,
				offset = 0,
				range  = vk.DeviceSize(boneCount * size_of(Mat4)),
			}

			descriptorWrite: []vk.WriteDescriptorSet = {
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.MAIN].descriptorSets[index],
					dstBinding = 0,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .UNIFORM_BUFFER,
					pImageInfo = nil,
					pBufferInfo = &uniformBufferInfo,
					pTexelBufferView = nil,
				},
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.MAIN].descriptorSets[index],
					dstBinding = 1,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .STORAGE_BUFFER,
					pImageInfo = nil,
					pBufferInfo = &instanceBufferInfo,
					pTexelBufferView = nil,
				},
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.MAIN].descriptorSets[index],
					dstBinding = 2,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .STORAGE_BUFFER,
					pImageInfo = nil,
					pBufferInfo = &boneBufferInfo,
					pTexelBufferView = nil,
				},
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.MAIN].descriptorSets[index],
					dstBinding = 3,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .COMBINED_IMAGE_SAMPLER,
					pImageInfo = &textureInfo,
					pBufferInfo = nil,
					pTexelBufferView = nil,
				},
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.MAIN].descriptorSets[index],
					dstBinding = 4,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .COMBINED_IMAGE_SAMPLER,
					pImageInfo = &normalInfo,
					pBufferInfo = nil,
					pTexelBufferView = nil,
				},
			}
			vk.UpdateDescriptorSets(
				device,
				u32(len(descriptorWrite)),
				raw_data(descriptorWrite),
				0,
				nil,
			)
		}
	}

	// POST
	{
		poolSizes: []vk.DescriptorPoolSize = {{type = .STORAGE_IMAGE, descriptorCount = 2}}
		poolInfo: vk.DescriptorPoolCreateInfo = {
			sType         = .DESCRIPTOR_POOL_CREATE_INFO,
			pNext         = nil,
			flags         = {},
			maxSets       = MAX_FRAMES_IN_FLIGHT,
			poolSizeCount = u32(len(poolSizes)),
			pPoolSizes    = raw_data(poolSizes),
		}

		if vk.CreateDescriptorPool(
			device,
			&poolInfo,
			nil,
			&pipelines[PipelineIndex.POST].descriptorPool,
		) !=
		.SUCCESS {
			log.log(.Error, "Failed to create descriptor pool!")
			panic("Failed to create descriptor pool!")
		}

		layoutBindings: []vk.DescriptorSetLayoutBinding = {
			{
				binding = 0,
				descriptorType = .STORAGE_IMAGE,
				descriptorCount = 1,
				stageFlags = {.COMPUTE},
				pImmutableSamplers = nil,
			},
			{
				binding = 1,
				descriptorType = .STORAGE_IMAGE,
				descriptorCount = 1,
				stageFlags = {.COMPUTE},
				pImmutableSamplers = nil,
			},
		}
		layoutInfo: vk.DescriptorSetLayoutCreateInfo = {
			sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
			pNext        = nil,
			flags        = {},
			bindingCount = u32(len(layoutBindings)),
			pBindings    = raw_data(layoutBindings),
		}
		if vk.CreateDescriptorSetLayout(
			device,
			&layoutInfo,
			nil,
			&pipelines[PipelineIndex.POST].descriptorSetLayout,
		) !=
		.SUCCESS {
			log.log(.Error, "Failed to create compute descriptor set layout!")
			panic("Failed to create compute descriptor set layout!")
		}

		layouts := make([]vk.DescriptorSetLayout, MAX_FRAMES_IN_FLIGHT)
		defer delete(layouts)
		for &layout in layouts {
			layout = pipelines[PipelineIndex.POST].descriptorSetLayout
		}

		allocInfo: vk.DescriptorSetAllocateInfo = {
			sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
			pNext              = nil,
			descriptorPool     = pipelines[PipelineIndex.POST].descriptorPool,
			descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
			pSetLayouts        = raw_data(layouts),
		}

		if vk.AllocateDescriptorSets(
			device,
			&allocInfo,
			raw_data(pipelines[PipelineIndex.POST].descriptorSets[:]),
		) !=
		.SUCCESS {
			log.log(.Error, "Failed to allocate compute descriptor sets!")
			panic("Failed to allocate compute descriptor sets!")
		}

		inImageInfo: vk.DescriptorImageInfo = {
			sampler     = inImage.sampler,
			imageView   = inImage.view,
			imageLayout = .GENERAL,
		}
		outImageInfo: vk.DescriptorImageInfo = {
			sampler     = outImage.sampler,
			imageView   = outImage.view,
			imageLayout = .GENERAL,
		}

		for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
			descriptorWrite: []vk.WriteDescriptorSet = {
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.POST].descriptorSets[index],
					dstBinding = 0,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .STORAGE_IMAGE,
					pImageInfo = &inImageInfo,
					pBufferInfo = nil,
					pTexelBufferView = nil,
				},
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.POST].descriptorSets[index],
					dstBinding = 1,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .STORAGE_IMAGE,
					pImageInfo = &outImageInfo,
					pBufferInfo = nil,
					pTexelBufferView = nil,
				},
			}

			vk.UpdateDescriptorSets(
				device,
				u32(len(descriptorWrite)),
				raw_data(descriptorWrite),
				0,
				nil,
			)
		}
	}
}

// ###################################################################
// #                         Frame Resources                         #
// ###################################################################

@(private = "file")
createStorageImage :: proc(using graphicsContext: ^GraphicsContext) {
	inImage.format = swapchainFormat.format
	createImage(
		graphicsContext,
		&inImage,
		{},
		.D2,
		swapchainExtent.width,
		swapchainExtent.height,
		1,
		{._1},
		.OPTIMAL,
		{.TRANSFER_DST, .SAMPLED, .STORAGE},
		{.DEVICE_LOCAL},
		.EXCLUSIVE,
		0,
		nil,
	)
	inImage.view = createImageView(
		graphicsContext,
		inImage.image,
		.D2,
		inImage.format,
		{.COLOR},
		1,
	)
	outImage.format = swapchainFormat.format
	createImage(
		graphicsContext,
		&outImage,
		{},
		.D2,
		swapchainExtent.width,
		swapchainExtent.height,
		1,
		{._1},
		.OPTIMAL,
		{.TRANSFER_SRC, .SAMPLED, .STORAGE},
		{.DEVICE_LOCAL},
		.EXCLUSIVE,
		0,
		nil,
	)
	outImage.view = createImageView(
		graphicsContext,
		outImage.image,
		.D2,
		outImage.format,
		{.COLOR},
		1,
	)
}

@(private = "file")
createSyncObjects :: proc(using graphicsContext: ^GraphicsContext) {
	imagesAvailable = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	rendersFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	computeFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	inFlightFrames = make([]vk.Fence, MAX_FRAMES_IN_FLIGHT)
	semaphoreInfo: vk.SemaphoreCreateInfo = {
		sType = .SEMAPHORE_CREATE_INFO,
		pNext = nil,
		flags = {},
	}
	fenceInfo: vk.FenceCreateInfo = {
		sType = .FENCE_CREATE_INFO,
		pNext = nil,
		flags = {.SIGNALED},
	}

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		result :=
			vk.CreateSemaphore(
				device,
				&semaphoreInfo,
				nil,
				&imagesAvailable[index],
			) |
			vk.CreateSemaphore(
				device,
				&semaphoreInfo,
				nil,
				&rendersFinished[index],
			) |
			vk.CreateSemaphore(
				device,
				&semaphoreInfo,
				nil,
				&computeFinished[index],
			) |
			vk.CreateFence(
				device,
				&fenceInfo,
				nil,
				&inFlightFrames[index],
			)
		if result != .SUCCESS {
			log.log(.Error, "Failed to create sync objects!")
			panic("Failed to create sync objects!")
		}
	}
}

// ###################################################################
// #                             Pipeline                            #
// ###################################################################

@(private = "file")
findSupportedDepthFormat :: proc(
	using graphicsContext: ^GraphicsContext,
	candidates: []vk.Format,
	tiling: vk.ImageTiling,
	features: vk.FormatFeatureFlags,
) -> vk.Format {
	for format in candidates {
		props: vk.FormatProperties
		vk.GetPhysicalDeviceFormatProperties(physicalDevice, format, &props)
		if tiling == .LINEAR && (props.linearTilingFeatures & features) == features {
			return format
		} else if tiling == .OPTIMAL && (props.optimalTilingFeatures & features) == features {
			return format
		}
	}
	log.log(.Error, "Failed to find supported format!")
	panic("Failed to find supported format!")
}

@(private = "file")
createRenderPass :: proc(using graphicsContext: ^GraphicsContext) {
	pipelines[PipelineIndex.MAIN].colour.format = swapchainFormat.format
	createImage(
		graphicsContext,
		&pipelines[PipelineIndex.MAIN].colour,
		{},
		.D2,
		u32(RENDER_SIZE.x),
		u32(RENDER_SIZE.y),
		1,
		{._1},
		.OPTIMAL,
		{.COLOR_ATTACHMENT, .TRANSFER_SRC},
		{.DEVICE_LOCAL},
		.EXCLUSIVE,
		0,
		nil,
	)
	pipelines[PipelineIndex.MAIN].colour.view = createImageView(
		graphicsContext,
		pipelines[PipelineIndex.MAIN].colour.image,
		.D2,
		pipelines[PipelineIndex.MAIN].colour.format,
		{.COLOR},
		1,
	)

	pipelines[PipelineIndex.MAIN].depth.format = findSupportedDepthFormat(
		graphicsContext,
		{.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
	)
	createImage(
		graphicsContext,
		&pipelines[PipelineIndex.MAIN].depth,
		{},
		.D2,
		u32(RENDER_SIZE.x),
		u32(RENDER_SIZE.y),
		1,
		{._1},
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
		{.DEVICE_LOCAL},
		.EXCLUSIVE,
		0,
		nil,
	)
	pipelines[PipelineIndex.MAIN].depth.view = createImageView(
		graphicsContext,
		pipelines[PipelineIndex.MAIN].depth.image,
		.D2,
		pipelines[PipelineIndex.MAIN].depth.format,
		{.DEPTH},
		1,
	)

	attachments: []vk.AttachmentDescription = {
		{
			flags = {},
			format = pipelines[PipelineIndex.MAIN].colour.format,
			samples = {._1},
			loadOp = .CLEAR,
			storeOp = .STORE,
			stencilLoadOp = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout = .UNDEFINED,
			finalLayout = .COLOR_ATTACHMENT_OPTIMAL,
		},
		{
			flags = {},
			format = pipelines[PipelineIndex.MAIN].depth.format,
			samples = {._1},
			loadOp = .CLEAR,
			storeOp = .DONT_CARE,
			stencilLoadOp = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout = .UNDEFINED,
			finalLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		},
	}

	colourAttachmentRef: vk.AttachmentReference = {
		attachment = 0,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	depthAttachmentRef: vk.AttachmentReference = {
		attachment = 1,
		layout     = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	subpass: vk.SubpassDescription = {
		flags                   = {},
		pipelineBindPoint       = .GRAPHICS,
		inputAttachmentCount    = 0,
		pInputAttachments       = nil,
		colorAttachmentCount    = 1,
		pColorAttachments       = &colourAttachmentRef,
		pResolveAttachments     = nil,
		pDepthStencilAttachment = &depthAttachmentRef,
		preserveAttachmentCount = 0,
		pPreserveAttachments    = nil,
	}

	renderPassInfo: vk.RenderPassCreateInfo = {
		sType           = .RENDER_PASS_CREATE_INFO,
		pNext           = nil,
		flags           = {},
		attachmentCount = u32(len(attachments)),
		pAttachments    = raw_data(attachments),
		subpassCount    = 1,
		pSubpasses      = &subpass,
		dependencyCount = 0,
		pDependencies   = nil,
	}

	if vk.CreateRenderPass(
		   device,
		   &renderPassInfo,
		   nil,
		   &pipelines[PipelineIndex.MAIN].vulkanRenderPass,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Unable to create render pass!")
		panic("Unable to create render pass!")
	}
}

@(private = "file")
createFramebuffers :: proc(using graphicsContext: ^GraphicsContext) {
	frameBufferInfo: vk.FramebufferCreateInfo = {
		sType           = .FRAMEBUFFER_CREATE_INFO,
		pNext           = nil,
		flags           = {},
		renderPass      = pipelines[PipelineIndex.MAIN].vulkanRenderPass,
		attachmentCount = 2,
		pAttachments    = raw_data(
			[]vk.ImageView{pipelines[PipelineIndex.MAIN].colour.view, pipelines[PipelineIndex.MAIN].depth.view},
		),
		width           = u32(RENDER_SIZE.x),
		height          = u32(RENDER_SIZE.y),
		layers          = 1,
	}

	pipelines[PipelineIndex.MAIN].frameBuffers = make([]vk.Framebuffer, len(swapchainImageViews))
	for index in 0 ..< len(swapchainImageViews) {
		if vk.CreateFramebuffer(
			   device,
			   &frameBufferInfo,
			   nil,
			   &pipelines[PipelineIndex.MAIN].frameBuffers[index],
		   ) !=
		   .SUCCESS {
			log.log(.Error, "Failed to create frame buffer!")
			panic("Failed to create frame buffer!")
		}
	}
}

@(private = "file")
createShaderModule :: proc(
	using graphicsContext: ^GraphicsContext,
	filename: string,
) -> (
	shaderModule: vk.ShaderModule,
) {
	loadShaderFile :: proc(filepath: string) -> (data: []byte) {
		fileHandle, err := os.open(filepath, mode = (os.O_RDONLY | os.O_APPEND))
		if err != 0 {
			log.log(.Error, "Shader file couldn't be opened!")
			panic("Shader file couldn't be opened!")
		}
		defer os.close(fileHandle)
		success: bool
		if data, success = os.read_entire_file_from_handle(fileHandle); !success {
			log.log(.Error, "Shader file couldn't be read!")
			panic("Shader file couldn't be read!")
		}
		return
	}

	code := loadShaderFile(filename)
	createInfo: vk.ShaderModuleCreateInfo = {
		sType    = .SHADER_MODULE_CREATE_INFO,
		pNext    = nil,
		flags    = {},
		codeSize = len(code),
		pCode    = (^u32)(raw_data(code)),
	}
	if vk.CreateShaderModule(device, &createInfo, nil, &shaderModule) != .SUCCESS {
		log.log(.Error, "Failed to create shader module")
		panic("Failed to create shader module")
	}
	delete(code)
	return
}

@(private = "file")
createMainPipeline :: proc(using graphicsContext: ^GraphicsContext) {
	PipelineLayoutInfo: vk.PipelineLayoutCreateInfo = {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		pNext                  = nil,
		flags                  = {},
		setLayoutCount         = 1,
		pSetLayouts            = &pipelines[PipelineIndex.MAIN].descriptorSetLayout,
		pushConstantRangeCount = 0,
		pPushConstantRanges    = nil,
	}

	if vk.CreatePipelineLayout(
		   device,
		   &PipelineLayoutInfo,
		   nil,
		   &pipelines[PipelineIndex.MAIN].layout,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create pipeline layout!")
		panic("Failed to create pipeline layout!")
	}

	vertexInputInfo: vk.PipelineVertexInputStateCreateInfo = {
		sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		pNext                           = nil,
		flags                           = {},
		vertexBindingDescriptionCount   = 1,
		pVertexBindingDescriptions      = &vertexBindingDescription,
		vertexAttributeDescriptionCount = u32(len(vertexInputAttributeDescriptions)),
		pVertexAttributeDescriptions    = raw_data(vertexInputAttributeDescriptions),
	}

	inputAssembly: vk.PipelineInputAssemblyStateCreateInfo = {
		sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		pNext                  = nil,
		flags                  = {},
		topology               = .TRIANGLE_LIST,
		primitiveRestartEnable = false,
	}

	viewportState: vk.PipelineViewportStateCreateInfo = {
		sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		pNext         = nil,
		flags         = {},
		viewportCount = 1,
		pViewports    = nil,
		scissorCount  = 1,
		pScissors     = nil,
	}

	rasterizer: vk.PipelineRasterizationStateCreateInfo = {
		sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		pNext                   = nil,
		flags                   = {},
		depthClampEnable        = false,
		rasterizerDiscardEnable = false,
		polygonMode             = .FILL,
		cullMode                = {.BACK},
		frontFace               = .CLOCKWISE,
		depthBiasEnable         = false,
		depthBiasConstantFactor = 0.0,
		depthBiasClamp          = 0.0,
		depthBiasSlopeFactor    = 0.0,
		lineWidth               = 1.0,
	}

	multisampling: vk.PipelineMultisampleStateCreateInfo = {
		sType                 = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		pNext                 = nil,
		flags                 = {},
		rasterizationSamples  = {._1},
		sampleShadingEnable   = false,
		minSampleShading      = 1.0,
		pSampleMask           = nil,
		alphaToCoverageEnable = false,
		alphaToOneEnable      = false,
	}

	depthStencil: vk.PipelineDepthStencilStateCreateInfo = {
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

	colourBlendAttachment: vk.PipelineColorBlendAttachmentState = {
		blendEnable         = false,
		srcColorBlendFactor = .ONE,
		dstColorBlendFactor = .ZERO,
		colorBlendOp        = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ZERO,
		alphaBlendOp        = .ADD,
		colorWriteMask      = {.R, .G, .B, .A},
	}

	colourBlending: vk.PipelineColorBlendStateCreateInfo = {
		sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		pNext           = nil,
		flags           = {},
		logicOpEnable   = false,
		logicOp         = .COPY,
		attachmentCount = 1,
		pAttachments    = &colourBlendAttachment,
		blendConstants  = {0, 0, 0, 0},
	}

	dynamicStates: []vk.DynamicState = {.VIEWPORT, .SCISSOR}

	dynamicStateInfo: vk.PipelineDynamicStateCreateInfo = {
		sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		pNext             = nil,
		flags             = {},
		dynamicStateCount = u32(len(dynamicStates)),
		pDynamicStates    = raw_data(dynamicStates),
	}

	shaderStages := [?]vk.ShaderStageFlag{.VERTEX, .FRAGMENT}

	shaderFiles := [?]string{"./assets/shaders/main_vert.spv", "./assets/shaders/main_frag.spv"}

	shaderStagesInfo := make([]vk.PipelineShaderStageCreateInfo, len(shaderFiles))
	defer {
		for stage in shaderStagesInfo {
			vk.DestroyShaderModule(device, stage.module, nil)
		}
		delete(shaderStagesInfo)
	}
	for path, index in shaderFiles {
		shaderStagesInfo[index] = {
			sType               = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			pNext               = nil,
			flags               = {},
			stage               = {shaderStages[index]},
			module              = createShaderModule(graphicsContext, path),
			pName               = "main",
			pSpecializationInfo = nil,
		}
	}

	pipelineInfo: vk.GraphicsPipelineCreateInfo = {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext               = nil,
		flags               = {},
		stageCount          = u32(len(shaderStagesInfo)),
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
		layout              = pipelines[PipelineIndex.MAIN].layout,
		renderPass          = pipelines[PipelineIndex.MAIN].vulkanRenderPass,
		subpass             = 0,
		basePipelineHandle  = {},
		basePipelineIndex   = 0,
	}

	if vk.CreateGraphicsPipelines(
		   device,
		   0,
		   1,
		   &pipelineInfo,
		   nil,
		   &pipelines[PipelineIndex.MAIN].pipeline,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create pipeline!")
		panic("Failed to create pipeline!")
	}
}

@(private = "file")
createPostPipeline :: proc(using graphicsContext: ^GraphicsContext) {
	PipelineLayoutInfo: vk.PipelineLayoutCreateInfo = {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		pNext                  = nil,
		flags                  = {},
		setLayoutCount         = 1,
		pSetLayouts            = &pipelines[PipelineIndex.POST].descriptorSetLayout,
		pushConstantRangeCount = 0,
		pPushConstantRanges    = nil,
	}

	if vk.CreatePipelineLayout(
		   device,
		   &PipelineLayoutInfo,
		   nil,
		   &pipelines[PipelineIndex.POST].layout,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create postprocess pipeline layout!")
		panic("Failed to create postprocess pipeline layout!")
	}

	shaderStageInfo: vk.PipelineShaderStageCreateInfo = {
		sType               = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		pNext               = nil,
		flags               = {},
		stage               = {.COMPUTE},
		module              = createShaderModule(
			graphicsContext,
			"./assets/shaders/post_comp.spv",
		),
		pName               = "main",
		pSpecializationInfo = nil,
	}

	pipelineInfo: vk.ComputePipelineCreateInfo = {
		sType              = .COMPUTE_PIPELINE_CREATE_INFO,
		pNext              = nil,
		flags              = {},
		stage              = shaderStageInfo,
		layout             = pipelines[PipelineIndex.POST].layout,
		basePipelineHandle = {},
		basePipelineIndex  = 0,
	}

	if vk.CreateComputePipelines(
		   device,
		   0,
		   1,
		   &pipelineInfo,
		   nil,
		   &pipelines[PipelineIndex.POST].pipeline,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create postprocess pipeline!")
		panic("Failed to create postprocess pipeline!")
	}

	vk.DestroyShaderModule(device, shaderStageInfo.module, nil)
}

// ###################################################################
// #                           Render Loop                           #
// ###################################################################

@(private = "file")
recordGraphicsBuffer :: proc(
	using graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	imageIndex: u32,
) {
	beginInfo: vk.CommandBufferBeginInfo = {
		sType            = .COMMAND_BUFFER_BEGIN_INFO,
		pNext            = nil,
		flags            = {},
		pInheritanceInfo = nil,
	}
	if vk.BeginCommandBuffer(commandBuffer, &beginInfo) != .SUCCESS {
		log.log(.Error, "Failed to being recording command buffer!")
		panic("Failed to being recording command buffer!")
	}

	renderPassInfo: vk.RenderPassBeginInfo = {
		sType = .RENDER_PASS_BEGIN_INFO,
		pNext = nil,
		renderPass = pipelines[PipelineIndex.MAIN].vulkanRenderPass,
		framebuffer = pipelines[PipelineIndex.MAIN].frameBuffers[imageIndex],
		renderArea = vk.Rect2D{offset = {0, 0}, extent = {u32(RENDER_SIZE.x), u32(RENDER_SIZE.y)}},
		clearValueCount = 2,
		pClearValues = raw_data(
			[]vk.ClearValue {
				{color = vk.ClearColorValue{float32 = CLEAR_COLOUR}},
				{depthStencil = vk.ClearDepthStencilValue{depth = 1, stencil = 0}},
			},
		),
	}
	vk.CmdBeginRenderPass(commandBuffer, &renderPassInfo, .INLINE)

	viewport: vk.Viewport = {
		x        = 0,
		y        = 0,
		width    = RENDER_SIZE.x,
		height   = RENDER_SIZE.y,
		minDepth = 0,
		maxDepth = 1,
	}
	vk.CmdSetViewport(commandBuffer, 0, 1, &viewport)

	scissor: vk.Rect2D = {
		offset = {0, 0},
		extent = {u32(RENDER_SIZE.x), u32(RENDER_SIZE.y)},
	}
	vk.CmdSetScissor(commandBuffer, 0, 1, &scissor)

	vk.CmdBindDescriptorSets(
		commandBuffer,
		.GRAPHICS,
		pipelines[PipelineIndex.MAIN].layout,
		0,
		1,
		&pipelines[PipelineIndex.MAIN].descriptorSets[currentFrame],
		0,
		nil,
	)
	vk.CmdBindPipeline(commandBuffer, .GRAPHICS, pipelines[PipelineIndex.MAIN].pipeline)

	vk.CmdBindVertexBuffers(
		commandBuffer,
		0,
		1,
		&vertexBuffer.buffer,
		raw_data([]vk.DeviceSize{0}),
	)
	vk.CmdBindIndexBuffer(commandBuffer, indexBuffer.buffer, 0, .UINT32)
	for &inst, i in instances {
		vk.CmdDrawIndexed(
			commandBuffer,
			models[inst.modelID].indexCount,
			1,
			models[inst.modelID].indexOffset,
			i32(models[inst.modelID].vertexOffset),
			u32(i),
		)
	}

	vk.CmdEndRenderPass(commandBuffer)

	if vk.EndCommandBuffer(commandBuffer) != .SUCCESS {
		log.log(.Error, "Failed to record command buffer!")
		panic("Failed to record command buffer!")
	}
}

@(private = "file")
recordComputeBuffer :: proc(
	using graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	imageIndex: u32,
) {
	beginInfo: vk.CommandBufferBeginInfo = {
		sType            = .COMMAND_BUFFER_BEGIN_INFO,
		pNext            = nil,
		flags            = {},
		pInheritanceInfo = nil,
	}

	if vk.BeginCommandBuffer(commandBuffer, &beginInfo) != .SUCCESS {
		log.log(.Error, "Failed to start recording compute commands!")
		panic("Failed to start recording compute commands!")
	}

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		pipelines[PipelineIndex.MAIN].renderPass.colour.image,
		.UNDEFINED,
		.TRANSFER_SRC_OPTIMAL,
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		inImage.image,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		1,
	)

	upscaleImage(
		commandBuffer,
		pipelines[PipelineIndex.MAIN].colour.image,
		inImage.image,
		vk.Extent2D{u32(RENDER_SIZE.x), u32(RENDER_SIZE.y)},
		swapchainExtent,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		inImage.image,
		.TRANSFER_DST_OPTIMAL,
		.GENERAL,
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		outImage.image,
		.TRANSFER_SRC_OPTIMAL,
		.GENERAL,
		1,
	)

	vk.CmdBindDescriptorSets(
		commandBuffer,
		.COMPUTE,
		pipelines[PipelineIndex.POST].layout,
		0,
		1,
		&pipelines[PipelineIndex.POST].descriptorSets[currentFrame],
		0,
		nil,
	)

	vk.CmdBindPipeline(commandBuffer, .COMPUTE, pipelines[PipelineIndex.POST].pipeline)

	vk.CmdDispatch(
		commandBuffer,
		swapchainExtent.width / 32 + 1,
		swapchainExtent.height / 32 + 1,
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		outImage.image,
		.UNDEFINED,
		.TRANSFER_SRC_OPTIMAL,
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		swapchainImages[imageIndex],
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		1,
	)

	copyImage(
		commandBuffer,
		vk.Extent3D {
			swapchainExtent.width,
			swapchainExtent.height,
			1,
		},
		outImage.image,
		swapchainImages[imageIndex],
		.TRANSFER_SRC_OPTIMAL,
		.TRANSFER_DST_OPTIMAL,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		swapchainImages[imageIndex],
		.UNDEFINED,
		.PRESENT_SRC_KHR,
		1,
	)

	if vk.EndCommandBuffer(commandBuffer) != .SUCCESS {
		log.log(.Error, "Failed to record compute command buffer!")
		panic("Failed to record compute command buffer!")
	}
}

@(private = "file")
updateViewProjectionUniform :: proc(using graphicsContext: ^GraphicsContext, camera: Camera) {
	view := lookAt(camera.eye, camera.center, camera.up)
	projection: Mat4
	if camera.mode == .PERSPECTIVE {
		projection = perspective(
			radians(f32(45.0)),
			f32(swapchainExtent.width) /
			f32(swapchainExtent.height),
			0.1,
			10000,
		)
	} else if camera.mode == .ORTHOGRAPHIC {
		projection = orthographic(
			radians(f32(45.0)),
			f32(swapchainExtent.width) /
			f32(swapchainExtent.height),
			0.1,
			10000,
		)
	} else {
		log.log(.Error, "Undefined camera mode!")
		panic("Undefined camera mode!")
	}
	viewProjection: ViewProjectionUniform = {
		view           = view,
		projection     = projection,
		viewProjection = projection * view,
	}
	mem.copy(
		viewProjectionUniforms[currentFrame].mapped,
		&viewProjection,
		size_of(ViewProjectionUniform),
	)
}

@(private = "file")
updateInstanceBuffer :: proc(using graphicsContext: ^GraphicsContext) {
	finalBoneTransforms := make([]Mat4, boneCount)
	instanceData := make([]InstanceInfo, len(instances))
	defer delete(finalBoneTransforms)
	defer delete(instanceData)
	finalBoneTransforms[0] = IMat4
	boneOffset: u32 = 1
	now := time.now()
	for &instance, instanceIndex in instances {
		instanceData[instanceIndex] = {
			model         = translate(
				instance.position,
			) * quatToRotation(instance.rotation) * scale(instance.scale),
			boneOffset    = boneOffset,
			samplerOffset = f32(instance.textureID),
		}

		model := &models[instance.modelID]

		if len(model^.skeleton) == 0 {
			instanceData[instanceIndex].boneOffset = 0
			continue
		}

		skeleton := &model^.skeleton
		animation := model^.animations[instance.animID]
		now = instance.animStartTime // Pauses animations
		timeSinceAnimStart := time.duration_seconds(time.diff(instance.animStartTime, now))
		timeStamp :=
			timeSinceAnimStart -
			(floor(timeSinceAnimStart / animation.duration) * animation.duration)
		localBoneTransforms := make([]Mat4, len(skeleton))
		defer delete(localBoneTransforms)

		for index in 0 ..< len(skeleton) {
			localBoneTransforms[index] = IMat4
		}

		for &node, nodeIndex in animation.nodes {
			// a *= b == a = a * b
			// therefore I *= T *= R *= S == aT = I * T * R * S
			if node.numKeyPositions == 1 {
				localBoneTransforms[node.bone] *= translate(node.keyPositions[0].value)
			} else if node.numKeyPositions != 0 {
				id := instance.positionKeys[nodeIndex]
				for true {
					if node.keyPositions[id].time <= timeStamp &&
					   timeStamp <= node.keyPositions[id + 1].time {
						instance.positionKeys[nodeIndex] = id
						break
					}
					id += 1
					if id == node.numKeyPositions - 1 {
						id = 0
					}
				}
				valueDiff :=
					node.keyPositions[instance.positionKeys[nodeIndex] + 1].value -
					node.keyPositions[instance.positionKeys[nodeIndex]].value
				timeDiff :=
					(timeStamp - node.keyPositions[instance.positionKeys[nodeIndex]].time) /
					(node.keyPositions[instance.positionKeys[nodeIndex] + 1].time -
							node.keyPositions[instance.positionKeys[nodeIndex]].time)
				value :=
					f32(timeDiff) * valueDiff +
					node.keyPositions[instance.positionKeys[nodeIndex]].value
				localBoneTransforms[node.bone] *= translate(value)
			}

			if node.numKeyRotations == 1 {
				localBoneTransforms[node.bone] *= quatToRotation(node.keyRotations[0].value)
			} else if node.numKeyRotations != 0 {
				id := instance.rotationKeys[nodeIndex]
				for true {
					if node.keyRotations[id].time <= timeStamp &&
					   timeStamp <= node.keyRotations[id + 1].time {
						instance.rotationKeys[nodeIndex] = id
						break
					}
					id += 1
					if id == node.numKeyRotations - 1 {
						id = 0
					}
				}
				valueDiff :=
					node.keyRotations[instance.rotationKeys[nodeIndex] + 1].value -
					node.keyRotations[instance.rotationKeys[nodeIndex]].value
				timeDiff :=
					(timeStamp - node.keyRotations[instance.rotationKeys[nodeIndex]].time) /
					(node.keyRotations[instance.rotationKeys[nodeIndex] + 1].time -
							node.keyRotations[instance.rotationKeys[nodeIndex]].time)
				localBoneTransforms[node.bone] *= quatToRotation(
					quatLurp(
						node.keyRotations[instance.rotationKeys[nodeIndex]].value,
						node.keyRotations[instance.rotationKeys[nodeIndex] + 1].value,
						f32(timeDiff),
					),
				)
			}

			if node.numKeyScales == 1 {
				localBoneTransforms[node.bone] *= scale(node.keyScales[0].value)
			} else if node.numKeyScales != 0 {
				id := instance.scaleKeys[nodeIndex]
				for true {
					if node.keyScales[id].time <= timeStamp &&
					   timeStamp <= node.keyScales[id + 1].time {
						instance.scaleKeys[nodeIndex] = id
						break
					}
					id += 1
					if id == node.numKeyScales - 1 {
						id = 0
					}
				}
				valueDiff :=
					node.keyScales[instance.scaleKeys[nodeIndex] + 1].value -
					node.keyScales[instance.scaleKeys[nodeIndex]].value
				timeDiff :=
					(timeStamp - node.keyScales[instance.scaleKeys[nodeIndex]].time) /
					(node.keyScales[instance.scaleKeys[nodeIndex] + 1].time -
							node.keyScales[instance.scaleKeys[nodeIndex]].time)
				value :=
					f32(timeDiff) * valueDiff + node.keyScales[instance.scaleKeys[nodeIndex]].value
				localBoneTransforms[node.bone] *= scale(value)
			}
		}

		finalBoneTransforms[boneOffset] = localBoneTransforms[0]
		if localBoneTransforms[0] != IMat4 {
			finalBoneTransforms[boneOffset] *= skeleton[0].inverseBind
		}
		for boneIndex in 1 ..< u32(len(skeleton)) {
			localBoneTransforms[boneIndex] =
				localBoneTransforms[skeleton[boneIndex].parentIndex] *
				localBoneTransforms[boneIndex]
			finalBoneTransforms[boneOffset + boneIndex] = localBoneTransforms[boneIndex]
			if localBoneTransforms[boneIndex] != IMat4 {
				finalBoneTransforms[boneOffset + boneIndex] *= skeleton[boneIndex].inverseBind
			}
		}
		boneOffset += u32(len(skeleton))
	}
	mem.copy(
		boneBuffers[currentFrame].mapped,
		raw_data(finalBoneTransforms),
		boneCount * size_of(Mat4),
	)
	mem.copy(
		instanceBuffers[currentFrame].mapped,
		raw_data(instanceData),
		len(instances) * size_of(InstanceInfo),
	)
}

drawFrame :: proc(using graphicsContext: ^GraphicsContext, camera: Camera) {
	vk.WaitForFences(
		device,
		1,
		&inFlightFrames[currentFrame],
		true,
		max(u64),
	)

	imageIndex: u32
	if result := vk.AcquireNextImageKHR(
		device,
		swapchain,
		max(u64),
		imagesAvailable[currentFrame],
		{},
		&imageIndex,
	); result == .ERROR_OUT_OF_DATE_KHR {
		recreateSwapchain(graphicsContext)
		return
	} else if result != .SUCCESS && result != .SUBOPTIMAL_KHR {
		log.log(.Error, "Failed to aquire swapchain image!")
		panic("Failed to aquire swapchain image!")
	}
	vk.ResetFences(
		device,
		1,
		&inFlightFrames[currentFrame],
	)

	vk.ResetCommandBuffer(graphicsCommandBuffers[currentFrame], {})
	vk.ResetCommandBuffer(computeCommandBuffers[currentFrame], {})
	updateViewProjectionUniform(graphicsContext, camera)
	updateInstanceBuffer(graphicsContext)
	recordGraphicsBuffer(
		graphicsContext,
		graphicsCommandBuffers[currentFrame],
		imageIndex,
	)
	recordComputeBuffer(
		graphicsContext,
		computeCommandBuffers[currentFrame],
		imageIndex,
	)

	submitInfo: vk.SubmitInfo = {
		sType                = .SUBMIT_INFO,
		pNext                = nil,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = &imagesAvailable[currentFrame],
		pWaitDstStageMask    = &vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT},
		commandBufferCount   = 1,
		pCommandBuffers      = &graphicsCommandBuffers[currentFrame],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &rendersFinished[currentFrame],
	}

	if vk.QueueSubmit(graphicsQueue, 1, &submitInfo, 0) != .SUCCESS {
		log.log(.Error, "Failed to submit draw command buffer!")
		panic("Failed to submit draw command buffer!")
	}

	submitInfo = {
		sType                = .SUBMIT_INFO,
		pNext                = nil,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = &rendersFinished[currentFrame],
		pWaitDstStageMask    = &vk.PipelineStageFlags{.COMPUTE_SHADER},
		commandBufferCount   = 1,
		pCommandBuffers      = &computeCommandBuffers[currentFrame],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &computeFinished[currentFrame],
	}

	if vk.QueueSubmit(
		   computeQueue,
		   1,
		   &submitInfo,
		   inFlightFrames[currentFrame],
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to submit compute command buffer!")
		panic("Failed to submit compute command buffer!")
	}

	presentInfo: vk.PresentInfoKHR = {
		sType              = .PRESENT_INFO_KHR,
		pNext              = nil,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = &rendersFinished[currentFrame],
		swapchainCount     = 1,
		pSwapchains        = &swapchain,
		pImageIndices      = &imageIndex,
		pResults           = nil,
	}

	if result := vk.QueuePresentKHR(presentQueue, &presentInfo);
	   result == .ERROR_OUT_OF_DATE_KHR ||
	   result == .SUBOPTIMAL_KHR ||
	   framebufferResized {
		framebufferResized = false
		recreateSwapchain(graphicsContext)
	} else if result != .SUCCESS {
		log.log(.Error, "Failed to present swapchain image!")
		panic("Failed to present swapchain image!")
	}

	currentFrame += (currentFrame + 1) % 2
}

// ###################################################################
// #                             Cleanup                             #
// ###################################################################

@(private = "file")
cleanupSwapchain :: proc(using graphicsContext: ^GraphicsContext) {
	for imageView in swapchainImageViews {
		vk.DestroyImageView(device, imageView, nil)
	}
	vk.DestroySwapchainKHR(device, swapchain, nil)
	vk.DestroyImageView(device, inImage.view, nil)
	vk.DestroyImage(device, inImage.image, nil)
	vk.FreeMemory(device, inImage.memory, nil)
	vk.DestroyImageView(device, outImage.view, nil)
	vk.DestroyImage(device, outImage.image, nil)
	vk.FreeMemory(device, outImage.memory, nil)

	vk.DestroyDescriptorPool(
		device,
		pipelines[PipelineIndex.POST].descriptorPool,
		nil,
	)
	vk.DestroyDescriptorSetLayout(
		device,
		pipelines[PipelineIndex.POST].descriptorSetLayout,
		nil,
	)
	vk.DestroyPipeline(device, pipelines[PipelineIndex.POST].pipeline, nil)
	vk.DestroyPipelineLayout(
		device,
		pipelines[PipelineIndex.POST].layout,
		nil,
	)
}

@(private = "file")
cleanupAssets :: proc(using graphicsContext: ^GraphicsContext) {
	vk.DestroyBuffer(device, indexBuffer.buffer, nil)
	vk.FreeMemory(device, indexBuffer.memory, nil)
	vk.DestroyBuffer(device, vertexBuffer.buffer, nil)
	vk.FreeMemory(device, vertexBuffer.memory, nil)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyBuffer(device, instanceBuffers[i].buffer, nil)
		vk.FreeMemory(device, instanceBuffers[i].memory, nil)
		vk.DestroyBuffer(device, boneBuffers[i].buffer, nil)
		vk.FreeMemory(device, boneBuffers[i].memory, nil)
	}
	vk.DestroyImageView(device, albidos.view, nil)
	vk.DestroyImage(device, albidos.image, nil)
	vk.FreeMemory(device, albidos.memory, nil)
	vk.DestroySampler(device, albidos.sampler, nil)
	vk.DestroyImageView(device, normals.view, nil)
	vk.DestroyImage(device, normals.image, nil)
	vk.FreeMemory(device, normals.memory, nil)
	vk.DestroySampler(device, normals.sampler, nil)

	for model in models {
		delete(model.vertices)
		delete(model.indices)
		delete(model.skeleton)
		for animation in model.animations {
			for node in animation.nodes {
				delete(node.keyPositions)
				delete(node.keyRotations)
				delete(node.keyScales)
			}
			delete(animation.nodes)
		}
		delete(model.animations)
	}
	delete(models)
	for instance in instances {
		delete(instance.scaleKeys)
		delete(instance.positionKeys)
		delete(instance.rotationKeys)
	}
	delete(instances)
	delete(vertices)
	delete(indices)
}

clanupVkGraphics :: proc(using graphicsContext: ^GraphicsContext) {
	vk.DeviceWaitIdle(device)

	cleanupAssets(graphicsContext)

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyBuffer(
			device,
			viewProjectionUniforms[index].buffer,
			nil,
		)
		vk.FreeMemory(
			device,
			viewProjectionUniforms[index].memory,
			nil,
		)
	}

	for frameBuffer in pipelines[PipelineIndex.MAIN].frameBuffers {
		vk.DestroyFramebuffer(device, frameBuffer, nil)
	}
	delete(pipelines[PipelineIndex.MAIN].frameBuffers)

	cleanupSwapchain(graphicsContext)
	delete(swapchainImages)
	delete(swapchainImageViews)

	vk.DestroyImageView(device, pipelines[PipelineIndex.MAIN].colour.view, nil)
	vk.DestroyImage(device, pipelines[PipelineIndex.MAIN].colour.image, nil)
	vk.FreeMemory(device, pipelines[PipelineIndex.MAIN].colour.memory, nil)

	vk.DestroyImageView(device, pipelines[PipelineIndex.MAIN].depth.view, nil)
	vk.DestroyImage(device, pipelines[PipelineIndex.MAIN].depth.image, nil)
	vk.FreeMemory(device, pipelines[PipelineIndex.MAIN].depth.memory, nil)

	vk.DestroyDescriptorPool(
		device,
		pipelines[PipelineIndex.MAIN].descriptorPool,
		nil,
	)

	vk.DestroyDescriptorSetLayout(
		device,
		pipelines[PipelineIndex.MAIN].descriptorSetLayout,
		nil,
	)

	vk.DestroyPipeline(device, pipelines[PipelineIndex.MAIN].pipeline, nil)
	vk.DestroyPipelineLayout(
		device,
		pipelines[PipelineIndex.MAIN].layout,
		nil,
	)
	vk.DestroyRenderPass(device, pipelines[PipelineIndex.MAIN].vulkanRenderPass, nil)
	
	delete(pipelines)

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroySemaphore(device, imagesAvailable[index], nil)
		vk.DestroySemaphore(device, rendersFinished[index], nil)
		vk.DestroySemaphore(device, computeFinished[index], nil)
		vk.DestroyFence(device, inFlightFrames[index], nil)
	}
	delete(imagesAvailable)
	delete(rendersFinished)
	delete(computeFinished)
	delete(inFlightFrames)

	vk.DestroyCommandPool(device, graphicsCommandPool, nil)
	vk.DestroyCommandPool(device, computeCommandPool, nil)
	delete(graphicsCommandBuffers)
	delete(computeCommandBuffers)

	vk.DestroyDevice(device, nil)
	when ODIN_DEBUG {
		vk.DestroyDebugUtilsMessengerEXT(
			instance,
			debugMessenger,
			nil,
		)
	}
	vk.DestroySurfaceKHR(instance, surface, nil)
	vk.DestroyInstance(instance, nil)
}
