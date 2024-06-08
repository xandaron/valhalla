#pragma once 
#include "../../cfg.h"
#include "vkMesh/vertex_menagerie.h"
#include "vkUtil/frame.h"
#include "vkImage/texture.h"
#include "vkImage/cubemap.h"
#include "vkJob/job.h"
#include "vkJob/worker_thread.h"
#include "../../Game/camera.h"
#include "../../Game/scene.h"
#include "../../Game/entity.h"

namespace Graphics {

	class Engine {
	public:
		Engine(int width, int height, GLFWwindow* window, Game::Camera* camera);
		
		void loadAssets(Game::AssetPack assetPackage);

		void render(Game::Scene* scene);

		~Engine();

	private:
		//GLFW variables
		int width;
		int height;
		GLFWwindow* window;

		//Instance variables
		vk::Instance instance{ nullptr };
		vk::DebugUtilsMessengerEXT debugMessenger{ nullptr };
		vk::DispatchLoaderDynamic dldi;
		vk::SurfaceKHR surface;

		//Device variables
		vk::PhysicalDevice physicalDevice{ nullptr };
		vk::Device device{ nullptr };
		vk::Queue graphicsQueue{ nullptr };
		vk::Queue presentQueue{ nullptr };
		vk::SwapchainKHR swapchain{ nullptr };
		std::vector<vkUtil::SwapchainFrame> swapchainImageViews;
		vk::Format swapchainFormat;
		vk::Extent2D swapchainExtent;

		//Pipeline variables
		std::vector<pipelineType> pipelineTypes = { {pipelineType::SKY, pipelineType::STANDARD} };
		std::unordered_map<pipelineType, vk::PipelineLayout> pipelineLayout;
		std::unordered_map<pipelineType, vk::RenderPass> renderpass;
		std::unordered_map<pipelineType, vk::Pipeline> pipeline;

		//Descriptor variables
		std::unordered_map<pipelineType, vk::DescriptorSetLayout> frameSetLayout;
		vk::DescriptorPool frameDescriptorPool; //Descriptors bound on a "per frame" basis
		std::unordered_map<pipelineType, vk::DescriptorSetLayout> meshSetLayout;
		vk::DescriptorPool meshDescriptorPool; //Descriptors bound on a "per mesh" basis

		//Command variables
		vk::CommandPool commandPool;
		vk::CommandBuffer mainCommandBuffer;

		//Synchronization objects
		int maxFramesInFlight, frameNumber;

		//Asset pointers
		vkMesh::VertexMenagerie* meshes;
		std::unordered_map<std::string, vkImage::Texture*> materials;
		vkImage::CubeMap* cubemap;

		//Job System
		bool done = false;
		vkJob::WorkQueue workQueue;
		std::vector<std::thread> workers;

		/**
		* Creates an instance.
		*
		* @throws std::runtime_error if instance creation fails.
		*/
		void createInstance();

		/**
		* Creates a Vulkan debug messenger for validation layers.
		*/
		void createDebugMessenger();

		/**
		* Creates a GLFW surface.
		*
		* @throws std::runtime_error when GLFW fails to create a surface.
		*/
		void createSurface();

		/**
		* Creates physical and logical devices as well and assigning queue families.
		*
		* @throws std::runtime_error Couldn't create physical or logical device.
		*/
		void createDevice();

		/**
		* Creates a swap chain.
		* 
		* @throws std::runtime_error Couldn't create a swap chain.
		*/
		void createSwapchain();

		/**
		* Destroys old swap chain and creates a new one.
		* 
		* @throws std::runtime_error Couldn't create new swap chain.
		*/
		void recreateSwapchain();

		void createImageViews();

		//pipeline setup
		void createDescriptorSetLayouts();
		void createPipelines();

		//final setup steps
		void finalizeSetup();
		void createFramebuffers();
		void createFrameResources();

		//asset creation
		void createWorkerThreads();
		void endWorkerThreads();
		void createAssets(Game::AssetPack assetPack);

		void prepareFrame(uint32_t imageIndex, Game::Scene* scene);
		void prepareScene(vk::CommandBuffer commandBuffer);
		void recordDrawCommandsSky(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene);
		void recordDrawCommandsScene(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene);
		void renderObjects(vk::CommandBuffer commandBuffer, std::string objectType, uint32_t& startInstance, uint32_t instanceCount);

		//Cleanup functions
		void cleanupSwapchain();
	};
}