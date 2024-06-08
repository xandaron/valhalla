#include "swap_chain.h"
#include "../vkImage/image.h"
#include "../vkUtil/queue_family.h"

vkInit::SwapchainBundle vkInit::createSwapchain(vk::Device logicalDevice, vk::PhysicalDevice physicalDevice,
	vk::SurfaceKHR surface, vk::Extent2D extent, vk::SwapchainKHR oldSwapchain
) {
	SwapchainSupportDetails support = querySwapchainSupport(physicalDevice, surface);
	vk::SurfaceFormatKHR format = chooseSwapchainSurfaceFormat(support.formats);
	vk::PresentModeKHR presentMode = chooseSwapchainPresentMode(support.presentModes);
	extent = chooseSwapchainExtent(extent, support.capabilities);
	uint32_t imageCount = std::min(
		support.capabilities.maxImageCount,
		support.capabilities.minImageCount + 1
	);
	if (support.capabilities.maxImageCount == 0) {
		imageCount = support.capabilities.minImageCount + 1;
	}
	/**
	* VULKAN_HPP_CONSTEXPR SwapchainCreateInfoKHR(
	*	 vk::SwapchainCreateFlagsKHR	 flags_				    = {},
	*	 vk::SurfaceKHR					 surface_			    = {},
	*	 uint32_t						 minImageCount_		    = {},
	*	 vk::Format						 imageFormat_		    = vk::Format::eUndefined,
	*	 vk::ColorSpaceKHR				 imageColorSpace_	    = vk::ColorSpaceKHR::eSrgbNonlinear,
	*	 vk::Extent2D					 imageExtent_		    = {},
	*	 uint32_t						 imageArrayLayers_	    = {},
	*	 vk::ImageUsageFlags			 imageUsage_			= {},
	*	 vk::SharingMode				 imageSharingMode_	    = vk::SharingMode::eExclusive,
	*	 uint32_t						 queueFamilyIndexCount_ = {},
	*	 const uint32_t *				 pQueueFamilyIndices_   = {},
	*	 vk::SurfaceTransformFlagBitsKHR preTransform_		    = vk::SurfaceTransformFlagBitsKHR::eIdentity,
	*	 vk::CompositeAlphaFlagBitsKHR	 compositeAlpha_	    = vk::CompositeAlphaFlagBitsKHR::eOpaque,
	*	 vk::PresentModeKHR				 presentMode_		    = vk::PresentModeKHR::eImmediate,
	*	 vk::Bool32						 clipped_			    = {},
	*	 vk::SwapchainKHR				 oldSwapchain_		    = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::SwapchainCreateInfoKHR createInfo{
		vk::SwapchainCreateFlagsKHR(),
		surface,
		imageCount,
		format.format,
		format.colorSpace,
		extent,
		1,
		vk::ImageUsageFlagBits::eColorAttachment,
		vk::SharingMode::eExclusive,
		{},
		{},
		support.capabilities.currentTransform,
		vk::CompositeAlphaFlagBitsKHR::eOpaque,
		presentMode,
		VK_TRUE,
		oldSwapchain
	};
	vkUtil::QueueFamilyIndices indices = vkUtil::findQueueFamilies(physicalDevice, surface);
	uint32_t queueFamilyIndices[] = { indices.graphicsFamily.value(), indices.presentFamily.value() };
	if (indices.graphicsFamily != indices.presentFamily) {
		createInfo.imageSharingMode = vk::SharingMode::eConcurrent;
		createInfo.queueFamilyIndexCount = 2;
		createInfo.pQueueFamilyIndices = queueFamilyIndices;
	}
	else {
		createInfo.imageSharingMode = vk::SharingMode::eExclusive;
	}
	
	try {
		return {
			logicalDevice.createSwapchainKHR(createInfo),
			format.format,
			extent
		};
	}
	catch (vk::SystemError err) {
		throw std::runtime_error("Failed to create swapchain!");
	}
}

inline vkInit::SwapchainSupportDetails vkInit::querySwapchainSupport(vk::PhysicalDevice device, vk::SurfaceKHR surface) {
	/**
	* typedef struct VkSurfaceCapabilitiesKHR {
	*	uint32_t                         minImageCount;
	*	uint32_t                         maxImageCount;
	*	VkExtent2D                       currentExtent;
	*	VkExtent2D                       minImageExtent;
	*	VkExtent2D                       maxImageExtent;
	*	uint32_t                         maxImageArrayLayers;
	*	VkSurfaceTransformFlagsKHR       supportedTransforms;
	*	VkSurfaceTransformFlagBitsKHR    currentTransform;
	*	VkCompositeAlphaFlagsKHR         supportedCompositeAlpha;
	*	VkImageUsageFlags                supportedUsageFlags;
	* } VkSurfaceCapabilitiesKHR;
	*/
	return{
		device.getSurfaceCapabilitiesKHR(surface),
		device.getSurfaceFormatsKHR(surface),
		device.getSurfacePresentModesKHR(surface)
	};
}

vk::SurfaceFormatKHR vkInit::chooseSwapchainSurfaceFormat(std::vector<vk::SurfaceFormatKHR> formats) {
	for (vk::SurfaceFormatKHR format : formats) {
		if (format.format == vk::Format::eB8G8R8A8Unorm
			&& format.colorSpace == vk::ColorSpaceKHR::eSrgbNonlinear) {
			return format;
		}
	}
	return formats[0];
}

vk::PresentModeKHR vkInit::chooseSwapchainPresentMode(std::vector<vk::PresentModeKHR> presentModes) {
	for (vk::PresentModeKHR presentMode : presentModes) {
		if (presentMode == vk::PresentModeKHR::eMailbox) {
			return presentMode;
		}
	}
	return vk::PresentModeKHR::eFifo;
}

vk::Extent2D vkInit::chooseSwapchainExtent(vk::Extent2D extent, vk::SurfaceCapabilitiesKHR capabilities) {
	if (capabilities.currentExtent.width != UINT32_MAX) {
		return capabilities.currentExtent;
	}
	else {
		extent.width = std::min(
			capabilities.maxImageExtent.width,
			std::max(capabilities.minImageExtent.width, extent.width)
		);
		extent.height = std::min(
			capabilities.maxImageExtent.height,
			std::max(capabilities.minImageExtent.height, extent.height)
		);
		return extent;
	}
}