package Valhalla

import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import t "core:time"

import "vendor:glfw"
import "vendor:stb/image"
import vk "vendor:vulkan"

import fbx "ufbx"

// ###################################################################
// #                          Constants                              #
// ###################################################################

@(private = "file")
requestedLayers: []cstring = {"VK_LAYER_KHRONOS_validation"}

@(private = "file")
requiredDeviceExtensions: []cstring = {vk.KHR_SWAPCHAIN_EXTENSION_NAME}

@(private = "file")
skyShaderStages: []vk.ShaderStageFlag = {
	.VERTEX,
	.FRAGMENT,
	/*.COMPUTE,*/
}

@(private = "file")
shaderStages: []vk.ShaderStageFlag = {
	.VERTEX,
	.FRAGMENT,
	/*.COMPUTE,*/
}

@(private = "file")
shaderFiles: []string = {
	"./assets/shaders/shader_vert.spv",
	"./assets/shaders/shader_frag.spv", /*"./assets/shaders/shader_comp.spv",*/
}

@(private = "file")
skyShaderFiles: []string = {"./assets/shaders/skybox_vert.spv", "./assets/shaders/skybox_frag.spv"}

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
		format = .R32G32B32A32_UINT,
		offset = u32(offset_of(Vertex, bones)),
	},
	{
		location = 3,
		binding = 0,
		format = .R32G32B32A32_SFLOAT,
		offset = u32(offset_of(Vertex, weights)),
	},
}

@(private = "file")
ENGINE_VERSION: u32 : (0 << 22) | (0 << 12) | (1)

@(private = "file")
CUBE_PATH: cstring : "./assets/models/cube.fbx"

@(private = "file")
MODEL_PATH: cstring : "./assets/models/dancing.fbx"

@(private = "file")
SKY_FRONT: cstring : "./assets/textures/cubemap_front.jpg"
SKY_BACK: cstring : "./assets/textures/cubemap_back.jpg"
SKY_LEFT: cstring : "./assets/textures/cubemap_left.jpg"
SKY_RIGHT: cstring : "./assets/textures/cubemap_right.jpg"
SKY_TOP: cstring : "./assets/textures/cubemap_top.jpg"
SKY_BOTTOM: cstring : "./assets/textures/cubemap_bottom.jpg"

@(private = "file")
R_TEXTURE_PATH: cstring : "./assets/textures/red.jpg"
G_TEXTURE_PATH: cstring : "./assets/textures/green.jpg"
B_TEXTURE_PATH: cstring : "./assets/textures/blue.jpg"

@(private = "file")
MAX_FRAMES_IN_FLIGHT: u32 : 2

@(private = "file")
MAX_MODEL_INSTANCES: int : 4

// ###################################################################
// #                       Data Structures                           #
// ###################################################################

@(private = "file")
Vertex :: struct {
	position: Vec3,
	texCoord: Vec2,
	bones:    [4]u32,
	weights:  Vec4,
}

@(private = "file")
Bone :: struct {
	name:        cstring,
	isRoot:      bool,
	parentIndex: u32,
	inverseBind: Mat4,
	sceneRoot:   Mat4,
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
	image:     vk.Image,
	memory:    vk.DeviceMemory,
	view:      vk.ImageView,
	format:    vk.Format,
	sampler:   vk.Sampler,
	mipLevels: u32,
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
	SKYBOX = 0,
	MAIN   = 1,
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
}

@(private = "file")
SwapchainSupportDetails :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	formats:      []vk.SurfaceFormatKHR,
	modes:        []vk.PresentModeKHR,
}

Camera :: struct {
	eye, center, up: Vec3,
	distance:        f32,
}

@(private = "file")
Buffer :: struct {
	buffer: vk.Buffer,
	memory: vk.DeviceMemory,
	mapped: rawptr,
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

	// Swapchain
	swapchain:              vk.SwapchainKHR,
	swapchainFormat:        vk.SurfaceFormatKHR,
	swapchainMode:          vk.PresentModeKHR,
	swapchainExtent:        vk.Extent2D,
	swapchainImages:        []vk.Image,
	swapchainImageViews:    []vk.ImageView,
	swapchainFrameBuffers:  []vk.Framebuffer,

	// Frame Resources
	depthImage:             Image,
	colourImage:            Image,
	imagesAvailable:        []vk.Semaphore,
	rendersFinished:        []vk.Semaphore,
	inFlightFrames:         []vk.Fence,

	// Descriptor
	descriptorPool:         vk.DescriptorPool,
	descriptorSets:         []vk.DescriptorSet,

	// Pipeline
	pipelines:              []vk.Pipeline,
	descriptorSetLayout:    vk.DescriptorSetLayout,
	pipelineLayout:         vk.PipelineLayout,
	renderPass:             vk.RenderPass,

	// Commands
	commandPool:            vk.CommandPool,
	commandBuffers:         []vk.CommandBuffer,

	// Assets
	models:                 []Model,
	textures:               Image,
	instances:              []Instance,
	vertices:               []Vertex, // To-Do: Vertex and Index buffers should be one buffer
	indices:                []u32,
	skybox:                 Image,
	boneCount:              int,

	// Buffers
	vertexBuffer:           Buffer,
	indexBuffer:            Buffer,
	viewProjectionUniforms: [MAX_FRAMES_IN_FLIGHT]Buffer, // ToDo: Combine into single buffer
	instanceBuffers:        [MAX_FRAMES_IN_FLIGHT]Buffer,
	boneBuffers:            [MAX_FRAMES_IN_FLIGHT]Buffer,

	// Util
	startTime:              t.Time,
	currentFrame:           u32,
	framebufferResized:     b8,
	msaaSamples:            vk.SampleCountFlags,
	hasAssetsLoaded:        b8,
}

// ###################################################################
// #                          Functions                              #
// ###################################################################

initVkGraphics :: proc(graphicsContext: ^GraphicsContext) {
	// load_proc_addresses_global :: proc(vk_get_instance_proc_addr: rawptr)
	vk.load_proc_addresses(rawptr(glfw.GetInstanceProcAddress))

	graphicsContext^.framebufferResized = false
	graphicsContext^.currentFrame = 0
	graphicsContext^.msaaSamples = {._1}
	graphicsContext^.startTime = t.now()
	graphicsContext^.hasAssetsLoaded = false

	createInstance(graphicsContext)
	when ODIN_DEBUG {
		vkSetupDebugMessenger(graphicsContext)
	}
	createSurface(graphicsContext)
	pickPhysicalDevice(graphicsContext)
	createLogicalDevice(graphicsContext)

	// Swapchain
	createSwapchain(graphicsContext)
	createSwapchainImageViews(graphicsContext)

	// Commands
	createCommandPool(graphicsContext)
	createCommandBuffers(graphicsContext)

	// Assets
	loadAssets(graphicsContext)

	// Shader buffers
	createViewProjectionUniform(graphicsContext)

	// Descriptor Sets
	createDescriptorPool(graphicsContext)
	createDescriptionSetLayout(graphicsContext)
	createDescriptorSets(graphicsContext)

	// Frame Resources
	createColourResources(graphicsContext)
	createDepthResources(graphicsContext)
	createSyncObjects(graphicsContext)

	// Pipeline
	createRenderPass(graphicsContext)
	createFramebuffers(graphicsContext)
	createPipelines(graphicsContext)
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
	vk.EnumerateInstanceExtensionProperties(nil, &extensionCount, raw_data(availableExtensions))
	instance_extension_outer_loop: for name in glfwExtensions {
		for &extension in availableExtensions {
			if name == cstring(&extension.extensionName[0]) {
				append(&supportedExtensions, name)
				continue instance_extension_outer_loop
			}
		}
		log(.ERROR, fmt.aprintf("Failed to find required extension: {}", name))
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
			log(.WARNING, fmt.aprintf("Failed to find requested extension: {}", name))
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

@(private = "file")
createSurface :: proc(graphicsContext: ^GraphicsContext) {
	if glfw.CreateWindowSurface(
		   graphicsContext^.instance,
		   graphicsContext^.window,
		   nil,
		   &graphicsContext^.surface,
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create surface!")
		panic("Failed to create surface!")
	}
}

// ###################################################################
// #                           Device                                #
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
	for queueFamily, index in queueFamilies {
		if .GRAPHICS in queueFamily.queueFlags {
			indices.graphicsFamily = u32(index)
			foundGraphicsFamily = true
		}

		presentSupport: b32
		if vk.GetPhysicalDeviceSurfaceSupportKHR(
			   physicalDevice,
			   (u32)(index),
			   graphicsContext^.surface,
			   &presentSupport,
		   ); presentSupport {
			indices.presentFamily = u32(index)
			foundPresentFamily = true
		}

		if foundGraphicsFamily && foundPresentFamily {
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
		graphicsContext^.surface,
		&swapchainSupport.capabilities,
	)

	formatCount: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(
		physicalDevice,
		graphicsContext^.surface,
		&formatCount,
		nil,
	)
	if formatCount != 0 {
		swapchainSupport.formats = make([]vk.SurfaceFormatKHR, formatCount)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(
			physicalDevice,
			graphicsContext^.surface,
			&formatCount,
			raw_data(swapchainSupport.formats),
		)
	}

	modeCount: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(
		physicalDevice,
		graphicsContext^.surface,
		&modeCount,
		nil,
	)
	if modeCount != 0 {
		swapchainSupport.modes = make([]vk.PresentModeKHR, modeCount)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			physicalDevice,
			graphicsContext^.surface,
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
	vk.EnumeratePhysicalDevices(graphicsContext^.instance, &deviceCount, nil)

	if deviceCount == 0 {
		log(.ERROR, "No devices with Vulkan support!")
		panic("No devices with Vulkan support!")
	}

	physicalDevices := make([]vk.PhysicalDevice, deviceCount)
	vk.EnumeratePhysicalDevices(graphicsContext^.instance, &deviceCount, raw_data(physicalDevices))

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

@(private = "file")
createLogicalDevice :: proc(graphicsContext: ^GraphicsContext) {
	graphicsContext^.queueFamilies, _ = findQueueFamilies(
		graphicsContext^.physicalDevice,
		graphicsContext,
	)

	queuePriority: f32 = 1.0
	queueCreateInfos: [dynamic]vk.DeviceQueueCreateInfo
	defer delete(queueCreateInfos)
	queueCreateInfo: vk.DeviceQueueCreateInfo = {
		sType            = .DEVICE_QUEUE_CREATE_INFO,
		pNext            = nil,
		flags            = {},
		queueFamilyIndex = graphicsContext^.queueFamilies.graphicsFamily,
		queueCount       = 1,
		pQueuePriorities = &queuePriority,
	}
	append(&queueCreateInfos, queueCreateInfo)

	if graphicsContext^.queueFamilies.graphicsFamily !=
	   graphicsContext^.queueFamilies.presentFamily {
		queueCreateInfo = {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			pNext            = nil,
			flags            = {},
			queueFamilyIndex = graphicsContext^.queueFamilies.presentFamily,
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
		   graphicsContext^.physicalDevice,
		   &createInfo,
		   nil,
		   &graphicsContext^.device,
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create logical device!")
		panic("Failed to create logical device!")
	}

	// load_proc_addresses_device :: proc(device: Device)
	vk.load_proc_addresses(graphicsContext^.device)

	vk.GetDeviceQueue(
		graphicsContext^.device,
		graphicsContext^.queueFamilies.graphicsFamily,
		0,
		&graphicsContext^.graphicsQueue,
	)
	vk.GetDeviceQueue(
		graphicsContext^.device,
		graphicsContext^.queueFamilies.presentFamily,
		0,
		&graphicsContext^.presentQueue,
	)
}

// ###################################################################
// #                          Swapchain                              #
// ###################################################################

@(private = "file")
createSwapchain :: proc(graphicsContext: ^GraphicsContext) {
	chooseFormat :: proc(formats: []vk.SurfaceFormatKHR) -> (format: vk.SurfaceFormatKHR) {
		for format in formats {
			if format.format == .R8G8B8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
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
		width, height := glfw.GetFramebufferSize(graphicsContext^.window)
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

	swapchainSupport := querySwapchainSupport(graphicsContext^.physicalDevice, graphicsContext)
	graphicsContext^.swapchainFormat = chooseFormat(swapchainSupport.formats)
	graphicsContext^.swapchainMode = choosePresentMode(swapchainSupport.modes)
	graphicsContext^.swapchainExtent = chooseExtent(swapchainSupport.capabilities, graphicsContext)

	ideal := swapchainSupport.capabilities.minImageCount + 1
	max := swapchainSupport.capabilities.maxImageCount
	imageCount := max if max > 0 && ideal > max else ideal

	oneQueueFamily :=
		graphicsContext^.queueFamilies.graphicsFamily ==
		graphicsContext^.queueFamilies.presentFamily
	createInfo: vk.SwapchainCreateInfoKHR = {
		sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
		pNext                 = nil,
		flags                 = {},
		surface               = graphicsContext^.surface,
		minImageCount         = imageCount,
		imageFormat           = graphicsContext^.swapchainFormat.format,
		imageColorSpace       = graphicsContext^.swapchainFormat.colorSpace,
		imageExtent           = graphicsContext^.swapchainExtent,
		imageArrayLayers      = 1,
		imageUsage            = {.COLOR_ATTACHMENT},
		imageSharingMode      = oneQueueFamily ? .EXCLUSIVE : .CONCURRENT,
		queueFamilyIndexCount = oneQueueFamily ? 0 : 2,
		pQueueFamilyIndices   = oneQueueFamily \
		? nil \
		: raw_data(
			[]u32 {
				graphicsContext^.queueFamilies.graphicsFamily,
				graphicsContext^.queueFamilies.graphicsFamily,
			},
		),
		preTransform          = swapchainSupport.capabilities.currentTransform,
		compositeAlpha        = {.OPAQUE},
		presentMode           = graphicsContext^.swapchainMode,
		clipped               = true,
		oldSwapchain          = {},
	}

	if vk.CreateSwapchainKHR(
		   graphicsContext^.device,
		   &createInfo,
		   nil,
		   &graphicsContext^.swapchain,
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create swapchain!")
		panic("Failed to create swapchain!")
	}

	vk.GetSwapchainImagesKHR(graphicsContext^.device, graphicsContext^.swapchain, &imageCount, nil)
	graphicsContext^.swapchainImages = make([]vk.Image, imageCount)
	vk.GetSwapchainImagesKHR(
		graphicsContext^.device,
		graphicsContext^.swapchain,
		&imageCount,
		raw_data(graphicsContext^.swapchainImages),
	)
}

@(private = "file")
createSwapchainImageViews :: proc(graphicsContext: ^GraphicsContext) {
	graphicsContext^.swapchainImageViews = make(
		[]vk.ImageView,
		len(graphicsContext^.swapchainImages),
	)
	for index in 0 ..< len(graphicsContext^.swapchainImages) {
		graphicsContext^.swapchainImageViews[index] = createImageView(
			graphicsContext,
			graphicsContext^.swapchainImages[index],
			.D2,
			graphicsContext^.swapchainFormat.format,
			{.COLOR},
			1,
			1,
		)
	}
}

@(private = "file")
recreateSwapchain :: proc(graphicsContext: ^GraphicsContext) {
	width, height := glfw.GetFramebufferSize(graphicsContext^.window)
	for width == 0 && height == 0 {
		width, height = glfw.GetFramebufferSize(graphicsContext^.window)
		glfw.WaitEvents()
	}

	vk.DeviceWaitIdle(graphicsContext^.device)
	cleanupSwapchain(graphicsContext)

	createSwapchain(graphicsContext)
	createSwapchainImageViews(graphicsContext)
	createColourResources(graphicsContext)
	createDepthResources(graphicsContext)
	createFramebuffers(graphicsContext)
}

// ###################################################################
// #                          Commands                               #
// ###################################################################

@(private = "file")
createCommandPool :: proc(graphicsContext: ^GraphicsContext) {
	poolInfo: vk.CommandPoolCreateInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		pNext            = nil,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = graphicsContext^.queueFamilies.graphicsFamily,
	}
	if vk.CreateCommandPool(
		   graphicsContext^.device,
		   &poolInfo,
		   nil,
		   &graphicsContext^.commandPool,
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create command pool!")
		panic("Failed to create command pool!")
	}
}

@(private = "file")
createCommandBuffers :: proc(graphicsContext: ^GraphicsContext) {
	graphicsContext^.commandBuffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
	allocInfo: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = graphicsContext^.commandPool,
		level              = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}
	if vk.AllocateCommandBuffers(
		   graphicsContext^.device,
		   &allocInfo,
		   raw_data(graphicsContext^.commandBuffers),
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to allocate command buffer!")
		panic("Failed to allocate command buffer!")
	}
}

@(private = "file")
beginSingleTimeCommands :: proc(
	graphicsContext: ^GraphicsContext,
) -> (
	commandBuffer: vk.CommandBuffer,
) {
	allocInfo: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = graphicsContext^.commandPool,
		level              = .PRIMARY,
		commandBufferCount = 1,
	}
	vk.AllocateCommandBuffers(graphicsContext^.device, &allocInfo, &commandBuffer)
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
endSingleTimeCommands :: proc(graphicsContext: ^GraphicsContext, commandBuffer: vk.CommandBuffer) {
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
	vk.QueueSubmit(graphicsContext^.graphicsQueue, 1, &submitInfo, fence)
	vk.QueueWaitIdle(graphicsContext^.graphicsQueue)
	vk.FreeCommandBuffers(graphicsContext^.device, graphicsContext^.commandPool, 1, &commandBuffer)
}

// ###################################################################
// #                           Buffers                               #
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
	if vk.CreateBuffer(graphicsContext^.device, &bufferInfo, nil, buffer) != .SUCCESS {
		log(.ERROR, "Failed to create buffer!")
		panic("Failed to create buffer!")
	}

	memRequirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(graphicsContext^.device, buffer^, &memRequirements)
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
	if vk.AllocateMemory(graphicsContext^.device, &allocInfo, nil, bufferMemory) != .SUCCESS {
		log(.ERROR, "Failed to allocate buffer memory!")
		panic("Failed to allocate buffer memory!")
	}
	vk.BindBufferMemory(graphicsContext^.device, buffer^, bufferMemory^, 0)
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
		commandBuffer: vk.CommandBuffer = beginSingleTimeCommands(graphicsContext)
		copyRegion: vk.BufferCopy = {
			srcOffset = 0,
			dstOffset = 0,
			size      = vk.DeviceSize(size),
		}
		vk.CmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion)
		endSingleTimeCommands(graphicsContext, commandBuffer)
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
		graphicsContext^.device,
		stagingBufferMemory,
		0,
		(vk.DeviceSize)(bufferSize),
		{},
		&data,
	)
	mem.copy(data, srcData, bufferSize)
	vk.UnmapMemory(graphicsContext^.device, stagingBufferMemory)

	createBuffer(
		graphicsContext,
		bufferSize,
		{.TRANSFER_DST, bufferType},
		{.DEVICE_LOCAL},
		&dstBuffer^.buffer,
		&dstBuffer^.memory,
	)

	copyBuffer(graphicsContext, stagingBuffer, dstBuffer^.buffer, bufferSize)
	vk.DestroyBuffer(graphicsContext^.device, stagingBuffer, nil)
	vk.FreeMemory(graphicsContext^.device, stagingBufferMemory, nil)
}

@(private = "file")
createVertexBuffer :: proc(graphicsContext: ^GraphicsContext) {
	loadBufferToGPU(
		graphicsContext,
		size_of(Vertex) * len(graphicsContext^.vertices),
		raw_data(graphicsContext^.vertices),
		&graphicsContext^.vertexBuffer,
		.VERTEX_BUFFER,
	)
	graphicsContext^.vertexBuffer.mapped = nil
}

@(private = "file")
createIndexBuffer :: proc(graphicsContext: ^GraphicsContext) {
	loadBufferToGPU(
		graphicsContext,
		size_of(u32) * len(graphicsContext^.indices),
		raw_data(graphicsContext^.indices),
		&graphicsContext^.indexBuffer,
		.INDEX_BUFFER,
	)
	graphicsContext^.indexBuffer.mapped = nil
}

@(private = "file")
createViewProjectionUniform :: proc(graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(ViewProjectionUniform),
			{.UNIFORM_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&graphicsContext^.viewProjectionUniforms[i].buffer,
			&graphicsContext^.viewProjectionUniforms[i].memory,
		)
		vk.MapMemory(
			graphicsContext^.device,
			graphicsContext^.viewProjectionUniforms[i].memory,
			0,
			size_of(ViewProjectionUniform),
			{},
			&graphicsContext^.viewProjectionUniforms[i].mapped,
		)
	}
}

@(private = "file")
createInstanceBuffer :: proc(graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Instance) * len(graphicsContext^.instances),
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&graphicsContext^.instanceBuffers[i].buffer,
			&graphicsContext^.instanceBuffers[i].memory,
		)
		vk.MapMemory(
			graphicsContext^.device,
			graphicsContext^.instanceBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Instance) * len(graphicsContext^.instances)),
			{},
			&graphicsContext^.instanceBuffers[i].mapped,
		)
	}
}

@(private = "file")
createBoneBuffer :: proc(graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Mat4) * graphicsContext^.boneCount,
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&graphicsContext^.boneBuffers[i].buffer,
			&graphicsContext^.boneBuffers[i].memory,
		)
		vk.MapMemory(
			graphicsContext^.device,
			graphicsContext^.boneBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Mat4) * graphicsContext^.boneCount),
			{},
			&graphicsContext^.boneBuffers[i].mapped,
		)
	}
}

// ###################################################################
// #                           Images                                #
// ###################################################################

@(private = "file")
findMemoryType :: proc(
	graphicsContext: ^GraphicsContext,
	typeFilter: u32,
	properties: vk.MemoryPropertyFlags,
) -> u32 {
	memProperties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(graphicsContext^.physicalDevice, &memProperties)
	for i in 0 ..< memProperties.memoryTypeCount {
		if typeFilter & (1 << i) != 0 &&
		   (memProperties.memoryTypes[i].propertyFlags & properties) == properties {
			return i
		}
	}
	log(.ERROR, "Failed to find suitable memory type!")
	panic("Failed to find suitable memory type!")
}

@(private = "file")
createImage :: proc(
	graphicsContext: ^GraphicsContext,
	flags: vk.ImageCreateFlags,
	imageType: vk.ImageType,
	format: vk.Format,
	width, height, mipLevels, arrayLayers: u32,
	sampleCount: vk.SampleCountFlags,
	tiling: vk.ImageTiling,
	usage: vk.ImageUsageFlags,
	properties: vk.MemoryPropertyFlags,
	image: ^vk.Image,
	imageMemory: ^vk.DeviceMemory,
) {
	imageInfo: vk.ImageCreateInfo = {
		sType                 = .IMAGE_CREATE_INFO,
		pNext                 = nil,
		flags                 = flags,
		imageType             = imageType,
		format                = format,
		extent                = {width, height, 1},
		mipLevels             = mipLevels,
		arrayLayers           = arrayLayers,
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

	memRequirements: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(graphicsContext^.device, image^, &memRequirements)
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
	if vk.AllocateMemory(graphicsContext^.device, &allocInfo, nil, imageMemory) != .SUCCESS {
		log(.ERROR, "Failed to allocate image memory!")
		panic("Failed to allocate image memory!")
	}
	vk.BindImageMemory(graphicsContext^.device, image^, imageMemory^, 0)
}

@(private = "file")
createImageView :: proc(
	graphicsContext: ^GraphicsContext,
	image: vk.Image,
	viewType: vk.ImageViewType,
	format: vk.Format,
	aspectFlags: vk.ImageAspectFlags,
	levelCount, layerCount: u32,
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
			levelCount = levelCount,
			baseArrayLayer = 0,
			layerCount = layerCount,
		},
	}
	if vk.CreateImageView(graphicsContext^.device, &viewInfo, nil, &imageView) != .SUCCESS {
		log(.ERROR, "Failed to create image view!")
		panic("Failed to create image view!")
	}
	return imageView
}

transitionImageLayout :: proc(
	graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	image: vk.Image,
	format: vk.Format,
	oldLayout, newLayout: vk.ImageLayout,
	mipLevel, layerCount: u32,
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
			levelCount = mipLevel,
			baseArrayLayer = 0,
			layerCount = layerCount,
		},
	}
	sourceStage, destinationStage: vk.PipelineStageFlags
	if oldLayout == .UNDEFINED && newLayout == .TRANSFER_DST_OPTIMAL {
		barrier.srcAccessMask = {}
		barrier.dstAccessMask = {.TRANSFER_WRITE}
		sourceStage = {.TOP_OF_PIPE}
		destinationStage = {.TRANSFER}
	} else if oldLayout == .TRANSFER_DST_OPTIMAL && newLayout == .SHADER_READ_ONLY_OPTIMAL {
		barrier.srcAccessMask = {.TRANSFER_WRITE}
		barrier.dstAccessMask = {.SHADER_READ}
		sourceStage = {.TRANSFER}
		destinationStage = {.FRAGMENT_SHADER}
	} else {
		log(.ERROR, "Unsupported layout transition!")
		panic("Unsupported layout transition!")
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

generateMipmaps :: proc(
	graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	image: vk.Image,
	format: vk.Format,
	width, height, mipLevels, layerCount: u32,
) {
	formatProperties: vk.FormatProperties
	vk.GetPhysicalDeviceFormatProperties(
		graphicsContext^.physicalDevice,
		format,
		&formatProperties,
	)

	if !(.SAMPLED_IMAGE_FILTER_LINEAR in formatProperties.optimalTilingFeatures) {
		log(.ERROR, "Image format does not support linear blitting!")
		panic("Image format does not support linear blitting!")
	}

	barrier: vk.ImageMemoryBarrier = {
		sType = .IMAGE_MEMORY_BARRIER,
		pNext = nil,
		srcAccessMask = {},
		dstAccessMask = {},
		oldLayout = .UNDEFINED,
		newLayout = .UNDEFINED,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = layerCount,
		},
	}
	mipWidth := i32(width)
	mipHeight := i32(height)
	for i in 1 ..< mipLevels {
		barrier.subresourceRange.baseMipLevel = i - 1
		barrier.oldLayout = .TRANSFER_DST_OPTIMAL
		barrier.newLayout = .TRANSFER_SRC_OPTIMAL
		barrier.srcAccessMask = {.TRANSFER_WRITE}
		barrier.dstAccessMask = {.TRANSFER_READ}

		vk.CmdPipelineBarrier(
			commandBuffer,
			{.TRANSFER},
			{.TRANSFER},
			{},
			0,
			nil,
			0,
			nil,
			1,
			&barrier,
		)
		blit: vk.ImageBlit = {
			srcSubresource = vk.ImageSubresourceLayers {
				aspectMask = {.COLOR},
				mipLevel = i - 1,
				baseArrayLayer = 0,
				layerCount = layerCount,
			},
			srcOffsets = [2]vk.Offset3D {
				{x = 0, y = 0, z = 0},
				{x = mipWidth, y = mipHeight, z = 1},
			},
			dstSubresource = vk.ImageSubresourceLayers {
				aspectMask = {.COLOR},
				mipLevel = i,
				baseArrayLayer = 0,
				layerCount = layerCount,
			},
			dstOffsets = [2]vk.Offset3D {
				{x = 0, y = 0, z = 0},
				{
					x = mipWidth > 1 ? mipWidth / 2 : 1,
					y = mipHeight > 1 ? mipHeight / 2 : 1,
					z = 1,
				},
			},
		}
		vk.CmdBlitImage(
			commandBuffer,
			image,
			.TRANSFER_SRC_OPTIMAL,
			image,
			.TRANSFER_DST_OPTIMAL,
			1,
			&blit,
			.LINEAR,
		)

		barrier.oldLayout = .TRANSFER_SRC_OPTIMAL
		barrier.newLayout = .SHADER_READ_ONLY_OPTIMAL
		barrier.srcAccessMask = {.TRANSFER_READ}
		barrier.dstAccessMask = {.SHADER_READ}

		vk.CmdPipelineBarrier(
			commandBuffer,
			{.TRANSFER},
			{.FRAGMENT_SHADER},
			{},
			0,
			nil,
			0,
			nil,
			1,
			&barrier,
		)

		if mipWidth > 1 do mipWidth /= 2
		if mipHeight > 1 do mipHeight /= 2
	}

	barrier.subresourceRange.baseMipLevel = mipLevels - 1
	barrier.oldLayout = .TRANSFER_DST_OPTIMAL
	barrier.newLayout = .SHADER_READ_ONLY_OPTIMAL
	barrier.srcAccessMask = {.TRANSFER_WRITE}
	barrier.dstAccessMask = {.SHADER_READ}

	vk.CmdPipelineBarrier(
		commandBuffer,
		{.TRANSFER},
		{.FRAGMENT_SHADER},
		{},
		0,
		nil,
		0,
		nil,
		1,
		&barrier,
	)
}

// ###################################################################
// #                        Create Assets                            #
// ###################################################################

@(private = "file")
loadModels :: proc(graphicsContext: ^GraphicsContext, modelPaths: []cstring) {
	loadFBX :: proc(graphicsContext: ^GraphicsContext, model: ^Model, filename: cstring) {
		loadSkeleton :: proc(node: ^fbx.Node) -> Skeleton {
			loadBone :: proc(node: ^fbx.Node, skeleton: ^[dynamic]Bone, parentIndex: u32) {
				bone: Bone = {
					name        = node^.bone^.element.name.data,
					isRoot      = false,
					parentIndex = parentIndex,
				}
				thisIndex := len(skeleton^)
				append(skeleton, bone)
				for index in 0 ..< node^.children.count {
					loadBone(node^.children.data[index], skeleton, u32(thisIndex))
				}
			}

			skeleton: [dynamic]Bone
			bone: Bone = {
				name        = node^.bone^.element.name.data,
				isRoot      = true,
				parentIndex = 0,
			}
			append(&skeleton, bone)
			for index in 0 ..< node^.children.count {
				loadBone(node^.children.data[index], &skeleton, 0)
			}
			return skeleton[:]
		}

		opts: fbx.Load_Opts = {
			_begin_zero = 0,
			target_axes = fbx.Coordinate_Axes {
				right = .POSITIVE_X,
				up = .POSITIVE_Y,
				front = .NEGATIVE_Z,
			},
			_end_zero = 0,
		}
		err: fbx.Error = {}
		scene := fbx.load_file(filename, &opts, &err)
		defer fbx.free_scene(scene)
		if scene == nil {
			log(.ERROR, fmt.aprintf("Failed to load FBX file! Reason\n{}", err.description.data))
			panic("Failed to load FBX file!")
		}

		mesh: ^fbx.Mesh
		for index in 0 ..< scene.nodes.count {
			node := scene.nodes.data[index]
			if node.is_root do continue
			if node.mesh != nil && mesh == nil {
				mesh = node.mesh
				continue
			} else if node^.bone != nil && model^.skeleton == nil {
				model^.skeleton = loadSkeleton(node)
				continue
			}
		}

		{
			index_count := 3 * mesh.num_triangles
			model^.indices = make([]u32, index_count)
			model^.indexCount = u32(index_count)
			off: u32 = 0
			for i in 0 ..< mesh.faces.count {
				face := mesh.faces.data[i]
				tris := fbx.catch_triangulate_face(
					nil,
					&model^.indices[off],
					uint(index_count),
					mesh,
					face,
				)
				off += 3 * tris
			}
		}

		{
			vertex_count := mesh.num_indices
			model^.vertices = make([]Vertex, vertex_count)
			for i in 0 ..< vertex_count {
				vertexIndex := mesh.vertex_position.indices.data[i]
				pos := mesh.vertex_position.values.data[vertexIndex]
				uv := mesh.vertex_uv.values.data[vertexIndex]
				model^.vertices[i] = {
					position = {f32(pos.x), f32(pos.y), f32(pos.z)},
					texCoord = {f32(uv.x), 1 - f32(uv.y)},
				}
				if len(model^.skeleton) == 0 {
					continue
				}
				deformer := mesh.skin_deformers.data[0]^
				numWeights := deformer.vertices.data[vertexIndex].num_weights
				if numWeights > 4 {
					numWeights = 4
				}
				firstWeightIndex := deformer.vertices.data[vertexIndex].weight_begin
				totalWeight: f32 = 0
				for j in 0 ..< numWeights {
					skinWeight := deformer.weights.data[firstWeightIndex + u32(j)]
					boneName :=
						deformer.clusters.data[skinWeight.cluster_index]^.bone_node.element.name
					for bone, index in model^.skeleton {
						if bone.name == boneName.data {
							model^.vertices[i].bones[j] = u32(index)
						}
					}
					model^.vertices[i].weights[j] = f32(skinWeight.weight)
					totalWeight += f32(skinWeight.weight)
				}
				if totalWeight != 1.0 {
					for j in 0 ..< numWeights {
						model^.vertices[i].weights[j] /= totalWeight
					}
				}
			}
		}

		for index in 0 ..< scene.skin_cluster.count {
			skinCluster := scene.skin_cluster.data[index]^
			boneIndex: u32
			for &bone, index in model^.skeleton {
				if bone.name != skinCluster.bone_node^.element.name.data {
					continue
				}
				boneIndex = u32(index)
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
				m = skinCluster.geometry_to_world.cols
				bone.sceneRoot = {
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
				name := sceneNode^.element.name.data
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

	graphicsContext^.models = make([]Model, len(modelPaths))
	indexCount: u32 = 0
	vertices: [dynamic]Vertex
	indices: [dynamic]u32
	for path, index in modelPaths {
		loadFBX(graphicsContext, &graphicsContext^.models[index], path)
		graphicsContext^.models[index].vertexOffset = u32(len(vertices))
		graphicsContext^.models[index].indexOffset = indexCount
		indexCount += graphicsContext^.models[index].indexCount
		append(&vertices, ..graphicsContext^.models[index].vertices)
		append(&indices, ..graphicsContext^.models[index].indices)
	}
	graphicsContext^.vertices = vertices[:]
	graphicsContext^.indices = indices[:]
}

@(private = "file")
loadTextures :: proc(
	graphicsContext: ^GraphicsContext,
	texture: ^Image,
	texturePaths: []cstring,
	cube: b8,
) {
	textureWidth, textureHeight: i32
	pixels := image.load(texturePaths[0], &textureWidth, &textureHeight, nil, 4)
	image.image_free(pixels)
	textureSize := int(textureWidth * textureHeight * 4)
	textureCount := len(texturePaths)
	texture^.mipLevels = u32(floor(log2(f32(max(textureWidth, textureHeight))))) + 1

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
		pixels := image.load(path, &width, &height, nil, 4)
		defer image.image_free(pixels)
		if pixels == nil {
			log(.ERROR, "Failed to load texture!")
			panic("Failed to load texture!")
		}

		if textureWidth != width || textureHeight != height {
			log(.ERROR, "Image of wrong dims!")
			panic("Image of wrong dims!")
		}

		data: rawptr
		vk.MapMemory(
			graphicsContext^.device,
			stagingBufferMemory,
			vk.DeviceSize(textureSize * index),
			vk.DeviceSize(textureSize),
			{},
			&data,
		)
		mem.copy(data, pixels, textureSize)
		vk.UnmapMemory(graphicsContext^.device, stagingBufferMemory)
	}

	format: vk.ImageCreateFlags

	if cube {
		format = {.CUBE_COMPATIBLE}
	}

	createImage(
		graphicsContext,
		format,
		.D2,
		.R8G8B8A8_SRGB,
		u32(textureWidth),
		u32(textureHeight),
		texture^.mipLevels,
		u32(textureCount),
		{._1},
		.OPTIMAL,
		{.TRANSFER_DST, .TRANSFER_SRC, .SAMPLED},
		{.DEVICE_LOCAL},
		&texture^.image,
		&texture^.memory,
	)

	commandBuffer := beginSingleTimeCommands(graphicsContext)
	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		texture^.image,
		.R8G8B8A8_SRGB,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		texture^.mipLevels,
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

	generateMipmaps(
		graphicsContext,
		commandBuffer,
		texture^.image,
		.R8G8B8A8_SRGB,
		u32(textureWidth),
		u32(textureHeight),
		texture^.mipLevels,
		u32(textureCount),
	)

	endSingleTimeCommands(graphicsContext, commandBuffer)

	vk.DestroyBuffer(graphicsContext^.device, stagingBuffer, nil)
	vk.FreeMemory(graphicsContext^.device, stagingBufferMemory, nil)
}

@(private = "file")
createTextureView :: proc(
	graphicsContext: ^GraphicsContext,
	texture: ^Image,
	viewType: vk.ImageViewType,
	format: vk.Format,
	aspectFlags: vk.ImageAspectFlags,
	layerCount: u32,
) {
	texture^.view = createImageView(
		graphicsContext,
		texture^.image,
		viewType,
		format,
		aspectFlags,
		texture^.mipLevels,
		layerCount,
	)
}

@(private = "file")
createSampler :: proc(graphicsContext: ^GraphicsContext, image: ^Image) {
	properties: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(graphicsContext^.physicalDevice, &properties)
	samplerInfo: vk.SamplerCreateInfo = {
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
	if vk.CreateSampler(graphicsContext^.device, &samplerInfo, nil, &image^.sampler) != .SUCCESS {
		log(.ERROR, "Failed to create texture sampler!")
		panic("Failed to create texture sampler!")
	}
}

@(private = "file")
loadAssets :: proc(graphicsContext: ^GraphicsContext) {
	if graphicsContext^.hasAssetsLoaded {
		cleanupAssets(graphicsContext)
	}

	loadModels(graphicsContext, {CUBE_PATH, MODEL_PATH})

	createVertexBuffer(graphicsContext)
	createIndexBuffer(graphicsContext)

	loadTextures(
		graphicsContext,
		&graphicsContext^.skybox,
		{
			SKY_RIGHT, //x++
			SKY_LEFT, //x--
			SKY_TOP, // y++
			SKY_BOTTOM, // y--
			SKY_FRONT, // z++
			SKY_BACK, // z--
		},
		true,
	)
	createTextureView(
		graphicsContext,
		&graphicsContext^.skybox,
		.CUBE,
		.R8G8B8A8_SRGB,
		{.COLOR},
		6,
	)
	createSampler(graphicsContext, &graphicsContext^.skybox)

	loadTextures(
		graphicsContext,
		&graphicsContext^.textures,
		{R_TEXTURE_PATH, G_TEXTURE_PATH, B_TEXTURE_PATH},
		false,
	)
	createTextureView(
		graphicsContext,
		&graphicsContext^.textures,
		.D2_ARRAY,
		.R8G8B8A8_SRGB,
		{.COLOR},
		3,
	)
	createSampler(graphicsContext, &graphicsContext^.textures)

	now := t.now()
	graphicsContext^.instances = make([]Instance, MAX_MODEL_INSTANCES)
	for &instance, index in graphicsContext^.instances {
		instance = {
			modelID       = 1,
			animID        = 1,
			textureID     = u32(index),
			position      = {f32(index - 1), 0, index == 1 ? 0 : 1},
			rotation      = quatFromY(f32(radians(180.0))),
			scale         = {0.005, 0.005, 0.005},
			animStartTime = t.time_add(now, t.Duration(index * 1000000000)),
		}
		graphicsContext^.boneCount += len(graphicsContext^.models[instance.modelID].skeleton)
		instance.positionKeys = make(
			[]u32,
			len(graphicsContext^.models[instance.modelID].skeleton),
		)
		instance.rotationKeys = make(
			[]u32,
			len(graphicsContext^.models[instance.modelID].skeleton),
		)
		instance.scaleKeys = make([]u32, len(graphicsContext^.models[instance.modelID].skeleton))
	}

	createInstanceBuffer(graphicsContext)
	createBoneBuffer(graphicsContext)

	graphicsContext^.hasAssetsLoaded = true
}

// ###################################################################
// #                      Shader Descriptors                         #
// ###################################################################

@(private = "file")
createDescriptorPool :: proc(graphicsContext: ^GraphicsContext) {
	poolSize: []vk.DescriptorPoolSize = {
		{type = .UNIFORM_BUFFER, descriptorCount = MAX_FRAMES_IN_FLIGHT},
		{type = .STORAGE_BUFFER, descriptorCount = MAX_FRAMES_IN_FLIGHT},
		{type = .STORAGE_BUFFER, descriptorCount = MAX_FRAMES_IN_FLIGHT},
		{type = .COMBINED_IMAGE_SAMPLER, descriptorCount = MAX_FRAMES_IN_FLIGHT},
		{type = .COMBINED_IMAGE_SAMPLER, descriptorCount = MAX_FRAMES_IN_FLIGHT},
	}
	poolInfo: vk.DescriptorPoolCreateInfo = {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		pNext         = nil,
		flags         = {},
		maxSets       = MAX_FRAMES_IN_FLIGHT,
		poolSizeCount = u32(len(poolSize)),
		pPoolSizes    = raw_data(poolSize),
	}
	if vk.CreateDescriptorPool(
		   graphicsContext^.device,
		   &poolInfo,
		   nil,
		   &graphicsContext^.descriptorPool,
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create descriptor pool!")
		panic("Failed to create descriptor pool!")
	}
}

@(private = "file")
createDescriptionSetLayout :: proc(graphicsContext: ^GraphicsContext) {
	viewProjectionLayoutBinding: vk.DescriptorSetLayoutBinding = {
		binding            = 0,
		descriptorType     = .UNIFORM_BUFFER,
		descriptorCount    = 1,
		stageFlags         = {.VERTEX},
		pImmutableSamplers = nil,
	}
	instanceLayoutBinding: vk.DescriptorSetLayoutBinding = {
		binding            = 1,
		descriptorType     = .STORAGE_BUFFER,
		descriptorCount    = 1,
		stageFlags         = {.VERTEX},
		pImmutableSamplers = nil,
	}
	boneLayoutBinding: vk.DescriptorSetLayoutBinding = {
		binding            = 2,
		descriptorType     = .STORAGE_BUFFER,
		descriptorCount    = 1,
		stageFlags         = {.VERTEX},
		pImmutableSamplers = nil,
	}
	textureSamplerLayoutBinding: vk.DescriptorSetLayoutBinding = {
		binding            = 3,
		descriptorType     = .COMBINED_IMAGE_SAMPLER,
		descriptorCount    = 1,
		stageFlags         = {.FRAGMENT},
		pImmutableSamplers = nil,
	}
	skySamplerLayoutBinding: vk.DescriptorSetLayoutBinding = {
		binding            = 4,
		descriptorType     = .COMBINED_IMAGE_SAMPLER,
		descriptorCount    = 1,
		stageFlags         = {.FRAGMENT},
		pImmutableSamplers = nil,
	}
	layoutInfo: vk.DescriptorSetLayoutCreateInfo = {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		pNext        = nil,
		flags        = {},
		bindingCount = 5,
		pBindings    = raw_data(
			[]vk.DescriptorSetLayoutBinding {
				viewProjectionLayoutBinding,
				instanceLayoutBinding,
				boneLayoutBinding,
				textureSamplerLayoutBinding,
				skySamplerLayoutBinding,
			},
		),
	}
	if vk.CreateDescriptorSetLayout(
		   graphicsContext^.device,
		   &layoutInfo,
		   nil,
		   &graphicsContext^.descriptorSetLayout,
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create descriptor set layout!")
		panic("Failed to create descriptor set layout!")
	}
}

@(private = "file")
createDescriptorSets :: proc(graphicsContext: ^GraphicsContext) {
	layouts := make([]vk.DescriptorSetLayout, MAX_FRAMES_IN_FLIGHT)
	defer delete(layouts)
	for &layout in layouts {
		layout = graphicsContext^.descriptorSetLayout
	}
	allocInfo: vk.DescriptorSetAllocateInfo = {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		pNext              = nil,
		descriptorPool     = graphicsContext^.descriptorPool,
		descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
		pSetLayouts        = raw_data(layouts),
	}
	graphicsContext^.descriptorSets = make([]vk.DescriptorSet, MAX_FRAMES_IN_FLIGHT)
	if vk.AllocateDescriptorSets(
		   graphicsContext^.device,
		   &allocInfo,
		   raw_data(graphicsContext^.descriptorSets),
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to allocate descriptor sets!")
		panic("Failed to allocate descriptor sets!")
	}
	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		uniformBufferInfo: vk.DescriptorBufferInfo = {
			buffer = graphicsContext^.viewProjectionUniforms[index].buffer,
			offset = 0,
			range  = size_of(ViewProjectionUniform),
		}
		instanceBufferInfo: vk.DescriptorBufferInfo = {
			buffer = graphicsContext^.instanceBuffers[index].buffer,
			offset = 0,
			range  = vk.DeviceSize(len(graphicsContext^.instances) * size_of(InstanceInfo)),
		}
		boneBufferInfo: vk.DescriptorBufferInfo = {
			buffer = graphicsContext^.boneBuffers[index].buffer,
			offset = 0,
			range  = vk.DeviceSize(graphicsContext^.boneCount * size_of(Mat4)),
		}
		textureInfo: vk.DescriptorImageInfo = {
			sampler     = graphicsContext^.textures.sampler,
			imageView   = graphicsContext^.textures.view,
			imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		}
		skyInfo: vk.DescriptorImageInfo = {
			sampler     = graphicsContext^.skybox.sampler,
			imageView   = graphicsContext^.skybox.view,
			imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		}
		descriptorWrite: []vk.WriteDescriptorSet = {
			{
				sType = .WRITE_DESCRIPTOR_SET,
				pNext = nil,
				dstSet = graphicsContext^.descriptorSets[index],
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
				dstSet = graphicsContext^.descriptorSets[index],
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
				dstSet = graphicsContext^.descriptorSets[index],
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
				dstSet = graphicsContext^.descriptorSets[index],
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
				dstSet = graphicsContext^.descriptorSets[index],
				dstBinding = 4,
				dstArrayElement = 0,
				descriptorCount = 1,
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				pImageInfo = &skyInfo,
				pBufferInfo = nil,
				pTexelBufferView = nil,
			},
		}
		vk.UpdateDescriptorSets(graphicsContext^.device, 5, raw_data(descriptorWrite), 0, nil)
	}
}

// ###################################################################
// #                       Frame Resources                           #
// ###################################################################

@(private = "file")
createColourResources :: proc(graphicsContext: ^GraphicsContext) {
	graphicsContext^.colourImage.format = graphicsContext^.swapchainFormat.format
	createImage(
		graphicsContext,
		{},
		.D2,
		graphicsContext^.colourImage.format,
		graphicsContext^.swapchainExtent.width,
		graphicsContext^.swapchainExtent.height,
		1,
		1,
		graphicsContext^.msaaSamples,
		.OPTIMAL,
		{.TRANSIENT_ATTACHMENT, .COLOR_ATTACHMENT},
		{.DEVICE_LOCAL},
		&graphicsContext^.colourImage.image,
		&graphicsContext^.colourImage.memory,
	)
	graphicsContext^.colourImage.view = createImageView(
		graphicsContext,
		graphicsContext^.colourImage.image,
		.D2,
		graphicsContext^.colourImage.format,
		{.COLOR},
		1,
		1,
	)
}

@(private = "file")
createDepthResources :: proc(graphicsContext: ^GraphicsContext) {
	findSupportedFormat :: proc(
		graphicsContext: ^GraphicsContext,
		candidates: []vk.Format,
		tiling: vk.ImageTiling,
		features: vk.FormatFeatureFlags,
	) -> vk.Format {
		for format in candidates {
			props: vk.FormatProperties
			vk.GetPhysicalDeviceFormatProperties(graphicsContext^.physicalDevice, format, &props)
			if tiling == .LINEAR && (props.linearTilingFeatures & features) == features {
				return format
			} else if tiling == .OPTIMAL && (props.optimalTilingFeatures & features) == features {
				return format
			}
		}
		log(.ERROR, "Failed to find supported format!")
		panic("Failed to find supported format!")
	}

	hasStencilComponent :: proc(format: vk.Format) -> bool {
		return format == .D32_SFLOAT_S8_UINT || format == .D24_UNORM_S8_UINT
	}

	graphicsContext^.depthImage.format = findSupportedFormat(
		graphicsContext,
		{.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
	)
	createImage(
		graphicsContext,
		{},
		.D2,
		graphicsContext^.depthImage.format,
		graphicsContext^.swapchainExtent.width,
		graphicsContext^.swapchainExtent.height,
		1,
		1,
		graphicsContext^.msaaSamples,
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
		{.DEVICE_LOCAL},
		&graphicsContext^.depthImage.image,
		&graphicsContext^.depthImage.memory,
	)
	graphicsContext^.depthImage.view = createImageView(
		graphicsContext,
		graphicsContext^.depthImage.image,
		.D2,
		graphicsContext^.depthImage.format,
		{.DEPTH},
		1,
		1,
	)
}

@(private = "file")
createSyncObjects :: proc(graphicsContext: ^GraphicsContext) {
	graphicsContext^.imagesAvailable = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	graphicsContext^.rendersFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	graphicsContext^.inFlightFrames = make([]vk.Fence, MAX_FRAMES_IN_FLIGHT)
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
		if ((vk.CreateSemaphore(
					   graphicsContext^.device,
					   &semaphoreInfo,
					   nil,
					   &graphicsContext^.imagesAvailable[index],
				   ) |
				   vk.CreateSemaphore(
					   graphicsContext^.device,
					   &semaphoreInfo,
					   nil,
					   &graphicsContext^.rendersFinished[index],
				   ) |
				   vk.CreateFence(
					   graphicsContext^.device,
					   &fenceInfo,
					   nil,
					   &graphicsContext^.inFlightFrames[index],
				   )) !=
			   .SUCCESS) {
			log(.ERROR, "Failed to create sync objects!")
			panic("Failed to create sync objects!")
		}
	}
}

// ###################################################################
// #                          Pipeline                               #
// ###################################################################

@(private = "file")
createRenderPass :: proc(graphicsContext: ^GraphicsContext) {
	colourAttachment: vk.AttachmentDescription = {
		flags          = {},
		format         = graphicsContext^.colourImage.format,
		samples        = graphicsContext^.msaaSamples,
		loadOp         = .CLEAR,
		storeOp        = .STORE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .COLOR_ATTACHMENT_OPTIMAL,
	}

	depthAttachment: vk.AttachmentDescription = {
		flags          = {},
		format         = graphicsContext^.depthImage.format,
		samples        = graphicsContext^.msaaSamples,
		loadOp         = .CLEAR,
		storeOp        = .DONT_CARE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	colourAttachmentResolve: vk.AttachmentDescription = {
		flags          = {},
		format         = graphicsContext^.colourImage.format,
		samples        = {._1},
		loadOp         = .DONT_CARE,
		storeOp        = .STORE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .PRESENT_SRC_KHR,
	}

	colourAttachmentRef: vk.AttachmentReference = {
		attachment = 0,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	depthAttachmentRef: vk.AttachmentReference = {
		attachment = 1,
		layout     = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	colourAttachmentResolveRef: vk.AttachmentReference = {
		attachment = 2,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	subpass: vk.SubpassDescription = {
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

	renderPassInfo: vk.RenderPassCreateInfo = {
		sType           = .RENDER_PASS_CREATE_INFO,
		pNext           = nil,
		flags           = {},
		attachmentCount = 3,
		pAttachments    = raw_data(
			[]vk.AttachmentDescription{colourAttachment, depthAttachment, colourAttachmentResolve},
		),
		subpassCount    = 1,
		pSubpasses      = &subpass,
		dependencyCount = 1,
		pDependencies   = &vk.SubpassDependency {
			srcSubpass = vk.SUBPASS_EXTERNAL,
			dstSubpass = 0,
			srcStageMask = {.COLOR_ATTACHMENT_OUTPUT, .LATE_FRAGMENT_TESTS},
			dstStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
			srcAccessMask = {.COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE},
			dstAccessMask = {.COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE},
			dependencyFlags = {},
		},
	}

	if vk.CreateRenderPass(
		   graphicsContext^.device,
		   &renderPassInfo,
		   nil,
		   &graphicsContext^.renderPass,
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Unable to create render pass!")
		panic("Unable to create render pass!")
	}
}

@(private = "file")
createFramebuffers :: proc(graphicsContext: ^GraphicsContext) {
	imageViewCount := u32(len(graphicsContext^.swapchainImageViews))
	graphicsContext^.swapchainFrameBuffers = make([]vk.Framebuffer, imageViewCount)
	for index in 0 ..< imageViewCount {
		frameBufferInfo: vk.FramebufferCreateInfo = {
			sType           = .FRAMEBUFFER_CREATE_INFO,
			pNext           = nil,
			flags           = {},
			renderPass      = graphicsContext^.renderPass,
			attachmentCount = 3,
			pAttachments    = raw_data(
				[]vk.ImageView {
					graphicsContext^.colourImage.view,
					graphicsContext^.depthImage.view,
					graphicsContext^.swapchainImageViews[index],
				},
			),
			width           = graphicsContext^.swapchainExtent.width,
			height          = graphicsContext^.swapchainExtent.height,
			layers          = 1,
		}
		if vk.CreateFramebuffer(
			   graphicsContext^.device,
			   &frameBufferInfo,
			   nil,
			   &graphicsContext^.swapchainFrameBuffers[index],
		   ) !=
		   .SUCCESS {
			log(.ERROR, "Failed to create frame buffer!")
			panic("Failed to create frame buffer!")
		}
	}
}

@(private = "file")
createPipelines :: proc(graphicsContext: ^GraphicsContext) {
	createShaderModule :: proc(
		graphicsContext: ^GraphicsContext,
		filename: string,
	) -> (
		shaderModule: vk.ShaderModule,
	) {
		loadShaderFile :: proc(filepath: string) -> (data: []byte) {
			fileHandle, err := os.open(filepath, mode = (os.O_RDONLY | os.O_APPEND))
			if err != 0 {
				log(.ERROR, "Shader file couldn't be opened!")
				panic("Shader file couldn't be opened!")
			}
			defer os.close(fileHandle)
			success: bool
			if data, success = os.read_entire_file_from_handle(fileHandle); !success {
				log(.ERROR, "Shader file couldn't be read!")
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
		if vk.CreateShaderModule(graphicsContext^.device, &createInfo, nil, &shaderModule) !=
		   .SUCCESS {
			log(.ERROR, "Failed to create shader module")
			panic("Failed to create shader module")
		}
		return
	}

	graphicsContext^.pipelines = make([]vk.Pipeline, 2)

	PipelineLayoutInfo: vk.PipelineLayoutCreateInfo = {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		pNext                  = nil,
		flags                  = {},
		setLayoutCount         = 1,
		pSetLayouts            = &graphicsContext^.descriptorSetLayout,
		pushConstantRangeCount = 0,
		pPushConstantRanges    = nil,
	}

	if vk.CreatePipelineLayout(
		   graphicsContext^.device,
		   &PipelineLayoutInfo,
		   nil,
		   &graphicsContext^.pipelineLayout,
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create pipeline layout!")
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
		rasterizationSamples  = graphicsContext^.msaaSamples,
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
		depthTestEnable       = false,
		depthWriteEnable      = false,
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

	skyShaderStagesInfo := make([]vk.PipelineShaderStageCreateInfo, len(skyShaderFiles))
	for path, index in skyShaderFiles {
		skyShaderStagesInfo[index] = {
			sType               = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			pNext               = nil,
			flags               = {},
			stage               = {skyShaderStages[index]},
			module              = createShaderModule(graphicsContext, path),
			pName               = "main",
			pSpecializationInfo = nil,
		}
	}

	pipelineInfo: vk.GraphicsPipelineCreateInfo = {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext               = nil,
		flags               = {},
		stageCount          = u32(len(skyShaderStagesInfo)),
		pStages             = raw_data(skyShaderStagesInfo),
		pVertexInputState   = &vertexInputInfo,
		pInputAssemblyState = &inputAssembly,
		pTessellationState  = nil,
		pViewportState      = &viewportState,
		pRasterizationState = &rasterizer,
		pMultisampleState   = &multisampling,
		pDepthStencilState  = &depthStencil,
		pColorBlendState    = &colourBlending,
		pDynamicState       = &dynamicStateInfo,
		layout              = graphicsContext^.pipelineLayout,
		renderPass          = graphicsContext^.renderPass,
		subpass             = 0,
		basePipelineHandle  = {},
		basePipelineIndex   = -1,
	}

	pipelineCacheCreateInfo: vk.PipelineCacheCreateInfo = {
		sType           = .PIPELINE_CACHE_CREATE_INFO,
		pNext           = nil,
		flags           = {},
		initialDataSize = 0,
		pInitialData    = nil,
	}

	pipelineCache: vk.PipelineCache
	vk.CreatePipelineCache(graphicsContext^.device, &pipelineCacheCreateInfo, nil, &pipelineCache)

	// depthStencil.depthWriteEnable = true
	// depthStencil.depthTestEnable = true
	rasterizer.cullMode = {.FRONT}
	// rasterizer.frontFace = .CLOCKWISE
	if vk.CreateGraphicsPipelines(
		   graphicsContext^.device,
		   pipelineCache,
		   1,
		   &pipelineInfo,
		   nil,
		   &graphicsContext^.pipelines[PipelineType.SKYBOX],
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create pipeline!")
		panic("Failed to create pipeline!")
	}

	shaderStagesInfo := make([]vk.PipelineShaderStageCreateInfo, len(shaderFiles))
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

	depthStencil.depthWriteEnable = true
	depthStencil.depthTestEnable = true
	rasterizer.cullMode = {.BACK}
	rasterizer.frontFace = .CLOCKWISE
	pipelineInfo.stageCount = u32(len(shaderStages))
	pipelineInfo.pStages = raw_data(shaderStagesInfo)
	if vk.CreateGraphicsPipelines(
		   graphicsContext^.device,
		   pipelineCache,
		   1,
		   &pipelineInfo,
		   nil,
		   &graphicsContext^.pipelines[PipelineType.MAIN],
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to create pipeline!")
		panic("Failed to create pipeline!")
	}

	for stage in skyShaderStagesInfo {
		vk.DestroyShaderModule(graphicsContext^.device, stage.module, nil)
	}
	delete(skyShaderStagesInfo)

	for stage in shaderStagesInfo {
		vk.DestroyShaderModule(graphicsContext^.device, stage.module, nil)
	}
	delete(shaderStagesInfo)

	vk.DestroyPipelineCache(graphicsContext^.device, pipelineCache, nil)
}

// ###################################################################
// #                         Render Loop                             #
// ###################################################################

@(private = "file")
recordCommandBuffer :: proc(
	graphicsContext: ^GraphicsContext,
	commandBuffer: ^vk.CommandBuffer,
	imageIndex: u32,
) {
	beginInfo: vk.CommandBufferBeginInfo = {
		sType            = .COMMAND_BUFFER_BEGIN_INFO,
		pNext            = nil,
		flags            = {},
		pInheritanceInfo = nil,
	}
	if vk.BeginCommandBuffer(commandBuffer^, &beginInfo) != .SUCCESS {
		log(.ERROR, "Failed to being recording command buffer!")
		panic("Failed to being recording command buffer!")
	}

	renderPassInfo: vk.RenderPassBeginInfo = {
		sType = .RENDER_PASS_BEGIN_INFO,
		pNext = nil,
		renderPass = graphicsContext^.renderPass,
		framebuffer = graphicsContext^.swapchainFrameBuffers[imageIndex],
		renderArea = vk.Rect2D{offset = {0, 0}, extent = graphicsContext^.swapchainExtent},
		clearValueCount = 2,
		pClearValues = raw_data(
			[]vk.ClearValue {
				{color = vk.ClearColorValue{float32 = {0, 0, 0, 1}}},
				{depthStencil = vk.ClearDepthStencilValue{depth = 1, stencil = 0}},
			},
		),
	}
	vk.CmdBeginRenderPass(commandBuffer^, &renderPassInfo, .INLINE)

	viewport: vk.Viewport = {
		x        = 0,
		y        = 0,
		width    = f32(graphicsContext^.swapchainExtent.width),
		height   = f32(graphicsContext^.swapchainExtent.height),
		minDepth = 0,
		maxDepth = 1,
	}
	vk.CmdSetViewport(commandBuffer^, 0, 1, &viewport)

	scissor: vk.Rect2D = {
		offset = {0, 0},
		extent = graphicsContext^.swapchainExtent,
	}
	vk.CmdSetScissor(commandBuffer^, 0, 1, &scissor)

	vk.CmdBindDescriptorSets(
		commandBuffer^,
		.GRAPHICS,
		graphicsContext^.pipelineLayout,
		0,
		1,
		&graphicsContext^.descriptorSets[graphicsContext^.currentFrame],
		0,
		nil,
	)

	vk.CmdBindVertexBuffers(
		commandBuffer^,
		0,
		1,
		&graphicsContext^.vertexBuffer.buffer,
		raw_data([]vk.DeviceSize{0}),
	)
	vk.CmdBindIndexBuffer(commandBuffer^, graphicsContext^.indexBuffer.buffer, 0, .UINT32)

	vk.CmdBindPipeline(commandBuffer^, .GRAPHICS, graphicsContext^.pipelines[PipelineType.SKYBOX])
	vk.CmdDrawIndexed(commandBuffer^, graphicsContext^.models[0].indexCount, 1, 0, 0, 0)

	vk.CmdBindPipeline(commandBuffer^, .GRAPHICS, graphicsContext^.pipelines[PipelineType.MAIN])
	for &model in graphicsContext^.models[1:] {
		vk.CmdDrawIndexed(
			commandBuffer^,
			model.indexCount,
			3,
			model.indexOffset,
			i32(model.vertexOffset),
			1,
		)
	}

	vk.CmdEndRenderPass(commandBuffer^)
	if vk.EndCommandBuffer(commandBuffer^) != .SUCCESS {
		log(.ERROR, "Failed to record command buffer!")
		panic("Failed to record command buffer!")
	}
}

@(private = "file")
updateViewProjectionUniform :: proc(graphicsContext: ^GraphicsContext, camera: Camera) {
	view := lookAt(camera.eye, camera.center, camera.up)
	projection := perspective(
		radians(f32(45.0)),
		f32(graphicsContext^.swapchainExtent.width) / f32(graphicsContext^.swapchainExtent.height),
		0.1,
		10000,
	)
	viewProjection: ViewProjectionUniform = {
		view           = view,
		projection     = projection,
		viewProjection = projection * view,
	}
	mem.copy(
		graphicsContext^.viewProjectionUniforms[graphicsContext^.currentFrame].mapped,
		&viewProjection,
		size_of(ViewProjectionUniform),
	)
}

@(private = "file")
updateInstanceBuffer :: proc(graphicsContext: ^GraphicsContext) {
	finalBoneTransforms := make([]Mat4, graphicsContext^.boneCount)
	instanceData := make([]InstanceInfo, MAX_MODEL_INSTANCES)
	defer delete(finalBoneTransforms)
	defer delete(instanceData)
	boneOffset: u32 = 0
	now := t.now()
	for &instance, instanceIndex in graphicsContext^.instances {
		instanceData[instanceIndex] = {
			model         = translate(
				instance.position,
			) * quatToRotation(instance.rotation) * scale(instance.scale),
			boneOffset    = boneOffset,
			samplerOffset = f32(instance.textureID),
		}

		skeleton := &graphicsContext^.models[instance.modelID].skeleton
		animation := graphicsContext^.models[instance.modelID].animations[instance.animID]
		timeSinceAnimStart := t.duration_seconds(t.diff(instance.animStartTime, now))
		timeStamp :=
			timeSinceAnimStart -
			(floor(timeSinceAnimStart / animation.duration) * animation.duration)
		localBoneTransforms := make([]Mat4, len(skeleton))

		for index in 0 ..< len(skeleton) {
			localBoneTransforms[index] = IMat4
		}

		defer boneOffset += u32(len(skeleton))
		defer delete(localBoneTransforms)

		for &node, nodeIndex in animation.nodes {
			bone := skeleton[node.bone]
			parentTransform := localBoneTransforms[bone.parentIndex]
			animTransform: Mat4

			// a *= b == a = a * b
			// therefore aT *= T *= R *= S == aT = T * R * S * aT
			if node.numKeyPositions == 1 {
				animTransform = translate(node.keyPositions[0].value)
			} else {
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
				animTransform = translate(value)
			}

			if node.numKeyRotations == 1 {
				animTransform *= quatToRotation(node.keyRotations[0].value)
			} else {
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
				animTransform *= quatToRotation(
					quatLurp(
						node.keyRotations[instance.rotationKeys[nodeIndex]].value,
						node.keyRotations[instance.rotationKeys[nodeIndex] + 1].value,
						f32(timeDiff),
					),
				)
			}

			if node.numKeyScales == 1 {
				animTransform *= scale(node.keyScales[0].value)
			} else {
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
				animTransform *= scale(value)
			}
			localBoneTransforms[node.bone] = parentTransform * animTransform
			finalBoneTransforms[node.bone + boneOffset] =
				localBoneTransforms[node.bone] * bone.inverseBind
		}
	}
	mem.copy(
		graphicsContext^.boneBuffers[graphicsContext^.currentFrame].mapped,
		raw_data(finalBoneTransforms),
		len(finalBoneTransforms) * size_of(Mat4),
	)
	mem.copy(
		graphicsContext^.instanceBuffers[graphicsContext^.currentFrame].mapped,
		raw_data(instanceData),
		MAX_MODEL_INSTANCES * size_of(InstanceInfo),
	)
}

drawFrame :: proc(graphicsContext: ^GraphicsContext, camera: Camera) {
	vk.WaitForFences(
		graphicsContext^.device,
		1,
		&graphicsContext^.inFlightFrames[graphicsContext^.currentFrame],
		true,
		max(u64),
	)

	imageIndex: u32
	result := vk.AcquireNextImageKHR(
		graphicsContext^.device,
		graphicsContext^.swapchain,
		max(u64),
		graphicsContext^.imagesAvailable[graphicsContext^.currentFrame],
		{},
		&imageIndex,
	)
	if result == .ERROR_OUT_OF_DATE_KHR {
		recreateSwapchain(graphicsContext)
		return
	} else if (result != .SUCCESS && result != .SUBOPTIMAL_KHR) {
		log(.ERROR, "Failed to aquire swapchain image!")
		panic("Failed to aquire swapchain image!")
	}
	vk.ResetFences(
		graphicsContext^.device,
		1,
		&graphicsContext^.inFlightFrames[graphicsContext^.currentFrame],
	)

	vk.ResetCommandBuffer(graphicsContext^.commandBuffers[graphicsContext^.currentFrame], {})
	updateViewProjectionUniform(graphicsContext, camera)
	updateInstanceBuffer(graphicsContext)
	recordCommandBuffer(
		graphicsContext,
		&graphicsContext^.commandBuffers[graphicsContext^.currentFrame],
		imageIndex,
	)

	submitInfo: vk.SubmitInfo = {
		sType                = .SUBMIT_INFO,
		pNext                = nil,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = raw_data(
			[]vk.Semaphore{graphicsContext^.imagesAvailable[graphicsContext^.currentFrame]},
		),
		pWaitDstStageMask    = raw_data([]vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}),
		commandBufferCount   = 1,
		pCommandBuffers      = &graphicsContext^.commandBuffers[graphicsContext^.currentFrame],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = raw_data(
			[]vk.Semaphore{graphicsContext^.rendersFinished[graphicsContext^.currentFrame]},
		),
	}

	if vk.QueueSubmit(
		   graphicsContext^.graphicsQueue,
		   1,
		   &submitInfo,
		   graphicsContext^.inFlightFrames[graphicsContext^.currentFrame],
	   ) !=
	   .SUCCESS {
		log(.ERROR, "Failed to submit draw command buffer!")
		panic("Failed to submit draw command buffer!")
	}

	presentInfo: vk.PresentInfoKHR = {
		sType              = .PRESENT_INFO_KHR,
		pNext              = nil,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = raw_data(
			[]vk.Semaphore{graphicsContext^.rendersFinished[graphicsContext^.currentFrame]},
		),
		swapchainCount     = 1,
		pSwapchains        = raw_data([]vk.SwapchainKHR{graphicsContext^.swapchain}),
		pImageIndices      = &imageIndex,
		pResults           = nil,
	}

	result = vk.QueuePresentKHR(graphicsContext^.presentQueue, &presentInfo)
	if result == .ERROR_OUT_OF_DATE_KHR ||
	   result == .SUBOPTIMAL_KHR ||
	   graphicsContext^.framebufferResized {
		graphicsContext^.framebufferResized = false
		recreateSwapchain(graphicsContext)
	} else if result != .SUCCESS {
		log(.ERROR, "Failed to present swapchain image!")
		panic("Failed to present swapchain image!")
	}

	graphicsContext^.currentFrame += (graphicsContext^.currentFrame + 1) % 2
}

// ###################################################################
// #                           Cleanup                               #
// ###################################################################

@(private = "file")
cleanupSwapchain :: proc(graphicsContext: ^GraphicsContext) {
	vk.DestroyImageView(graphicsContext^.device, graphicsContext^.colourImage.view, nil)
	vk.DestroyImage(graphicsContext^.device, graphicsContext^.colourImage.image, nil)
	vk.FreeMemory(graphicsContext^.device, graphicsContext^.colourImage.memory, nil)
	vk.DestroyImageView(graphicsContext^.device, graphicsContext^.depthImage.view, nil)
	vk.DestroyImage(graphicsContext^.device, graphicsContext^.depthImage.image, nil)
	vk.FreeMemory(graphicsContext^.device, graphicsContext^.depthImage.memory, nil)
	for frameBuffer in graphicsContext^.swapchainFrameBuffers {
		vk.DestroyFramebuffer(graphicsContext^.device, frameBuffer, nil)
	}
	for index in 0 ..< len(graphicsContext^.swapchainImageViews) {
		vk.DestroyImageView(
			graphicsContext^.device,
			graphicsContext^.swapchainImageViews[index],
			nil,
		)
	}
	vk.DestroySwapchainKHR(graphicsContext^.device, graphicsContext^.swapchain, nil)
}

@(private = "file")
cleanupAssets :: proc(graphicsContext: ^GraphicsContext) {
	vk.DestroyBuffer(graphicsContext^.device, graphicsContext^.indexBuffer.buffer, nil)
	vk.FreeMemory(graphicsContext^.device, graphicsContext^.indexBuffer.memory, nil)
	vk.DestroyBuffer(graphicsContext^.device, graphicsContext^.vertexBuffer.buffer, nil)
	vk.FreeMemory(graphicsContext^.device, graphicsContext^.vertexBuffer.memory, nil)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyBuffer(graphicsContext^.device, graphicsContext^.instanceBuffers[i].buffer, nil)
		vk.FreeMemory(graphicsContext^.device, graphicsContext^.instanceBuffers[i].memory, nil)
		vk.DestroyBuffer(graphicsContext^.device, graphicsContext^.boneBuffers[i].buffer, nil)
		vk.FreeMemory(graphicsContext^.device, graphicsContext^.boneBuffers[i].memory, nil)
	}
	vk.DestroyImageView(graphicsContext^.device, graphicsContext^.textures.view, nil)
	vk.DestroyImage(graphicsContext^.device, graphicsContext^.textures.image, nil)
	vk.FreeMemory(graphicsContext^.device, graphicsContext^.textures.memory, nil)
	vk.DestroySampler(graphicsContext^.device, graphicsContext^.textures.sampler, nil)
	vk.DestroyImageView(graphicsContext^.device, graphicsContext^.skybox.view, nil)
	vk.DestroyImage(graphicsContext^.device, graphicsContext^.skybox.image, nil)
	vk.FreeMemory(graphicsContext^.device, graphicsContext^.skybox.memory, nil)
	vk.DestroySampler(graphicsContext^.device, graphicsContext^.skybox.sampler, nil)

	delete(graphicsContext^.models)
	delete(graphicsContext^.instances)
	delete(graphicsContext^.vertices)
	delete(graphicsContext^.indices)
}

clanupVkGraphics :: proc(graphicsContext: ^GraphicsContext) {
	vk.DeviceWaitIdle(graphicsContext^.device)
	cleanupAssets(graphicsContext)
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyBuffer(
			graphicsContext^.device,
			graphicsContext^.viewProjectionUniforms[i].buffer,
			nil,
		)
		vk.FreeMemory(
			graphicsContext^.device,
			graphicsContext^.viewProjectionUniforms[i].memory,
			nil,
		)
	}
	vk.DestroyDescriptorPool(graphicsContext^.device, graphicsContext^.descriptorPool, nil)
	vk.DestroyDescriptorSetLayout(
		graphicsContext^.device,
		graphicsContext^.descriptorSetLayout,
		nil,
	)
	for pipeline in graphicsContext^.pipelines {
		vk.DestroyPipeline(graphicsContext^.device, pipeline, nil)
	}
	vk.DestroyPipelineLayout(graphicsContext^.device, graphicsContext^.pipelineLayout, nil)
	vk.DestroyRenderPass(graphicsContext^.device, graphicsContext^.renderPass, nil)
	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroySemaphore(graphicsContext^.device, graphicsContext^.imagesAvailable[index], nil)
		vk.DestroySemaphore(graphicsContext^.device, graphicsContext^.rendersFinished[index], nil)
		vk.DestroyFence(graphicsContext^.device, graphicsContext^.inFlightFrames[index], nil)
	}
	cleanupSwapchain(graphicsContext)
	vk.DestroyCommandPool(graphicsContext^.device, graphicsContext^.commandPool, nil)
	vk.DestroyDevice(graphicsContext^.device, nil)
	when ODIN_DEBUG {
		vk.DestroyDebugUtilsMessengerEXT(
			graphicsContext^.instance,
			graphicsContext^.debugMessenger,
			nil,
		)
	}
	vk.DestroySurfaceKHR(graphicsContext^.instance, graphicsContext^.surface, nil)
	vk.DestroyInstance(graphicsContext^.instance, nil)

	delete(graphicsContext^.swapchainImages)
	delete(graphicsContext^.swapchainImageViews)
	delete(graphicsContext^.swapchainFrameBuffers)
	delete(graphicsContext^.commandBuffers)
	delete(graphicsContext^.imagesAvailable)
	delete(graphicsContext^.rendersFinished)
	delete(graphicsContext^.inFlightFrames)
	delete(graphicsContext^.descriptorSets)
}
