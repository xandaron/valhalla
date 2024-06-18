#include "image_views.h"
#include "../vkImage/image.h"

inline vk::ImageViewCreateInfo vkInit::createImageViewCreateInfo(
	vk::Image image, vk::Format format, vk::ImageViewType type, vk::ImageAspectFlagBits aspect, uint32_t layerCount
)
{
	/*
	* ImageViewCreateInfo(
	*	vk::ImageViewCreateFlags  flags_			= {},
	*	vk::Image                 image_			= {},
	*	vk::ImageViewType         viewType_			= vk::ImageViewType::e1D,
	*	vk::Format                format_			= vk::Format::eUndefined,
	*	vk::ComponentMapping	  components_       = {},
	*	vk::ImageSubresourceRange subresourceRange_ = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return{
		vk::ImageViewCreateFlagBits(),
		image,
		type,
		format,
		/**
		* ComponentMapping(
		*	vk::ComponentSwizzle r_ = vk::ComponentSwizzle::eIdentity,
		*	vk::ComponentSwizzle g_ = vk::ComponentSwizzle::eIdentity,
		*	vk::ComponentSwizzle b_ = vk::ComponentSwizzle::eIdentity,
		*	vk::ComponentSwizzle a_ = vk::ComponentSwizzle::eIdentity
		* ) VULKAN_HPP_NOEXCEPT
		*/
		{
			vk::ComponentSwizzle::eIdentity,
			vk::ComponentSwizzle::eIdentity,
			vk::ComponentSwizzle::eIdentity,
			vk::ComponentSwizzle::eIdentity
		},
		/**
		* ImageSubresourceRange(
		*	vk::ImageAspectFlags aspectMask_	 = {},
		*	uint32_t             baseMipLevel_   = {},
		*	uint32_t             levelCount_     = {},
		*	uint32_t             baseArrayLayer_ = {},
		*	uint32_t             layerCount_     = {}
		* ) VULKAN_HPP_NOEXCEPT
		*/
		{
			aspect,
			0,
			1,
			0,
			layerCount
		}
	};
}

std::vector<vkUtil::SwapchainImageView> vkInit::createImageViews(
	vk::Device device, vk::SwapchainKHR swapchain, vk::Format format
) {
	std::vector<vk::Image> images = device.getSwapchainImagesKHR(swapchain);
	std::vector<vkUtil::SwapchainImageView> frames(images.size());
	for (size_t i = 0; i < images.size(); i++) {
		frames[i].image = images[i];
		try {
			frames[i].imageView = device.createImageView(createImageViewCreateInfo(
				images[i], format, vk::ImageViewType::e2D, vk::ImageAspectFlagBits::eColor, 1
			));
		}
		catch (vk::SystemError err) {
			throw std::runtime_error(std::format("Failed to create image view. Reason:\n\t{}", err.what()).c_str());
		}
	}
	return frames;
}
