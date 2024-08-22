package Valhalla

import "core:c"
import "core:log"
import "core:mem"
import "core:os"
import t "core:time"
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
MAX_MODEL_INSTANCES: int : 3

@(private = "file")
RENDER_SIZE: Vec2 : {1980, 1080}

@(private = "file")
CLEAR_COLOUR: Vec4 : {255.0 / 255.0, 120.0 / 255.0, 0.0 / 255.0, 255.0 / 255.0}

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
	animStartTime: t.Time,
}

@(private = "file")
PipelineType :: enum {
	MAIN = 0,
	POST = 1,
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
	swapchainFrameBuffers:  []vk.Framebuffer,

	// Frame Resources
	colourImage:            Image,
	depthImage:             Image,
	inImage:                Image,
	outImage:               Image,
	imagesAvailable:        []vk.Semaphore,
	rendersFinished:        []vk.Semaphore,
	computeFinished:        []vk.Semaphore,
	inFlightFrames:         []vk.Fence,

	// Descriptor
	descriptorPools:        []vk.DescriptorPool,
	descriptorSets:         [][]vk.DescriptorSet,

	// Pipeline
	pipelines:              []vk.Pipeline,
	descriptorSetLayouts:   []vk.DescriptorSetLayout,
	pipelineLayouts:        []vk.PipelineLayout,
	renderPass:             vk.RenderPass,

	// Commands
	graphicsCommandPool:    vk.CommandPool,
	graphicsCommandBuffers: []vk.CommandBuffer,
	computeCommandPool:     vk.CommandPool,
	computeCommandBuffers:  []vk.CommandBuffer,

	// Assets
	models:                 []Model,
	albidos:                Image,
	normals:                Image,
	instances:              []Instance,
	vertices:               []Vertex, // TODO: Vertex and Index buffers should be one buffer
	indices:                []u32,
	boneCount:              int,

	// Buffers
	vertexBuffer:           Buffer,
	indexBuffer:            Buffer,
	viewProjectionUniforms: [MAX_FRAMES_IN_FLIGHT]Buffer, // TODO: Combine into single buffer
	instanceBuffers:        [MAX_FRAMES_IN_FLIGHT]Buffer,
	boneBuffers:            [MAX_FRAMES_IN_FLIGHT]Buffer,

	// Util
	startTime:              t.Time,
	currentFrame:           u32,
	framebufferResized:     b8,
	hasAssetsLoaded:        b8,
}

// ###################################################################
// #                            Functions                            #
// ###################################################################

initVkGraphics :: proc(graphicsContext: ^GraphicsContext) {
	// load_proc_addresses_global :: proc(vk_get_instance_proc_addr: rawptr)
	vk.load_proc_addresses(rawptr(glfw.GetInstanceProcAddress))

	graphicsContext.framebufferResized = false
	graphicsContext.currentFrame = 0
	graphicsContext.startTime = t.now()
	graphicsContext.hasAssetsLoaded = false
	graphicsContext.boneCount = 1

	createInstance(graphicsContext)
	when ODIN_DEBUG {
		vkSetupDebugMessenger(graphicsContext)
	}
	createSurface(graphicsContext)
	pickPhysicalDevice(graphicsContext)
	createLogicalDevice(graphicsContext)

	// Swapchain
	getSwapchainInfo(graphicsContext)
	graphicsContext.swapchainImages = make([]vk.Image, graphicsContext.swapchainImageCount)
	graphicsContext.swapchainImageViews = make([]vk.ImageView, graphicsContext.swapchainImageCount)
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

	// Descriptor Sets
	graphicsContext.descriptorPools = make([]vk.DescriptorPool, 2)
	graphicsContext.descriptorSetLayouts = make([]vk.DescriptorSetLayout, 2)
	graphicsContext.descriptorSets = make([][]vk.DescriptorSet, 2)
	graphicsContext.descriptorSets[PipelineType.MAIN] = make(
		[]vk.DescriptorSet,
		MAX_FRAMES_IN_FLIGHT,
	)
	graphicsContext.descriptorSets[PipelineType.POST] = make(
		[]vk.DescriptorSet,
		MAX_FRAMES_IN_FLIGHT,
	)
	createMainDescriptorSets(graphicsContext)
	createPostDescriptorSets(graphicsContext)

	// Pipeline
	createRenderPass(graphicsContext)
	graphicsContext.swapchainFrameBuffers = make(
		[]vk.Framebuffer,
		u32(len(graphicsContext.swapchainImageViews)),
	)
	createFramebuffers(graphicsContext)
	graphicsContext.pipelineLayouts = make([]vk.PipelineLayout, 2)
	graphicsContext.pipelines = make([]vk.Pipeline, 2)
	createMainPipeline(graphicsContext)
	createPostPipeline(graphicsContext)
}

@(private = "file")
createInstance :: proc(graphicsContext: ^GraphicsContext) {
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

	if vk.CreateInstance(&instanceInfo, nil, &graphicsContext.instance) != .SUCCESS {
		log.log(.Error, "Failed to create vulkan instance.")
		panic("Failed to create vulkan instance.")
	}

	// load_proc_addresses_instance :: proc(instance: Instance)
	vk.load_proc_addresses(graphicsContext.instance)
}

@(private = "file")
createSurface :: proc(graphicsContext: ^GraphicsContext) {
	if glfw.CreateWindowSurface(
		   graphicsContext.instance,
		   graphicsContext.window,
		   nil,
		   &graphicsContext.surface,
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
createLogicalDevice :: proc(graphicsContext: ^GraphicsContext) {
	graphicsContext.queueFamilies, _ = findQueueFamilies(
		graphicsContext.physicalDevice,
		graphicsContext,
	)

	queuePriority: f32 = 1.0
	queueCreateInfos: [dynamic]vk.DeviceQueueCreateInfo
	defer delete(queueCreateInfos)
	queueCreateInfo: vk.DeviceQueueCreateInfo = {
		sType            = .DEVICE_QUEUE_CREATE_INFO,
		pNext            = nil,
		flags            = {},
		queueFamilyIndex = graphicsContext.queueFamilies.graphicsFamily,
		queueCount       = 1,
		pQueuePriorities = &queuePriority,
	}
	append(&queueCreateInfos, queueCreateInfo)

	if graphicsContext.queueFamilies.graphicsFamily !=
	   graphicsContext.queueFamilies.presentFamily {
		queueCreateInfo = {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			pNext            = nil,
			flags            = {},
			queueFamilyIndex = graphicsContext.queueFamilies.presentFamily,
			queueCount       = 1,
			pQueuePriorities = &queuePriority,
		}
		append(&queueCreateInfos, queueCreateInfo)
	}

	if graphicsContext.queueFamilies.graphicsFamily !=
	   graphicsContext.queueFamilies.computeFamily {
		queueCreateInfo = {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			pNext            = nil,
			flags            = {},
			queueFamilyIndex = graphicsContext.queueFamilies.computeFamily,
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
		   graphicsContext.physicalDevice,
		   &createInfo,
		   nil,
		   &graphicsContext.device,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create logical device!")
		panic("Failed to create logical device!")
	}

	// load_proc_addresses_device :: proc(device: Device)
	vk.load_proc_addresses(graphicsContext.device)

	vk.GetDeviceQueue(
		graphicsContext.device,
		graphicsContext.queueFamilies.graphicsFamily,
		0,
		&graphicsContext.graphicsQueue,
	)
	vk.GetDeviceQueue(
		graphicsContext.device,
		graphicsContext.queueFamilies.presentFamily,
		0,
		&graphicsContext.presentQueue,
	)
	vk.GetDeviceQueue(
		graphicsContext.device,
		graphicsContext.queueFamilies.computeFamily,
		0,
		&graphicsContext.computeQueue,
	)
}

// ###################################################################
// #                            Swapchain                            #
// ###################################################################

@(private = "file")
getSwapchainInfo :: proc(graphicsContext: ^GraphicsContext) {
	swapchainSupport := querySwapchainSupport(graphicsContext.physicalDevice, graphicsContext)
	delete(swapchainSupport.formats)
	delete(swapchainSupport.modes)

	ideal := swapchainSupport.capabilities.minImageCount + 1
	max := swapchainSupport.capabilities.maxImageCount
	graphicsContext.swapchainImageCount = max if max > 0 && ideal > max else ideal
	graphicsContext.swapchainTransform = swapchainSupport.capabilities.currentTransform
}

@(private = "file")
createSwapchain :: proc(graphicsContext: ^GraphicsContext) {
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
		graphicsContext: ^GraphicsContext,
	) -> (
		extent: vk.Extent2D,
	) {
		if capabilities.currentExtent.width != max(u32) {
			return capabilities.currentExtent
		}
		width, height := glfw.GetFramebufferSize(graphicsContext.window)
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

	swapchainSupport := querySwapchainSupport(graphicsContext.physicalDevice, graphicsContext)
	graphicsContext.swapchainFormat = chooseFormat(swapchainSupport.formats)
	graphicsContext.swapchainMode = choosePresentMode(swapchainSupport.modes)
	graphicsContext.swapchainExtent = chooseExtent(swapchainSupport.capabilities, graphicsContext)
	delete(swapchainSupport.formats)
	delete(swapchainSupport.modes)

	oneQueueFamily :=
		graphicsContext.queueFamilies.graphicsFamily ==
			graphicsContext.queueFamilies.presentFamily &&
		graphicsContext.queueFamilies.graphicsFamily == graphicsContext.queueFamilies.computeFamily
	createInfo: vk.SwapchainCreateInfoKHR = {
		sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
		pNext                 = nil,
		flags                 = {},
		surface               = graphicsContext.surface,
		minImageCount         = graphicsContext.swapchainImageCount,
		imageFormat           = graphicsContext.swapchainFormat.format,
		imageColorSpace       = graphicsContext.swapchainFormat.colorSpace,
		imageExtent           = graphicsContext.swapchainExtent,
		imageArrayLayers      = 1,
		imageUsage            = {.TRANSFER_DST, .COLOR_ATTACHMENT},
		imageSharingMode      = oneQueueFamily ? .EXCLUSIVE : .CONCURRENT,
		queueFamilyIndexCount = oneQueueFamily ? 0 : 2,
		pQueueFamilyIndices   = oneQueueFamily ? nil : raw_data([]u32{graphicsContext.queueFamilies.graphicsFamily, graphicsContext.queueFamilies.presentFamily, graphicsContext.queueFamilies.computeFamily}),
		preTransform          = graphicsContext.swapchainTransform,
		compositeAlpha        = {.OPAQUE},
		presentMode           = graphicsContext.swapchainMode,
		clipped               = true,
		oldSwapchain          = {},
	}

	if vk.CreateSwapchainKHR(
		   graphicsContext.device,
		   &createInfo,
		   nil,
		   &graphicsContext.swapchain,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create swapchain!")
		panic("Failed to create swapchain!")
	}

	vk.GetSwapchainImagesKHR(
		graphicsContext.device,
		graphicsContext.swapchain,
		&graphicsContext.swapchainImageCount,
		raw_data(graphicsContext.swapchainImages),
	)

	for index in 0 ..< graphicsContext.swapchainImageCount {
		graphicsContext.swapchainImageViews[index] = createImageView(
			graphicsContext,
			graphicsContext.swapchainImages[index],
			.D2,
			graphicsContext.swapchainFormat.format,
			{.COLOR},
			1,
		)
	}
}

@(private = "file")
recreateSwapchain :: proc(graphicsContext: ^GraphicsContext) {
	width, height := glfw.GetFramebufferSize(graphicsContext.window)
	for width == 0 && height == 0 {
		width, height = glfw.GetFramebufferSize(graphicsContext.window)
		glfw.WaitEvents()
	}

	vk.DeviceWaitIdle(graphicsContext.device)
	cleanupSwapchain(graphicsContext)

	createSwapchain(graphicsContext)
	createFramebuffers(graphicsContext)
	createStorageImage(graphicsContext)
	createPostDescriptorSets(graphicsContext)
	createPostPipeline(graphicsContext)
}

// ###################################################################
// #                             Commands                            #
// ###################################################################

@(private = "file")
createCommandBuffers :: proc(graphicsContext: ^GraphicsContext) {
	poolInfo: vk.CommandPoolCreateInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		pNext            = nil,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = graphicsContext.queueFamilies.graphicsFamily,
	}
	if vk.CreateCommandPool(
		   graphicsContext.device,
		   &poolInfo,
		   nil,
		   &graphicsContext.graphicsCommandPool,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create command pool!")
		panic("Failed to create command pool!")
	}

	graphicsContext.graphicsCommandBuffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
	allocInfo: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = graphicsContext.graphicsCommandPool,
		level              = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}
	if vk.AllocateCommandBuffers(
		   graphicsContext.device,
		   &allocInfo,
		   raw_data(graphicsContext.graphicsCommandBuffers),
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to allocate command buffer!")
		panic("Failed to allocate command buffer!")
	}

	poolInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		pNext            = nil,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = graphicsContext.queueFamilies.computeFamily,
	}
	if vk.CreateCommandPool(
		   graphicsContext.device,
		   &poolInfo,
		   nil,
		   &graphicsContext.computeCommandPool,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create command pool!")
		panic("Failed to create command pool!")
	}

	graphicsContext.computeCommandBuffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
	allocInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = graphicsContext.computeCommandPool,
		level              = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}
	if vk.AllocateCommandBuffers(
		   graphicsContext.device,
		   &allocInfo,
		   raw_data(graphicsContext.computeCommandBuffers),
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to allocate command buffer!")
		panic("Failed to allocate command buffer!")
	}
}

@(private = "file")
beginSingleTimeCommands :: proc(
	graphicsContext: ^GraphicsContext,
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
	vk.AllocateCommandBuffers(graphicsContext.device, &allocInfo, &commandBuffer)
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
	graphicsContext: ^GraphicsContext,
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
	vk.QueueSubmit(graphicsContext.graphicsQueue, 1, &submitInfo, fence)
	vk.QueueWaitIdle(graphicsContext.graphicsQueue)
	vk.FreeCommandBuffers(graphicsContext.device, commandPool, 1, &commandBuffer)
}

// ###################################################################
// #                             Buffers                             #
// ###################################################################

@(private = "file")
createBuffer :: proc(
	graphicsContext: ^GraphicsContext,
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
	if vk.CreateBuffer(graphicsContext.device, &bufferInfo, nil, buffer) != .SUCCESS {
		log.log(.Error, "Failed to create buffer!")
		panic("Failed to create buffer!")
	}

	memRequirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(graphicsContext.device, buffer^, &memRequirements)
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
	if vk.AllocateMemory(graphicsContext.device, &allocInfo, nil, bufferMemory) != .SUCCESS {
		log.log(.Error, "Failed to allocate buffer memory!")
		panic("Failed to allocate buffer memory!")
	}
	vk.BindBufferMemory(graphicsContext.device, buffer^, bufferMemory^, 0)
}

@(private = "file")
loadBufferToGPU :: proc(
	graphicsContext: ^GraphicsContext,
	bufferSize: int,
	srcData: rawptr,
	dstBuffer: ^Buffer,
	bufferType: vk.BufferUsageFlag,
) {
	copyBuffer :: proc(
		graphicsContext: ^GraphicsContext,
		srcBuffer, dstBuffer: vk.Buffer,
		size: int,
	) {
		commandBuffer: vk.CommandBuffer = beginSingleTimeCommands(
			graphicsContext,
			graphicsContext.graphicsCommandPool,
		)
		copyRegion: vk.BufferCopy = {
			srcOffset = 0,
			dstOffset = 0,
			size      = vk.DeviceSize(size),
		}
		vk.CmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion)
		endSingleTimeCommands(graphicsContext, commandBuffer, graphicsContext.graphicsCommandPool)
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
		graphicsContext.device,
		stagingBufferMemory,
		0,
		(vk.DeviceSize)(bufferSize),
		{},
		&data,
	)
	mem.copy(data, srcData, bufferSize)
	vk.UnmapMemory(graphicsContext.device, stagingBufferMemory)

	createBuffer(
		graphicsContext,
		bufferSize,
		{.TRANSFER_DST, bufferType},
		{.DEVICE_LOCAL},
		&dstBuffer^.buffer,
		&dstBuffer^.memory,
	)

	copyBuffer(graphicsContext, stagingBuffer, dstBuffer^.buffer, bufferSize)
	vk.DestroyBuffer(graphicsContext.device, stagingBuffer, nil)
	vk.FreeMemory(graphicsContext.device, stagingBufferMemory, nil)
}

@(private = "file")
createVertexBuffer :: proc(graphicsContext: ^GraphicsContext) {
	loadBufferToGPU(
		graphicsContext,
		size_of(Vertex) * len(graphicsContext.vertices),
		raw_data(graphicsContext.vertices),
		&graphicsContext.vertexBuffer,
		.VERTEX_BUFFER,
	)
	graphicsContext.vertexBuffer.mapped = nil
}

@(private = "file")
createIndexBuffer :: proc(graphicsContext: ^GraphicsContext) {
	loadBufferToGPU(
		graphicsContext,
		size_of(u32) * len(graphicsContext.indices),
		raw_data(graphicsContext.indices),
		&graphicsContext.indexBuffer,
		.INDEX_BUFFER,
	)
	graphicsContext.indexBuffer.mapped = nil
}

@(private = "file")
createViewProjectionUniform :: proc(graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(ViewProjectionUniform),
			{.UNIFORM_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&graphicsContext.viewProjectionUniforms[i].buffer,
			&graphicsContext.viewProjectionUniforms[i].memory,
		)
		vk.MapMemory(
			graphicsContext.device,
			graphicsContext.viewProjectionUniforms[i].memory,
			0,
			size_of(ViewProjectionUniform),
			{},
			&graphicsContext.viewProjectionUniforms[i].mapped,
		)
	}
}

@(private = "file")
createInstanceBuffer :: proc(graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Instance) * len(graphicsContext.instances),
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&graphicsContext.instanceBuffers[i].buffer,
			&graphicsContext.instanceBuffers[i].memory,
		)
		vk.MapMemory(
			graphicsContext.device,
			graphicsContext.instanceBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Instance) * len(graphicsContext.instances)),
			{},
			&graphicsContext.instanceBuffers[i].mapped,
		)
	}
}

@(private = "file")
createBoneBuffer :: proc(graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Mat4) * graphicsContext.boneCount,
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&graphicsContext.boneBuffers[i].buffer,
			&graphicsContext.boneBuffers[i].memory,
		)
		vk.MapMemory(
			graphicsContext.device,
			graphicsContext.boneBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Mat4) * graphicsContext.boneCount),
			{},
			&graphicsContext.boneBuffers[i].mapped,
		)
	}
}

// ###################################################################
// #                              Images                             #
// ###################################################################

@(private = "file")
findMemoryType :: proc(
	graphicsContext: ^GraphicsContext,
	typeFilter: u32,
	properties: vk.MemoryPropertyFlags,
) -> u32 {
	memProperties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(graphicsContext.physicalDevice, &memProperties)
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
	graphicsContext: ^GraphicsContext,
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

	if vk.CreateImage(graphicsContext.device, &imageInfo, nil, &image^.image) != .SUCCESS {
		log.log(.Error, "Failed to create texture!")
		panic("Failed to create texture!")
	}

	memRequirements: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(graphicsContext.device, image^.image, &memRequirements)
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
	if vk.AllocateMemory(graphicsContext.device, &allocInfo, nil, &image.memory) != .SUCCESS {
		log.log(.Error, "Failed to allocate image memory!")
		panic("Failed to allocate image memory!")
	}
	if vk.BindImageMemory(graphicsContext.device, image.image, image.memory, 0) != .SUCCESS {
		log.log(.Error, "Failed to bind image memory!")
		panic("Failed to bind image memory!")
	}
}

@(private = "file")
createImageView :: proc(
	graphicsContext: ^GraphicsContext,
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
	if vk.CreateImageView(graphicsContext.device, &viewInfo, nil, &imageView) != .SUCCESS {
		log.log(.Error, "Failed to create image view!")
		panic("Failed to create image view!")
	}
	return imageView
}

transitionImageLayout :: proc(
	graphicsContext: ^GraphicsContext,
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
	graphicsContext: ^GraphicsContext,
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
	graphicsContext: ^GraphicsContext,
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
loadModels :: proc(graphicsContext: ^GraphicsContext, modelPaths: []cstring) {
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

	graphicsContext.models = make([]Model, len(modelPaths))
	vertices: [dynamic]Vertex
	indices: [dynamic]u32
	vertexCount: u32 = 0
	indexCount: u32 = 0
	for path, index in modelPaths {
		graphicsContext.models[index].vertexOffset = vertexCount
		graphicsContext.models[index].indexOffset = indexCount
		loadFBX(graphicsContext, &graphicsContext.models[index], path)
		append(&vertices, ..graphicsContext.models[index].vertices)
		append(&indices, ..graphicsContext.models[index].indices)
		vertexCount += u32(len(graphicsContext.models[index].vertices))
		indexCount += graphicsContext.models[index].indexCount
	}
	graphicsContext.vertices = vertices[:]
	graphicsContext.indices = indices[:]
}

@(private = "file")
loadTextures :: proc(graphicsContext: ^GraphicsContext, texture: ^Image, texturePaths: []cstring) {
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
			graphicsContext.device,
			stagingBufferMemory,
			vk.DeviceSize(textureSize * index),
			vk.DeviceSize(textureSize),
			{},
			&data,
		)
		mem.copy(data, pixels, textureSize)
		vk.UnmapMemory(graphicsContext.device, stagingBufferMemory)
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

	commandBuffer := beginSingleTimeCommands(graphicsContext, graphicsContext.graphicsCommandPool)
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
	endSingleTimeCommands(graphicsContext, commandBuffer, graphicsContext.graphicsCommandPool)

	vk.DestroyBuffer(graphicsContext.device, stagingBuffer, nil)
	vk.FreeMemory(graphicsContext.device, stagingBufferMemory, nil)

	texture.view = createImageView(
		graphicsContext,
		texture.image,
		.D2_ARRAY,
		texture.format,
		{.COLOR},
		1,
	)

	properties: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(graphicsContext.physicalDevice, &properties)
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
	graphicsContext: ^GraphicsContext,
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
	if vk.CreateSampler(graphicsContext.device, &samplerInfo, nil, &sampler) != .SUCCESS {
		log.log(.Error, "Failed to create texture sampler!")
		panic("Failed to create texture sampler!")
	}
	return
}

@(private = "file")
loadAssets :: proc(graphicsContext: ^GraphicsContext) {
	if graphicsContext.hasAssetsLoaded {
		cleanupAssets(graphicsContext)
	}

	loadModels(graphicsContext, {MODEL_PATH})

	createVertexBuffer(graphicsContext)
	createIndexBuffer(graphicsContext)

	loadTextures(graphicsContext, &graphicsContext.albidos, {TEXTURE_PATH})
	loadTextures(graphicsContext, &graphicsContext.normals, {NORMALS_PATH})

	now := t.now()
	graphicsContext.instances = make([]Instance, 1)
	for &instance, index in graphicsContext.instances {
		instance = {
			modelID       = 0,
			animID        = 0,
			textureID     = 0,
			position      = {0, 0, 0},
			rotation      = quatFromY(f32(radians(180.0))),
			scale         = {0.003, 0.003, 0.003},
			animStartTime = now,
		}
		graphicsContext.boneCount += len(graphicsContext.models[instance.modelID].skeleton)
		instance.positionKeys = make([]u32, len(graphicsContext.models[instance.modelID].skeleton))
		instance.rotationKeys = make([]u32, len(graphicsContext.models[instance.modelID].skeleton))
		instance.scaleKeys = make([]u32, len(graphicsContext.models[instance.modelID].skeleton))
	}

	createInstanceBuffer(graphicsContext)
	createBoneBuffer(graphicsContext)

	graphicsContext.hasAssetsLoaded = true
}

// ###################################################################
// #                        Shader Descriptors                       #
// ###################################################################

@(private = "file")
createMainDescriptorSets :: proc(graphicsContext: ^GraphicsContext) {
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
		   graphicsContext.device,
		   &poolInfo,
		   nil,
		   &graphicsContext.descriptorPools[PipelineType.MAIN],
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
		   graphicsContext.device,
		   &layoutInfo,
		   nil,
		   &graphicsContext.descriptorSetLayouts[PipelineType.MAIN],
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create descriptor set layout!")
		panic("Failed to create descriptor set layout!")
	}

	layouts := make([]vk.DescriptorSetLayout, MAX_FRAMES_IN_FLIGHT)
	defer delete(layouts)

	for &layout in layouts {
		layout = graphicsContext.descriptorSetLayouts[PipelineType.MAIN]
	}

	allocInfo: vk.DescriptorSetAllocateInfo = {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		pNext              = nil,
		descriptorPool     = graphicsContext.descriptorPools[PipelineType.MAIN],
		descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
		pSetLayouts        = raw_data(layouts),
	}

	if vk.AllocateDescriptorSets(
		   graphicsContext.device,
		   &allocInfo,
		   raw_data(graphicsContext.descriptorSets[PipelineType.MAIN]),
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to allocate descriptor sets!")
		panic("Failed to allocate descriptor sets!")
	}

	textureInfo: vk.DescriptorImageInfo = {
		sampler     = graphicsContext.albidos.sampler,
		imageView   = graphicsContext.albidos.view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}

	normalInfo: vk.DescriptorImageInfo = {
		sampler     = graphicsContext.normals.sampler,
		imageView   = graphicsContext.normals.view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		uniformBufferInfo: vk.DescriptorBufferInfo = {
			buffer = graphicsContext.viewProjectionUniforms[index].buffer,
			offset = 0,
			range  = size_of(ViewProjectionUniform),
		}

		instanceBufferInfo: vk.DescriptorBufferInfo = {
			buffer = graphicsContext.instanceBuffers[index].buffer,
			offset = 0,
			range  = vk.DeviceSize(len(graphicsContext.instances) * size_of(InstanceInfo)),
		}

		boneBufferInfo: vk.DescriptorBufferInfo = {
			buffer = graphicsContext.boneBuffers[index].buffer,
			offset = 0,
			range  = vk.DeviceSize(graphicsContext.boneCount * size_of(Mat4)),
		}

		descriptorWrite: []vk.WriteDescriptorSet = {
			{
				sType = .WRITE_DESCRIPTOR_SET,
				pNext = nil,
				dstSet = graphicsContext.descriptorSets[PipelineType.MAIN][index],
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
				dstSet = graphicsContext.descriptorSets[PipelineType.MAIN][index],
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
				dstSet = graphicsContext.descriptorSets[PipelineType.MAIN][index],
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
				dstSet = graphicsContext.descriptorSets[PipelineType.MAIN][index],
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
				dstSet = graphicsContext.descriptorSets[PipelineType.MAIN][index],
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
			graphicsContext.device,
			u32(len(descriptorWrite)),
			raw_data(descriptorWrite),
			0,
			nil,
		)
	}
}

@(private = "file")
createPostDescriptorSets :: proc(graphicsContext: ^GraphicsContext) {
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
		   graphicsContext.device,
		   &poolInfo,
		   nil,
		   &graphicsContext.descriptorPools[PipelineType.POST],
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
		   graphicsContext.device,
		   &layoutInfo,
		   nil,
		   &graphicsContext.descriptorSetLayouts[PipelineType.POST],
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create compute descriptor set layout!")
		panic("Failed to create compute descriptor set layout!")
	}

	layouts := make([]vk.DescriptorSetLayout, MAX_FRAMES_IN_FLIGHT)
	defer delete(layouts)
	for &layout in layouts {
		layout = graphicsContext.descriptorSetLayouts[PipelineType.POST]
	}

	allocInfo: vk.DescriptorSetAllocateInfo = {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		pNext              = nil,
		descriptorPool     = graphicsContext.descriptorPools[PipelineType.POST],
		descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
		pSetLayouts        = raw_data(layouts),
	}

	if vk.AllocateDescriptorSets(
		   graphicsContext.device,
		   &allocInfo,
		   raw_data(graphicsContext.descriptorSets[PipelineType.POST]),
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to allocate compute descriptor sets!")
		panic("Failed to allocate compute descriptor sets!")
	}

	inImageInfo: vk.DescriptorImageInfo = {
		sampler     = graphicsContext.inImage.sampler,
		imageView   = graphicsContext.inImage.view,
		imageLayout = .GENERAL,
	}
	outImageInfo: vk.DescriptorImageInfo = {
		sampler     = graphicsContext.outImage.sampler,
		imageView   = graphicsContext.outImage.view,
		imageLayout = .GENERAL,
	}

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		descriptorWrite: []vk.WriteDescriptorSet = {
			{
				sType = .WRITE_DESCRIPTOR_SET,
				pNext = nil,
				dstSet = graphicsContext.descriptorSets[PipelineType.POST][index],
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
				dstSet = graphicsContext.descriptorSets[PipelineType.POST][index],
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
			graphicsContext.device,
			u32(len(descriptorWrite)),
			raw_data(descriptorWrite),
			0,
			nil,
		)
	}
}

// ###################################################################
// #                         Frame Resources                         #
// ###################################################################

@(private = "file")
createStorageImage :: proc(graphicsContext: ^GraphicsContext) {
	graphicsContext.inImage.format = graphicsContext.swapchainFormat.format
	createImage(
		graphicsContext,
		&graphicsContext.inImage,
		{},
		.D2,
		graphicsContext.swapchainExtent.width,
		graphicsContext.swapchainExtent.height,
		1,
		{._1},
		.OPTIMAL,
		{.TRANSFER_DST, .SAMPLED, .STORAGE},
		{.DEVICE_LOCAL},
		.EXCLUSIVE,
		0,
		nil,
	)
	graphicsContext.inImage.view = createImageView(
		graphicsContext,
		graphicsContext.inImage.image,
		.D2,
		graphicsContext.inImage.format,
		{.COLOR},
		1,
	)
	graphicsContext.outImage.format = graphicsContext.swapchainFormat.format
	createImage(
		graphicsContext,
		&graphicsContext.outImage,
		{},
		.D2,
		graphicsContext.swapchainExtent.width,
		graphicsContext.swapchainExtent.height,
		1,
		{._1},
		.OPTIMAL,
		{.TRANSFER_SRC, .SAMPLED, .STORAGE},
		{.DEVICE_LOCAL},
		.EXCLUSIVE,
		0,
		nil,
	)
	graphicsContext.outImage.view = createImageView(
		graphicsContext,
		graphicsContext.outImage.image,
		.D2,
		graphicsContext.outImage.format,
		{.COLOR},
		1,
	)
}

@(private = "file")
createSyncObjects :: proc(graphicsContext: ^GraphicsContext) {
	graphicsContext.imagesAvailable = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	graphicsContext.rendersFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	graphicsContext.computeFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	graphicsContext.inFlightFrames = make([]vk.Fence, MAX_FRAMES_IN_FLIGHT)
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
				graphicsContext.device,
				&semaphoreInfo,
				nil,
				&graphicsContext.imagesAvailable[index],
			) |
			vk.CreateSemaphore(
				graphicsContext.device,
				&semaphoreInfo,
				nil,
				&graphicsContext.rendersFinished[index],
			) |
			vk.CreateSemaphore(
				graphicsContext.device,
				&semaphoreInfo,
				nil,
				&graphicsContext.computeFinished[index],
			) |
			vk.CreateFence(
				graphicsContext.device,
				&fenceInfo,
				nil,
				&graphicsContext.inFlightFrames[index],
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
createRenderPass :: proc(graphicsContext: ^GraphicsContext) {
	findSupportedDepthFormat :: proc(
		graphicsContext: ^GraphicsContext,
		candidates: []vk.Format,
		tiling: vk.ImageTiling,
		features: vk.FormatFeatureFlags,
	) -> vk.Format {
		for format in candidates {
			props: vk.FormatProperties
			vk.GetPhysicalDeviceFormatProperties(graphicsContext.physicalDevice, format, &props)
			if tiling == .LINEAR && (props.linearTilingFeatures & features) == features {
				return format
			} else if tiling == .OPTIMAL && (props.optimalTilingFeatures & features) == features {
				return format
			}
		}
		log.log(.Error, "Failed to find supported format!")
		panic("Failed to find supported format!")
	}

	hasStencilComponent :: proc(format: vk.Format) -> bool {
		return format == .D32_SFLOAT_S8_UINT || format == .D24_UNORM_S8_UINT
	}

	graphicsContext.colourImage.format = graphicsContext.swapchainFormat.format
	createImage(
		graphicsContext,
		&graphicsContext.colourImage,
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
	graphicsContext.colourImage.view = createImageView(
		graphicsContext,
		graphicsContext.colourImage.image,
		.D2,
		graphicsContext.colourImage.format,
		{.COLOR},
		1,
	)

	graphicsContext.depthImage.format = findSupportedDepthFormat(
		graphicsContext,
		{.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
	)
	createImage(
		graphicsContext,
		&graphicsContext.depthImage,
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
	graphicsContext.depthImage.view = createImageView(
		graphicsContext,
		graphicsContext.depthImage.image,
		.D2,
		graphicsContext.depthImage.format,
		{.DEPTH},
		1,
	)

	attachments: []vk.AttachmentDescription = {
		{
			flags = {},
			format = graphicsContext.colourImage.format,
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
			format = graphicsContext.depthImage.format,
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
		   graphicsContext.device,
		   &renderPassInfo,
		   nil,
		   &graphicsContext.renderPass,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Unable to create render pass!")
		panic("Unable to create render pass!")
	}
}

@(private = "file")
createFramebuffers :: proc(graphicsContext: ^GraphicsContext) {
	imageViewCount := u32(len(graphicsContext.swapchainImageViews))

	frameBufferInfo: vk.FramebufferCreateInfo = {
		sType           = .FRAMEBUFFER_CREATE_INFO,
		pNext           = nil,
		flags           = {},
		renderPass      = graphicsContext.renderPass,
		attachmentCount = 2,
		pAttachments    = raw_data(
			[]vk.ImageView{graphicsContext.colourImage.view, graphicsContext.depthImage.view},
		),
		width           = u32(RENDER_SIZE.x),
		height          = u32(RENDER_SIZE.y),
		layers          = 1,
	}

	for index in 0 ..< imageViewCount {
		if vk.CreateFramebuffer(
			   graphicsContext.device,
			   &frameBufferInfo,
			   nil,
			   &graphicsContext.swapchainFrameBuffers[index],
		   ) !=
		   .SUCCESS {
			log.log(.Error, "Failed to create frame buffer!")
			panic("Failed to create frame buffer!")
		}
	}
}

@(private = "file")
createShaderModule :: proc(
	graphicsContext: ^GraphicsContext,
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
	if vk.CreateShaderModule(graphicsContext.device, &createInfo, nil, &shaderModule) != .SUCCESS {
		log.log(.Error, "Failed to create shader module")
		panic("Failed to create shader module")
	}
	delete(code)
	return
}

@(private = "file")
createMainPipeline :: proc(graphicsContext: ^GraphicsContext) {
	PipelineLayoutInfo: vk.PipelineLayoutCreateInfo = {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		pNext                  = nil,
		flags                  = {},
		setLayoutCount         = 1,
		pSetLayouts            = &graphicsContext.descriptorSetLayouts[PipelineType.MAIN],
		pushConstantRangeCount = 0,
		pPushConstantRanges    = nil,
	}

	if vk.CreatePipelineLayout(
		   graphicsContext.device,
		   &PipelineLayoutInfo,
		   nil,
		   &graphicsContext.pipelineLayouts[PipelineType.MAIN],
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
			vk.DestroyShaderModule(graphicsContext.device, stage.module, nil)
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
		layout              = graphicsContext.pipelineLayouts[PipelineType.MAIN],
		renderPass          = graphicsContext.renderPass,
		subpass             = 0,
		basePipelineHandle  = {},
		basePipelineIndex   = 0,
	}

	if vk.CreateGraphicsPipelines(
		   graphicsContext.device,
		   0,
		   1,
		   &pipelineInfo,
		   nil,
		   &graphicsContext.pipelines[PipelineType.MAIN],
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create pipeline!")
		panic("Failed to create pipeline!")
	}
}

@(private = "file")
createPostPipeline :: proc(graphicsContext: ^GraphicsContext) {
	PipelineLayoutInfo: vk.PipelineLayoutCreateInfo = {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		pNext                  = nil,
		flags                  = {},
		setLayoutCount         = 1,
		pSetLayouts            = &graphicsContext.descriptorSetLayouts[PipelineType.POST],
		pushConstantRangeCount = 0,
		pPushConstantRanges    = nil,
	}

	if vk.CreatePipelineLayout(
		   graphicsContext.device,
		   &PipelineLayoutInfo,
		   nil,
		   &graphicsContext.pipelineLayouts[PipelineType.POST],
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
		layout             = graphicsContext.pipelineLayouts[PipelineType.POST],
		basePipelineHandle = {},
		basePipelineIndex  = 0,
	}

	if vk.CreateComputePipelines(
		   graphicsContext.device,
		   0,
		   1,
		   &pipelineInfo,
		   nil,
		   &graphicsContext.pipelines[PipelineType.POST],
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create postprocess pipeline!")
		panic("Failed to create postprocess pipeline!")
	}

	vk.DestroyShaderModule(graphicsContext.device, shaderStageInfo.module, nil)
}

// ###################################################################
// #                           Render Loop                           #
// ###################################################################

@(private = "file")
recordGraphicsBuffer :: proc(
	graphicsContext: ^GraphicsContext,
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
		renderPass = graphicsContext.renderPass,
		framebuffer = graphicsContext.swapchainFrameBuffers[imageIndex],
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
		graphicsContext.pipelineLayouts[PipelineType.MAIN],
		0,
		1,
		&graphicsContext.descriptorSets[PipelineType.MAIN][graphicsContext.currentFrame],
		0,
		nil,
	)

	vk.CmdBindVertexBuffers(
		commandBuffer,
		0,
		1,
		&graphicsContext.vertexBuffer.buffer,
		raw_data([]vk.DeviceSize{0}),
	)
	vk.CmdBindIndexBuffer(commandBuffer, graphicsContext.indexBuffer.buffer, 0, .UINT32)

	vk.CmdBindPipeline(commandBuffer, .GRAPHICS, graphicsContext.pipelines[PipelineType.MAIN])
	for &model in graphicsContext.models {
		vk.CmdDrawIndexed(
			commandBuffer,
			model.indexCount,
			1,
			model.indexOffset,
			i32(model.vertexOffset),
			0,
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
	graphicsContext: ^GraphicsContext,
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
		graphicsContext.colourImage.image,
		.UNDEFINED,
		.TRANSFER_SRC_OPTIMAL,
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		graphicsContext.inImage.image,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		1,
	)

	upscaleImage(
		commandBuffer,
		graphicsContext.colourImage.image,
		graphicsContext.inImage.image,
		vk.Extent2D{u32(RENDER_SIZE.x), u32(RENDER_SIZE.y)},
		graphicsContext.swapchainExtent,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		graphicsContext.inImage.image,
		.TRANSFER_DST_OPTIMAL,
		.GENERAL,
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		graphicsContext.outImage.image,
		.TRANSFER_SRC_OPTIMAL,
		.GENERAL,
		1,
	)

	vk.CmdBindDescriptorSets(
		commandBuffer,
		.COMPUTE,
		graphicsContext.pipelineLayouts[PipelineType.POST],
		0,
		1,
		&graphicsContext.descriptorSets[PipelineType.POST][graphicsContext.currentFrame],
		0,
		nil,
	)

	vk.CmdBindPipeline(commandBuffer, .COMPUTE, graphicsContext.pipelines[PipelineType.POST])

	vk.CmdDispatch(
		commandBuffer,
		graphicsContext.swapchainExtent.width / 32 + 1,
		graphicsContext.swapchainExtent.height / 32 + 1,
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		graphicsContext.outImage.image,
		.UNDEFINED,
		.TRANSFER_SRC_OPTIMAL,
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		graphicsContext.swapchainImages[imageIndex],
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		1,
	)

	copyImage(
		commandBuffer,
		vk.Extent3D {
			graphicsContext.swapchainExtent.width,
			graphicsContext.swapchainExtent.height,
			1,
		},
		graphicsContext.outImage.image,
		graphicsContext.swapchainImages[imageIndex],
		.TRANSFER_SRC_OPTIMAL,
		.TRANSFER_DST_OPTIMAL,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		graphicsContext.swapchainImages[imageIndex],
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
updateViewProjectionUniform :: proc(graphicsContext: ^GraphicsContext, camera: Camera) {
	view := lookAt(camera.eye, camera.center, camera.up)
	projection: Mat4
	if camera.mode == .PERSPECTIVE {
		projection = perspective(
			radians(f32(45.0)),
			f32(graphicsContext.swapchainExtent.width) /
			f32(graphicsContext.swapchainExtent.height),
			0.1,
			10000,
		)
	} else if camera.mode == .ORTHOGRAPHIC {
		projection = orthographic(
			radians(f32(45.0)),
			f32(graphicsContext.swapchainExtent.width) /
			f32(graphicsContext.swapchainExtent.height),
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
		graphicsContext.viewProjectionUniforms[graphicsContext.currentFrame].mapped,
		&viewProjection,
		size_of(ViewProjectionUniform),
	)
}

@(private = "file")
updateInstanceBuffer :: proc(graphicsContext: ^GraphicsContext) {
	finalBoneTransforms := make([]Mat4, graphicsContext.boneCount)
	instanceData := make([]InstanceInfo, len(graphicsContext.instances))
	defer delete(finalBoneTransforms)
	defer delete(instanceData)
	finalBoneTransforms[0] = IMat4
	boneOffset: u32 = 1
	now := t.now()
	for &instance, instanceIndex in graphicsContext.instances {
		instanceData[instanceIndex] = {
			model         = translate(
				instance.position,
			) * quatToRotation(instance.rotation) * scale(instance.scale),
			boneOffset    = boneOffset,
			samplerOffset = f32(instance.textureID),
		}

		model := &graphicsContext.models[instance.modelID]

		if len(model^.skeleton) == 0 {
			instanceData[instanceIndex].boneOffset = 0
			continue
		}

		skeleton := &model^.skeleton
		animation := model^.animations[instance.animID]
		timeSinceAnimStart := t.duration_seconds(t.diff(instance.animStartTime, now))
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
		graphicsContext.boneBuffers[graphicsContext.currentFrame].mapped,
		raw_data(finalBoneTransforms),
		len(finalBoneTransforms) * size_of(Mat4),
	)
	mem.copy(
		graphicsContext.instanceBuffers[graphicsContext.currentFrame].mapped,
		raw_data(instanceData),
		len(graphicsContext.instances) * size_of(InstanceInfo),
	)
}

drawFrame :: proc(graphicsContext: ^GraphicsContext, camera: Camera) {
	vk.WaitForFences(
		graphicsContext.device,
		1,
		&graphicsContext.inFlightFrames[graphicsContext.currentFrame],
		true,
		max(u64),
	)

	imageIndex: u32
	if result := vk.AcquireNextImageKHR(
		graphicsContext.device,
		graphicsContext.swapchain,
		max(u64),
		graphicsContext.imagesAvailable[graphicsContext.currentFrame],
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
		graphicsContext.device,
		1,
		&graphicsContext.inFlightFrames[graphicsContext.currentFrame],
	)

	vk.ResetCommandBuffer(graphicsContext.graphicsCommandBuffers[graphicsContext.currentFrame], {})
	vk.ResetCommandBuffer(graphicsContext.computeCommandBuffers[graphicsContext.currentFrame], {})
	updateViewProjectionUniform(graphicsContext, camera)
	updateInstanceBuffer(graphicsContext)
	recordGraphicsBuffer(
		graphicsContext,
		graphicsContext.graphicsCommandBuffers[graphicsContext.currentFrame],
		imageIndex,
	)
	recordComputeBuffer(
		graphicsContext,
		graphicsContext.computeCommandBuffers[graphicsContext.currentFrame],
		imageIndex,
	)

	submitInfo: vk.SubmitInfo = {
		sType                = .SUBMIT_INFO,
		pNext                = nil,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = &graphicsContext.imagesAvailable[graphicsContext.currentFrame],
		pWaitDstStageMask    = &vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT},
		commandBufferCount   = 1,
		pCommandBuffers      = &graphicsContext.graphicsCommandBuffers[graphicsContext.currentFrame],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &graphicsContext.rendersFinished[graphicsContext.currentFrame],
	}

	if vk.QueueSubmit(graphicsContext.graphicsQueue, 1, &submitInfo, 0) != .SUCCESS {
		log.log(.Error, "Failed to submit draw command buffer!")
		panic("Failed to submit draw command buffer!")
	}

	submitInfo = {
		sType                = .SUBMIT_INFO,
		pNext                = nil,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = &graphicsContext.rendersFinished[graphicsContext.currentFrame],
		pWaitDstStageMask    = &vk.PipelineStageFlags{.BOTTOM_OF_PIPE},
		commandBufferCount   = 1,
		pCommandBuffers      = &graphicsContext.computeCommandBuffers[graphicsContext.currentFrame],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &graphicsContext.computeFinished[graphicsContext.currentFrame],
	}

	if vk.QueueSubmit(
		   graphicsContext.computeQueue,
		   1,
		   &submitInfo,
		   graphicsContext.inFlightFrames[graphicsContext.currentFrame],
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to submit compute command buffer!")
		panic("Failed to submit compute command buffer!")
	}

	presentInfo: vk.PresentInfoKHR = {
		sType              = .PRESENT_INFO_KHR,
		pNext              = nil,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = &graphicsContext.computeFinished[graphicsContext.currentFrame],
		swapchainCount     = 1,
		pSwapchains        = &graphicsContext.swapchain,
		pImageIndices      = &imageIndex,
		pResults           = nil,
	}

	if result := vk.QueuePresentKHR(graphicsContext.presentQueue, &presentInfo);
	   result == .ERROR_OUT_OF_DATE_KHR ||
	   result == .SUBOPTIMAL_KHR ||
	   graphicsContext.framebufferResized {
		graphicsContext.framebufferResized = false
		recreateSwapchain(graphicsContext)
	} else if result != .SUCCESS {
		log.log(.Error, "Failed to present swapchain image!")
		panic("Failed to present swapchain image!")
	}

	graphicsContext.currentFrame += (graphicsContext.currentFrame + 1) % 2
}

// ###################################################################
// #                             Cleanup                             #
// ###################################################################

@(private = "file")
cleanupSwapchain :: proc(graphicsContext: ^GraphicsContext) {
	for frameBuffer in graphicsContext.swapchainFrameBuffers {
		vk.DestroyFramebuffer(graphicsContext.device, frameBuffer, nil)
	}
	for imageView in graphicsContext.swapchainImageViews {
		vk.DestroyImageView(graphicsContext.device, imageView, nil)
	}
	vk.DestroySwapchainKHR(graphicsContext.device, graphicsContext.swapchain, nil)
	vk.DestroyImageView(graphicsContext.device, graphicsContext.inImage.view, nil)
	vk.DestroyImage(graphicsContext.device, graphicsContext.inImage.image, nil)
	vk.FreeMemory(graphicsContext.device, graphicsContext.inImage.memory, nil)
	vk.DestroyImageView(graphicsContext.device, graphicsContext.outImage.view, nil)
	vk.DestroyImage(graphicsContext.device, graphicsContext.outImage.image, nil)
	vk.FreeMemory(graphicsContext.device, graphicsContext.outImage.memory, nil)

	vk.DestroyDescriptorPool(
		graphicsContext.device,
		graphicsContext.descriptorPools[PipelineType.POST],
		nil,
	)
	vk.DestroyDescriptorSetLayout(
		graphicsContext.device,
		graphicsContext.descriptorSetLayouts[PipelineType.POST],
		nil,
	)
	vk.DestroyPipeline(graphicsContext.device, graphicsContext.pipelines[PipelineType.POST], nil)
	vk.DestroyPipelineLayout(
		graphicsContext.device,
		graphicsContext.pipelineLayouts[PipelineType.POST],
		nil,
	)
}

@(private = "file")
cleanupAssets :: proc(graphicsContext: ^GraphicsContext) {
	vk.DestroyBuffer(graphicsContext.device, graphicsContext.indexBuffer.buffer, nil)
	vk.FreeMemory(graphicsContext.device, graphicsContext.indexBuffer.memory, nil)
	vk.DestroyBuffer(graphicsContext.device, graphicsContext.vertexBuffer.buffer, nil)
	vk.FreeMemory(graphicsContext.device, graphicsContext.vertexBuffer.memory, nil)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyBuffer(graphicsContext.device, graphicsContext.instanceBuffers[i].buffer, nil)
		vk.FreeMemory(graphicsContext.device, graphicsContext.instanceBuffers[i].memory, nil)
		vk.DestroyBuffer(graphicsContext.device, graphicsContext.boneBuffers[i].buffer, nil)
		vk.FreeMemory(graphicsContext.device, graphicsContext.boneBuffers[i].memory, nil)
	}
	vk.DestroyImageView(graphicsContext.device, graphicsContext.albidos.view, nil)
	vk.DestroyImage(graphicsContext.device, graphicsContext.albidos.image, nil)
	vk.FreeMemory(graphicsContext.device, graphicsContext.albidos.memory, nil)
	vk.DestroySampler(graphicsContext.device, graphicsContext.albidos.sampler, nil)

	for model in graphicsContext.models {
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
	delete(graphicsContext.models)
	for instance in graphicsContext.instances {
		delete(instance.scaleKeys)
		delete(instance.positionKeys)
		delete(instance.rotationKeys)
	}
	delete(graphicsContext.instances)
	delete(graphicsContext.vertices)
	delete(graphicsContext.indices)
}

clanupVkGraphics :: proc(graphicsContext: ^GraphicsContext) {
	vk.DeviceWaitIdle(graphicsContext.device)

	cleanupAssets(graphicsContext)

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyBuffer(
			graphicsContext.device,
			graphicsContext.viewProjectionUniforms[index].buffer,
			nil,
		)
		vk.FreeMemory(
			graphicsContext.device,
			graphicsContext.viewProjectionUniforms[index].memory,
			nil,
		)
	}

	cleanupSwapchain(graphicsContext)
	delete(graphicsContext.swapchainImages)
	delete(graphicsContext.swapchainImageViews)
	delete(graphicsContext.swapchainFrameBuffers)

	vk.DestroyDescriptorPool(
		graphicsContext.device,
		graphicsContext.descriptorPools[PipelineType.MAIN],
		nil,
	)
	delete(graphicsContext.descriptorPools)

	vk.DestroyDescriptorSetLayout(
		graphicsContext.device,
		graphicsContext.descriptorSetLayouts[PipelineType.MAIN],
		nil,
	)
	delete(graphicsContext.descriptorSetLayouts)

	for set in graphicsContext.descriptorSets {
		delete(set)
	}
	delete(graphicsContext.descriptorSets)

	vk.DestroyPipeline(graphicsContext.device, graphicsContext.pipelines[PipelineType.MAIN], nil)
	vk.DestroyPipelineLayout(
		graphicsContext.device,
		graphicsContext.pipelineLayouts[PipelineType.MAIN],
		nil,
	)
	delete(graphicsContext.pipelines)
	delete(graphicsContext.pipelineLayouts)

	vk.DestroyRenderPass(graphicsContext.device, graphicsContext.renderPass, nil)

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroySemaphore(graphicsContext.device, graphicsContext.imagesAvailable[index], nil)
		vk.DestroySemaphore(graphicsContext.device, graphicsContext.rendersFinished[index], nil)
		vk.DestroySemaphore(graphicsContext.device, graphicsContext.computeFinished[index], nil)
		vk.DestroyFence(graphicsContext.device, graphicsContext.inFlightFrames[index], nil)
	}
	delete(graphicsContext.imagesAvailable)
	delete(graphicsContext.rendersFinished)
	delete(graphicsContext.computeFinished)
	delete(graphicsContext.inFlightFrames)

	vk.DestroyImageView(graphicsContext.device, graphicsContext.colourImage.view, nil)
	vk.DestroyImage(graphicsContext.device, graphicsContext.colourImage.image, nil)
	vk.FreeMemory(graphicsContext.device, graphicsContext.colourImage.memory, nil)

	vk.DestroyImageView(graphicsContext.device, graphicsContext.depthImage.view, nil)
	vk.DestroyImage(graphicsContext.device, graphicsContext.depthImage.image, nil)
	vk.FreeMemory(graphicsContext.device, graphicsContext.depthImage.memory, nil)

	vk.DestroyCommandPool(graphicsContext.device, graphicsContext.graphicsCommandPool, nil)
	vk.DestroyCommandPool(graphicsContext.device, graphicsContext.computeCommandPool, nil)
	delete(graphicsContext.graphicsCommandBuffers)
	delete(graphicsContext.computeCommandBuffers)

	vk.DestroyDevice(graphicsContext.device, nil)
	when ODIN_DEBUG {
		vk.DestroyDebugUtilsMessengerEXT(
			graphicsContext.instance,
			graphicsContext.debugMessenger,
			nil,
		)
	}
	vk.DestroySurfaceKHR(graphicsContext.instance, graphicsContext.surface, nil)
	vk.DestroyInstance(graphicsContext.instance, nil)
}
