#pragma once 
#include "../../cfg.h"
#include "../model/vertex_menagerie.h"
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

		~Engine();

		void load_assets(Game::AssetPack assetPackage);

		void render(Game::Scene* scene);

	private:
		//glfw-related variables
		int width;
		int height;
		GLFWwindow* window;

		//instance-related variables
		vk::Instance instance{ nullptr };
		vk::DebugUtilsMessengerEXT debugMessenger{ nullptr };
		vk::DispatchLoaderDynamic dldi;
		vk::SurfaceKHR surface;

		//device-related variables
		vk::PhysicalDevice physicalDevice{ nullptr };
		vk::Device device{ nullptr };
		vk::Queue graphicsQueue{ nullptr };
		vk::Queue presentQueue{ nullptr };
		vk::SwapchainKHR swapchain{ nullptr };
		std::vector<vkUtil::SwapChainFrame> swapchainFrames;
		vk::Format swapchainFormat;
		vk::Extent2D swapchainExtent;

		//pipeline-related variables
		std::vector<pipelineType> pipelineTypes = { {pipelineType::SKY, pipelineType::STANDARD} };
		std::unordered_map<pipelineType, vk::PipelineLayout> pipelineLayout;
		std::unordered_map <pipelineType, vk::RenderPass> renderpass;
		std::unordered_map <pipelineType, vk::Pipeline> pipeline;

		//descriptor-related variables
		std::unordered_map <pipelineType, vk::DescriptorSetLayout> frameSetLayout;
		vk::DescriptorPool frameDescriptorPool; //Descriptors bound on a "per frame" basis
		std::unordered_map <pipelineType, vk::DescriptorSetLayout> meshSetLayout;
		vk::DescriptorPool meshDescriptorPool; //Descriptors bound on a "per mesh" basis

		//Command-related variables
		vk::CommandPool commandPool;
		vk::CommandBuffer mainCommandBuffer;

		//Synchronization objects
		int maxFramesInFlight, frameNumber;

		//asset pointers
		VertexMenagerie* meshes;
		std::unordered_map<std::string, vkImage::Texture*> materials;
		vkImage::CubeMap* cubemap;

		//Job System
		bool done = false;
		vkJob::WorkQueue workQueue;
		std::vector<std::thread> workers;

		//instance setup
		void make_instance();

		//device setup
		void make_device();
		void make_swapchain();
		void recreate_swapchain();

		//pipeline setup
		void make_descriptor_set_layouts();
		void make_pipelines();

		//final setup steps
		void finalize_setup();
		void make_framebuffers();
		void make_frame_resources();

		//asset creation
		void make_worker_threads();
		void end_worker_threads();
		void make_assets(Game::AssetPack assetPack);

		void prepare_frame(uint32_t imageIndex, Game::Scene* scene);
		void prepare_scene(vk::CommandBuffer commandBuffer);
		void record_draw_commands_sky(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene);
		void record_draw_commands_scene(vk::CommandBuffer commandBuffer, uint32_t imageIndex, Game::Scene* scene);
		void render_objects(vk::CommandBuffer commandBuffer, std::string objectType, uint32_t& startInstance, uint32_t instanceCount);

		//Cleanup functions
		void cleanup_swapchain();
	};
}