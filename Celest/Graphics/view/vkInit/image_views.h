#pragma once
#include "../../cfg.h"
#include "../vkUtil/frame.h"

namespace vkInit {
	inline vk::ImageViewCreateInfo createImageViewCreateInfo(vk::Image image, vk::Format format,
		vk::ImageViewType type, vk::ImageAspectFlagBits aspect, uint32_t layerCount);

	std::vector<vkUtil::SwapchainImageView> createImageViews(vk::Device device,
		vk::SwapchainKHR swapchain, vk::Format format);
}