#include "engine.h"
#include "vkInit/instance.h"
#include "vkInit/device.h"
#include "vkInit/swapchain.h"
#include "vkInit/pipeline.h"
#include "vkInit/framebuffer.h"
#include "vkInit/commands.h"
#include "vkInit/sync.h"
#include "vkInit/descriptors.h"
#include "vkMesh/mesh.h"
#include "vkMesh/obj_mesh.h"

Graphics::Engine::Engine(int width, int height, GLFWwindow* window) {

	this->width = width;
	this->height = height;
	this->window = window;

	vkLogging::Logger::get_logger()->print("Making a graphics engine...");

	make_instance();

	make_device();

	make_descriptor_set_layouts();
	make_pipelines();

	finalize_setup();

	vkUtil::CameraView cameraVectors;

	cameraVectors.eye	   = { -1.0f,  0.0f, 5.0f };
	cameraVectors.center   = {  0.0f,  0.0f, 5.0f };
	cameraVectors.forwards = {  1.0f,  0.0f, 0.0f };
	cameraVectors.right	   = {  0.0f, -1.0f, 0.0f };
	cameraVectors.up	   = {  0.0f,  0.0f, 1.0f };

	camera = new vkUtil::Camera(cameraVectors);
}

void Graphics::Engine::make_instance() {

	instance = vkInit::make_instance("Not KSP");
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

void Graphics::Engine::make_device() {

	physicalDevice = vkInit::choose_physical_device(instance);
	device = vkInit::create_logical_device(physicalDevice, surface);
	std::array<vk::Queue, 2> queues = vkInit::get_queues(physicalDevice, device, surface);
	graphicsQueue = queues[0];
	presentQueue = queues[1];
	make_swapchain();
	frameNumber = 0;
}

/**
* Make a swapchain
*/
void Graphics::Engine::make_swapchain() {

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
void Graphics::Engine::recreate_swapchain() {

	width = 0;
	height = 0;
	while (width == 0 || height == 0) {
		glfwGetFramebufferSize(window, &width, &height);
		glfwWaitEvents();
	}

	device.waitIdle();

	cleanup_swapchain();
	make_swapchain();
	make_framebuffers();
	make_frame_resources();
	vkInit::commandBufferInputChunk commandBufferInput = { device, commandPool, swapchainFrames };
	vkInit::make_frame_command_buffers(commandBufferInput);
}

void Graphics::Engine::make_descriptor_set_layouts() {

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

void Graphics::Engine::make_pipelines() {

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
		vkMesh::getPosColorBindingDescription(),
		vkMesh::getPosColorAttributeDescriptions());
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
void Graphics::Engine::make_framebuffers() {

	vkInit::framebufferInput frameBufferInput;
	frameBufferInput.device = device;
	frameBufferInput.renderpass = renderpass;
	frameBufferInput.swapchainExtent = swapchainExtent;
	vkInit::make_framebuffers(frameBufferInput, swapchainFrames);
}

void Graphics::Engine::finalize_setup() {

	make_framebuffers();

	commandPool = vkInit::make_command_pool(device, physicalDevice, surface);

	vkInit::commandBufferInputChunk commandBufferInput = { device, commandPool, swapchainFrames };
	mainCommandBuffer = vkInit::make_command_buffer(commandBufferInput);
	vkInit::make_frame_command_buffers(commandBufferInput);

	make_frame_resources();
}

void Graphics::Engine::make_frame_resources() {

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

void Graphics::Engine::make_worker_threads() {

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

void Graphics::Engine::end_worker_threads() {

	done = true;
	size_t threadCount = std::thread::hardware_concurrency() - 1;

	for (size_t i = 0; i < threadCount; ++i) {
		workers[i].join();
	}

	std::cout << "Threads ended successfully." << std::endl;
}

void Graphics::Engine::make_assets(Game::AssetPack assetPack)
{

	std::vector<std::string> objectTypes = assetPack.objectTypes;
	std::unordered_map<std::string, std::vector<const char*>> model_filenames = assetPack.model_filenames;
	std::unordered_map<std::string, std::vector<const char*>> texture_filenames = assetPack.texture_filenames;
	std::unordered_map<std::string, glm::mat4> preTransforms = assetPack.preTransforms;

	//Meshes
	meshes = new VertexMenagerie();
	std::unordered_map<std::string, vkMesh::ObjMesh> loaded_models;
	
	//Make a descriptor pool to allocate sets.
	vkInit::descriptorSetLayoutData bindings;
	bindings.count = 1;
	bindings.types.push_back(vk::DescriptorType::eCombinedImageSampler);

	meshDescriptorPool = vkInit::make_descriptor_pool(device, static_cast<uint32_t>(texture_filenames.size()) + 1, bindings);

	//Submit loading work
	workQueue.lock.lock();
	for (std::string type : objectTypes) {
		vkImage::TextureInputChunk textureInfo;
		textureInfo.logicalDevice = device;
		textureInfo.physicalDevice = physicalDevice;
		textureInfo.layout = meshSetLayout[pipelineType::STANDARD];
		textureInfo.descriptorPool = meshDescriptorPool;
		textureInfo.filenames = texture_filenames[type];
		materials[type] = new vkImage::Texture();
		loaded_models[type] = vkMesh::ObjMesh();
		workQueue.add(
			new vkJob::MakeTexture(materials[type], textureInfo)
		);
		workQueue.add(
			new vkJob::MakeModel(loaded_models[type],
				model_filenames[type][0], 
				model_filenames[type][1],
				preTransforms[type])
		);
	}
	workQueue.lock.unlock();

	//Work will be done by the background threads,
	//we just need to wait.
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
	for (std::pair<std::string, vkMesh::ObjMesh> pair : loaded_models) {
		meshes->consume(pair.first, pair.second.vertices, pair.second.indices);
	}

	vertexBufferFinalizationChunk finalizationInfo;
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
	textureInfo.filenames = { {
			"textures/sky_front.png",  //x+
			"textures/sky_back.png",   //x-
			"textures/sky_right.png",  //y+
			"textures/sky_left.png",   //y-
			"textures/sky_top.png",    //z+
			"textures/sky_bottom.png", //z-
	} };
	cubemap = new vkImage::CubeMap(textureInfo);
}

void Graphics::Engine::load_assets(Game::AssetPack assetPack) {
	make_worker_threads();
	make_assets(assetPack);
	end_worker_threads();
}

void Graphics::Engine::prepare_frame(uint32_t imageIndex, Game::Scene* scene) {

	vkUtil::SwapChainFrame& _frame = swapchainFrames[imageIndex];

	vkUtil::CameraView cameraViewData = camera->cameraViewData;
	vkUtil::CameraVectors cameraVectorData;
	cameraVectorData.forwards = { cameraViewData.forwards.x, cameraViewData.forwards.y, cameraViewData.forwards.z, 0 };
	cameraVectorData.right	  = {    cameraViewData.right.x,    cameraViewData.right.y,    cameraViewData.right.z, 0 };
	cameraVectorData.up		  = {       cameraViewData.up.x,       cameraViewData.up.y,       cameraViewData.up.z, 0 };
	memcpy(_frame.cameraVectorWriteLocation, &(cameraVectorData), sizeof(vkUtil::CameraVectors));

	glm::mat4 view = glm::lookAt(cameraViewData.eye, cameraViewData.center, cameraViewData.up);

	glm::mat4 projection = glm::perspective(glm::radians(45.0f), static_cast<float>(swapchainExtent.width) / static_cast<float>(swapchainExtent.height), 0.1f, 100.0f);
	projection[1][1] *= -1;

	vkUtil::CameraMatrices cameraMatrixData;
	cameraMatrixData.view = view;
	cameraMatrixData.projection = projection;
	cameraMatrixData.viewProjection = projection * view;
	memcpy(_frame.cameraMatrixWriteLocation, &(cameraMatrixData), sizeof(vkUtil::CameraMatrices));

	size_t i = 0;
	for (std::pair<std::string, std::vector<std::vector<PhysicsData::Vector3D<double>*>>> pair : scene->positions) {
		for (std::vector<PhysicsData::Vector3D<double>*> position : pair.second) {
			_frame.modelTransforms[i++] = glm::translate(glm::mat4(1.0), position[0]->toGlm())
										* glm::rotate(glm::mat4(1.0), (float)glm::radians(position[1]->x), glm::vec3(1, 0, 0))
										* glm::rotate(glm::mat4(1.0), (float)glm::radians(position[1]->y), glm::vec3(0, 1, 0))
										* glm::rotate(glm::mat4(1.0), (float)glm::radians(position[1]->z), glm::vec3(0, 0, 1));
		}
	}
	memcpy(_frame.modelBufferWriteLocation, _frame.modelTransforms.data(), i * sizeof(glm::mat4));

	_frame.write_descriptor_set();
}

void Graphics::Engine::prepare_scene(vk::CommandBuffer commandBuffer) {

	vk::Buffer vertexBuffers[] = { meshes->vertexBuffer.buffer };
	vk::DeviceSize offsets[] = { 0 };
	commandBuffer.bindVertexBuffers(0, 1, vertexBuffers, offsets);
	commandBuffer.bindIndexBuffer(meshes->indexBuffer.buffer, 0, vk::IndexType::eUint32);
}

void Graphics::Engine::record_draw_commands_sky(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene) {

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

void Graphics::Engine::record_draw_commands_scene(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene) {

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

	prepare_scene(commandBuffer);

	uint32_t startInstance = 0;
	for (std::pair<std::string, std::vector<std::vector<PhysicsData::Vector3D<double>*>>> pair : scene->positions) {
		render_objects(
			commandBuffer, pair.first, startInstance, static_cast<uint32_t>(pair.second.size())
		);
	}

	commandBuffer.endRenderPass();
}

void Graphics::Engine::render_objects(vk::CommandBuffer commandBuffer, std::string objectType, uint32_t& startInstance, uint32_t instanceCount) {

	int indexCount = meshes->indexCounts.find(objectType)->second;
	int firstIndex = meshes->firstIndices.find(objectType)->second;
	materials[objectType]->use(commandBuffer, pipelineLayout[pipelineType::STANDARD]);
	commandBuffer.drawIndexed(indexCount, instanceCount, firstIndex, 0, startInstance);
	startInstance += instanceCount;
}

void Graphics::Engine::render(Game::Scene* scene) {

	device.waitForFences(1, &(swapchainFrames[frameNumber].inFlight), VK_TRUE, UINT64_MAX);
	device.resetFences(1, &(swapchainFrames[frameNumber].inFlight));

	//acquireNextImageKHR(vk::SwapChainKHR, timeout, semaphore_to_signal, fence)
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
		recreate_swapchain();
		return;
	}
	catch (vk::IncompatibleDisplayKHRError error) {
		std::cout << "Recreate" << std::endl;
		recreate_swapchain();
		return;
	}
	catch (vk::SystemError error) {
		std::cout << "Failed to acquire swapchain image!" << std::endl;
	}

	vk::CommandBuffer commandBuffer = swapchainFrames[frameNumber].commandBuffer;

	commandBuffer.reset();

	prepare_frame(imageIndex, scene);

	vk::CommandBufferBeginInfo beginInfo = {};

	try {
		commandBuffer.begin(beginInfo);
	}
	catch (vk::SystemError err) {
		vkLogging::Logger::get_logger()->print("Failed to begin recording command buffer!");
	}

	record_draw_commands_sky(commandBuffer, imageIndex, scene);
	record_draw_commands_scene(commandBuffer, imageIndex, scene);

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
		recreate_swapchain();
		return;
	}

	frameNumber = (frameNumber + 1) % maxFramesInFlight;
}

/**
* Free the memory associated with the swapchain objects
*/
void Graphics::Engine::cleanup_swapchain() {

	for (vkUtil::SwapChainFrame& frame : swapchainFrames) {
		frame.destroy();
	}
	device.destroySwapchainKHR(swapchain);

	device.destroyDescriptorPool(frameDescriptorPool);
}

vkUtil::Camera* Graphics::Engine::getCameraPointer() {
	return camera;
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

	cleanup_swapchain();
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