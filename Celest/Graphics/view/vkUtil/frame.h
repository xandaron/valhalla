#pragma once
#include "../../../cfg.h"
#include "../../../Game/camera.h"

namespace vkUtil {

	/**
		Holds the data structures associated with a "Frame"
	*/
	class SwapchainImageView {
	public:
		//For doing work
		vk::Device logicalDevice;
		vk::PhysicalDevice physicalDevice;

		//Swapchain-type stuff
		vk::Image image;
		vk::ImageView imageView;
		std::unordered_map<pipelineType, vk::Framebuffer> framebuffer;
		vk::Image depthBuffer;
		vk::DeviceMemory depthBufferMemory;
		vk::ImageView depthBufferView;
		vk::Format depthFormat;
		int width, height;

		vk::CommandBuffer commandBuffer;

		//Sync objects
		vk::Semaphore imageAvailable, renderFinished;
		vk::Fence inFlight;

		//Resources
		Game::CameraMatrices cameraMatrixData;
		Buffer cameraMatrixBuffer;
		void* cameraMatrixWriteLocation;

		Game::CameraVectors cameraVectorData;
		Buffer cameraVectorBuffer;
		void* cameraVectorWriteLocation;

		std::vector<glm::mat4> modelTransforms;
		Buffer modelBuffer;
		void* modelBufferWriteLocation;

		//Resource Descriptors
		vk::DescriptorBufferInfo cameraVectorDescriptor, cameraMatrixDescriptor, ssboDescriptor;
		std::unordered_map<pipelineType, vk::DescriptorSet> descriptorSet;

		//Write Operations
		std::vector<vk::WriteDescriptorSet> writeOps;

		void makeDescriptorResources();

		void recordWriteOperations();

		void makeDepthResources();

		void writeDescriptorSet();

		void destroy();
	};
}