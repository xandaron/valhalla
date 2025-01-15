package Valhalla

import ImFD "ImFileDialog"
import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"
import "imgui"
import implGLFW "imgui/imgui_impl_glfw"
import implVulkan "imgui/imgui_impl_vulkan"
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
MAX_FRAMES_IN_FLIGHT: u32 : 2

@(private = "file")
RENDER_SIZE: Vec2 : {1980, 1080}

@(private = "file")
SHADOW_RESOLUTION: Vec2 : {2048, 2048}

@(private = "file")
IMAGES_RESOLUTION: Vec2 : {4096, 4096}

@(private = "file")
DEPTH_BIAS_CONSTANT: f32 : 1.25

@(private = "file")
DEPTH_BIAS_SLOPE: f32 : 1.75

@(private = "file")
UI_ENABLED: bool : true


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
	vkImage: vk.Image,
	memory:  vk.DeviceMemory,
	view:    vk.ImageView,
	format:  vk.Format,
	sampler: vk.Sampler,
}

@(private = "file")
ImFDImageData :: struct {
	descriptorSet: vk.DescriptorSet,
	using image:   Image,
}

// Use Vec4 becuse of alignment issues when using Vec3
@(private = "file")
LightData :: struct #align (16) {
	mvp:             Mat4,
	position:        Vec4,
	colourIntensity: Vec4,
}

@(private = "file")
UniformBuffer :: struct #align (16) {
	view:           Mat4,
	projection:     Mat4,
	viewProjection: Mat4,
	lightCount:     u32,
}

@(private = "file")
InstanceInfo :: struct #align (16) {
	model:                Mat4,
	boneOffset:           u32,
	textureSamplerOffset: f32,
	normalsSamplerOffset: f32,
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
ImguiData :: struct {
	uiContext:      ^imgui.Context,
	frameBuffers:   []vk.Framebuffer,
	descriptorPool: vk.DescriptorPool,
	renderPass:     vk.RenderPass,
	colour:         Image,
	imfdImages:     [dynamic]ImFDImageData,
}

@(private = "file")
RenderPass :: struct {
	frameBuffers: []vk.Framebuffer,
	colour:       Image,
	depth:        Image,
	renderPass:   vk.RenderPass,
	descriptor:   vk.DescriptorImageInfo,
}

@(private = "file")
PipelineIndex :: enum {
	SHADOW = 0,
	MAIN   = 1,
	POST   = 2,
}

@(private = "file")
Pipeline :: struct {
	using renderPassData: RenderPass,
	descriptorPool:       vk.DescriptorPool,
	descriptorSets:       [MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet,
	pipeline:             vk.Pipeline,
	descriptorSetLayout:  vk.DescriptorSetLayout,
	layout:               vk.PipelineLayout,
}

@(private = "file")
PointLight :: struct {
	name:            cstring,
	position:        Vec3,
	direction:       Vec3,
	colourIntensity: Vec3,
	fov:             f32,
	rotationAngle:   f32,
	rotationAxis:    Vec3,
}

@(private = "file")
Instance :: struct {
	name:         cstring,
	modelID:      u32,
	animID:       u32,
	textureID:    f32,
	normalID:     f32,
	position:     Vec3,
	rotation:     Vec3,
	scale:        Vec3,
	positionKeys: []u32,
	rotationKeys: []u32,
	scaleKeys:    []u32,
	animTimer:    f64,
}

@(private = "file")
Scene :: struct {
	name:            cstring,
	clearColour:     [4]i32,

	// Scene
	instances:       []Instance,
	pointLights:     []PointLight,
	cameras:         []Camera,
	activeCamera:    u32,

	// Assets
	modelPaths:      []cstring,
	models:          []Model,
	texturePaths:    []cstring,
	textures:        Image,
	textureCount:    u32,
	normalPaths:     []cstring,
	normals:         Image,
	normalsCount:    u32,
	vertices:        []Vertex,
	indices:         []u32,
	boneCount:       int,
	shadowImages:    Image,

	// Buffers TODO: All buffers should be one buffer using offsets
	vertexBuffer:    Buffer,
	indexBuffer:     Buffer,
	instanceBuffers: [MAX_FRAMES_IN_FLIGHT]Buffer,
	boneBuffers:     [MAX_FRAMES_IN_FLIGHT]Buffer,
	lightBuffers:    [MAX_FRAMES_IN_FLIGHT]Buffer,
}

CameraMode :: enum {
	PERSPECTIVE,
	ORTHOGRAPHIC,
}

Camera :: struct {
	name:            cstring,
	eye, center, up: Vec3,
	distance:        f32,
	fov:             f32,
	mode:            CameraMode,
}

GraphicsContext :: struct {
	// GLFW + IMGUI
	window:                glfw.WindowHandle,
	imguiData:             ImguiData,

	// Vulkan Data
	instance:              vk.Instance,
	debugMessenger:        vk.DebugUtilsMessengerEXT,
	surface:               vk.SurfaceKHR,
	physicalDevice:        vk.PhysicalDevice,
	device:                vk.Device,

	// Queues
	queueFamilies:         QueueFamilyIndices,
	graphicsQueue:         vk.Queue,
	presentQueue:          vk.Queue,
	computeQueue:          vk.Queue,

	// Swapchain
	swapchainImageCount:   u32,
	swapchainTransform:    vk.SurfaceTransformFlagsKHR,
	swapchain:             vk.SwapchainKHR,
	swapchainFormat:       vk.SurfaceFormatKHR,
	swapchainMode:         vk.PresentModeKHR,
	swapchainExtent:       vk.Extent2D,
	swapchainImages:       []vk.Image,
	swapchainImageViews:   []vk.ImageView,
	pipelines:             []Pipeline,

	// Frame Resources
	inImage:               Image,
	outImage:              Image,
	inFlightFrames:        []vk.Fence,
	rendersFinished:       []vk.Semaphore,
	computeFinished:       []vk.Semaphore,
	uiFinished:            []vk.Semaphore,
	imagesAvailable:       []vk.Semaphore,

	// Commands
	graphicsCommandPool:   vk.CommandPool,
	mainCommandBuffers:    []vk.CommandBuffer,
	uiCommandBuffers:      []vk.CommandBuffer,
	computeCommandPool:    vk.CommandPool,
	computeCommandBuffers: []vk.CommandBuffer,

	// Scene Data
	scenes:                []Scene,
	activeScene:           u32,

	// Buffer
	uniformBuffers:        [MAX_FRAMES_IN_FLIGHT]Buffer,

	// Util
	currentFrame:          u32,
	framebufferResized:    b8,
}


// ###################################################################
// #                               Init                              #
// ###################################################################


initVkGraphics :: proc(using graphicsContext: ^GraphicsContext) {
	when ODIN_DEBUG {
		glfw.SetErrorCallback(glfwErrorCallback)
	}
	if !glfw.Init() {
		log.log(.Fatal, "Failed to initalize glfw, quitting application.")
		return
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	if window = glfw.CreateWindow(1600, 800, "Valhalla", nil, nil); window == nil {
		log.log(.Fatal, "Failed to create window, quitting application.")
		return
	}

	glfw.SetKeyCallback(window, keyCallback)
	glfw.SetMouseButtonCallback(window, glfwMouseButtonCallback)
	glfw.SetCursorPosCallback(window, glfwCursorPosCallback)
	glfw.SetScrollCallback(window, glfwScrollCallback)
	glfw.SetFramebufferSizeCallback(window, framebufferResizeCallback)

	vk.load_proc_addresses(rawptr(glfw.GetInstanceProcAddress))

	framebufferResized = false
	currentFrame = 0

	createInstance(graphicsContext)
	when ODIN_DEBUG {
		vkSetupDebugMessenger(graphicsContext)
	}
	createSurface(graphicsContext)
	pickPhysicalDevice(graphicsContext)
	createLogicalDevice(graphicsContext)
	createSwapchain(graphicsContext)
	createCommandBuffers(graphicsContext)
	createUniformBuffer(graphicsContext)
	createSyncObjects(graphicsContext)
	pipelines = make([]Pipeline, len(PipelineIndex))
	createRenderPass(graphicsContext)
	createFramebuffers(graphicsContext)
	createGraphicsDescriptorSets(graphicsContext)
	createComputeDescriptorSets(graphicsContext)
	updateGraphicsDescriptorSets(graphicsContext)
	updateComputeDescriptorSets(graphicsContext)
	createGraphicsPipelines(graphicsContext)
	createComputePipelines(graphicsContext)

	when UI_ENABLED {
		initImgui(graphicsContext)
		updateImgui(graphicsContext)
	}
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
	if glfw.CreateWindowSurface(instance, window, nil, &surface) != .SUCCESS {
		log.log(.Fatal, "Failed to create surface!")
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
	queueFamilies, _ = findQueueFamilies(physicalDevice, graphicsContext)

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

	if vk.CreateDevice(physicalDevice, &createInfo, nil, &device) != .SUCCESS {
		log.log(.Error, "Failed to create logical device!")
		panic("Failed to create logical device!")
	}

	// load_proc_addresses_device :: proc(device: Device)
	vk.load_proc_addresses(device)

	vk.GetDeviceQueue(device, queueFamilies.graphicsFamily, 0, &graphicsQueue)
	vk.GetDeviceQueue(device, queueFamilies.presentFamily, 0, &presentQueue)
	vk.GetDeviceQueue(device, queueFamilies.computeFamily, 0, &computeQueue)
}


// ###################################################################
// #                            Swapchain                            #
// ###################################################################


@(private = "file")
createSwapchain :: proc(using graphicsContext: ^GraphicsContext) {
	chooseFormat :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
		for format in formats {
			if (format.format == .B8G8R8A8_UNORM || format.format == .R8G8B8A8_UNORM) && format.colorSpace == .SRGB_NONLINEAR {
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

	max := swapchainSupport.capabilities.maxImageCount
	min := swapchainSupport.capabilities.minImageCount
	swapchainImageCount = max if max == 1 else (2 if 2 >= min else min)
	swapchainTransform = swapchainSupport.capabilities.currentTransform

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
		queueFamilyIndexCount = oneQueueFamily ? 0 : 3,
		pQueueFamilyIndices   = oneQueueFamily ? nil : raw_data([]u32{queueFamilies.graphicsFamily, queueFamilies.presentFamily, queueFamilies.computeFamily}),
		preTransform          = swapchainTransform,
		compositeAlpha        = {.OPAQUE},
		presentMode           = swapchainMode,
		clipped               = true,
		oldSwapchain          = {},
	}

	if vk.CreateSwapchainKHR(device, &createInfo, nil, &swapchain) != .SUCCESS {
		log.log(.Error, "Failed to create swapchain!")
		panic("Failed to create swapchain!")
	}

	swapchainImages = make([]vk.Image, swapchainImageCount)
	vk.GetSwapchainImagesKHR(device, swapchain, &swapchainImageCount, raw_data(swapchainImages))

	swapchainImageViews = make([]vk.ImageView, swapchainImageCount)
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
		glfw.WaitEvents()
		width, height = glfw.GetFramebufferSize(window)
	}

	if res := vk.DeviceWaitIdle(device); res != .SUCCESS {
		panic("Error waiting for device idle!")
	}

	cleanupSwapchain(graphicsContext)

	createSwapchain(graphicsContext)
	updateComputeDescriptorSets(graphicsContext)

	when UI_ENABLED {
		cleanupImgui(graphicsContext)
		updateImgui(graphicsContext)
	}
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
	if vk.CreateCommandPool(device, &poolInfo, nil, &graphicsCommandPool) != .SUCCESS {
		log.log(.Error, "Failed to create command pool!")
		panic("Failed to create command pool!")
	}

	mainCommandBuffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
	allocInfo: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = graphicsCommandPool,
		level              = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}
	if vk.AllocateCommandBuffers(device, &allocInfo, raw_data(mainCommandBuffers)) != .SUCCESS {
		log.log(.Error, "Failed to allocate command buffer!")
		panic("Failed to allocate command buffer!")
	}

	uiCommandBuffers = make([]vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT)
	allocInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = graphicsCommandPool,
		level              = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}
	if vk.AllocateCommandBuffers(device, &allocInfo, raw_data(uiCommandBuffers)) != .SUCCESS {
		log.log(.Error, "Failed to allocate command buffer!")
		panic("Failed to allocate command buffer!")
	}

	poolInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		pNext            = nil,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = queueFamilies.computeFamily,
	}
	if vk.CreateCommandPool(device, &poolInfo, nil, &computeCommandPool) != .SUCCESS {
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
	if vk.AllocateCommandBuffers(device, &allocInfo, raw_data(computeCommandBuffers)) != .SUCCESS {
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
	vk.CreateFence(device, &fenceCreateInfo, nil, &fence)
	vk.QueueSubmit(graphicsQueue, 1, &submitInfo, fence)
	vk.WaitForFences(device, 1, &fence, true, ~u64(0))
	vk.DestroyFence(device, fence, nil)
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
	vkDevice := graphicsContext.device
	if vk.CreateBuffer(vkDevice, &bufferInfo, nil, buffer) != .SUCCESS {
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
	vk.MapMemory(device, stagingBufferMemory, 0, (vk.DeviceSize)(bufferSize), {}, &data)
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
createVertexBuffer :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	loadBufferToGPU(
		graphicsContext,
		size_of(Vertex) * len(scenes[sceneIndex].vertices),
		raw_data(scenes[sceneIndex].vertices),
		&scenes[sceneIndex].vertexBuffer,
		.VERTEX_BUFFER,
	)
	scenes[sceneIndex].vertexBuffer.mapped = nil
}

@(private = "file")
createIndexBuffer :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	loadBufferToGPU(
		graphicsContext,
		size_of(u32) * len(scenes[sceneIndex].indices),
		raw_data(scenes[sceneIndex].indices),
		&scenes[sceneIndex].indexBuffer,
		.INDEX_BUFFER,
	)
	scenes[sceneIndex].indexBuffer.mapped = nil
}

@(private = "file")
createUniformBuffer :: proc(using graphicsContext: ^GraphicsContext) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(UniformBuffer),
			{.UNIFORM_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&uniformBuffers[i].buffer,
			&uniformBuffers[i].memory,
		)
		vk.MapMemory(
			device,
			uniformBuffers[i].memory,
			0,
			size_of(UniformBuffer),
			{},
			&uniformBuffers[i].mapped,
		)
	}
}

@(private = "file")
createInstanceBuffer :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Instance) * len(scenes[sceneIndex].instances),
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&scenes[sceneIndex].instanceBuffers[i].buffer,
			&scenes[sceneIndex].instanceBuffers[i].memory,
		)
		vk.MapMemory(
			device,
			scenes[sceneIndex].instanceBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Instance) * len(scenes[sceneIndex].instances)),
			{},
			&scenes[sceneIndex].instanceBuffers[i].mapped,
		)
	}
}

@(private = "file")
createBoneBuffer :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(Mat4) * scenes[sceneIndex].boneCount,
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&scenes[sceneIndex].boneBuffers[i].buffer,
			&scenes[sceneIndex].boneBuffers[i].memory,
		)
		vk.MapMemory(
			device,
			scenes[sceneIndex].boneBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(Mat4) * scenes[sceneIndex].boneCount),
			{},
			&scenes[sceneIndex].boneBuffers[i].mapped,
		)
	}
}

@(private = "file")
createLightBuffer :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		createBuffer(
			graphicsContext,
			size_of(LightData) * len(scenes[sceneIndex].pointLights),
			{.STORAGE_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&scenes[sceneIndex].lightBuffers[i].buffer,
			&scenes[sceneIndex].lightBuffers[i].memory,
		)
		vk.MapMemory(
			device,
			scenes[sceneIndex].lightBuffers[i].memory,
			0,
			vk.DeviceSize(size_of(LightData) * len(scenes[sceneIndex].pointLights)),
			{},
			&scenes[sceneIndex].lightBuffers[i].mapped,
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

	if vk.CreateImage(device, &imageInfo, nil, &image.vkImage) != .SUCCESS {
		log.log(.Error, "Failed to create texture!")
		panic("Failed to create texture!")
	}

	memRequirements: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(device, image.vkImage, &memRequirements)
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
	if vk.BindImageMemory(device, image.vkImage, image.memory, 0) != .SUCCESS {
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
		sType = .IMAGE_VIEW_CREATE_INFO,
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

@(private = "file")
createSampler :: proc(
	using graphicsContext: ^GraphicsContext,
	filter: vk.Filter,
	mipMode: vk.SamplerMipmapMode,
	addressMode: vk.SamplerAddressMode,
	anistropyEnabled: b32,
	maxAnistropy: f32,
	borderColour: vk.BorderColor,
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
		borderColor             = borderColour,
		unnormalizedCoordinates = false,
	}
	if vk.CreateSampler(device, &samplerInfo, nil, &sampler) != .SUCCESS {
		log.log(.Error, "Failed to create texture sampler!")
		panic("Failed to create texture sampler!")
	}
	return
}

@(private = "file")
transitionImageLayout :: proc(
	using graphicsContext: ^GraphicsContext,
	commandBuffer: vk.CommandBuffer,
	image: vk.Image,
	oldLayout, newLayout: vk.ImageLayout,
	aspectMask: vk.ImageAspectFlags,
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
			aspectMask = aspectMask,
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
	case .SHADER_READ_ONLY_OPTIMAL:
		barrier.srcAccessMask = {.SHADER_READ}
		sourceStage = {.FRAGMENT_SHADER}
	case .GENERAL:
		barrier.srcAccessMask = {.SHADER_READ}
		sourceStage = {.COMPUTE_SHADER}
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
	case .COLOR_ATTACHMENT_OPTIMAL:
		barrier.dstAccessMask = {.SHADER_WRITE}
		destinationStage = {.VERTEX_SHADER}
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

@(private = "file")
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

@(private = "file")
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

@(private = "file")
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

@(private = "file")
upscaleImage :: proc(
	commandBuffer: vk.CommandBuffer,
	src, dst: vk.Image,
	srcSize, dstSize: vk.Extent3D,
) {
	blit: vk.ImageBlit = {
		srcSubresource = {aspectMask = {.COLOR}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		srcOffsets = {
			{x = 0, y = 0, z = 0},
			{x = i32(srcSize.width), y = i32(srcSize.height), z = 1},
		},
		dstSubresource = {
			aspectMask = {.COLOR},
			mipLevel = 0,
			baseArrayLayer = dstSize.depth,
			layerCount = 1,
		},
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
		.LINEAR,
	)
}


// ###################################################################
// #                          Create Assets                          #
// ###################################################################


@(private = "file")
loadModels :: proc(
	using graphicsContext: ^GraphicsContext,
	sceneIndex: u32,
	modelPaths: []cstring,
) {
	loadFBX :: proc(graphicsContext: ^GraphicsContext, model: ^Model, filename: cstring) {
		opts: fbx.Load_Opts = {
			target_axes = fbx.Coordinate_Axes {
				right = .POSITIVE_X,
				up = .POSITIVE_Y,
				front = .POSITIVE_Z,
			},
		}
		err: fbx.Error
		scene := fbx.load_file(filename, &opts, &err)
		if err.type != .NONE || scene == nil {
			log.logf(.Error, "Failed to load FBX file! Reason\n{}", err.description.data)
			panic("Failed to load FBX file!")
		}
		defer fbx.free_scene(scene)

		model.skeleton = make([]Bone, scene.bones.count)
		boneIndex := 0
		for index in 0 ..< scene.nodes.count {
			node := scene.nodes.data[index]
			if node.attrib_type != .BONE {
				continue
			}

			parentIndex: u32 = 0
			if !node.parent.is_root {
				for bone, index in model.skeleton {
					if bone.name == node.parent.element.name.data {
						parentIndex = u32(index)
						break
					}
				}
			}
			model.skeleton[boneIndex] = {
				name        = node.bone.element.name.data,
				isRoot      = node.parent.is_root,
				parentIndex = parentIndex,
			}
			boneIndex += 1
		}

		vertexCount: uint = 0
		indexCount: uint = 0
		for index in 0 ..< scene.meshes.count {
			vertexCount += scene.meshes.data[index].num_indices
			indexCount += scene.meshes.data[index].num_triangles * 3
		}

		model.vertices = make([]Vertex, vertexCount)
		model.indices = make([]u32, indexCount)
		model.indexCount = u32(indexCount)

		vertexOffset, indexOffset, meshIndexOffset: u32 = 0, 0, 0
		for meshIndex in 0 ..< scene.meshes.count {
			mesh := scene.meshes.data[meshIndex]
			for faceIndex in 0 ..< mesh.faces.count {
				face := mesh.faces.data[faceIndex]
				triangulatedIndexCount := (face.num_indices - 2) * 3

				err: fbx.Panic
				tris := fbx.catch_triangulate_face(
					&err,
					raw_data(model.indices[indexOffset:indexOffset + triangulatedIndexCount]),
					uint(triangulatedIndexCount),
					mesh,
					face,
				)

				if err.did_panic {
					errMessage := transmute(string)err.message[0:err.message_length]
					log.log(.Error, errMessage)
					panic(errMessage)
				}

				for &index in model.indices[indexOffset:indexOffset + triangulatedIndexCount] {
					index += meshIndexOffset
				}
				indexOffset += triangulatedIndexCount
			}

			for indiceIndex in 0 ..< mesh.num_indices {
				indiceIndex := u32(indiceIndex)
				vertexIndex := mesh.vertex_position.indices.data[indiceIndex]
				pos := mesh.vertex_position.values.data[vertexIndex]

				uv := [2]f64{0, 0}
				if mesh.vertex_uv.values.count != 0 {
					uv = mesh.vertex_uv.values.data[mesh.vertex_uv.indices.data[indiceIndex]]
				}

				norm := [3]f64{0, 1, 0}
				if mesh.vertex_normal.values.count != 0 {
					norm =
						mesh.vertex_normal.values.data[mesh.vertex_normal.indices.data[indiceIndex]]
				}

				model.vertices[indiceIndex + vertexOffset] = {
					position = {f32(pos.x), f32(pos.y), f32(pos.z)},
					texCoord = {f32(uv.x), 1 - f32(uv.y)},
					normal   = {f32(norm.x), f32(norm.y), f32(norm.z)},
					weights  = {1.0, 0.0, 0.0, 0.0},
					bones    = {0, 0, 0, 0},
				}

				if mesh.skin_deformers.count != 0 {
					deformer := mesh.skin_deformers.data[0]
					numWeights :=
						deformer.vertices.data[vertexIndex].num_weights if deformer.vertices.data[vertexIndex].num_weights <= 4 else 4
					firstWeightIndex := deformer.vertices.data[vertexIndex].weight_begin

					for weightIndex in 0 ..< numWeights {
						skinWeight := deformer.weights.data[firstWeightIndex + weightIndex]
						boneName :=
							deformer.clusters.data[skinWeight.cluster_index].bone_node.element.name

						for &bone, boneIndex in model.skeleton {
							if bone.name == boneName.data {
								model.vertices[indiceIndex + vertexOffset].bones[weightIndex] =
									u32(boneIndex)
								break
							}
						}

						model.vertices[indiceIndex + vertexOffset].weights[weightIndex] = f32(
							skinWeight.weight,
						)
					}

					if numWeights != 0 {
						model.vertices[indiceIndex + vertexOffset].weights = normalize(
							model.vertices[indiceIndex + vertexOffset].weights,
						)
					}
				}
			}

			vertexOffset += u32(mesh.num_indices)
			meshIndexOffset = indexOffset
		}

		for clusterIndex in 0 ..< scene.skin_cluster.count {
			skinCluster := scene.skin_cluster.data[clusterIndex]^
			for &bone in model^.skeleton {
				if bone.name != skinCluster.bone_node.element.name.data {
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

		model.animations = make([]Anim, scene.anim_stacks.count)
		for animIndex in 0 ..< scene.anim_stacks.count {
			stack := scene.anim_stacks.data[animIndex]

			err: fbx.Error
			bakedAnim := fbx.bake_anim(scene, stack.anim, nil, &err)
			if err.type != .NONE {
				log.logf(.Error, "Error baking animation: {}", err.description.data)
				continue
			}
			defer fbx.free_baked_anim(bakedAnim)

			animation := &model.animations[animIndex]
			animation.duration = bakedAnim^.playback_duration
			animation.nodes = make([]AnimNode, bakedAnim.nodes.count)

			for bakedIndex in 0 ..< bakedAnim.nodes.count {
				bakedNode := bakedAnim.nodes.data[bakedIndex]
				sceneNode := scene.nodes.data[bakedNode.typed_id]

				for bone, boneIndex in model.skeleton {
					if bone.name != sceneNode.element.name.data {
						continue
					}

					animNode := AnimNode {
						bone            = u32(boneIndex),
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

	scene := &scenes[sceneIndex]

	modelOffset := len(scene.models)
	modelCount := modelOffset + len(modelPaths)
	newModels := make([]Model, modelCount)
	for &model, index in scene.models {
		newModels[index] = model
	}
	scene.models = newModels

	vertexCount, indexCount := u32(len(scene.vertices)), u32(len(scene.indices))
	vertexIndex, indiceIndex := vertexCount, indexCount
	for path, index in modelPaths {
		loadFBX(graphicsContext, &scene.models[modelOffset + index], path)

		scene.models[modelOffset + index].vertexOffset = vertexCount
		scene.models[modelOffset + index].indexOffset = indexCount

		vertexCount += u32(len(scene.models[modelOffset + index].vertices))
		indexCount += u32(len(scene.models[modelOffset + index].indices))
	}

	newVertices := make([]Vertex, vertexCount)

	for &vertex, index in scene.vertices {
		newVertices[index] = vertex
	}
	delete(scene.vertices)
	scene.vertices = newVertices

	newIndices := make([]u32, indexCount)
	for &indice, index in scene.indices {
		newIndices[index] = indice
	}
	delete(scene.indices)
	scene.indices = newIndices


	for modelIndex in modelOffset ..< modelCount {
		model := &scene.models[modelIndex]

		for &vertex in model.vertices {
			scene.vertices[vertexIndex] = vertex
			vertexIndex += 1
		}

		for &indice in model.indices {
			scene.indices[indiceIndex] = indice
			indiceIndex += 1
		}
	}
}

@(private = "file")
loadTextures :: proc(
	using graphicsContext: ^GraphicsContext,
	texture: ^Image,
	texturePaths: []cstring,
) {
	textureCount := len(texturePaths)
	texture.format = .R8G8B8A8_SRGB
	createImage(
		graphicsContext,
		texture,
		{},
		.D2,
		u32(IMAGES_RESOLUTION.x),
		u32(IMAGES_RESOLUTION.y),
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
		texture.vkImage,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		{.COLOR},
		u32(textureCount),
	)
	endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)

	for path, index in texturePaths {
		width, height: i32
		pixels := img.load(path, &width, &height, nil, 4)
		defer img.image_free(pixels)
		if pixels == nil {
			log.log(.Error, "Failed to load texture!")
			panic("Failed to load texture!")
		}
		textureSize := int(width * height * 4)

		stagingBuffer: Buffer
		createBuffer(
			graphicsContext,
			textureSize,
			{.TRANSFER_SRC},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&stagingBuffer.buffer,
			&stagingBuffer.memory,
		)
		defer {
			vk.DestroyBuffer(device, stagingBuffer.buffer, nil)
			vk.FreeMemory(device, stagingBuffer.memory, nil)
		}

		data: rawptr
		vk.MapMemory(device, stagingBuffer.memory, 0, vk.DeviceSize(textureSize), {}, &data)
		mem.copy(data, pixels, textureSize)
		vk.UnmapMemory(device, stagingBuffer.memory)

		stagingImage: Image
		stagingImage.format = .R8G8B8A8_SRGB
		createImage(
			graphicsContext,
			&stagingImage,
			{},
			.D2,
			u32(width),
			u32(height),
			1,
			{._1},
			.OPTIMAL,
			{.TRANSFER_DST, .TRANSFER_SRC},
			{.DEVICE_LOCAL},
			.EXCLUSIVE,
			0,
			nil,
		)
		defer {
			vk.DestroyImage(device, stagingImage.vkImage, nil)
			vk.FreeMemory(device, stagingImage.memory, nil)
		}

		commandBuffer := beginSingleTimeCommands(graphicsContext, graphicsCommandPool)
		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			stagingImage.vkImage,
			.UNDEFINED,
			.TRANSFER_DST_OPTIMAL,
			{.COLOR},
			1,
		)

		copyBufferToImage(
			graphicsContext,
			commandBuffer,
			stagingBuffer.buffer,
			stagingImage.vkImage,
			u32(width),
			u32(height),
		)

		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			stagingImage.vkImage,
			.TRANSFER_DST_OPTIMAL,
			.TRANSFER_SRC_OPTIMAL,
			{.COLOR},
			1,
		)

		upscaleImage(
			commandBuffer,
			stagingImage.vkImage,
			texture.vkImage,
			{u32(width), u32(height), 0},
			{u32(IMAGES_RESOLUTION.x), u32(IMAGES_RESOLUTION.y), u32(index)},
		)
		endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)
	}

	commandBuffer = beginSingleTimeCommands(graphicsContext, graphicsCommandPool)
	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		texture.vkImage,
		.TRANSFER_DST_OPTIMAL,
		.SHADER_READ_ONLY_OPTIMAL,
		{.COLOR},
		u32(textureCount),
	)
	endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)

	texture.view = createImageView(
		graphicsContext,
		texture.vkImage,
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
		.INT_OPAQUE_WHITE,
	)
}

// MAKE SURE TO UPDATE THE RELEVENT DESCRIPTOR SET
@(private = "file")
addTextures :: proc(
	using graphicsContext: ^GraphicsContext,
	texture: ^Image,
	textureCount: ^u32,
	texturePaths: []cstring,
) {
	newTexturesCount := u32(len(texturePaths))
	newTexture: Image
	newTexture.format = texture.format
	createImage(
		graphicsContext,
		&newTexture,
		{},
		.D2,
		u32(IMAGES_RESOLUTION.x),
		u32(IMAGES_RESOLUTION.y),
		textureCount^ + newTexturesCount,
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
		texture.vkImage,
		.SHADER_READ_ONLY_OPTIMAL,
		.TRANSFER_SRC_OPTIMAL,
		{.COLOR},
		textureCount^,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		newTexture.vkImage,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		{.COLOR},
		textureCount^ + newTexturesCount,
	)

	vk.CopyImageToImage(
		device,
		&vk.CopyImageToImageInfo {
			sType = .COPY_IMAGE_TO_IMAGE_INFO,
			pNext = nil,
			flags = {},
			srcImage = texture.vkImage,
			srcImageLayout = .TRANSFER_SRC_OPTIMAL,
			dstImage = newTexture.vkImage,
			dstImageLayout = .TRANSFER_DST_OPTIMAL,
			regionCount = 1,
			pRegions = &vk.ImageCopy2 {
				sType = .IMAGE_COPY_2,
				pNext = nil,
				srcSubresource = vk.ImageSubresourceLayers {
					aspectMask = {.COLOR},
					mipLevel = 1,
					baseArrayLayer = 0,
					layerCount = 1,
				},
				srcOffset = vk.Offset3D{0, 0, 0},
				dstSubresource = vk.ImageSubresourceLayers {
					aspectMask = {.COLOR},
					mipLevel = 1,
					baseArrayLayer = 0,
					layerCount = 1,
				},
				dstOffset = vk.Offset3D{0, 0, 0},
				extent = vk.Extent3D {
					u32(IMAGES_RESOLUTION.x),
					u32(IMAGES_RESOLUTION.y),
					textureCount^,
				},
			},
		},
	)
	endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)

	vk.DestroyImageView(device, texture.view, nil)
	vk.DestroyImage(device, texture.vkImage, nil)
	vk.FreeMemory(device, texture.memory, nil)

	newTexture.sampler = texture.sampler
	texture^ = newTexture

	for path, index in texturePaths {
		width, height: i32
		pixels := img.load(path, &width, &height, nil, 4)
		defer img.image_free(pixels)
		if pixels == nil {
			log.log(.Error, "Failed to load texture!")
			panic("Failed to load texture!")
		}
		textureSize := int(width * height * 4)

		stagingBuffer: Buffer
		createBuffer(
			graphicsContext,
			textureSize,
			{.TRANSFER_SRC},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&stagingBuffer.buffer,
			&stagingBuffer.memory,
		)
		defer {
			vk.DestroyBuffer(device, stagingBuffer.buffer, nil)
			vk.FreeMemory(device, stagingBuffer.memory, nil)
		}

		data: rawptr
		vk.MapMemory(device, stagingBuffer.memory, 0, vk.DeviceSize(textureSize), {}, &data)
		mem.copy(data, pixels, textureSize)
		vk.UnmapMemory(device, stagingBuffer.memory)

		stagingImage: Image
		stagingImage.format = .R8G8B8A8_SRGB
		createImage(
			graphicsContext,
			&stagingImage,
			{},
			.D2,
			u32(width),
			u32(height),
			1,
			{._1},
			.OPTIMAL,
			{.TRANSFER_DST, .TRANSFER_SRC},
			{.DEVICE_LOCAL},
			.EXCLUSIVE,
			0,
			nil,
		)
		defer {
			vk.DestroyImage(device, stagingImage.vkImage, nil)
			vk.FreeMemory(device, stagingImage.memory, nil)
		}

		commandBuffer := beginSingleTimeCommands(graphicsContext, graphicsCommandPool)
		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			stagingImage.vkImage,
			.UNDEFINED,
			.TRANSFER_DST_OPTIMAL,
			{.COLOR},
			1,
		)

		copyBufferToImage(
			graphicsContext,
			commandBuffer,
			stagingBuffer.buffer,
			stagingImage.vkImage,
			u32(width),
			u32(height),
		)

		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			stagingImage.vkImage,
			.TRANSFER_DST_OPTIMAL,
			.TRANSFER_SRC_OPTIMAL,
			{.COLOR},
			1,
		)

		upscaleImage(
			commandBuffer,
			stagingImage.vkImage,
			texture.vkImage,
			{u32(width), u32(height), 0},
			{u32(IMAGES_RESOLUTION.x), u32(IMAGES_RESOLUTION.y), textureCount^ + u32(index)},
		)
		endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)
	}

	textureCount^ += newTexturesCount

	commandBuffer = beginSingleTimeCommands(graphicsContext, graphicsCommandPool)
	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		texture.vkImage,
		.TRANSFER_DST_OPTIMAL,
		.SHADER_READ_ONLY_OPTIMAL,
		{.COLOR},
		textureCount^,
	)
	endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)

	texture.view = createImageView(
		graphicsContext,
		texture.vkImage,
		.D2_ARRAY,
		texture.format,
		{.COLOR},
		textureCount^ + newTexturesCount,
	)
}

@(private = "file")
createShadowImage :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	scenes[sceneIndex].shadowImages.format = findSupportedDepthFormat(
		graphicsContext,
		{.D16_UNORM, .D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
		.OPTIMAL,
		{},
	)

	createImage(
		graphicsContext,
		&scenes[sceneIndex].shadowImages,
		{},
		.D2,
		u32(SHADOW_RESOLUTION.x),
		u32(SHADOW_RESOLUTION.y),
		u32(len(scenes[sceneIndex].pointLights)),
		{._1},
		.OPTIMAL,
		{.TRANSFER_DST, .SAMPLED},
		{.DEVICE_LOCAL},
		.EXCLUSIVE,
		0,
		nil,
	)

	commandBuffer := beginSingleTimeCommands(graphicsContext, graphicsCommandPool)
	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		scenes[sceneIndex].shadowImages.vkImage,
		.UNDEFINED,
		.SHADER_READ_ONLY_OPTIMAL,
		{.DEPTH},
		u32(len(scenes[sceneIndex].pointLights)),
	)
	endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)

	scenes[sceneIndex].shadowImages.view = createImageView(
		graphicsContext,
		scenes[sceneIndex].shadowImages.vkImage,
		.D2_ARRAY,
		scenes[sceneIndex].shadowImages.format,
		{.DEPTH},
		u32(len(scenes[sceneIndex].pointLights)),
	)

	scenes[sceneIndex].shadowImages.sampler = createSampler(
		graphicsContext,
		.LINEAR,
		.LINEAR,
		.CLAMP_TO_BORDER,
		false,
		1,
		.FLOAT_OPAQUE_BLACK,
	)
}

LoadSceneError :: enum {
	None,
	FailedToLoadSceneFile,
	FailedToParseJson,
	FailedToLoadModel,
	FailedToLoadTexture,
}

loadScene :: proc(
	using graphicsContext: ^GraphicsContext,
	sceneFile: string,
) -> (
	index: u32,
	err: LoadSceneError = .None,
) {
	parseJSON :: proc(sceneFile: string) -> (scene: Scene, err: LoadSceneError = .None) {
		data, ok := os.read_entire_file_from_filename(sceneFile)
		if !ok {
			log.logf(.Error, "Failed to load scene file: {}", sceneFile)
			err = .FailedToLoadSceneFile
			return
		}
		defer delete(data)

		jsonData, error := json.parse(data)
		if error != .None {
			log.logf(.Error, "Failed to parse json: {}", error)
			err = .FailedToParseJson
			return
		}
		defer json.destroy_value(jsonData)

		root := jsonData.(json.Object)

		scene.name = strings.clone_to_cstring(root["name"].(json.String))

		clearColour := root["clear_colour"].(json.Array)
		scene.clearColour = {
			i32(clearColour[0].(json.Float)),
			i32(clearColour[1].(json.Float)),
			i32(clearColour[2].(json.Float)),
			i32(clearColour[3].(json.Float)),
		}

		cameras := root["cameras"].(json.Array)
		scene.cameras = make([]Camera, len(cameras))
		for camera, i in cameras {
			camera := camera.(json.Object)
			eye := camera["eye"].(json.Array)
			center := camera["center"].(json.Array)
			up := camera["up"].(json.Array)
			scene.cameras[i] = {
				name     = strings.clone_to_cstring(camera["name"].(json.String)),
				eye      = Vec3 {
					f32(eye[0].(json.Float)),
					f32(eye[1].(json.Float)),
					f32(eye[2].(json.Float)),
				},
				center   = Vec3 {
					f32(center[0].(json.Float)),
					f32(center[1].(json.Float)),
					f32(center[2].(json.Float)),
				},
				up       = Vec3 {
					f32(up[0].(json.Float)),
					f32(up[1].(json.Float)),
					f32(up[2].(json.Float)),
				},
				distance = f32(camera["distance"].(json.Float)),
				fov      = f32(camera["fov"].(json.Float)),
				mode     = .PERSPECTIVE if camera["mode"].(json.Float) == 0 else .ORTHOGRAPHIC,
			}
		}

		lights := root["lights"].(json.Array)
		scene.pointLights = make([]PointLight, len(lights))
		for light, i in lights {
			light := light.(json.Object)
			position := light["position"].(json.Array)
			direction := light["direction"].(json.Array)
			colour := light["colour"].(json.Array)
			rotationAxis := light["rotation_axis"].(json.Array)
			scene.pointLights[i] = {
				name            = strings.clone_to_cstring(light["name"].(json.String)),
				position        = Vec3 {
					f32(position[0].(json.Float)),
					f32(position[1].(json.Float)),
					f32(position[2].(json.Float)),
				},
				direction       = Vec3 {
					f32(direction[0].(json.Float)),
					f32(direction[1].(json.Float)),
					f32(direction[2].(json.Float)),
				},
				colourIntensity = f32(
					light["intensity"].(json.Float),
				) * Vec3{f32(colour[0].(json.Float)), f32(colour[1].(json.Float)), f32(colour[2].(json.Float))},
				fov             = f32(light["fov"].(json.Float)),
				rotationAngle   = f32(light["rotation_angle"].(json.Float)),
				rotationAxis    = Vec3 {
					f32(rotationAxis[0].(json.Float)),
					f32(rotationAxis[1].(json.Float)),
					f32(rotationAxis[2].(json.Float)),
				},
			}
		}

		models := root["models"].(json.Array)
		scene.modelPaths = make([]cstring, len(models))
		for model, i in models {
			scene.modelPaths[i] = strings.clone_to_cstring(model.(json.String))
		}

		albedos := root["albedos"].(json.Array)
		scene.texturePaths = make([]cstring, len(albedos))
		for texture, i in albedos {
			scene.texturePaths[i] = strings.clone_to_cstring(texture.(json.String))
		}

		normals := root["normals"].(json.Array)
		scene.normalPaths = make([]cstring, len(normals))
		for normal, i in normals {
			scene.normalPaths[i] = strings.clone_to_cstring(normal.(json.String))
		}

		instances := root["instances"].(json.Array)
		scene.instances = make([]Instance, len(instances))
		for instance, i in instances {
			instance := instance.(json.Object)
			position := instance["position"].(json.Array)
			rotation := instance["rotation"].(json.Array)
			scale := instance["scale"].(json.Array)
			scene.instances[i] = {
				name      = strings.clone_to_cstring(instance["name"].(json.String)),
				modelID   = u32(instance["model"].(json.Float)),
				animID    = 0,
				textureID = f32(instance["albedo"].(json.Float)),
				normalID  = f32(instance["normal"].(json.Float)),
				position  = Vec3 {
					f32(position[0].(json.Float)),
					f32(position[1].(json.Float)),
					f32(position[2].(json.Float)),
				},
				rotation  = Vec3 {
					f32(rotation[0].(json.Float)),
					f32(rotation[1].(json.Float)),
					f32(rotation[2].(json.Float)),
				},
				scale     = Vec3 {
					f32(scale[0].(json.Float)),
					f32(scale[1].(json.Float)),
					f32(scale[2].(json.Float)),
				},
			}
		}
		return
	}

	loadSceneAssets :: proc(
		using graphicsContext: ^GraphicsContext,
		sceneIndex: u32,
	) -> (
		err: LoadSceneError = .None,
	) {
		loadModels(graphicsContext, sceneIndex, scenes[sceneIndex].modelPaths)

		createVertexBuffer(graphicsContext, sceneIndex)
		createIndexBuffer(graphicsContext, sceneIndex)

		loadTextures(graphicsContext, &scenes[sceneIndex].textures, scenes[sceneIndex].texturePaths)
		loadTextures(graphicsContext, &scenes[sceneIndex].normals, scenes[sceneIndex].normalPaths)

		for &instance in scenes[sceneIndex].instances {
			skeletonLength := len(scenes[sceneIndex].models[instance.modelID].skeleton)
			scenes[sceneIndex].boneCount += skeletonLength
			instance.positionKeys = make([]u32, skeletonLength)
			instance.rotationKeys = make([]u32, skeletonLength)
			instance.scaleKeys = make([]u32, skeletonLength)
			instance.animTimer = 0.0
		}
		scenes[sceneIndex].boneCount += 1

		createInstanceBuffer(graphicsContext, sceneIndex)
		createBoneBuffer(graphicsContext, sceneIndex)
		createLightBuffer(graphicsContext, sceneIndex)
		createShadowImage(graphicsContext, sceneIndex)
		return
	}

	index = u32(len(scenes))
	newScenes := make([]Scene, index + 1)
	for &scene, index in scenes {
		newScenes[index] = scene
	}
	delete(scenes)
	scenes = newScenes

	if scenes[index], err = parseJSON(sceneFile); err != .None {
		panic("Couldn't parse file")
	}

	if err = loadSceneAssets(graphicsContext, index); err != .None {
		panic("Load error")
	}
	return
}

setActiveScene :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	if res := vk.DeviceWaitIdle(device); res != .SUCCESS {
		panic("Failed to wait for device idle!")
	}

	activeScene = sceneIndex
	updateSceneDescriptorSets(graphicsContext, sceneIndex)
}

// ###################################################################
// #                        Shader Descriptors                       #
// ###################################################################


@(private = "file")
createGraphicsDescriptorSets :: proc(using graphicsContext: ^GraphicsContext) {
	// SHADOW
	{
		layoutBindings: []vk.DescriptorSetLayoutBinding = {
			{
				binding = 0,
				descriptorType = .STORAGE_BUFFER,
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
			   &pipelines[PipelineIndex.SHADOW].descriptorSetLayout,
		   ) !=
		   .SUCCESS {
			log.log(.Error, "Failed to create descriptor set layout!")
			panic("Failed to create descriptor set layout!")
		}

		poolSizes: []vk.DescriptorPoolSize = {{type = .STORAGE_BUFFER, descriptorCount = 3}}

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
			   &pipelines[PipelineIndex.SHADOW].descriptorPool,
		   ) !=
		   .SUCCESS {
			log.log(.Error, "Failed to create descriptor pool!")
			panic("Failed to create descriptor pool!")
		}

		layouts := make([]vk.DescriptorSetLayout, MAX_FRAMES_IN_FLIGHT)
		defer delete(layouts)

		for &layout in layouts {
			layout = pipelines[PipelineIndex.SHADOW].descriptorSetLayout
		}

		allocInfo: vk.DescriptorSetAllocateInfo = {
			sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
			pNext              = nil,
			descriptorPool     = pipelines[PipelineIndex.SHADOW].descriptorPool,
			descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
			pSetLayouts        = raw_data(layouts),
		}

		if vk.AllocateDescriptorSets(
			   device,
			   &allocInfo,
			   raw_data(pipelines[PipelineIndex.SHADOW].descriptorSets[:]),
		   ) !=
		   .SUCCESS {
			log.log(.Error, "Failed to allocate descriptor sets!")
			panic("Failed to allocate descriptor sets!")
		}
	}

	// MAIN
	{
		layoutBindings: []vk.DescriptorSetLayoutBinding = {
			{
				binding = 0,
				descriptorType = .UNIFORM_BUFFER,
				descriptorCount = 1,
				stageFlags = {.VERTEX, .FRAGMENT},
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
				descriptorType = .STORAGE_BUFFER,
				descriptorCount = 1,
				stageFlags = {.VERTEX, .FRAGMENT},
				pImmutableSamplers = nil,
			},
			{
				binding = 4,
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				stageFlags = {.FRAGMENT},
				pImmutableSamplers = nil,
			},
			{
				binding = 5,
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				stageFlags = {.FRAGMENT},
				pImmutableSamplers = nil,
			},
			{
				binding = 6,
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

		poolSizes: []vk.DescriptorPoolSize = {
			{type = .UNIFORM_BUFFER, descriptorCount = 1},
			{type = .STORAGE_BUFFER, descriptorCount = 3},
			{type = .COMBINED_IMAGE_SAMPLER, descriptorCount = 3},
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
	}
}

@(private = "file")
updateGraphicsDescriptorSets :: proc(using graphicsContext: ^GraphicsContext) {
	// MAIN
	{
		uniformBufferInfo: vk.DescriptorBufferInfo = {
			offset = 0,
			range  = size_of(UniformBuffer),
		}

		for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
			uniformBufferInfo.buffer = uniformBuffers[index].buffer

			descriptorWrite: vk.WriteDescriptorSet = {
				sType            = .WRITE_DESCRIPTOR_SET,
				pNext            = nil,
				dstSet           = pipelines[PipelineIndex.MAIN].descriptorSets[index],
				dstBinding       = 0,
				dstArrayElement  = 0,
				descriptorCount  = 1,
				descriptorType   = .UNIFORM_BUFFER,
				pImageInfo       = nil,
				pBufferInfo      = &uniformBufferInfo,
				pTexelBufferView = nil,
			}

			vk.UpdateDescriptorSets(device, 1, &descriptorWrite, 0, nil)
		}
	}
}

@(private = "file")
createComputeDescriptorSets :: proc(using graphicsContext: ^GraphicsContext) {
	// POST PROCESSING
	{
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
			{
				binding = 2,
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				stageFlags = {.COMPUTE},
				pImmutableSamplers = nil,
			},
			{
				binding = 3,
				descriptorType = .UNIFORM_BUFFER,
				descriptorCount = 1,
				stageFlags = {.COMPUTE},
				pImmutableSamplers = nil,
			},
			{
				binding = 4,
				descriptorType = .STORAGE_BUFFER,
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

		poolSizes: []vk.DescriptorPoolSize = {
			{type = .STORAGE_IMAGE, descriptorCount = 2},
			{type = .COMBINED_IMAGE_SAMPLER, descriptorCount = 1},
			{type = .UNIFORM_BUFFER, descriptorCount = 1},
			{type = .STORAGE_BUFFER, descriptorCount = 1},
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
			   &pipelines[PipelineIndex.POST].descriptorPool,
		   ) !=
		   .SUCCESS {
			log.log(.Error, "Failed to create descriptor pool!")
			panic("Failed to create descriptor pool!")
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

		sceneDepth: vk.DescriptorImageInfo = {
			sampler     = pipelines[PipelineIndex.MAIN].depth.sampler,
			imageView   = pipelines[PipelineIndex.MAIN].depth.view,
			imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		}

		for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
			descriptorWrite: vk.WriteDescriptorSet = {
				sType            = .WRITE_DESCRIPTOR_SET,
				pNext            = nil,
				dstSet           = pipelines[PipelineIndex.POST].descriptorSets[index],
				dstBinding       = 2,
				dstArrayElement  = 0,
				descriptorCount  = 1,
				descriptorType   = .COMBINED_IMAGE_SAMPLER,
				pImageInfo       = &sceneDepth,
				pBufferInfo      = nil,
				pTexelBufferView = nil,
			}

			vk.UpdateDescriptorSets(device, 1, &descriptorWrite, 0, nil)
		}
	}
}

@(private = "file")
updateComputeDescriptorSets :: proc(using graphicsContext: ^GraphicsContext) {
	// POST PROCESSING
	{
		inImage.format = .R8G8B8A8_UNORM
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
			{.TRANSFER_SRC, .TRANSFER_DST, .STORAGE},
			{.DEVICE_LOCAL},
			.EXCLUSIVE,
			0,
			nil,
		)

		inImage.view = createImageView(
			graphicsContext,
			inImage.vkImage,
			.D2,
			inImage.format,
			{.COLOR},
			1,
		)

		outImage.format = .R8G8B8A8_UNORM
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
			{.TRANSFER_SRC, .STORAGE},
			{.DEVICE_LOCAL},
			.EXCLUSIVE,
			0,
			nil,
		)

		outImage.view = createImageView(
			graphicsContext,
			outImage.vkImage,
			.D2,
			outImage.format,
			{.COLOR},
			1,
		)

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

		sceneDepth: vk.DescriptorImageInfo = {
			sampler     = pipelines[PipelineIndex.MAIN].depth.sampler,
			imageView   = pipelines[PipelineIndex.MAIN].depth.view,
			imageLayout = .SHADER_READ_ONLY_OPTIMAL,
		}

		uniformBufferInfo: vk.DescriptorBufferInfo = {
			offset = 0,
			range  = size_of(UniformBuffer),
		}

		for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
			uniformBufferInfo.buffer = uniformBuffers[index].buffer

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
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.POST].descriptorSets[index],
					dstBinding = 2,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .COMBINED_IMAGE_SAMPLER,
					pImageInfo = &sceneDepth,
					pBufferInfo = nil,
					pTexelBufferView = nil,
				},
				{
					sType = .WRITE_DESCRIPTOR_SET,
					pNext = nil,
					dstSet = pipelines[PipelineIndex.POST].descriptorSets[index],
					dstBinding = 3,
					dstArrayElement = 0,
					descriptorCount = 1,
					descriptorType = .UNIFORM_BUFFER,
					pImageInfo = nil,
					pBufferInfo = &uniformBufferInfo,
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

@(private = "file")
updateSceneDescriptorSets :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	instanceBufferInfo: vk.DescriptorBufferInfo = {
		offset = 0,
		range  = vk.DeviceSize(size_of(InstanceInfo) * len(scenes[sceneIndex].instances)),
	}

	boneBufferInfo: vk.DescriptorBufferInfo = {
		offset = 0,
		range  = vk.DeviceSize(size_of(Mat4) * scenes[sceneIndex].boneCount),
	}

	lightsBufferInfo: vk.DescriptorBufferInfo = {
		offset = 0,
		range  = vk.DeviceSize(size_of(LightData) * len(scenes[sceneIndex].pointLights)),
	}

	textureInfo: vk.DescriptorImageInfo = {
		sampler     = scenes[sceneIndex].textures.sampler,
		imageView   = scenes[sceneIndex].textures.view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}

	normalInfo: vk.DescriptorImageInfo = {
		sampler     = scenes[sceneIndex].normals.sampler,
		imageView   = scenes[sceneIndex].normals.view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}

	shadowInfo: vk.DescriptorImageInfo = {
		sampler     = scenes[sceneIndex].shadowImages.sampler,
		imageView   = scenes[sceneIndex].shadowImages.view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		instanceBufferInfo.buffer = scenes[sceneIndex].instanceBuffers[index].buffer
		boneBufferInfo.buffer = scenes[sceneIndex].boneBuffers[index].buffer
		lightsBufferInfo.buffer = scenes[sceneIndex].lightBuffers[index].buffer
		descriptorWrites: []vk.WriteDescriptorSet = {
			{
				sType = .WRITE_DESCRIPTOR_SET,
				pNext = nil,
				dstSet = pipelines[PipelineIndex.SHADOW].descriptorSets[index],
				dstBinding = 0,
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
				dstSet = pipelines[PipelineIndex.SHADOW].descriptorSets[index],
				dstBinding = 1,
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
				dstSet = pipelines[PipelineIndex.SHADOW].descriptorSets[index],
				dstBinding = 2,
				dstArrayElement = 0,
				descriptorCount = 1,
				descriptorType = .STORAGE_BUFFER,
				pImageInfo = nil,
				pBufferInfo = &lightsBufferInfo,
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
				descriptorType = .STORAGE_BUFFER,
				pImageInfo = nil,
				pBufferInfo = &lightsBufferInfo,
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
				pImageInfo = &textureInfo,
				pBufferInfo = nil,
				pTexelBufferView = nil,
			},
			{
				sType = .WRITE_DESCRIPTOR_SET,
				pNext = nil,
				dstSet = pipelines[PipelineIndex.MAIN].descriptorSets[index],
				dstBinding = 5,
				dstArrayElement = 0,
				descriptorCount = 1,
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				pImageInfo = &normalInfo,
				pBufferInfo = nil,
				pTexelBufferView = nil,
			},
			{
				sType = .WRITE_DESCRIPTOR_SET,
				pNext = nil,
				dstSet = pipelines[PipelineIndex.MAIN].descriptorSets[index],
				dstBinding = 6,
				dstArrayElement = 0,
				descriptorCount = 1,
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				pImageInfo = &shadowInfo,
				pBufferInfo = nil,
				pTexelBufferView = nil,
			},
			{
				sType = .WRITE_DESCRIPTOR_SET,
				pNext = nil,
				dstSet = pipelines[PipelineIndex.POST].descriptorSets[index],
				dstBinding = 4,
				dstArrayElement = 0,
				descriptorCount = 1,
				descriptorType = .STORAGE_BUFFER,
				pImageInfo = nil,
				pBufferInfo = &lightsBufferInfo,
				pTexelBufferView = nil,
			},
		}

		vk.UpdateDescriptorSets(
			device,
			u32(len(descriptorWrites)),
			raw_data(descriptorWrites),
			0,
			nil,
		)
	}
}

// ###################################################################
// #                         Frame Resources                         #
// ###################################################################


@(private = "file")
createSyncObjects :: proc(using graphicsContext: ^GraphicsContext) {
	inFlightFrames = make([]vk.Fence, MAX_FRAMES_IN_FLIGHT)
	rendersFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	computeFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	uiFinished = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)
	imagesAvailable = make([]vk.Semaphore, MAX_FRAMES_IN_FLIGHT)

	fenceInfo: vk.FenceCreateInfo = {
		sType = .FENCE_CREATE_INFO,
		pNext = nil,
		flags = {.SIGNALED},
	}

	semaphoreInfo: vk.SemaphoreCreateInfo = {
		sType = .SEMAPHORE_CREATE_INFO,
		pNext = nil,
		flags = {},
	}

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		result :=
			vk.CreateFence(device, &fenceInfo, nil, &inFlightFrames[index]) |
			vk.CreateSemaphore(device, &semaphoreInfo, nil, &rendersFinished[index]) |
			vk.CreateSemaphore(device, &semaphoreInfo, nil, &computeFinished[index]) |
			vk.CreateSemaphore(device, &semaphoreInfo, nil, &uiFinished[index]) |
			vk.CreateSemaphore(device, &semaphoreInfo, nil, &imagesAvailable[index])
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
	// SHADOW
	{
		pipelines[PipelineIndex.SHADOW].depth.format = findSupportedDepthFormat(
			graphicsContext,
			{.D16_UNORM, .D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
			.OPTIMAL,
			{.DEPTH_STENCIL_ATTACHMENT},
		)

		createImage(
			graphicsContext,
			&pipelines[PipelineIndex.SHADOW].depth,
			{},
			.D2,
			u32(SHADOW_RESOLUTION.x),
			u32(SHADOW_RESOLUTION.y),
			1,
			{._1},
			.OPTIMAL,
			{.DEPTH_STENCIL_ATTACHMENT, .TRANSFER_SRC},
			{.DEVICE_LOCAL},
			.EXCLUSIVE,
			0,
			nil,
		)

		pipelines[PipelineIndex.SHADOW].depth.view = createImageView(
			graphicsContext,
			pipelines[PipelineIndex.SHADOW].depth.vkImage,
			.D2,
			pipelines[PipelineIndex.SHADOW].depth.format,
			{.DEPTH},
			1,
		)

		attachment: vk.AttachmentDescription = {
			flags          = {},
			format         = pipelines[PipelineIndex.SHADOW].depth.format,
			samples        = {._1},
			loadOp         = .CLEAR,
			storeOp        = .STORE,
			stencilLoadOp  = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout  = .UNDEFINED,
			finalLayout    = .TRANSFER_SRC_OPTIMAL,
		}

		depthAttachmentRef: vk.AttachmentReference = {
			attachment = 0,
			layout     = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		}

		subpass: vk.SubpassDescription = {
			flags                   = {},
			pipelineBindPoint       = .GRAPHICS,
			inputAttachmentCount    = 0,
			pInputAttachments       = nil,
			colorAttachmentCount    = 0,
			pColorAttachments       = nil,
			pResolveAttachments     = nil,
			pDepthStencilAttachment = &depthAttachmentRef,
			preserveAttachmentCount = 0,
			pPreserveAttachments    = nil,
		}

		dependencies: []vk.SubpassDependency = {
			{
				srcSubpass = vk.SUBPASS_EXTERNAL,
				dstSubpass = 0,
				srcStageMask = {.FRAGMENT_SHADER},
				dstStageMask = {.EARLY_FRAGMENT_TESTS},
				srcAccessMask = {.SHADER_READ},
				dstAccessMask = {.DEPTH_STENCIL_ATTACHMENT_WRITE},
				dependencyFlags = {.BY_REGION},
			},
			{
				srcSubpass = 0,
				dstSubpass = vk.SUBPASS_EXTERNAL,
				srcStageMask = {.LATE_FRAGMENT_TESTS},
				dstStageMask = {.FRAGMENT_SHADER},
				srcAccessMask = {.DEPTH_STENCIL_ATTACHMENT_WRITE},
				dstAccessMask = {.SHADER_READ},
				dependencyFlags = {.BY_REGION},
			},
		}

		renderPassInfo: vk.RenderPassCreateInfo = {
			sType           = .RENDER_PASS_CREATE_INFO,
			pNext           = nil,
			flags           = {},
			attachmentCount = 1,
			pAttachments    = &attachment,
			subpassCount    = 1,
			pSubpasses      = &subpass,
			dependencyCount = u32(len(dependencies)),
			pDependencies   = raw_data(dependencies),
		}

		if vk.CreateRenderPass(
			   device,
			   &renderPassInfo,
			   nil,
			   &pipelines[PipelineIndex.SHADOW].renderPass,
		   ) !=
		   .SUCCESS {
			log.log(.Error, "Unable to create render pass!")
			panic("Unable to create render pass!")
		}
	}

	// MAIN
	{
		pipelines[PipelineIndex.MAIN].colour.format = .R8G8B8A8_UNORM

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
			pipelines[PipelineIndex.MAIN].colour.vkImage,
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
			{.DEPTH_STENCIL_ATTACHMENT, .SAMPLED},
			{.DEVICE_LOCAL},
			.EXCLUSIVE,
			0,
			nil,
		)

		pipelines[PipelineIndex.MAIN].depth.view = createImageView(
			graphicsContext,
			pipelines[PipelineIndex.MAIN].depth.vkImage,
			.D2,
			pipelines[PipelineIndex.MAIN].depth.format,
			{.DEPTH},
			1,
		)

		pipelines[PipelineIndex.MAIN].depth.sampler = createSampler(
			graphicsContext,
			.LINEAR,
			.LINEAR,
			.CLAMP_TO_EDGE,
			false,
			0.0,
			.INT_OPAQUE_WHITE,
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
				finalLayout = .TRANSFER_SRC_OPTIMAL,
			},
			{
				flags = {},
				format = pipelines[PipelineIndex.MAIN].depth.format,
				samples = {._1},
				loadOp = .CLEAR,
				storeOp = .STORE,
				stencilLoadOp = .DONT_CARE,
				stencilStoreOp = .DONT_CARE,
				initialLayout = .UNDEFINED,
				finalLayout = .SHADER_READ_ONLY_OPTIMAL,
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
			   &pipelines[PipelineIndex.MAIN].renderPass,
		   ) !=
		   .SUCCESS {
			log.log(.Error, "Unable to create render pass!")
			panic("Unable to create render pass!")
		}
	}
}

@(private = "file")
createFramebuffers :: proc(using graphicsContext: ^GraphicsContext) {
	// SHADOW
	{
		frameBufferInfo: vk.FramebufferCreateInfo = {
			sType           = .FRAMEBUFFER_CREATE_INFO,
			pNext           = nil,
			flags           = {},
			renderPass      = pipelines[PipelineIndex.SHADOW].renderPass,
			attachmentCount = 1,
			pAttachments    = &pipelines[PipelineIndex.SHADOW].depth.view,
			width           = u32(SHADOW_RESOLUTION.x),
			height          = u32(SHADOW_RESOLUTION.y),
			layers          = 1,
		}

		pipelines[PipelineIndex.SHADOW].frameBuffers = make(
			[]vk.Framebuffer,
			len(swapchainImageViews),
		)

		for index in 0 ..< len(swapchainImageViews) {
			if vk.CreateFramebuffer(
				   device,
				   &frameBufferInfo,
				   nil,
				   &pipelines[PipelineIndex.SHADOW].frameBuffers[index],
			   ) !=
			   .SUCCESS {
				log.log(.Error, "Failed to create frame buffer!")
				panic("Failed to create frame buffer!")
			}
		}
	}

	// MAIN
	{
		frameBufferInfo: vk.FramebufferCreateInfo = {
			sType           = .FRAMEBUFFER_CREATE_INFO,
			pNext           = nil,
			flags           = {},
			renderPass      = pipelines[PipelineIndex.MAIN].renderPass,
			attachmentCount = 2,
			pAttachments    = raw_data(
				[]vk.ImageView {
					pipelines[PipelineIndex.MAIN].colour.view,
					pipelines[PipelineIndex.MAIN].depth.view,
				},
			),
			width           = u32(RENDER_SIZE.x),
			height          = u32(RENDER_SIZE.y),
			layers          = 1,
		}

		pipelines[PipelineIndex.MAIN].frameBuffers = make(
			[]vk.Framebuffer,
			len(swapchainImageViews),
		)
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
createGraphicsPipelines :: proc(
	using graphicsContext: ^GraphicsContext,
	pipelineCache: vk.PipelineCache = 0,
) {
	pipelineCount: u32 : 2
	pipelineInfos := make([]vk.GraphicsPipelineCreateInfo, pipelineCount)
	defer delete(pipelineInfos)

	// SHADOW PIPELINE
	shadowPushConstant: vk.PushConstantRange = {
		stageFlags = {.VERTEX},
		offset     = 0,
		size       = size_of(u32),
	}

	shadowPipelineLayoutInfo: vk.PipelineLayoutCreateInfo = {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		pNext                  = nil,
		flags                  = {},
		setLayoutCount         = 1,
		pSetLayouts            = &pipelines[PipelineIndex.SHADOW].descriptorSetLayout,
		pushConstantRangeCount = 1,
		pPushConstantRanges    = &shadowPushConstant,
	}

	if vk.CreatePipelineLayout(
		   device,
		   &shadowPipelineLayoutInfo,
		   nil,
		   &pipelines[PipelineIndex.SHADOW].layout,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create pipeline layout!")
		panic("Failed to create pipeline layout!")
	}

	shadowShaderFiles := "./assets/shaders/light_vert.spv"

	shadowShaderStagesInfo: vk.PipelineShaderStageCreateInfo = {
		sType               = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		pNext               = nil,
		flags               = {},
		stage               = {.VERTEX},
		module              = createShaderModule(graphicsContext, shadowShaderFiles),
		pName               = "main",
		pSpecializationInfo = nil,
	}
	defer vk.DestroyShaderModule(device, shadowShaderStagesInfo.module, nil)

	pipelineInfos[0] = {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext               = nil,
		flags               = {},
		stageCount          = 1,
		pStages             = &shadowShaderStagesInfo,
		pVertexInputState   = &{
			sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			vertexBindingDescriptionCount = 1,
			pVertexBindingDescriptions = &vertexBindingDescription,
			vertexAttributeDescriptionCount = u32(len(vertexInputAttributeDescriptions)),
			pVertexAttributeDescriptions = raw_data(vertexInputAttributeDescriptions),
		},
		pInputAssemblyState = &{
			sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			topology = .TRIANGLE_LIST,
			primitiveRestartEnable = false,
		},
		pTessellationState  = nil,
		pViewportState      = &{
			sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			viewportCount = 1,
			pViewports = &vk.Viewport {
				x = 0,
				y = 0,
				width = SHADOW_RESOLUTION.x,
				height = SHADOW_RESOLUTION.y,
				minDepth = 0,
				maxDepth = 1,
			},
			scissorCount = 1,
			pScissors = &vk.Rect2D {
				offset = {0, 0},
				extent = {u32(SHADOW_RESOLUTION.x), u32(SHADOW_RESOLUTION.y)},
			},
		},
		pRasterizationState = &{
			sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			depthClampEnable = false,
			rasterizerDiscardEnable = false,
			polygonMode = .FILL,
			cullMode = {},
			frontFace = .CLOCKWISE,
			depthBiasEnable = true,
			depthBiasConstantFactor = DEPTH_BIAS_CONSTANT,
			depthBiasClamp = 0.0,
			depthBiasSlopeFactor = DEPTH_BIAS_SLOPE,
			lineWidth = 1.0,
		},
		pMultisampleState   = &{
			sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			rasterizationSamples = {._1},
			sampleShadingEnable = false,
			minSampleShading = 0.0,
			pSampleMask = nil,
			alphaToCoverageEnable = false,
			alphaToOneEnable = false,
		},
		pDepthStencilState  = &{
			sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			depthTestEnable = true,
			depthWriteEnable = true,
			depthCompareOp = .LESS_OR_EQUAL,
			depthBoundsTestEnable = false,
			stencilTestEnable = false,
			front = {},
			back = {
				failOp = .KEEP,
				passOp = .KEEP,
				depthFailOp = .KEEP,
				compareOp = .ALWAYS,
				compareMask = 0,
				writeMask = 0,
				reference = 0,
			},
			minDepthBounds = 0,
			maxDepthBounds = 1,
		},
		pColorBlendState    = &{
			sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			logicOpEnable = false,
			logicOp = .COPY,
			attachmentCount = 0,
			pAttachments = nil,
			blendConstants = {0, 0, 0, 0},
		},
		pDynamicState       = nil,
		layout              = pipelines[PipelineIndex.SHADOW].layout,
		renderPass          = pipelines[PipelineIndex.SHADOW].renderPass,
		subpass             = 0,
		basePipelineHandle  = {},
		basePipelineIndex   = 0,
	}

	// MAIN PIPELINE
	mainPipelineLayoutInfo: vk.PipelineLayoutCreateInfo = {
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
		   &mainPipelineLayoutInfo,
		   nil,
		   &pipelines[PipelineIndex.MAIN].layout,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create pipeline layout!")
		panic("Failed to create pipeline layout!")
	}

	mainShaderStages := [?]vk.ShaderStageFlag{.VERTEX, .FRAGMENT}
	mainShaderFiles := [?]string {
		"./assets/shaders/main_vert.spv",
		"./assets/shaders/main_frag.spv",
	}

	mainShaderStagesInfo := make([]vk.PipelineShaderStageCreateInfo, len(mainShaderFiles))
	for path, index in mainShaderFiles {
		mainShaderStagesInfo[index] = {
			sType               = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			pNext               = nil,
			flags               = {},
			stage               = {mainShaderStages[index]},
			module              = createShaderModule(graphicsContext, path),
			pName               = "main",
			pSpecializationInfo = nil,
		}
	}
	defer {
		for stage in mainShaderStagesInfo {
			vk.DestroyShaderModule(device, stage.module, nil)
		}
		delete(mainShaderStagesInfo)
	}

	pipelineInfos[1] = {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext               = nil,
		flags               = {},
		stageCount          = u32(len(mainShaderStagesInfo)),
		pStages             = raw_data(mainShaderStagesInfo),
		pVertexInputState   = &{
			sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			vertexBindingDescriptionCount = 1,
			pVertexBindingDescriptions = &vertexBindingDescription,
			vertexAttributeDescriptionCount = u32(len(vertexInputAttributeDescriptions)),
			pVertexAttributeDescriptions = raw_data(vertexInputAttributeDescriptions),
		},
		pInputAssemblyState = &{
			sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			topology = .TRIANGLE_LIST,
			primitiveRestartEnable = false,
		},
		pTessellationState  = nil,
		pViewportState      = &{
			sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			viewportCount = 1,
			pViewports = &vk.Viewport {
				x = 0,
				y = 0,
				width = RENDER_SIZE.x,
				height = RENDER_SIZE.y,
				minDepth = 0,
				maxDepth = 1,
			},
			scissorCount = 1,
			pScissors = &vk.Rect2D {
				offset = {0, 0},
				extent = {u32(RENDER_SIZE.x), u32(RENDER_SIZE.y)},
			},
		},
		pRasterizationState = &{
			sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			depthClampEnable = false,
			rasterizerDiscardEnable = false,
			polygonMode = .FILL,
			cullMode = {.BACK},
			frontFace = .CLOCKWISE,
			depthBiasEnable = false,
			depthBiasConstantFactor = 0.0,
			depthBiasClamp = 0.0,
			depthBiasSlopeFactor = 0.0,
			lineWidth = 1.0,
		},
		pMultisampleState   = &{
			sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			rasterizationSamples = {._1},
			sampleShadingEnable = false,
			minSampleShading = 1.0,
			pSampleMask = nil,
			alphaToCoverageEnable = false,
			alphaToOneEnable = false,
		},
		pDepthStencilState  = &{
			sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			depthTestEnable = true,
			depthWriteEnable = true,
			depthCompareOp = .LESS,
			depthBoundsTestEnable = false,
			stencilTestEnable = false,
			front = {},
			back = {},
			minDepthBounds = 0,
			maxDepthBounds = 1,
		},
		pColorBlendState    = &{
			sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			pNext = nil,
			flags = {},
			logicOpEnable = false,
			logicOp = .COPY,
			attachmentCount = 1,
			pAttachments = &vk.PipelineColorBlendAttachmentState {
				blendEnable = false,
				srcColorBlendFactor = .ONE,
				dstColorBlendFactor = .ZERO,
				colorBlendOp = .ADD,
				srcAlphaBlendFactor = .ONE,
				dstAlphaBlendFactor = .ZERO,
				alphaBlendOp = .ADD,
				colorWriteMask = {.R, .G, .B, .A},
			},
			blendConstants = {0, 0, 0, 0},
		},
		pDynamicState       = nil,
		layout              = pipelines[PipelineIndex.MAIN].layout,
		renderPass          = pipelines[PipelineIndex.MAIN].renderPass,
		subpass             = 0,
		basePipelineHandle  = {},
		basePipelineIndex   = 0,
	}

	vkPipelines := make([]vk.Pipeline, pipelineCount)
	defer delete(vkPipelines)
	if vk.CreateGraphicsPipelines(
		   device,
		   pipelineCache,
		   pipelineCount,
		   raw_data(pipelineInfos),
		   nil,
		   raw_data(vkPipelines),
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create pipeline!")
		panic("Failed to create pipeline!")
	}

	for pipeline, i in vkPipelines {
		pipelines[i].pipeline = pipeline
	}
}

@(private = "file")
createComputePipelines :: proc(
	using graphicsContext: ^GraphicsContext,
	pipelineCache: vk.PipelineCache = 0,
) {
	// POST PROCESSING
	postPipelineLayoutInfo: vk.PipelineLayoutCreateInfo = {
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
		   &postPipelineLayoutInfo,
		   nil,
		   &pipelines[PipelineIndex.POST].layout,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create postprocess pipeline layout!")
		panic("Failed to create postprocess pipeline layout!")
	}

	postShaderStageInfo: vk.PipelineShaderStageCreateInfo = {
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
	defer vk.DestroyShaderModule(device, postShaderStageInfo.module, nil)

	pipelineInfo: vk.ComputePipelineCreateInfo = {
		sType              = .COMPUTE_PIPELINE_CREATE_INFO,
		pNext              = nil,
		flags              = {},
		stage              = postShaderStageInfo,
		layout             = pipelines[PipelineIndex.POST].layout,
		basePipelineHandle = {},
		basePipelineIndex  = 0,
	}

	if vk.CreateComputePipelines(
		   device,
		   pipelineCache,
		   1,
		   &pipelineInfo,
		   nil,
		   &pipelines[PipelineIndex.POST].pipeline,
	   ) !=
	   .SUCCESS {
		log.log(.Error, "Failed to create postprocess pipeline!")
		panic("Failed to create postprocess pipeline!")
	}
}


// ###################################################################
// #                              Imgui                              #
// ###################################################################


@(private = "file")
initImgui :: proc(using graphicsContext: ^GraphicsContext) {
	imgui.CHECKVERSION()

	poolSizes: []vk.DescriptorPoolSize = {
		{.SAMPLER, 1000},
		{.COMBINED_IMAGE_SAMPLER, 1000},
		{.SAMPLED_IMAGE, 1000},
		{.STORAGE_IMAGE, 1000},
		{.UNIFORM_TEXEL_BUFFER, 1000},
		{.STORAGE_TEXEL_BUFFER, 1000},
		{.UNIFORM_BUFFER, 1000},
		{.STORAGE_BUFFER, 1000},
		{.UNIFORM_BUFFER_DYNAMIC, 1000},
		{.STORAGE_BUFFER_DYNAMIC, 1000},
		{.INPUT_ATTACHMENT, 1000},
	}

	descriptorPoolCreateInfo: vk.DescriptorPoolCreateInfo = {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		pNext         = nil,
		flags         = {.FREE_DESCRIPTOR_SET},
		maxSets       = 1000,
		poolSizeCount = u32(len(poolSizes)),
		pPoolSizes    = raw_data(poolSizes),
	}

	if vk.CreateDescriptorPool(
		   device,
		   &descriptorPoolCreateInfo,
		   nil,
		   &imguiData.descriptorPool,
	   ) !=
	   .SUCCESS {
		log.log(.Fatal, "Failed to create imgui descriptor pool!")
		panic("Failed to create imgui descriptor pool!")
	}
}

@(private = "file")
updateImgui :: proc(using graphicsContext: ^GraphicsContext) {
	ImFDCreateImage: ImFD.CreateTexture : proc "system" (
		data: [^]c.uint8_t,
		width, height: c.int,
		format: c.char,
	) -> rawptr {
		context = runtime.default_context()
		using graphicsContext := engineState.graphicsContext

		imageData: ImFDImageData
		imageData.format = .B8G8R8A8_SRGB if format == 0 else .R8G8B8A8_SRGB
		createImage(
			graphicsContext,
			&imageData.image,
			{},
			.D2,
			u32(width),
			u32(height),
			1,
			{._1},
			.OPTIMAL,
			{.TRANSFER_DST, .SAMPLED},
			{.DEVICE_LOCAL},
			.EXCLUSIVE,
			0,
			nil,
		)

		imageData.view = createImageView(
			graphicsContext,
			imageData.vkImage,
			.D2,
			imageData.format,
			{.COLOR},
			1,
		)

		imageData.sampler = createSampler(
			graphicsContext,
			.LINEAR,
			.LINEAR,
			.REPEAT,
			false,
			1,
			.INT_OPAQUE_WHITE,
		)

		imageData.descriptorSet = implVulkan.AddTexture(
			imageData.image.sampler,
			imageData.image.view,
			.SHADER_READ_ONLY_OPTIMAL,
		)

		textureSize := int(width * height * 4)
		stagingBuffer: Buffer
		createBuffer(
			graphicsContext,
			textureSize,
			{.TRANSFER_SRC},
			{.HOST_VISIBLE, .HOST_COHERENT},
			&stagingBuffer.buffer,
			&stagingBuffer.memory,
		)
		defer {
			vk.DestroyBuffer(device, stagingBuffer.buffer, nil)
			vk.FreeMemory(device, stagingBuffer.memory, nil)
		}

		bufferData: rawptr
		vk.MapMemory(device, stagingBuffer.memory, 0, vk.DeviceSize(textureSize), {}, &bufferData)
		mem.copy(bufferData, data, textureSize)
		vk.UnmapMemory(device, stagingBuffer.memory)

		commandBuffer := beginSingleTimeCommands(graphicsContext, graphicsCommandPool)
		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			imageData.image.vkImage,
			.UNDEFINED,
			.TRANSFER_DST_OPTIMAL,
			{.COLOR},
			1,
		)

		copyBufferToImage(
			graphicsContext,
			commandBuffer,
			stagingBuffer.buffer,
			imageData.image.vkImage,
			u32(width),
			u32(height),
		)

		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			imageData.image.vkImage,
			.TRANSFER_DST_OPTIMAL,
			.SHADER_READ_ONLY_OPTIMAL,
			{.COLOR},
			1,
		)
		endSingleTimeCommands(graphicsContext, commandBuffer, graphicsCommandPool)

		append(&imguiData.imfdImages, imageData)

		return (rawptr)((uintptr)(imageData.descriptorSet))
	}

	ImFDDeleteImage: ImFD.DeleteTexture : proc "system" (descriptorPtr: rawptr) {}

	imguiData.uiContext = imgui.CreateContext()
	io := imgui.GetIO()
	imgui.StyleColorsDark()

	implVulkan.LoadFunctions(
		proc "c" (function_name: cstring, user_data: rawptr) -> vk.ProcVoidFunction {
			return vk.GetInstanceProcAddr((vk.Instance)(user_data), function_name)
		},
		instance,
	)

	if !implGLFW.InitForVulkan(window, true) {
		log.log(.Fatal, "Failed to initialize imgui for vulkan, quitting application.")
		return
	}

	// RenderPass
	{
		imguiData.colour.format = .R8G8B8A8_UNORM

		createImage(
			graphicsContext,
			&imguiData.colour,
			{},
			.D2,
			u32(swapchainExtent.width),
			u32(swapchainExtent.height),
			1,
			{._1},
			.OPTIMAL,
			{.COLOR_ATTACHMENT, .TRANSFER_SRC, .TRANSFER_DST},
			{.DEVICE_LOCAL},
			.EXCLUSIVE,
			0,
			nil,
		)

		imguiData.colour.view = createImageView(
			graphicsContext,
			imguiData.colour.vkImage,
			.D2,
			imguiData.colour.format,
			{.COLOR},
			1,
		)

		attachment: vk.AttachmentDescription = {
			flags          = {},
			format         = imguiData.colour.format,
			samples        = {._1},
			loadOp         = .LOAD,
			storeOp        = .STORE,
			stencilLoadOp  = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout  = .TRANSFER_DST_OPTIMAL,
			finalLayout    = .TRANSFER_SRC_OPTIMAL,
		}

		colourAttachmentRef: vk.AttachmentReference = {
			attachment = 0,
			layout     = .COLOR_ATTACHMENT_OPTIMAL,
		}

		subpass: vk.SubpassDescription = {
			flags                   = {},
			pipelineBindPoint       = .GRAPHICS,
			inputAttachmentCount    = 0,
			pInputAttachments       = nil,
			colorAttachmentCount    = 1,
			pColorAttachments       = &colourAttachmentRef,
			pResolveAttachments     = nil,
			pDepthStencilAttachment = nil,
			preserveAttachmentCount = 0,
			pPreserveAttachments    = nil,
		}

		renderPassInfo: vk.RenderPassCreateInfo = {
			sType           = .RENDER_PASS_CREATE_INFO,
			pNext           = nil,
			flags           = {},
			attachmentCount = 1,
			pAttachments    = &attachment,
			subpassCount    = 1,
			pSubpasses      = &subpass,
			dependencyCount = 0,
			pDependencies   = nil,
		}

		if vk.CreateRenderPass(device, &renderPassInfo, nil, &imguiData.renderPass) != .SUCCESS {
			log.log(.Error, "Unable to create render pass!")
			panic("Unable to create render pass!")
		}
	}

	// FrameBuffer
	{
		frameBufferInfo: vk.FramebufferCreateInfo = {
			sType           = .FRAMEBUFFER_CREATE_INFO,
			pNext           = nil,
			flags           = {},
			renderPass      = imguiData.renderPass,
			attachmentCount = 1,
			pAttachments    = &imguiData.colour.view,
			width           = u32(swapchainExtent.width),
			height          = u32(swapchainExtent.height),
			layers          = 1,
		}

		imguiData.frameBuffers = make([]vk.Framebuffer, len(swapchainImageViews))
		for index in 0 ..< len(swapchainImageViews) {
			if vk.CreateFramebuffer(
				   device,
				   &frameBufferInfo,
				   nil,
				   &imguiData.frameBuffers[index],
			   ) !=
			   .SUCCESS {
				log.log(.Error, "Failed to create frame buffer!")
				panic("Failed to create frame buffer!")
			}
		}
	}

	implInitInfo: implVulkan.InitInfo = {
		Instance                    = instance,
		PhysicalDevice              = physicalDevice,
		Device                      = device,
		QueueFamily                 = queueFamilies.graphicsFamily,
		Queue                       = graphicsQueue,
		DescriptorPool              = imguiData.descriptorPool,
		RenderPass                  = imguiData.renderPass,
		MinImageCount               = 2,
		ImageCount                  = 2,
		MSAASamples                 = ._1,

		// (Optional)
		PipelineCache               = {},
		Subpass                     = 0,
		DescriptorPoolSize          = 0,

		// (Optional) Dynamic Rendering
		// Need to explicitly enable VK_KHR_dynamic_rendering extension to use this, even for Vulkan 1.3.
		UseDynamicRendering         = false,
		// NOTE: Odin-imgui: this field if #ifdef'd out in the Dear ImGui side if the struct is not defined.
		// Keeping the field is a pretty safe bet, but make sure to check this if you have issues!
		PipelineRenderingCreateInfo = {},

		// (Optional) Allocation, Debugging
		Allocator                   = nil,
		CheckVkResultFn             = imguiCheckVkResult,
		MinAllocationSize           = 1024 * 1024, // Minimum allocation size. Set to 1024*1024 to satisfy zealous best practices validation layer and waste a little memory.
	}

	if !implVulkan.Init(&implInitInfo) {
		log.log(.Fatal, "Failed to init vulkan impl.")
		panic("Failed to init vulkan impl.")
	}

	ImFD.Init(ImFDCreateImage, ImFDDeleteImage)
	imguiData.imfdImages = make([dynamic]ImFDImageData)
}


// ###################################################################
// #                           Render Loop                           #
// ###################################################################


@(private = "file")
updateLightBuffer :: proc(using graphicsContext: ^GraphicsContext, delta: f32) {
	lightData := make([]LightData, len(scenes[activeScene].pointLights))
	defer delete(lightData)
	for &light, i in scenes[activeScene].pointLights {
		direction: Vec3
		lookAtVector: Vec3

		if light.rotationAxis != {0, 0, 0} {
			light.position =
				rotation3(f32(radians(light.rotationAngle * delta)), light.rotationAxis) *
				light.position
		}

		direction = normalize(Vec3{0, 0, 0} - light.position)
		lookAtVector = Vec3{0, 0, 0}
		up: Vec3
		dot := dot(direction, Vec3{0, 1, 0})
		if abs(dot) < 0.0001 {
			up = cross(direction, Vec3{0, 1, 0})
		} else {
			up = cross(direction, Vec3{0, 0, 1})
		}
		lightData[i] = {
			mvp             = perspective(
				radians(light.fov),
				1,
				0.01,
				100,
			) * lookAt(light.position, lookAtVector, up),
			position        = Vec4{light.position.x, light.position.y, light.position.z, 1},
			colourIntensity = Vec4 {
				light.colourIntensity.x,
				light.colourIntensity.y,
				light.colourIntensity.z,
				0,
			},
		}
	}
	mem.copy(
		scenes[activeScene].lightBuffers[currentFrame].mapped,
		raw_data(lightData),
		size_of(LightData) * len(scenes[activeScene].pointLights),
	)
}

@(private = "file")
updateUniformBuffer :: proc(using graphicsContext: ^GraphicsContext, camera: Camera) {
	view := lookAt(camera.eye, camera.center, camera.up)
	projection: Mat4
	if camera.mode == .PERSPECTIVE {
		projection = perspective(
			radians(camera.fov),
			f32(swapchainExtent.width) / f32(swapchainExtent.height),
			0.1,
			100,
		)
	} else if camera.mode == .ORTHOGRAPHIC {
		projection = orthographic(
			radians(camera.fov),
			f32(swapchainExtent.width) / f32(swapchainExtent.height),
			0.1,
			100,
		)
	} else {
		log.log(.Error, "Undefined camera mode!")
		panic("Undefined camera mode!")
	}
	viewProjection: UniformBuffer = {
		view           = view,
		projection     = projection,
		viewProjection = projection * view,
		lightCount     = u32(len(scenes[activeScene].pointLights)),
	}
	mem.copy(uniformBuffers[currentFrame].mapped, &viewProjection, size_of(UniformBuffer))
}

@(private = "file")
updateInstanceBuffer :: proc(using graphicsContext: ^GraphicsContext, delta: f32) {
	finalBoneTransforms := make([]Mat4, scenes[activeScene].boneCount)
	instanceData := make([]InstanceInfo, len(scenes[activeScene].instances))
	defer delete(finalBoneTransforms)
	defer delete(instanceData)
	finalBoneTransforms[0] = IMat4
	boneOffset: u32 = 1
	for &instance, instanceIndex in scenes[activeScene].instances {
		instanceData[instanceIndex] = {
			model                = translate(
				instance.position,
			) * quatToRotation(quatFromX(radians(instance.rotation.x)) * quatFromY(radians(instance.rotation.y)) * quatFromZ(radians(instance.rotation.x))) * scale(instance.scale),
			boneOffset           = boneOffset,
			textureSamplerOffset = f32(instance.textureID),
			normalsSamplerOffset = f32(instance.normalID),
		}

		model := &scenes[activeScene].models[instance.modelID]

		if len(model^.skeleton) == 0 {
			instanceData[instanceIndex].boneOffset = 0
			continue
		}

		skeleton := &model^.skeleton

		localBoneTransforms := make([]Mat4, len(skeleton))
		defer delete(localBoneTransforms)

		for index in 0 ..< len(skeleton) {
			localBoneTransforms[index] = IMat4
		}

		if len(model^.animations) != 0 {
			animation := model^.animations[instance.animID]
			instance.animTimer += f64(delta)
			instance.animTimer /= animation.duration
			instance.animTimer =
				(instance.animTimer - floor(instance.animTimer)) * animation.duration
			for &node, nodeIndex in animation.nodes {
				// a *= b == a = a * b
				// therefore I *= T *= R *= S == aT = I * T * R * S
				if node.numKeyPositions == 1 {
					localBoneTransforms[node.bone] *= translate(node.keyPositions[0].value)
				} else if node.numKeyPositions != 0 {
					id := instance.positionKeys[nodeIndex]
					for true {
						if node.keyPositions[id].time <= instance.animTimer &&
						   instance.animTimer <= node.keyPositions[id + 1].time {
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
						(instance.animTimer -
							node.keyPositions[instance.positionKeys[nodeIndex]].time) /
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
						if node.keyRotations[id].time <= instance.animTimer &&
						   instance.animTimer <= node.keyRotations[id + 1].time {
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
						(instance.animTimer -
							node.keyRotations[instance.rotationKeys[nodeIndex]].time) /
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
						if node.keyScales[id].time <= instance.animTimer &&
						   instance.animTimer <= node.keyScales[id + 1].time {
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
						(instance.animTimer - node.keyScales[instance.scaleKeys[nodeIndex]].time) /
						(node.keyScales[instance.scaleKeys[nodeIndex] + 1].time -
								node.keyScales[instance.scaleKeys[nodeIndex]].time)
					value :=
						f32(timeDiff) * valueDiff +
						node.keyScales[instance.scaleKeys[nodeIndex]].value
					localBoneTransforms[node.bone] *= scale(value)
				}
			}
		}

		finalBoneTransforms[boneOffset] = localBoneTransforms[0]
		if localBoneTransforms[0] != IMat4 {
			finalBoneTransforms[boneOffset] *= skeleton[0].inverseBind
		}
		for boneIndex in 1 ..< u32(len(skeleton)) {
			parentIndex := skeleton[boneIndex].parentIndex
			localBoneTransforms[boneIndex] =
				localBoneTransforms[parentIndex] * localBoneTransforms[boneIndex]
			finalBoneTransforms[boneOffset + boneIndex] = localBoneTransforms[boneIndex]
			if localBoneTransforms[boneIndex] != IMat4 {
				finalBoneTransforms[boneOffset + boneIndex] *= skeleton[boneIndex].inverseBind
			}
		}
		boneOffset += u32(len(skeleton))
	}

	mem.copy(
		scenes[activeScene].boneBuffers[currentFrame].mapped,
		raw_data(finalBoneTransforms),
		scenes[activeScene].boneCount * size_of(Mat4),
	)
	mem.copy(
		scenes[activeScene].instanceBuffers[currentFrame].mapped,
		raw_data(instanceData),
		len(scenes[activeScene].instances) * size_of(InstanceInfo),
	)
}

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

	// SHADOW
	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		scenes[activeScene].shadowImages.vkImage,
		.SHADER_READ_ONLY_OPTIMAL,
		.TRANSFER_DST_OPTIMAL,
		{.DEPTH},
		u32(len(scenes[activeScene].pointLights)),
	)

	for index: u32 = 0; index < u32(len(scenes[activeScene].pointLights)); index += 1 {
		renderPassInfo: vk.RenderPassBeginInfo = {
			sType = .RENDER_PASS_BEGIN_INFO,
			pNext = nil,
			renderPass = pipelines[PipelineIndex.SHADOW].renderPass,
			framebuffer = pipelines[PipelineIndex.SHADOW].frameBuffers[imageIndex],
			renderArea = vk.Rect2D {
				offset = {0, 0},
				extent = {u32(SHADOW_RESOLUTION.x), u32(SHADOW_RESOLUTION.y)},
			},
			clearValueCount = 1,
			pClearValues = &vk.ClearValue {
				depthStencil = vk.ClearDepthStencilValue{depth = 1, stencil = 0},
			},
		}
		vk.CmdBeginRenderPass(commandBuffer, &renderPassInfo, .INLINE)

		vk.CmdBindPipeline(commandBuffer, .GRAPHICS, pipelines[PipelineIndex.SHADOW].pipeline)
		vk.CmdBindDescriptorSets(
			commandBuffer,
			.GRAPHICS,
			pipelines[PipelineIndex.SHADOW].layout,
			0,
			1,
			&pipelines[PipelineIndex.SHADOW].descriptorSets[currentFrame],
			0,
			nil,
		)

		vk.CmdPushConstants(
			commandBuffer,
			pipelines[PipelineIndex.SHADOW].layout,
			{.VERTEX},
			0,
			4,
			&index,
		)

		vk.CmdBindVertexBuffers(
			commandBuffer,
			0,
			1,
			&scenes[activeScene].vertexBuffer.buffer,
			raw_data([]vk.DeviceSize{0}),
		)

		vk.CmdBindIndexBuffer(commandBuffer, scenes[activeScene].indexBuffer.buffer, 0, .UINT32)

		for &inst, j in scenes[activeScene].instances {
			vk.CmdDrawIndexed(
				commandBuffer,
				scenes[activeScene].models[inst.modelID].indexCount,
				1,
				scenes[activeScene].models[inst.modelID].indexOffset,
				i32(scenes[activeScene].models[inst.modelID].vertexOffset),
				u32(j),
			)
		}

		vk.CmdEndRenderPass(commandBuffer)

		vk.CmdCopyImage(
			commandBuffer,
			pipelines[PipelineIndex.SHADOW].depth.vkImage,
			.TRANSFER_SRC_OPTIMAL,
			scenes[activeScene].shadowImages.vkImage,
			.TRANSFER_DST_OPTIMAL,
			1,
			&vk.ImageCopy {
				srcSubresource = vk.ImageSubresourceLayers {
					aspectMask = {.DEPTH},
					mipLevel = 0,
					baseArrayLayer = 0,
					layerCount = 1,
				},
				srcOffset = {0, 0, 0},
				dstSubresource = vk.ImageSubresourceLayers {
					aspectMask = {.DEPTH},
					mipLevel = 0,
					baseArrayLayer = index,
					layerCount = 1,
				},
				dstOffset = {0, 0, 0},
				extent = vk.Extent3D {
					width = u32(SHADOW_RESOLUTION.x),
					height = u32(SHADOW_RESOLUTION.y),
					depth = 1,
				},
			},
		)
	}

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		scenes[activeScene].shadowImages.vkImage,
		.TRANSFER_DST_OPTIMAL,
		.SHADER_READ_ONLY_OPTIMAL,
		{.DEPTH},
		u32(len(scenes[activeScene].pointLights)),
	)

	// MAIN
	{
		renderPassInfo: vk.RenderPassBeginInfo = {
			sType = .RENDER_PASS_BEGIN_INFO,
			pNext = nil,
			renderPass = pipelines[PipelineIndex.MAIN].renderPass,
			framebuffer = pipelines[PipelineIndex.MAIN].frameBuffers[imageIndex],
			renderArea = vk.Rect2D {
				offset = {0, 0},
				extent = {u32(RENDER_SIZE.x), u32(RENDER_SIZE.y)},
			},
			clearValueCount = 2,
			pClearValues = raw_data(
				[]vk.ClearValue {
					{
						color = vk.ClearColorValue {
							float32 = Vec4 {
								f32(scenes[activeScene].clearColour.x) / 255.0,
								f32(scenes[activeScene].clearColour.y) / 255.0,
								f32(scenes[activeScene].clearColour.z) / 255.0,
								f32(scenes[activeScene].clearColour.w) / 255.0,
							},
						},
					},
					{depthStencil = vk.ClearDepthStencilValue{depth = 1, stencil = 0}},
				},
			),
		}
		vk.CmdBeginRenderPass(commandBuffer, &renderPassInfo, .INLINE)

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
			&scenes[activeScene].vertexBuffer.buffer,
			raw_data([]vk.DeviceSize{0}),
		)
		vk.CmdBindIndexBuffer(commandBuffer, scenes[activeScene].indexBuffer.buffer, 0, .UINT32)
		for &inst, index in scenes[activeScene].instances {
			vk.CmdDrawIndexed(
				commandBuffer,
				scenes[activeScene].models[inst.modelID].indexCount,
				1,
				scenes[activeScene].models[inst.modelID].indexOffset,
				i32(scenes[activeScene].models[inst.modelID].vertexOffset),
				u32(index),
			)
		}
		vk.CmdEndRenderPass(commandBuffer)
	}

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
		inImage.vkImage,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		{.COLOR},
		1,
	)

	upscaleImage(
		commandBuffer,
		pipelines[PipelineIndex.MAIN].colour.vkImage,
		inImage.vkImage,
		vk.Extent3D{u32(RENDER_SIZE.x), u32(RENDER_SIZE.y), 0},
		vk.Extent3D{swapchainExtent.width, swapchainExtent.height, 0},
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		inImage.vkImage,
		.TRANSFER_DST_OPTIMAL,
		.GENERAL,
		{.COLOR},
		1,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		outImage.vkImage,
		.UNDEFINED,
		.GENERAL,
		{.COLOR},
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
		outImage.vkImage,
		.UNDEFINED,
		.TRANSFER_SRC_OPTIMAL,
		{.COLOR},
		1,
	)

	when UI_ENABLED {
		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			imguiData.colour.vkImage,
			.UNDEFINED,
			.TRANSFER_DST_OPTIMAL,
			{.COLOR},
			1,
		)

		copyImage(
			commandBuffer,
			vk.Extent3D{swapchainExtent.width, swapchainExtent.height, 1},
			outImage.vkImage,
			imguiData.colour.vkImage,
			.TRANSFER_SRC_OPTIMAL,
			.TRANSFER_DST_OPTIMAL,
		)
	} else {
		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			swapchainImages[imageIndex],
			.UNDEFINED,
			.TRANSFER_DST_OPTIMAL,
			{.COLOR},
			1,
		)

		vk.CmdBlitImage(
			commandBuffer,
			outImage.image,
			.TRANSFER_SRC_OPTIMAL,
			swapchainImages[imageIndex],
			.TRANSFER_DST_OPTIMAL,
			1,
			&vk.ImageBlit {
				srcSubresource = {
					aspectMask = {.COLOR},
					mipLevel = 0,
					baseArrayLayer = 0,
					layerCount = 1,
				},
				srcOffsets = {
					{x = 0, y = 0, z = 0},
					{x = i32(swapchainExtent.width), y = i32(swapchainExtent.height), z = 1},
				},
				dstSubresource = {
					aspectMask = {.COLOR},
					mipLevel = 0,
					baseArrayLayer = 0,
					layerCount = 1,
				},
				dstOffsets = {
					{x = 0, y = 0, z = 0},
					{x = i32(swapchainExtent.width), y = i32(swapchainExtent.height), z = 1},
				},
			},
			.NEAREST,
		)

		transitionImageLayout(
			graphicsContext,
			commandBuffer,
			swapchainImages[imageIndex],
			.TRANSFER_DST_OPTIMAL,
			.PRESENT_SRC_KHR,
			{.COLOR},
			1,
		)
	}

	if vk.EndCommandBuffer(commandBuffer) != .SUCCESS {
		log.log(.Error, "Failed to record compute command buffer!")
		panic("Failed to record compute command buffer!")
	}
}

@(private = "file")
recordUIBuffer :: proc(
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
		renderPass = imguiData.renderPass,
		framebuffer = imguiData.frameBuffers[imageIndex],
		renderArea = vk.Rect2D{offset = {0, 0}, extent = swapchainExtent},
		clearValueCount = 0,
		pClearValues = nil,
	}
	vk.CmdBeginRenderPass(commandBuffer, &renderPassInfo, .INLINE)

	imgui.Render()
	implVulkan.RenderDrawData(imgui.GetDrawData(), commandBuffer)

	vk.CmdEndRenderPass(commandBuffer)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		swapchainImages[imageIndex],
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		{.COLOR},
		1,
	)

	vk.CmdBlitImage(
		commandBuffer,
		imguiData.colour.vkImage,
		.TRANSFER_SRC_OPTIMAL,
		swapchainImages[imageIndex],
		.TRANSFER_DST_OPTIMAL,
		1,
		&vk.ImageBlit {
			srcSubresource = {
				aspectMask = {.COLOR},
				mipLevel = 0,
				baseArrayLayer = 0,
				layerCount = 1,
			},
			srcOffsets = {
				{x = 0, y = 0, z = 0},
				{x = i32(swapchainExtent.width), y = i32(swapchainExtent.height), z = 1},
			},
			dstSubresource = {
				aspectMask = {.COLOR},
				mipLevel = 0,
				baseArrayLayer = 0,
				layerCount = 1,
			},
			dstOffsets = {
				{x = 0, y = 0, z = 0},
				{x = i32(swapchainExtent.width), y = i32(swapchainExtent.height), z = 1},
			},
		},
		.NEAREST,
	)

	transitionImageLayout(
		graphicsContext,
		commandBuffer,
		swapchainImages[imageIndex],
		.TRANSFER_DST_OPTIMAL,
		.PRESENT_SRC_KHR,
		{.COLOR},
		1,
	)

	if vk.EndCommandBuffer(commandBuffer) != .SUCCESS {
		log.log(.Error, "Failed to record ui command buffer!")
		panic("Failed to record ui command buffer!")
	}
}

@(private = "file")
drawUI :: proc(using graphicsContext: ^GraphicsContext) {
	constructCamerasHeader :: proc(using graphicsContext: ^GraphicsContext) {
		for &camera, index in scenes[activeScene].cameras {
			if !imgui.TreeNode(camera.name) {
				continue
			}
			active := u32(index) == scenes[activeScene].activeCamera
			imgui.Checkbox("Active", &active)
			if active {
				scenes[activeScene].activeCamera = u32(index)
			}
			imgui.InputFloat3("Position", &camera.eye)
			imgui.InputFloat("FOV", &camera.fov)
			imgui.Text("Camera Mode:")
			if imgui.RadioButton("Perspective", camera.mode == .PERSPECTIVE) {
				camera.mode = .PERSPECTIVE
			}
			if imgui.RadioButton("Orthographic", camera.mode == .ORTHOGRAPHIC) {
				camera.mode = .ORTHOGRAPHIC
			}
			imgui.TreePop()
		}
	}

	constructLightsHeader :: proc(using graphicsContext: ^GraphicsContext) {
		for &light in scenes[activeScene].pointLights {
			if !imgui.TreeNode(light.name) {
				continue
			}
			imgui.InputFloat3("Position", &light.position)
			imgui.InputFloat3("Colour", &light.colourIntensity)
			imgui.InputFloat("FOV", &light.fov)
			imgui.Text("Movement")
			imgui.InputFloat("Degrees", &light.rotationAngle)
			imgui.InputFloat3("Axis", &light.rotationAxis)
			imgui.TreePop()
		}
	}

	constructObjectsHeader :: proc(using graphicsContext: ^GraphicsContext) {
		for &instance in scenes[activeScene].instances {
			if !imgui.TreeNode(instance.name) {
				continue
			}
			imgui.InputFloat3("Position", &instance.position)
			imgui.InputFloat3("Rotation", &instance.rotation)
			imgui.InputFloat3("Scale", &instance.scale)
			imgui.TreePop()
		}
	}

	constructSceneEditor :: proc(using graphicsContext: ^GraphicsContext) {
		if imgui.BeginMenuBar() {
			if imgui.BeginMenu("File") {
				imgui.SeparatorText("Scene Files")
				if imgui.MenuItem("Load") {
					ImFD.Open(
						"TextureOpenDialog",
						"Open a scene",
						"JSON file (*.json){.json},.*",
						true,
						"./assets/",
					)
				}
				if imgui.MenuItem("Save") {

				}
				imgui.EndMenu()
			}
			imgui.EndMenuBar()
		}

		if imgui.Button("Toggle Time", {100, 20}) {
			paused = !paused
		}

		if imgui.BeginCombo("Scene Selection", scenes[activeScene].name) {
			for &scene, index in scenes {
				if activeScene != u32(index) && imgui.Selectable(scene.name, false) {
					setActiveScene(graphicsContext, u32(index))
				}
			}
			imgui.EndCombo()
		}

		imgui.InputInt4("Clear Colour", &scenes[activeScene].clearColour)

		if imgui.CollapsingHeader("Cameras") {
			constructCamerasHeader(graphicsContext)
		}

		if imgui.CollapsingHeader("Lights") {
			constructLightsHeader(graphicsContext)
		}

		if imgui.CollapsingHeader("Objects") {
			constructObjectsHeader(graphicsContext)
		}
	}

	implVulkan.NewFrame()
	implGLFW.NewFrame()
	imgui.NewFrame()

	if showMetrics {
		imgui.ShowMetricsWindow()
	}

	if showDemo {
		imgui.ShowDemoWindow()
	}

	if imgui.Begin("Scene Editor", nil, {.MenuBar}) {
		constructSceneEditor(graphicsContext)
	}
	imgui.End()

	if ImFD.IsDone("TextureOpenDialog") {
		if ImFD.HasResult() {
			file := ImFD.GetResult()
			index, err := loadScene(graphicsContext, string(file))
			setActiveScene(graphicsContext, index)
		}
		ImFD.Close()
	}
}

drawFrame :: proc(using graphicsContext: ^GraphicsContext, delta: f32) {
	vk.WaitForFences(device, 1, &inFlightFrames[currentFrame], true, max(u64))

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
	vk.ResetFences(device, 1, &inFlightFrames[currentFrame])

	vk.ResetCommandBuffer(mainCommandBuffers[currentFrame], {})
	vk.ResetCommandBuffer(computeCommandBuffers[currentFrame], {})
	vk.ResetCommandBuffer(uiCommandBuffers[currentFrame], {})

	when UI_ENABLED {
		drawUI(graphicsContext)
	}

	updateUniformBuffer(
		graphicsContext,
		scenes[activeScene].cameras[scenes[activeScene].activeCamera],
	)
	updateLightBuffer(graphicsContext, delta)
	updateInstanceBuffer(graphicsContext, delta)

	recordGraphicsBuffer(graphicsContext, mainCommandBuffers[currentFrame], imageIndex)
	recordComputeBuffer(graphicsContext, computeCommandBuffers[currentFrame], imageIndex)
	when UI_ENABLED {
		recordUIBuffer(graphicsContext, uiCommandBuffers[currentFrame], imageIndex)
	}

	submitInfo: vk.SubmitInfo = {
		sType                = .SUBMIT_INFO,
		pNext                = nil,
		waitSemaphoreCount   = 0,
		pWaitSemaphores      = nil,
		pWaitDstStageMask    = nil,
		commandBufferCount   = 1,
		pCommandBuffers      = &mainCommandBuffers[currentFrame],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &rendersFinished[currentFrame],
	}
	if vk.QueueSubmit(graphicsQueue, 1, &submitInfo, 0) != .SUCCESS {
		log.log(.Error, "Failed to submit draw command buffer!")
		panic("Failed to submit draw command buffer!")
	}

	waitSemaphoresCount: u32
	waitSemaphores: []vk.Semaphore
	waitDstStageMasks: []vk.PipelineStageFlags
	when UI_ENABLED {
		waitSemaphoresCount = 1
		waitSemaphores = {rendersFinished[currentFrame]}
		waitDstStageMasks = {{.COMPUTE_SHADER}}
	} else {
		waitSemaphoresCount = 2
		waitSemaphores = {rendersFinished[currentFrame], imagesAvailable[currentFrame]}
		waitDstStageMasks = {{.COMPUTE_SHADER}, {.BOTTOM_OF_PIPE}}
	}

	submitInfo = {
		sType                = .SUBMIT_INFO,
		pNext                = nil,
		waitSemaphoreCount   = waitSemaphoresCount,
		pWaitSemaphores      = raw_data(waitSemaphores),
		pWaitDstStageMask    = raw_data(waitDstStageMasks),
		commandBufferCount   = 1,
		pCommandBuffers      = &computeCommandBuffers[currentFrame],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &computeFinished[currentFrame],
	}
	fence: vk.Fence
	when !UI_ENABLED {
		fence = inFlightFrames[currentFrame]
	}

	if vk.QueueSubmit(computeQueue, 1, &submitInfo, fence) != .SUCCESS {
		log.log(.Error, "Failed to submit compute command buffer!")
		panic("Failed to submit compute command buffer!")
	}

	when UI_ENABLED {
		submitInfo = {
			sType                = .SUBMIT_INFO,
			pNext                = nil,
			waitSemaphoreCount   = 2,
			pWaitSemaphores      = raw_data(
				[]vk.Semaphore{computeFinished[currentFrame], imagesAvailable[currentFrame]},
			),
			pWaitDstStageMask    = raw_data(
				[]vk.PipelineStageFlags{{.TOP_OF_PIPE}, {.BOTTOM_OF_PIPE}},
			),
			commandBufferCount   = 1,
			pCommandBuffers      = &uiCommandBuffers[currentFrame],
			signalSemaphoreCount = 1,
			pSignalSemaphores    = &uiFinished[currentFrame],
		}
		if vk.QueueSubmit(graphicsQueue, 1, &submitInfo, inFlightFrames[currentFrame]) !=
		   .SUCCESS {
			log.log(.Error, "Failed to submit ui command buffer!")
			panic("Failed to submit ui command buffer!")
		}
	}

	waitSemaphore: ^vk.Semaphore
	when UI_ENABLED {
		waitSemaphore = &uiFinished[currentFrame]
	} else {
		waitSemaphore = &computeFinished[currentFrame]
	}

	presentInfo: vk.PresentInfoKHR = {
		sType              = .PRESENT_INFO_KHR,
		pNext              = nil,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = waitSemaphore,
		swapchainCount     = 1,
		pSwapchains        = &swapchain,
		pImageIndices      = &imageIndex,
		pResults           = nil,
	}

	if result := vk.QueuePresentKHR(presentQueue, &presentInfo);
	   result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR || framebufferResized {
		framebufferResized = false
		recreateSwapchain(graphicsContext)
	} else if result != .SUCCESS {
		log.log(.Error, "Failed to present swapchain image!")
		panic("Failed to present swapchain image!")
	}

	currentFrame = (currentFrame + 1) % 2
}


// ###################################################################
// #                             Cleanup                             #
// ###################################################################


@(private = "file")
cleanupSwapchain :: proc(using graphicsContext: ^GraphicsContext) {
	for imageView in swapchainImageViews {
		vk.DestroyImageView(device, imageView, nil)
	}
	delete(swapchainImages)
	delete(swapchainImageViews)

	vk.DestroySwapchainKHR(device, swapchain, nil)
	vk.DestroyImageView(device, inImage.view, nil)
	vk.DestroyImage(device, inImage.vkImage, nil)
	vk.FreeMemory(device, inImage.memory, nil)
	vk.DestroyImageView(device, outImage.view, nil)
	vk.DestroyImage(device, outImage.vkImage, nil)
	vk.FreeMemory(device, outImage.memory, nil)
}

@(private = "file")
cleanupScene :: proc(using graphicsContext: ^GraphicsContext, sceneIndex: u32) {
	vk.DestroyBuffer(device, scenes[sceneIndex].indexBuffer.buffer, nil)
	vk.FreeMemory(device, scenes[sceneIndex].indexBuffer.memory, nil)
	vk.DestroyBuffer(device, scenes[sceneIndex].vertexBuffer.buffer, nil)
	vk.FreeMemory(device, scenes[sceneIndex].vertexBuffer.memory, nil)

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyBuffer(device, scenes[sceneIndex].instanceBuffers[index].buffer, nil)
		vk.FreeMemory(device, scenes[sceneIndex].instanceBuffers[index].memory, nil)
		vk.DestroyBuffer(device, scenes[sceneIndex].boneBuffers[index].buffer, nil)
		vk.FreeMemory(device, scenes[sceneIndex].boneBuffers[index].memory, nil)
		vk.DestroyBuffer(device, scenes[sceneIndex].lightBuffers[index].buffer, nil)
		vk.FreeMemory(device, scenes[sceneIndex].lightBuffers[index].memory, nil)
	}

	vk.DestroyImageView(device, scenes[sceneIndex].textures.view, nil)
	vk.DestroyImage(device, scenes[sceneIndex].textures.vkImage, nil)
	vk.FreeMemory(device, scenes[sceneIndex].textures.memory, nil)
	vk.DestroySampler(device, scenes[sceneIndex].textures.sampler, nil)

	vk.DestroyImageView(device, scenes[sceneIndex].normals.view, nil)
	vk.DestroyImage(device, scenes[sceneIndex].normals.vkImage, nil)
	vk.FreeMemory(device, scenes[sceneIndex].normals.memory, nil)
	vk.DestroySampler(device, scenes[sceneIndex].normals.sampler, nil)

	vk.DestroyImageView(device, scenes[sceneIndex].shadowImages.view, nil)
	vk.DestroyImage(device, scenes[sceneIndex].shadowImages.vkImage, nil)
	vk.FreeMemory(device, scenes[sceneIndex].shadowImages.memory, nil)
	vk.DestroySampler(device, scenes[sceneIndex].shadowImages.sampler, nil)

	for &texturePath in scenes[sceneIndex].texturePaths {
		delete(texturePath)
	}
	delete(scenes[sceneIndex].texturePaths)

	for &normalPath in scenes[sceneIndex].normalPaths {
		delete(normalPath)
	}
	delete(scenes[sceneIndex].normalPaths)

	for &model in scenes[sceneIndex].models {
		delete(model.vertices)
		delete(model.indices)
		delete(model.skeleton)
		for &animation in model.animations {
			for &node in animation.nodes {
				delete(node.keyPositions)
				delete(node.keyRotations)
				delete(node.keyScales)
			}
			delete(animation.nodes)
		}
		delete(model.animations)
	}
	delete(scenes[sceneIndex].vertices)
	delete(scenes[sceneIndex].indices)
	delete(scenes[sceneIndex].models)

	for &modelPath in scenes[sceneIndex].modelPaths {
		delete(modelPath)
	}
	delete(scenes[sceneIndex].modelPaths)

	for &instance in scenes[sceneIndex].instances {
		delete(instance.name)
		delete(instance.scaleKeys)
		delete(instance.positionKeys)
		delete(instance.rotationKeys)
	}
	delete(scenes[sceneIndex].instances)

	for &light in scenes[sceneIndex].pointLights {
		delete(light.name)
	}
	delete(scenes[sceneIndex].pointLights)

	for &camera in scenes[sceneIndex].cameras {
		delete(camera.name)
	}
	delete(scenes[sceneIndex].cameras)
	delete(scenes[sceneIndex].name)
}

@(private = "file")
cleanupImgui :: proc(using graphicsContext: ^GraphicsContext) {
	// This should probably be in ImFDDeleteImage but that causes issues so this is the best solution I have at the moment
	for imageData, index in imguiData.imfdImages {
		vk.DestroyImageView(device, imageData.view, nil)
		vk.DestroyImage(device, imageData.vkImage, nil)
		vk.FreeMemory(device, imageData.memory, nil)
		vk.DestroySampler(device, imageData.sampler, nil)
		implVulkan.RemoveTexture(imageData.descriptorSet)
	}
	delete(imguiData.imfdImages)
	// ----------------------------------------------------

	ImFD.Shutdown()
	implVulkan.Shutdown()
	implGLFW.Shutdown()
	imgui.DestroyContext(imguiData.uiContext)

	for &frameBuffer in imguiData.frameBuffers {
		vk.DestroyFramebuffer(device, frameBuffer, nil)
	}
	delete(imguiData.frameBuffers)

	vk.DestroyImageView(device, imguiData.colour.view, nil)
	vk.DestroyImage(device, imguiData.colour.vkImage, nil)
	vk.FreeMemory(device, imguiData.colour.memory, nil)

	vk.DestroyRenderPass(device, imguiData.renderPass, nil)
}

clanupVkGraphics :: proc(using graphicsContext: ^GraphicsContext) {
	graphicsContext := graphicsContext
	if vk.DeviceWaitIdle(device) != .SUCCESS {
		panic("Failed to wait for device idle!")
	}

	for index in 0 ..< len(scenes) {
		cleanupScene(graphicsContext, u32(index))
	}
	delete(scenes)

	when UI_ENABLED {
		cleanupImgui(graphicsContext)
		vk.DestroyDescriptorPool(device, imguiData.descriptorPool, nil)
	}

	vk.FreeCommandBuffers(device, graphicsCommandPool, 2, raw_data(mainCommandBuffers))
	vk.FreeCommandBuffers(device, computeCommandPool, 2, raw_data(computeCommandBuffers))
	vk.FreeCommandBuffers(device, graphicsCommandPool, 2, raw_data(uiCommandBuffers))

	vk.DestroyCommandPool(device, graphicsCommandPool, nil)
	vk.DestroyCommandPool(device, computeCommandPool, nil)
	delete(mainCommandBuffers)
	delete(computeCommandBuffers)
	delete(uiCommandBuffers)

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyFence(device, inFlightFrames[index], nil)
		vk.DestroySemaphore(device, rendersFinished[index], nil)
		vk.DestroySemaphore(device, computeFinished[index], nil)
		vk.DestroySemaphore(device, uiFinished[index], nil)
		vk.DestroySemaphore(device, imagesAvailable[index], nil)
	}
	delete(inFlightFrames)
	delete(rendersFinished)
	delete(computeFinished)
	delete(uiFinished)
	delete(imagesAvailable)

	for index in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroyBuffer(device, uniformBuffers[index].buffer, nil)
		vk.FreeMemory(device, uniformBuffers[index].memory, nil)
	}

	for index in 0 ..< swapchainImageCount {
		vk.DestroyFramebuffer(device, pipelines[PipelineIndex.MAIN].frameBuffers[index], nil)
		vk.DestroyFramebuffer(device, pipelines[PipelineIndex.SHADOW].frameBuffers[index], nil)
	}
	delete(pipelines[PipelineIndex.MAIN].frameBuffers)
	delete(pipelines[PipelineIndex.SHADOW].frameBuffers)

	cleanupSwapchain(graphicsContext)

	// MAIN
	vk.DestroyImageView(device, pipelines[PipelineIndex.MAIN].colour.view, nil)
	vk.DestroyImage(device, pipelines[PipelineIndex.MAIN].colour.vkImage, nil)
	vk.FreeMemory(device, pipelines[PipelineIndex.MAIN].colour.memory, nil)

	vk.DestroyImageView(device, pipelines[PipelineIndex.MAIN].depth.view, nil)
	vk.DestroyImage(device, pipelines[PipelineIndex.MAIN].depth.vkImage, nil)
	vk.FreeMemory(device, pipelines[PipelineIndex.MAIN].depth.memory, nil)
	vk.DestroySampler(device, pipelines[PipelineIndex.MAIN].depth.sampler, nil)

	vk.DestroyDescriptorPool(device, pipelines[PipelineIndex.MAIN].descriptorPool, nil)
	vk.DestroyDescriptorSetLayout(device, pipelines[PipelineIndex.MAIN].descriptorSetLayout, nil)

	vk.DestroyPipeline(device, pipelines[PipelineIndex.MAIN].pipeline, nil)
	vk.DestroyPipelineLayout(device, pipelines[PipelineIndex.MAIN].layout, nil)
	vk.DestroyRenderPass(device, pipelines[PipelineIndex.MAIN].renderPass, nil)

	// POST
	vk.DestroyDescriptorPool(device, pipelines[PipelineIndex.POST].descriptorPool, nil)
	vk.DestroyDescriptorSetLayout(device, pipelines[PipelineIndex.POST].descriptorSetLayout, nil)

	vk.DestroyPipeline(device, pipelines[PipelineIndex.POST].pipeline, nil)
	vk.DestroyPipelineLayout(device, pipelines[PipelineIndex.POST].layout, nil)

	// LIGHT
	vk.DestroyImageView(device, pipelines[PipelineIndex.SHADOW].depth.view, nil)
	vk.DestroyImage(device, pipelines[PipelineIndex.SHADOW].depth.vkImage, nil)
	vk.FreeMemory(device, pipelines[PipelineIndex.SHADOW].depth.memory, nil)

	vk.DestroyDescriptorPool(device, pipelines[PipelineIndex.SHADOW].descriptorPool, nil)
	vk.DestroyDescriptorSetLayout(device, pipelines[PipelineIndex.SHADOW].descriptorSetLayout, nil)

	vk.DestroyPipeline(device, pipelines[PipelineIndex.SHADOW].pipeline, nil)
	vk.DestroyPipelineLayout(device, pipelines[PipelineIndex.SHADOW].layout, nil)
	vk.DestroyRenderPass(device, pipelines[PipelineIndex.SHADOW].renderPass, nil)

	delete(pipelines)

	vk.DestroyDevice(device, nil)
	vk.DestroySurfaceKHR(instance, surface, nil)

	when ODIN_DEBUG {
		vk.DestroyDebugUtilsMessengerEXT(instance, debugMessenger, nil)
	}

	vk.DestroyInstance(instance, nil)

	glfw.DestroyWindow(window)
	glfw.Terminate()
}
