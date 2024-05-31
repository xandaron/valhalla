#include "graphics_engine.h"
#include "vkInit/instance.h"
#include "vkInit/device.h"
#include "vkInit/swapchain.h"
#include "vkInit/pipeline.h"
#include "vkInit/framebuffer.h"
#include "vkInit/commands.h"
#include "vkInit/sync.h"
#include "vkInit/descriptors.h"
#include "vkMesh/mesh.h"

Graphics::Engine::Engine(int width, int height, GLFWwindow* window, Game::Camera* camera) {

	this->width = width;
	this->height = height;
	this->window = window;

	vkLogging::Logger::get_logger()->print("Making a graphics engine...");

	createInstance();
	createDevice();
	createDescriptorSetLayouts();
	createPipelines();
	finalizeSetup();
}

void Graphics::Engine::createInstance() {

	instance = vkInit::make_instance("New Innsmouth");
	dldi = vk::DispatchLoaderDynamic(instance, vkGetInstanceProcAddr);
	if (vkLogging::Logger::get_logger()->get_debug_mode()) {
		debugMessenger = vkLogging::make_debug_messenger(instance, dldi);
	}
	VkSurfaceKHR c_style_surface;
	if (glfwCreateWindowSurface(instance, window, nullptr, &c_style_surface) != VK_SUCCESS) {
		vkLogging::Logger::get_logger()->print("Failed to abstract glfw surface for Vulkan.");
	}
	else {
		vkLogging::Logger::get_logger()->print(
			"Successfully abstracted glfw surface for Vulkan.");
	}
	//copy constructor converts to hpp convention
	surface = c_style_surface;
}

void Graphics::Engine::createDevice() {

	physicalDevice = vkInit::choose_physical_device(instance);
	device = vkInit::create_logical_device(physicalDevice, surface);
	std::array<vk::Queue, 2> queues = vkInit::get_queues(physicalDevice, device, surface);
	graphicsQueue = queues[0];
	presentQueue = queues[1];
	createSwapchain();
	frameNumber = 0;
}

/**
* Make a swapchain
*/
void Graphics::Engine::createSwapchain() {

	vkInit::SwapChainBundle bundle = vkInit::create_swapchain(
		device, physicalDevice, surface, width, height
	);
	swapchain = bundle.swapchain;
	swapchainFrames = bundle.frames;
	swapchainFormat = bundle.format;
	swapchainExtent = bundle.extent;
	maxFramesInFlight = static_cast<int>(swapchainFrames.size());

	for (vkUtil::SwapChainFrame& frame : swapchainFrames) {
		frame.logicalDevice = device;
		frame.physicalDevice = physicalDevice;
		frame.width = swapchainExtent.width;
		frame.height = swapchainExtent.height;

		frame.make_depth_resources();
	}
}

/**
* The swapchain must be recreated upon resize or minimization, among other cases
*/
void Graphics::Engine::recreateSwapchain() {

	width = 0;
	height = 0;
	while (width == 0 || height == 0) {
		glfwGetFramebufferSize(window, &width, &height);
		glfwWaitEvents();
	}

	device.waitIdle();

	cleanupSwapchain();
	createSwapchain();
	createFramebuffers();
	createFrameResources();
	vkInit::commandBufferInputChunk commandBufferInput = { device, commandPool, swapchainFrames };
	vkInit::make_frame_command_buffers(commandBufferInput);
}

void Graphics::Engine::createDescriptorSetLayouts() {

	//Binding once per frame
	vkInit::descriptorSetLayoutData bindings;
	bindings.count = 1;

	bindings.indices.push_back(0);
	bindings.types.push_back(vk::DescriptorType::eUniformBuffer);
	bindings.counts.push_back(1);
	bindings.stages.push_back(vk::ShaderStageFlagBits::eVertex);

	frameSetLayout[pipelineType::SKY] = vkInit::make_descriptor_set_layout(device, bindings);

	bindings.count = 2;

	bindings.indices.push_back(1);
	bindings.types.push_back(vk::DescriptorType::eStorageBuffer);
	bindings.counts.push_back(1);
	bindings.stages.push_back(vk::ShaderStageFlagBits::eVertex);
	
	frameSetLayout[pipelineType::STANDARD] = vkInit::make_descriptor_set_layout(device, bindings);

	//Binding for individual draw calls
	bindings.count = 1;

	bindings.indices[0] = 0;
	bindings.types[0] = vk::DescriptorType::eCombinedImageSampler;
	bindings.counts[0] = 1;
	bindings.stages[0] = vk::ShaderStageFlagBits::eFragment;

	meshSetLayout[pipelineType::SKY] = vkInit::make_descriptor_set_layout(device, bindings);
	meshSetLayout[pipelineType::STANDARD] = vkInit::make_descriptor_set_layout(device, bindings);
}

void Graphics::Engine::createPipelines() {

	vkInit::PipelineBuilder pipelineBuilder(device);

	//Sky
	pipelineBuilder.set_overwrite_mode(false);
	pipelineBuilder.specify_vertex_shader("Graphics/shaders/sky_vertex.spv");
	pipelineBuilder.specify_fragment_shader("Graphics/shaders/sky_fragment.spv");
	pipelineBuilder.specify_swapchain_extent(swapchainExtent);
	pipelineBuilder.clear_depth_attachment();
	pipelineBuilder.add_descriptor_set_layout(frameSetLayout[pipelineType::SKY]);
	pipelineBuilder.add_descriptor_set_layout(meshSetLayout[pipelineType::SKY]);
	pipelineBuilder.add_color_attachment(swapchainFormat, 0);

	vkInit::GraphicsPipelineOutBundle output = pipelineBuilder.build();

	pipelineLayout[pipelineType::SKY] = output.layout;
	renderpass[pipelineType::SKY] = output.renderpass;
	pipeline[pipelineType::SKY] = output.pipeline;
	pipelineBuilder.reset();

	//Standard
	pipelineBuilder.set_overwrite_mode(true);
	pipelineBuilder.specify_vertex_format(
		vkMesh::Vertex::getBindingDescription(),
		vkMesh::Vertex::getAttributeDescriptions());
	pipelineBuilder.specify_vertex_shader("Graphics/shaders/vertex.spv");
	pipelineBuilder.specify_fragment_shader("Graphics/shaders/fragment.spv");
	pipelineBuilder.specify_swapchain_extent(swapchainExtent);
	pipelineBuilder.specify_depth_attachment(swapchainFrames[0].depthFormat, 1);
	pipelineBuilder.add_descriptor_set_layout(frameSetLayout[pipelineType::STANDARD]);
	pipelineBuilder.add_descriptor_set_layout(meshSetLayout[pipelineType::STANDARD]);
	pipelineBuilder.add_color_attachment(swapchainFormat, 0);

	output = pipelineBuilder.build();

	pipelineLayout[pipelineType::STANDARD] = output.layout;
	renderpass[pipelineType::STANDARD] = output.renderpass;
	pipeline[pipelineType::STANDARD] = output.pipeline;
}

/**
* Make a framebuffer for each frame
*/
void Graphics::Engine::createFramebuffers() {

	vkInit::framebufferInput frameBufferInput;
	frameBufferInput.device = device;
	frameBufferInput.renderpass = renderpass;
	frameBufferInput.swapchainExtent = swapchainExtent;
	vkInit::make_framebuffers(frameBufferInput, swapchainFrames);
}

void Graphics::Engine::finalizeSetup() {

	createFramebuffers();

	commandPool = vkInit::make_command_pool(device, physicalDevice, surface);

	vkInit::commandBufferInputChunk commandBufferInput = { device, commandPool, swapchainFrames };
	mainCommandBuffer = vkInit::make_command_buffer(commandBufferInput);
	vkInit::make_frame_command_buffers(commandBufferInput);

	createFrameResources();
}

void Graphics::Engine::createFrameResources() {

	vkInit::descriptorSetLayoutData bindings;
	bindings.count = 2;
	bindings.types.push_back(vk::DescriptorType::eUniformBuffer);
	bindings.types.push_back(vk::DescriptorType::eStorageBuffer);
	uint32_t descriptor_sets_per_frame = 2;

	frameDescriptorPool = vkInit::make_descriptor_pool(device, static_cast<uint32_t>(swapchainFrames.size() * descriptor_sets_per_frame), bindings);

	for (vkUtil::SwapChainFrame& frame : swapchainFrames) {

		frame.imageAvailable = vkInit::make_semaphore(device);
		frame.renderFinished = vkInit::make_semaphore(device);
		frame.inFlight = vkInit::make_fence(device);

		frame.make_descriptor_resources();

		frame.descriptorSet[pipelineType::SKY] = vkInit::allocate_descriptor_set(device, frameDescriptorPool, frameSetLayout[pipelineType::SKY]);
		frame.descriptorSet[pipelineType::STANDARD] = vkInit::allocate_descriptor_set(device, frameDescriptorPool, frameSetLayout[pipelineType::STANDARD]);

		frame.record_write_operations();
	}
}

void Graphics::Engine::createWorkerThreads() {

	done = false;
	size_t threadCount = std::thread::hardware_concurrency() - 1;

	workers.reserve(threadCount);
	vkInit::commandBufferInputChunk commandBufferInput = { device, commandPool, swapchainFrames };
	for (size_t i = 0; i < threadCount; ++i) {
		vk::CommandBuffer commandBuffer = vkInit::make_command_buffer(commandBufferInput);
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

	std::cout << "Threads ended successfully." << std::endl;
}

void Graphics::Engine::createAssets(Game::AssetPack assetPack) {

	//Meshes
	meshes = new vkMesh::VertexMenagerie();
	std::unordered_map<std::string, Meshloader::Mesh_Loader*> loaded_models;

	//Make a descriptor pool to allocate sets.
	vkInit::descriptorSetLayoutData bindings;
	bindings.count = 1;
	bindings.types.push_back(vk::DescriptorType::eCombinedImageSampler);

	meshDescriptorPool = vkInit::make_descriptor_pool(device, static_cast<uint32_t>(assetPack.texture_filenames.size()) + 1, bindings);

	//Submit loading work
	workQueue.lock.lock();
	for (int i = 0; i < assetPack.objectTypes.size(); i++) {
		vkImage::TextureInputChunk textureInfo;
		textureInfo.logicalDevice = device;
		textureInfo.physicalDevice = physicalDevice;
		textureInfo.layout = meshSetLayout[pipelineType::STANDARD];
		textureInfo.descriptorPool = meshDescriptorPool;
		textureInfo.filenames.push_back("assets/textures/" + assetPack.texture_filenames[i]);
		materials[assetPack.objectTypes[i]] = new vkImage::Texture();
		loaded_models[assetPack.objectTypes[i]] = vkMesh::createMeshLoader("assets/models/", assetPack.model_filenames[i], assetPack.preTransforms[i]);
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
	for (std::pair<std::string, Meshloader::Mesh_Loader*> pair : loaded_models) {
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
	textureInfo.filenames.push_back("assets/textures/sky_front.png");
	textureInfo.filenames.push_back("assets/textures/sky_back.png");
	textureInfo.filenames.push_back("assets/textures/sky_right.png");
	textureInfo.filenames.push_back("assets/textures/sky_left.png");
	textureInfo.filenames.push_back("assets/textures/sky_top.png");
	textureInfo.filenames.push_back("assets/textures/sky_bottom.png");
	cubemap = new vkImage::CubeMap(textureInfo);
}

void Graphics::Engine::loadAssets(Game::AssetPack assetPack) {
	createWorkerThreads();
	createAssets(assetPack);
	endWorkerThreads();
}

void Graphics::Engine::prepareFrame(uint32_t imageIndex, Game::Scene* scene) {

	vkUtil::SwapChainFrame& _frame = swapchainFrames[imageIndex];

	Game::CameraView cameraViewData = scene->getCamera()->getCameraViewData();
	Game::CameraVectors cameraVectorData;
	cameraVectorData.forward = { cameraViewData.forward.x, cameraViewData.forward.y, cameraViewData.forward.z, 0.0 };
	cameraVectorData.right = { cameraViewData.right.x,   cameraViewData.right.y,   cameraViewData.right.z, 0.0 };
	cameraVectorData.up = { cameraViewData.up.x,      cameraViewData.up.y,      cameraViewData.up.z, 0.0 };
	memcpy(_frame.cameraVectorWriteLocation, &(cameraVectorData), sizeof(Game::CameraVectors));

	glm::mat4 view = glm::lookAt(cameraViewData.eye, cameraViewData.center, cameraViewData.up);

	glm::mat4 projection = glm::perspective(glm::radians(45.0), static_cast<double>(swapchainExtent.width) / static_cast<double>(swapchainExtent.height), 0.1, 1000.0);
	projection[1][1] *= -1;

	Game::CameraMatrices cameraMatrixData;
	cameraMatrixData.view = view;
	cameraMatrixData.projection = projection;
	cameraMatrixData.viewProjection = projection * view;
	memcpy(_frame.cameraMatrixWriteLocation, &(cameraMatrixData), sizeof(Game::CameraMatrices));

	size_t i = 0;
	for (std::pair<std::string, std::vector<Entitys::Entity*>> pair : scene->getMappedObjects()) {
		for (Entitys::Entity* obj : pair.second) {
			_frame.modelTransforms[i++] = obj->getPhysicsObject()->translationMatrix;
		}
	}
	memcpy(_frame.modelBufferWriteLocation, _frame.modelTransforms.data(), i * sizeof(glm::f64mat4));

	_frame.write_descriptor_set();
}

void Graphics::Engine::prepareScene(vk::CommandBuffer commandBuffer) {

	vk::Buffer vertexBuffers[] = { meshes->vertexBuffer.buffer };
	vk::DeviceSize offsets[] = { 0 };
	commandBuffer.bindVertexBuffers(0, 1, vertexBuffers, offsets);
	commandBuffer.bindIndexBuffer(meshes->indexBuffer.buffer, 0, vk::IndexType::eUint32);
}

void Graphics::Engine::recordDrawCommandsSky(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene) {

	vk::RenderPassBeginInfo renderPassInfo = {};
	renderPassInfo.renderPass = renderpass[pipelineType::SKY];
	renderPassInfo.framebuffer = swapchainFrames[imageIndex].framebuffer[pipelineType::SKY];
	renderPassInfo.renderArea.offset.x = 0;
	renderPassInfo.renderArea.offset.y = 0;
	renderPassInfo.renderArea.extent = swapchainExtent;

	vk::ClearValue colorClear;
	std::array<float, 4> colors = { 1.0f, 0.5f, 0.25f, 1.0f };

	std::vector<vk::ClearValue> clearValues = { {colorClear} };

	renderPassInfo.clearValueCount = clearValues.size();
	renderPassInfo.pClearValues = clearValues.data();

	commandBuffer.beginRenderPass(&renderPassInfo, vk::SubpassContents::eInline);

	commandBuffer.bindPipeline(vk::PipelineBindPoint::eGraphics, pipeline[pipelineType::SKY]);

	commandBuffer.bindDescriptorSets(vk::PipelineBindPoint::eGraphics, pipelineLayout[pipelineType::SKY], 0, swapchainFrames[imageIndex].descriptorSet[pipelineType::SKY], nullptr);

	cubemap->use(commandBuffer, pipelineLayout[pipelineType::SKY]);
	commandBuffer.draw(6, 1, 0, 0);

	commandBuffer.endRenderPass();
}

void Graphics::Engine::recordDrawCommandsScene(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene) {

	vk::RenderPassBeginInfo renderPassInfo = {};
	renderPassInfo.renderPass = renderpass[pipelineType::STANDARD];
	renderPassInfo.framebuffer = swapchainFrames[imageIndex].framebuffer[pipelineType::STANDARD];
	renderPassInfo.renderArea.offset.x = 0;
	renderPassInfo.renderArea.offset.y = 0;
	renderPassInfo.renderArea.extent = swapchainExtent;

	vk::ClearValue colorClear;
	std::array<float, 4> colors = { 1.0f, 0.5f, 0.25f, 1.0f };
	colorClear.color = vk::ClearColorValue(colors);
	vk::ClearValue depthClear;

	depthClear.depthStencil = vk::ClearDepthStencilValue({ 1.0f, 0 });
	std::vector<vk::ClearValue> clearValues = { {colorClear,depthClear} };

	renderPassInfo.clearValueCount = 2;
	renderPassInfo.pClearValues = clearValues.data();

	commandBuffer.beginRenderPass(&renderPassInfo, vk::SubpassContents::eInline);

	commandBuffer.bindPipeline(vk::PipelineBindPoint::eGraphics, pipeline[pipelineType::STANDARD]);

	commandBuffer.bindDescriptorSets(vk::PipelineBindPoint::eGraphics, pipelineLayout[pipelineType::STANDARD], 0, swapchainFrames[imageIndex].descriptorSet[pipelineType::STANDARD], nullptr);

	prepareScene(commandBuffer);

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

	device.waitForFences(1, &(swapchainFrames[frameNumber].inFlight), VK_TRUE, UINT64_MAX);
	device.resetFences(1, &(swapchainFrames[frameNumber].inFlight));

	uint32_t imageIndex;
	try {
		vk::ResultValue acquire = device.acquireNextImageKHR(
			swapchain, UINT64_MAX,
			swapchainFrames[frameNumber].imageAvailable, nullptr
		);
		imageIndex = acquire.value;
	}
	catch (vk::OutOfDateKHRError error) {
		std::cout << "Recreate" << std::endl;
		recreateSwapchain();
		return;
	}
	catch (vk::IncompatibleDisplayKHRError error) {
		std::cout << "Recreate" << std::endl;
		recreateSwapchain();
		return;
	}
	catch (vk::SystemError error) {
		std::cout << "Failed to acquire swapchain image!" << std::endl;
	}

	vk::CommandBuffer commandBuffer = swapchainFrames[frameNumber].commandBuffer;

	commandBuffer.reset();

	prepareFrame(imageIndex, scene);

	vk::CommandBufferBeginInfo beginInfo = {};

	try {
		commandBuffer.begin(beginInfo);
	}
	catch (vk::SystemError err) {
		vkLogging::Logger::get_logger()->print("Failed to begin recording command buffer!");
	}

	recordDrawCommandsSky(commandBuffer, imageIndex, scene);
	recordDrawCommandsScene(commandBuffer, imageIndex, scene);

	try {
		commandBuffer.end();
	}
	catch (vk::SystemError err) {

		vkLogging::Logger::get_logger()->print("failed to record command buffer!");
	}

	vk::SubmitInfo submitInfo = {};

	vk::Semaphore waitSemaphores[] = { swapchainFrames[frameNumber].imageAvailable };
	vk::PipelineStageFlags waitStages[] = { vk::PipelineStageFlagBits::eColorAttachmentOutput };
	submitInfo.waitSemaphoreCount = 1;
	submitInfo.pWaitSemaphores = waitSemaphores;
	submitInfo.pWaitDstStageMask = waitStages;

	submitInfo.commandBufferCount = 1;
	submitInfo.pCommandBuffers = &commandBuffer;

	vk::Semaphore signalSemaphores[] = { swapchainFrames[frameNumber].renderFinished };
	submitInfo.signalSemaphoreCount = 1;
	submitInfo.pSignalSemaphores = signalSemaphores;

	try {
		graphicsQueue.submit(submitInfo, swapchainFrames[frameNumber].inFlight);
	}
	catch (vk::SystemError err) {
		vkLogging::Logger::get_logger()->print("failed to submit draw command buffer!");
	}

	vk::PresentInfoKHR presentInfo = {};
	presentInfo.waitSemaphoreCount = 1;
	presentInfo.pWaitSemaphores = signalSemaphores;

	vk::SwapchainKHR swapChains[] = { swapchain };
	presentInfo.swapchainCount = 1;
	presentInfo.pSwapchains = swapChains;

	presentInfo.pImageIndices = &imageIndex;

	vk::Result present;

	try {
		present = presentQueue.presentKHR(presentInfo);
	}
	catch (vk::OutOfDateKHRError error) {
		present = vk::Result::eErrorOutOfDateKHR;
	}

	if (present == vk::Result::eErrorOutOfDateKHR || present == vk::Result::eSuboptimalKHR) {
		std::cout << "Recreate" << std::endl;
		recreateSwapchain();
		return;
	}

	frameNumber = (frameNumber + 1) % maxFramesInFlight;
}

/**
* Free the memory associated with the swapchain objects
*/
void Graphics::Engine::cleanupSwapchain() {

	for (vkUtil::SwapChainFrame& frame : swapchainFrames) {
		frame.destroy();
	}
	device.destroySwapchainKHR(swapchain);

	device.destroyDescriptorPool(frameDescriptorPool);
}

Graphics::Engine::~Engine() {

	device.waitIdle();

	vkLogging::Logger::get_logger()->print("Goodbye see you!");

	device.destroyCommandPool(commandPool);

	for (pipelineType pipeline_type : pipelineTypes) {
		device.destroyPipeline(pipeline[pipeline_type]);
		device.destroyPipelineLayout(pipelineLayout[pipeline_type]);
		device.destroyRenderPass(renderpass[pipeline_type]);
	}

	cleanupSwapchain();
	for (pipelineType pipeline_type : pipelineTypes) {
		device.destroyDescriptorSetLayout(frameSetLayout[pipeline_type]);
		device.destroyDescriptorSetLayout(meshSetLayout[pipeline_type]);
	}
	device.destroyDescriptorPool(meshDescriptorPool);

	delete meshes;

	for (const auto& [key, texture] : materials) {
		delete texture;
	}
	delete cubemap;

	device.destroy();

	instance.destroySurfaceKHR(surface);
	if (vkLogging::Logger::get_logger()->get_debug_mode()) {
		instance.destroyDebugUtilsMessengerEXT(debugMessenger, nullptr, dldi);
	}
	/*
	* from vulkan_funcs.hpp:
	*
	* void Instance::destroy( Optional<const VULKAN_HPP_NAMESPACE::AllocationCallbacks> allocator = nullptr,
											Dispatch const & d = ::vk::getDispatchLoaderStatic())
	*/
	instance.destroy();

	//terminate glfw
	glfwTerminate();
}
