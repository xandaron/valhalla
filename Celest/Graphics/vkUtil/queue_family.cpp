#include "queue_family.h"

vkUtil::QueueFamilyIndices vkUtil::findQueueFamilies(vk::PhysicalDevice device, vk::SurfaceKHR surface) {
	QueueFamilyIndices indices;
	std::vector<vk::QueueFamilyProperties> queueFamilies = device.getQueueFamilyProperties();
	for (int i = 0; i < static_cast<uint32_t>(queueFamilies.size()); i++) {
		/**
		* QueueFamilyProperties(
		*	vk::QueueFlags queueFlags_                  = {},
		*	uint32_t       queueCount_                  = {},
		*	uint32_t       timestampValidBits_          = {},
		*	vk::Extent3D   minImageTransferGranularity_ = {}
		* ) VULKAN_HPP_NOEXCEPT
		*
		* typedef enum VkQueueFlagBits {
		*	VK_QUEUE_GRAPHICS_BIT       = 0x00000001,
		*	VK_QUEUE_COMPUTE_BIT        = 0x00000002,
		*	VK_QUEUE_TRANSFER_BIT       = 0x00000004,
		*	VK_QUEUE_SPARSE_BINDING_BIT = 0x00000008,
		* } VkQueueFlagBits;
		*/
		if ((queueFamilies[i].queueFlags & vk::QueueFlagBits::eGraphics) 
			&& (queueFamilies[i].queueFlags & vk::QueueFlagBits::eCompute)) {
			indices.graphicsFamily = i;
		}
		if (device.getSurfaceSupportKHR(i, surface)) {
			indices.presentFamily = i;
		}
		if (indices.isComplete()) {
			break;
		}
	}
	return indices;
}