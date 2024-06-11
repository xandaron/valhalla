#pragma once
#include "../../../cfg.h"
#include "../vkUtil/frame.h"
#include "../../control/logging.h"

namespace vkInit {
	/**
	* Data structures involved in making framebuffers for the swapchain.
	*/
	struct framebufferInput {
		vk::Device device;
		vk::Extent2D swapchainExtent;
		std::unordered_map<pipelineType, vk::RenderPass> renderpass;
	};

	/**
	* Create framebuffers for the swapchain.
	*
	* @param inputChunk          Required input for creation.
	* @param swapchainImageViews The vector to be populated with the created framebuffers.
	*/
	void createFramebuffers(framebufferInput inputChunk, std::vector<vkUtil::SwapchainImageView>& swapchainImageViews);
}