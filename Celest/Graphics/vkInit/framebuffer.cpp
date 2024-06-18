#include "framebuffer.h"

void vkInit::createFramebuffers(framebufferInput inputChunk, std::vector<vkUtil::SwapchainImageView>& swapchainImageViews) {
	for (int i = 0; i < swapchainImageViews.size(); i++) {
		std::vector<vk::ImageView> attachments{
			swapchainImageViews[i].imageView
		};
		/**
		* FramebufferCreateInfo(
		*	vk::FramebufferCreateFlags flags_           = {},
        *	vk::RenderPass             renderPass_      = {},
        *	uint32_t                   attachmentCount_ = {},
        *	const vk::ImageView *      pAttachments_    = {},
        *	uint32_t                   width_           = {},
        *	uint32_t                   height_          = {},
        *	uint32_t                   layers_          = {},
        *	const void *               pNext_           = nullptr
		* ) VULKAN_HPP_NOEXCEPT
		*/
		vk::FramebufferCreateInfo framebufferInfo{
			vk::FramebufferCreateFlags(),
			inputChunk.renderpass[pipelineType::SKY],
			static_cast<uint32_t>(attachments.size()),
			attachments.data(),
			inputChunk.swapchainExtent.width,
			inputChunk.swapchainExtent.height,
			1,
			nullptr
		};

		try {
			Debug::Logger::log(Debug::MESSAGE, std::format("Creating sky framebuffer for image view {}.", i));
			swapchainImageViews[i].framebuffer[pipelineType::SKY] = inputChunk.device.createFramebuffer(framebufferInfo);
		}
		catch (vk::SystemError err) {
			throw std::runtime_error(std::format("Failed to create framebuffer. Reason\n\t{}", i, err.what()).c_str());
		}

		framebufferInfo.renderPass = inputChunk.renderpass[pipelineType::STANDARD];
		attachments.push_back(swapchainImageViews[i].depthBufferView);
		framebufferInfo.attachmentCount = attachments.size();
		framebufferInfo.pAttachments = attachments.data();

		try {
			Debug::Logger::log(Debug::MESSAGE, std::format("Creating standard framebuffer for image view {}.", i));
			swapchainImageViews[i].framebuffer[pipelineType::STANDARD] = inputChunk.device.createFramebuffer(framebufferInfo);
		}
		catch (vk::SystemError err) {
			Debug::Logger::log(Debug::MINOR_ERROR, std::format("Failed to create framebuffer. Reason\n\t{}", i, err.what()));
		}
	}
}