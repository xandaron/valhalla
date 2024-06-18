#pragma once 
#include "vkCfg.h"
#include "vkMesh/vertex_menagerie.h"
#include "vkUtil/frame.h"
#include "vkImage/texture.h"
#include "vkImage/cubemap.h"
#include "vkJob/job.h"
#include "vkJob/worker_thread.h"
#include "../Game/camera.h"
#include "../Game/scene.h"
#include "../Game/entity.h"

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
		vk::Instance instance;
		vk::DebugUtilsMessengerEXT debugMessenger;
		vk::DispatchLoaderDynamic dldi;
		vk::SurfaceKHR surface;

		//Device variables
		vk::PhysicalDevice physicalDevice;
		vk::Device device;
		vk::Queue graphicsQueue;
		vk::Queue presentQueue;
		vk::SwapchainKHR swapchain;
		std::vector<vkUtil::SwapchainImageView> swapchainImageViews;
		vk::Format swapchainFormat;
		vk::Extent2D swapchainExtent;

		//Pipeline variables
		std::vector<pipelineType> pipelineTypes = { {pipelineType::SKY, pipelineType::STANDARD} };
		std::unordered_map<pipelineType, vk::PipelineLayout> pipelineLayout;
		std::unordered_map<pipelineType, vk::RenderPass> renderpass;
		std::unordered_map<pipelineType, vk::Pipeline> pipeline;
		std::unordered_map<pipelineType, std::vector<vk::PipelineShaderStageCreateInfo>> shaderStages;

		//Descriptor variables
		std::unordered_map<pipelineType, vk::DescriptorSetLayout> frameSetLayout;
		std::unordered_map<pipelineType, vk::DescriptorSetLayout> meshSetLayout;
		vk::DescriptorPool frameDescriptorPool;
		vk::DescriptorPool meshDescriptorPool;

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
		inline void createInstance();

		/**
		* Creates a Vulkan debug messenger for validation layers.
		*/
		inline void createDebugMessenger();

		/**
		* Creates a GLFW surface.
		*
		* @throws std::runtime_error when GLFW fails to create a surface.
		*/
		inline void createSurface();

		/**
		* Creates physical and logical devices as well and assigning queue families.
		*
		* @throws std::runtime_error Couldn't create physical or logical device.
		*/
		inline void createDevice();

		/**
		* Creates a swap chain.
		* 
		* @throws std::runtime_error Couldn't create a swap chain.
		*/
		inline void createSwapchain();

		/**
		* Destroys old swap chain and creates a new one.
		* 
		* @throws std::runtime_error Couldn't create new swap chain.
		*/
		void recreateSwapchain();

		inline void createImageViews();

		//pipeline setup
		inline void createDescriptorSetLayouts();

		inline void createPipelines();

		//final setup steps
		inline void createCommandPool();


		inline void createFramebuffers();
		inline void createFrameResources();

		//asset creation
		void createWorkerThreads();
		void endWorkerThreads();
		void createAssets(Game::AssetPack assetPack);

		void prepareFrame(uint32_t imageIndex, Game::Scene* scene);
		void prepareScene(vk::CommandBuffer commandBuffer);
		void recordDrawCommandsSky(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene);
		void recordDrawCommandsScene(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene);
		void renderObjects(vk::CommandBuffer commandBuffer, std::string objectType, uint32_t& startInstance, uint32_t instanceCount);

		inline vk::Viewport* createViewport(vk::Extent2D swapchainExtent);

		inline vk::Rect2D* createScissor(vk::Extent2D swapchainExtent);

		/**
		* Free the memory associated with the swapchain objects
		*/
		void cleanupSwapchain();
	};
}