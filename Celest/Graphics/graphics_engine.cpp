#include "graphics_engine.h"
#include "vkInit/instance.h"
#include "vkInit/device.h"
#include "vkInit/swapchain.h"
#include "vkInit/image_views.h"
#include "vkInit/descriptors.h"
#include "vkInit/pipeline.h"
#include "vkInit/framebuffer.h"
#include "vkInit/command_pool.h"
#include "vkInit/sync.h"
#include "vkMesh/mesh.h"
#include "debug/vkLogging.h"

Graphics::Engine::Engine(int width, int height, GLFWwindow* window, Game::Camera* camera) {
	this->width = width;
	this->height = height;
	this->window = window;
	
	Debug::Logger::log(Debug::MESSAGE, "Creating new graphics engine");
	
	createInstance();
	createDebugMessenger();
	createSurface();
	createDevice();
	createSwapchain();
	createImageViews();
	createDescriptorSetLayouts();
	createPipelines();
	createFramebuffers();
	createCommandPool();
	createFrameResources();
}

inline void Graphics::Engine::createInstance() {
	instance = vkInit::makeInstance("Celest");
}

inline void Graphics::Engine::createDebugMessenger() {
	dldi = vk::DispatchLoaderDynamic(instance, vkGetInstanceProcAddr);
	//Debug::makeDebugMessenger(instance, dldi, debugMessenger);
}

inline void Graphics::Engine::createSurface() {
	VkSurfaceKHR c_style_surface;
	if (glfwCreateWindowSurface(instance, window, nullptr, &c_style_surface) != VK_SUCCESS) {
		throw std::runtime_error("Failed to create a glfw surface for Vulkan.");
	}
	else {
		Debug::Logger::log(Debug::MESSAGE, "Successfully abstracted glfw surface for Vulkan.");
	}
	surface = c_style_surface;
}

inline void Graphics::Engine::createDevice() {
	physicalDevice = vkInit::choosePhysicalDevice(instance, surface);
	device = vkInit::createLogicalDevice(physicalDevice, surface);
	vkUtil::QueueFamilyIndices familyIndices = vkUtil::findQueueFamilies(physicalDevice, surface);
	graphicsQueue = device.getQueue(familyIndices.graphicsFamily.value(), 0);
	presentQueue = device.getQueue(familyIndices.presentFamily.value(), 0);
}

inline void Graphics::Engine::createSwapchain() {
	vkInit::SwapchainBundle swapchainBundle = vkInit::createSwapchain(
		device, physicalDevice, surface, { static_cast<uint32_t>(width), static_cast<uint32_t>(height) }, nullptr
	);
	swapchain = swapchainBundle.swapchain;
	swapchainFormat = swapchainBundle.format;
	swapchainExtent = swapchainBundle.extent;
}

void Graphics::Engine::recreateSwapchain() {
	int width = 0, height = 0;
	glfwGetFramebufferSize(window, &width, &height);
	while (width == 0 || height == 0) {
		glfwGetFramebufferSize(window, &width, &height);
		glfwWaitEvents();
	}
	device.waitIdle();

	Debug::Logger::log(Debug::DEBUG, "Recreating swapchain.");
	cleanupSwapchain();
	createSwapchain();
	createImageViews();
	createFramebuffers();
	createFrameResources();
	vkInit::createFrameCommandBuffers({ device, commandPool, swapchainImageViews });
}

inline void Graphics::Engine::createImageViews() {
	swapchainImageViews = vkInit::createImageViews(device, swapchain, swapchainFormat);
	maxFramesInFlight = static_cast<int>(swapchainImageViews.size());
	for (vkUtil::SwapchainImageView& frame : swapchainImageViews) {
		frame.logicalDevice = device;
		frame.physicalDevice = physicalDevice;
		frame.width = swapchainExtent.width;
		frame.height = swapchainExtent.height;
		frame.makeDepthResources();
	}
	frameNumber = 0;
}

inline void Graphics::Engine::createDescriptorSetLayouts() {
	Debug::Logger::log(Debug::MESSAGE, "Creating descriptor sets.");
	/**
	* struct descriptorSetLayoutData {
	*	int								  count;
	*	std::vector<uint32_t>			  indices;
	*	std::vector<vk::DescriptorType>	  types;
	*	std::vector<uint32_t>			  counts;
	*	std::vector<vk::ShaderStageFlags> stages;
	* };
	*/
	vkInit::descriptorSetLayoutData bindings{
		2,
		{ 0u, 1u },
		{ vk::DescriptorType::eUniformBuffer, vk::DescriptorType::eStorageBuffer },
		{ 1u, 1u },
		{ vk::ShaderStageFlagBits::eVertex, vk::ShaderStageFlagBits::eVertex }
	};
	frameSetLayout[pipelineType::SKY] = vkInit::makeDescriptorSetLayout(device, bindings);
	frameSetLayout[pipelineType::STANDARD] = vkInit::makeDescriptorSetLayout(device, bindings);
	
	bindings = {
		1,
		{ 0u },
		{ vk::DescriptorType::eCombinedImageSampler },
		{ 1u },
		{ vk::ShaderStageFlagBits::eFragment }
	};
	meshSetLayout[pipelineType::SKY] = vkInit::makeDescriptorSetLayout(device, bindings);
	meshSetLayout[pipelineType::STANDARD] = vkInit::makeDescriptorSetLayout(device, bindings);
}

inline void Graphics::Engine::createPipelines() {
	/**
	* struct PipelineBuildInfo {
	*	vk::Device& device;
	*	bool overwrite;
	*	VertexInputInfo vertexInputInfo;
	*	std::vector<shaderInfo> shaderStages;
	*	vk::Extent2D swapchainExtent;
	*	AttachmentInfo depthAttachmentInfo;
	*	std::vector<vk::DescriptorSetLayout> descriptorSetLayouts;
	*	AttachmentInfo colourAttachmentInfo;
	* };
	*/
	vkInit::PipelineBuildInfo skyPipelineBuildInfo{
		device,
		false,
		{ vkMesh::Vertex::getBindingDescription(), vkMesh::Vertex::getAttributeDescriptions() },
		{
			{ vk::ShaderStageFlagBits::eVertex, "Graphics/shaders/sky_vertex.spv" },
			{ vk::ShaderStageFlagBits::eFragment, "Graphics/shaders/sky_fragment.spv" }
		},
		swapchainExtent,
		{ swapchainFormat, 0 },
		{ vk::Format::eUndefined, 1},
		{ frameSetLayout[pipelineType::SKY], meshSetLayout[pipelineType::SKY] }
	};
	vkInit::GraphicsPipelineOutBundle output = vkInit::buildPipeline(skyPipelineBuildInfo);
	pipelineLayout[pipelineType::SKY] = output.layout;
	renderpass[pipelineType::SKY] = output.renderpass;
	pipeline[pipelineType::SKY] = output.pipeline;
	shaderStages[pipelineType::SKY] = output.shaders;

	vkInit::PipelineBuildInfo pipelineBuildInfo{
		device,
		true,
		{ vkMesh::Vertex::getBindingDescription(), vkMesh::Vertex::getAttributeDescriptions() },
		{
			{ vk::ShaderStageFlagBits::eVertex, "Graphics/shaders/vertex.spv" },
			{ vk::ShaderStageFlagBits::eFragment, "Graphics/shaders/fragment.spv" }
			//{ vk::ShaderStageFlagBits::eCompute, "Graphics/shaders/compute.spv" }
		},
		swapchainExtent,
		{ swapchainFormat, 0 },
		{ swapchainImageViews[0].depthFormat, 1 },
		{ frameSetLayout[pipelineType::STANDARD], meshSetLayout[pipelineType::STANDARD] }
	};
	output = vkInit::buildPipeline(pipelineBuildInfo);
	pipelineLayout[pipelineType::STANDARD] = output.layout;
	renderpass[pipelineType::STANDARD] = output.renderpass;
	pipeline[pipelineType::STANDARD] = output.pipeline;
	shaderStages[pipelineType::STANDARD] = output.shaders;
}

inline void Graphics::Engine::createFramebuffers() {
	vkInit::createFramebuffers(
		{
			device,
			swapchainExtent,
			renderpass
		}, 
		swapchainImageViews
	);
}

inline void Graphics::Engine::createCommandPool() {
	commandPool = vkInit::createCommandPool(device, physicalDevice, surface);
	vkInit::commandBufferInputChunk commandBufferInput = { device, commandPool, swapchainImageViews };
	mainCommandBuffer = vkInit::createCommandBuffer(commandBufferInput);
	vkInit::createFrameCommandBuffers(commandBufferInput);
}

inline void Graphics::Engine::createFrameResources() {
	/**
	* struct descriptorSetLayoutData {
	*	int                               count;
	*	std::vector<uint32_t>             indices;
	*	std::vector<vk::DescriptorType>   types;
	*	std::vector<uint32_t>             counts;
	*	std::vector<vk::ShaderStageFlags> stages;
	* };
	*/
	vkInit::descriptorSetLayoutData bindings;
	bindings.count = 2;
	bindings.types.push_back(vk::DescriptorType::eUniformBuffer);
	bindings.types.push_back(vk::DescriptorType::eStorageBuffer);
	uint32_t descriptor_sets_per_frame = 2;
	frameDescriptorPool = vkInit::makeDescriptorPool(device, static_cast<uint32_t>(swapchainImageViews.size() * descriptor_sets_per_frame), bindings);
	for (vkUtil::SwapchainImageView& frame : swapchainImageViews) {
		frame.imageAvailable = vkInit::makeSemaphore(device);
		frame.renderFinished = vkInit::makeSemaphore(device);
		frame.inFlight = vkInit::makeFence(device);
		frame.makeDescriptorResources();
		frame.descriptorSet[pipelineType::SKY] = vkInit::allocateDescriptorSet(device, frameDescriptorPool, frameSetLayout[pipelineType::SKY]);
		frame.descriptorSet[pipelineType::STANDARD] = vkInit::allocateDescriptorSet(device, frameDescriptorPool, frameSetLayout[pipelineType::STANDARD]);
		frame.recordWriteOperations();
	}
}

void Graphics::Engine::createWorkerThreads() {
	done = false;
	size_t threadCount = std::thread::hardware_concurrency() - 1;
	workers.reserve(threadCount);
	vkInit::commandBufferInputChunk commandBufferInput = { device, commandPool, swapchainImageViews };
	for (size_t i = 0; i < threadCount; ++i) {
		vk::CommandBuffer commandBuffer = vkInit::createCommandBuffer(commandBufferInput);
		workers.push_back(
			std::thread(
				vkJob::WorkerThread(workQueue, done, commandBuffer, graphicsQueue)
			)
		);
	}
}

void Graphics::Engine::endWorkerThreads() {
	done = true;
	size_t threadCount = std::thread::hardware_concurrency() - 1;
	for (size_t i = 0; i < threadCount; ++i) {
		workers[i].join();
	}
	Debug::Logger::log(Debug::MESSAGE, "Threads ended successfully.");
}

void Graphics::Engine::createAssets(Game::AssetPack assetPack) {
	meshes = new vkMesh::VertexMenagerie();
	std::unordered_map<std::string, vkUtil::MeshLoader*> loaded_models;

	vkInit::descriptorSetLayoutData bindings;
	bindings.count = 1;
	bindings.types.push_back(vk::DescriptorType::eCombinedImageSampler);
	meshDescriptorPool = vkInit::makeDescriptorPool(device, static_cast<uint32_t>(assetPack.texture_filenames.size()) + 1, bindings);

	workQueue.lock.lock();
	for (int i = 0; i < assetPack.objectTypes.size(); i++) {
		vkImage::TextureInputChunk textureInfo;
		textureInfo.logicalDevice = device;
		textureInfo.physicalDevice = physicalDevice;
		textureInfo.layout = meshSetLayout[pipelineType::STANDARD];
		textureInfo.descriptorPool = meshDescriptorPool;
		textureInfo.filenames.push_back(assetPack.texture_filenames[i]);
		materials[assetPack.objectTypes[i]] = new vkImage::Texture();
		loaded_models[assetPack.objectTypes[i]] = vkMesh::createMeshLoader(assetPack.model_filenames[i], assetPack.preTransforms[i]);
		workQueue.add(
			new vkJob::MakeTexture(materials[assetPack.objectTypes[i]], textureInfo)
		);
		workQueue.add(
			new vkJob::MakeModel(loaded_models[assetPack.objectTypes[i]])
		);
	}
	workQueue.lock.unlock();

	std::cout << "Waiting for work to finish." << std::endl;
	while (true) {

		if (!workQueue.lock.try_lock()) {
			std::this_thread::sleep_for(std::chrono::milliseconds(200));
			continue;
		}

		if (workQueue.done()) {
			std::cout << "Work finished" << std::endl;
			workQueue.clear();
			workQueue.lock.unlock();
			break;
		}
		workQueue.lock.unlock();
	}

	//Consume loaded meshes
	for (std::pair<std::string, vkUtil::MeshLoader*> pair : loaded_models) {
		meshes->consume(pair.first, pair.second->vertices, pair.second->indices);
		delete pair.second;
	}

	vkMesh::vertexBufferFinalizationChunk finalizationInfo;
	finalizationInfo.logicalDevice = device;
	finalizationInfo.physicalDevice = physicalDevice;
	finalizationInfo.commandBuffer = mainCommandBuffer;
	finalizationInfo.queue = graphicsQueue;
	meshes->finalize(finalizationInfo);

	//Proceed when work is done
	
	vkImage::TextureInputChunk textureInfo;
	textureInfo.commandBuffer = mainCommandBuffer;
	textureInfo.queue = graphicsQueue;
	textureInfo.logicalDevice = device;
	textureInfo.physicalDevice = physicalDevice;
	textureInfo.layout = meshSetLayout[pipelineType::STANDARD];
	textureInfo.descriptorPool = meshDescriptorPool;
	textureInfo.layout = meshSetLayout[pipelineType::SKY];
	textureInfo.filenames.push_back("assets/textures/blue.png");
	textureInfo.filenames.push_back("assets/textures/blue.png");
	textureInfo.filenames.push_back("assets/textures/blue.png");
	textureInfo.filenames.push_back("assets/textures/blue.png");
	textureInfo.filenames.push_back("assets/textures/blue.png");
	textureInfo.filenames.push_back("assets/textures/blue.png");
	cubemap = new vkImage::CubeMap(textureInfo);
}

void Graphics::Engine::loadAssets(Game::AssetPack assetPack) {
	createWorkerThreads();
	createAssets(assetPack);
	endWorkerThreads();
}

void Graphics::Engine::prepareFrame(uint32_t imageIndex, Game::Scene* scene) {
	vkUtil::SwapchainImageView& _frame = swapchainImageViews[imageIndex];
	Game::CameraView cameraViewData = scene->getCamera()->getCameraViewData();
	Game::CameraVectors cameraVectorData{
		{ cameraViewData.forward.x, cameraViewData.forward.y, cameraViewData.forward.z, 0.0 },
		{ cameraViewData.right.x,   cameraViewData.right.y,   cameraViewData.right.z, 0.0 },
		{ cameraViewData.up.x,      cameraViewData.up.y,      cameraViewData.up.z, 0.0 }
	};
	memcpy(_frame.cameraVectorWriteLocation, &(cameraVectorData), sizeof(Game::CameraVectors));

	glm::mat4 view = glm::lookAt(cameraViewData.eye, cameraViewData.center, cameraViewData.up);
	glm::mat4 projection = glm::perspective(glm::radians(45.0), static_cast<double>(swapchainExtent.width) / static_cast<double>(swapchainExtent.height), 0.1, 1000.0);
	projection[1][1] *= -1;

	Game::CameraMatrices cameraMatrixData{
		view,
		projection,
		projection * view
	};
	memcpy(_frame.cameraMatrixWriteLocation, &(cameraMatrixData), sizeof(Game::CameraMatrices));

	size_t i = 0;
	for (std::pair<std::string, std::vector<Entitys::Entity*>> pair : scene->getMappedObjects()) {
		for (Entitys::Entity* obj : pair.second) {
			_frame.modelTransforms[i++] = obj->getPhysicsObject()->translationMatrix;
		}
	}
	memcpy(_frame.modelBufferWriteLocation, _frame.modelTransforms.data(), i * sizeof(glm::f64mat4));
	_frame.writeDescriptorSet();
}

void Graphics::Engine::prepareScene(vk::CommandBuffer commandBuffer) {
	commandBuffer.setViewport(0, 1, createViewport(swapchainExtent));
	commandBuffer.setScissor(0, 1, createScissor(swapchainExtent));
	commandBuffer.bindVertexBuffers(0, 1, new vk::Buffer{ meshes->vertexBuffer.buffer }, new vk::DeviceSize{0});
	commandBuffer.bindIndexBuffer(meshes->indexBuffer.buffer, 0, vk::IndexType::eUint32);
}

void Graphics::Engine::recordDrawCommandsSky(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene) {
	/**
	* RenderPassBeginInfo(
	*	vk::RenderPass         renderPass_      = {},
	*	vk::Framebuffer        framebuffer_     = {},
	*	vk::Rect2D             renderArea_      = {},
	*	uint32_t               clearValueCount_ = {},
	*	const vk::ClearValue * pClearValues_    = {},
	*	const void *           pNext_           = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::RenderPassBeginInfo renderPassInfo{
		renderpass[pipelineType::SKY],
		swapchainImageViews[imageIndex].framebuffer[pipelineType::SKY],
		{ { 0, 0 }, swapchainExtent },
		1u,
		/**
		* ClearColorValue(
		*	const std::array<float, 4>& float32_ = {}
		* )
		*/
		new vk::ClearValue{ vk::ClearColorValue({ 0.0f, 0.0f, 0.0f, 1.0f }) },
		nullptr
	};
	commandBuffer.beginRenderPass(&renderPassInfo, vk::SubpassContents::eInline);
	commandBuffer.bindPipeline(vk::PipelineBindPoint::eGraphics, pipeline[pipelineType::SKY]);
	commandBuffer.bindDescriptorSets(
		vk::PipelineBindPoint::eGraphics, pipelineLayout[pipelineType::SKY],
		0, swapchainImageViews[imageIndex].descriptorSet[pipelineType::SKY],
		nullptr
	);
	cubemap->use(commandBuffer, pipelineLayout[pipelineType::SKY]);
	commandBuffer.draw(6, 1, 0, 0);
	commandBuffer.endRenderPass();
}

void Graphics::Engine::recordDrawCommandsScene(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene) {
	/**
	* ClearColorValue(
	*	const std::array<float, 4>& float32_ = {}
	* )
	*
	* ClearDepthStencilValue(
	*	float    depth_   = {},
	*	uint32_t stencil_ = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	std::vector<vk::ClearValue> clearValues{
		{ vk::ClearColorValue({ 0.0f, 0.0f, 0.0f, 1.0f }) },
		{ vk::ClearDepthStencilValue({ 1.0f, 0 }) }
	};
	/**
	* RenderPassBeginInfo(
	*	vk::RenderPass         renderPass_      = {},
    *	vk::Framebuffer        framebuffer_     = {},
    *	vk::Rect2D             renderArea_      = {},
    *	uint32_t               clearValueCount_ = {},
    *	const vk::ClearValue * pClearValues_    = {},
    *	const void *           pNext_           = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::RenderPassBeginInfo renderPassInfo{
		renderpass[pipelineType::STANDARD],
		swapchainImageViews[imageIndex].framebuffer[pipelineType::STANDARD],
		{ { 0, 0 }, swapchainExtent },
		static_cast<uint32_t>(clearValues.size()),
		clearValues.data(),
		nullptr
	};

	commandBuffer.beginRenderPass(&renderPassInfo, vk::SubpassContents::eInline);
	commandBuffer.bindPipeline(vk::PipelineBindPoint::eGraphics, pipeline[pipelineType::STANDARD]);
	commandBuffer.bindDescriptorSets(
		vk::PipelineBindPoint::eGraphics, pipelineLayout[pipelineType::STANDARD],
		0, swapchainImageViews[imageIndex].descriptorSet[pipelineType::STANDARD],
		nullptr
	);

	uint32_t startInstance = 0;
	for (std::pair<std::string, std::vector<Entitys::Entity*>> pair : scene->getMappedObjects()) {
		renderObjects(
			commandBuffer, pair.first, startInstance, static_cast<uint32_t>(pair.second.size())
		);
	}
	commandBuffer.endRenderPass();
}

void Graphics::Engine::renderObjects(vk::CommandBuffer commandBuffer, std::string objectType, uint32_t& startInstance, uint32_t instanceCount) {
	int indexCount = meshes->indexCounts.find(objectType)->second;
	int firstIndex = meshes->firstIndices.find(objectType)->second;
	materials[objectType]->use(commandBuffer, pipelineLayout[pipelineType::STANDARD]);
	commandBuffer.drawIndexed(indexCount, instanceCount, firstIndex, 0, startInstance);
	startInstance += instanceCount;
}

void Graphics::Engine::render(Game::Scene* scene) {
	if (device.waitForFences(1, &(swapchainImageViews[frameNumber].inFlight), VK_TRUE, UINT64_MAX) != vk::Result::eSuccess) {
		throw std::runtime_error("Fence returned a bad result.");
	}
	
	uint32_t imageIndex;
	try {
		vk::ResultValue acquire = device.acquireNextImageKHR(
			swapchain, UINT64_MAX, swapchainImageViews[frameNumber].imageAvailable, nullptr
		);
		imageIndex = acquire.value;
	}
	catch (vk::OutOfDateKHRError err) {
		recreateSwapchain();
		return;
	}
	catch (vk::IncompatibleDisplayKHRError err) {
		recreateSwapchain();
		return;
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to acquire swapchain image! Reason:\n\t{}", err.what()).c_str());
	}

	if (device.resetFences(1, &(swapchainImageViews[frameNumber].inFlight)) != vk::Result::eSuccess) {
		throw std::runtime_error("Fence reset returned a bad result.");
	}

	vk::CommandBuffer commandBuffer = swapchainImageViews[frameNumber].commandBuffer;
	commandBuffer.reset();
	prepareFrame(imageIndex, scene);
	/**
	* CommandBufferBeginInfo(
	*	vk::CommandBufferUsageFlags              flags_            = {},
    *	const vk::CommandBufferInheritanceInfo * pInheritanceInfo_ = {},
    *	const void *                             pNext_            = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::CommandBufferBeginInfo beginInfo{
		vk::CommandBufferUsageFlags(),
		0,
		nullptr
	};

	try {
		commandBuffer.begin(beginInfo);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to begin recording command buffer! Reason:\n\t{}", err.what()).c_str());
	}

	prepareScene(commandBuffer);
	recordDrawCommandsSky(commandBuffer, imageIndex, scene);
	recordDrawCommandsScene(commandBuffer, imageIndex, scene);

	try {
		commandBuffer.end();
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to record command buffer! Reason:\n\t{}", err.what()).c_str());
	}

	vk::Semaphore waitSemaphores[] = { swapchainImageViews[frameNumber].imageAvailable };
	vk::Semaphore signalSemaphores[] = { swapchainImageViews[frameNumber].renderFinished };
	vk::PipelineStageFlags waitStages[] = { vk::PipelineStageFlagBits::eColorAttachmentOutput };
	/**
	* SubmitInfo(
	*	uint32_t                      waitSemaphoreCount_   = {},
	*	const vk::Semaphore*          pWaitSemaphores_      = {},
	*	const vk::PipelineStageFlags* pWaitDstStageMask_    = {},
	*	uint32_t                      commandBufferCount_   = {},
	*	const vk::CommandBuffer*      pCommandBuffers_      = {},
	*	uint32_t                      signalSemaphoreCount_ = {},
	*	const vk::Semaphore*          pSignalSemaphores_    = {},
	*	const void*                   pNext_                = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::SubmitInfo submitInfo = {
		1,
		waitSemaphores,
		waitStages,
		1,
		&commandBuffer,
		1,
		signalSemaphores,
		nullptr
	};

	try {
		graphicsQueue.submit(submitInfo, swapchainImageViews[frameNumber].inFlight);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to submit draw command buffer! Reason\n\t{}", err.what()).c_str());
	}

	vk::Result result;
	/**
	* PresentInfoKHR(
	*	uint32_t                 waitSemaphoreCount_ = {},
    *	const vk::Semaphore *    pWaitSemaphores_    = {},
    *	uint32_t                 swapchainCount_     = {},
    *	const vk::SwapchainKHR * pSwapchains_        = {},
    *	const uint32_t *         pImageIndices_      = {},
    *	vk::Result *             pResults_           = {},
    *	const void *             pNext_              = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::PresentInfoKHR presentInfo{
		1,
		signalSemaphores,
		1,
		&swapchain,
		&imageIndex,
		&result,
		nullptr
	};

	try {
		presentQueue.presentKHR(presentInfo);
	}
	catch (vk::SystemError err) {
		if (result != vk::Result::eErrorOutOfDateKHR) {
			throw std::runtime_error(std::format("Failed to present to KHR. Reason\n\t{}", err.what()).c_str());
		}
	}

	if (result == vk::Result::eErrorOutOfDateKHR || result == vk::Result::eSuboptimalKHR) {
		recreateSwapchain();
		return;
	}
	frameNumber = (frameNumber + 1) % maxFramesInFlight;
}

inline vk::Viewport* Graphics::Engine::createViewport(vk::Extent2D swapchainExtent) {
	/**
	* Viewport(
	*	float x_ = {},
	*	float y_ = {},
	*	float width_ = {},
	*	float height_ = {},
	*	float minDepth_ = {},
	*	float maxDepth_ = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::Viewport{
		0.0f,
		0.0f,
		static_cast<float>(swapchainExtent.width),
		static_cast<float>(swapchainExtent.height),
		0.0f,
		1.0f
	};
}

inline vk::Rect2D* Graphics::Engine::createScissor(vk::Extent2D swapchainExtent) {
	/**
	* Rect2D(
	*	vk::Offset2D offset_ = {},
	*	vk::Extent2D extent_ = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::Rect2D{
		vk::Offset2D{ 0, 0 },
		swapchainExtent
	};
}

void Graphics::Engine::cleanupSwapchain() {
	for (vkUtil::SwapchainImageView& frame : swapchainImageViews) {
		frame.destroy();
	}
	device.destroySwapchainKHR(swapchain);
	device.destroyDescriptorPool(frameDescriptorPool);
}

Graphics::Engine::~Engine() {
	device.waitIdle();

	Debug::Logger::log(Debug::MESSAGE, "Destroying graphics engine.");

	device.destroyCommandPool(commandPool);

	for (pipelineType pipeline_type : pipelineTypes) {
		device.destroyPipeline(pipeline[pipeline_type]);
		device.destroyPipelineLayout(pipelineLayout[pipeline_type]);
		device.destroyRenderPass(renderpass[pipeline_type]);
		device.destroyDescriptorSetLayout(frameSetLayout[pipeline_type]);
		device.destroyDescriptorSetLayout(meshSetLayout[pipeline_type]);
		for (vk::PipelineShaderStageCreateInfo stage : shaderStages[pipeline_type]) {
			device.destroyShaderModule(stage.module);
		}
	}

	cleanupSwapchain();

	device.destroyDescriptorPool(meshDescriptorPool);
	delete meshes;

	for (const auto& [key, texture] : materials) {
		delete texture;
	}
	delete cubemap;

	device.destroy();

	instance.destroySurfaceKHR(surface);
	instance.destroyDebugUtilsMessengerEXT(debugMessenger, nullptr, dldi);
	instance.destroy();

	glfwTerminate();
}
