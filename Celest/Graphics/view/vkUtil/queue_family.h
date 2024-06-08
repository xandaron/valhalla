#pragma once
#include "../../cfg.h"
#include <optional>

namespace vkUtil {

	struct QueueFamilyIndices {
		std::optional<uint32_t> graphicsFamily;
		std::optional<uint32_t> presentFamily;

		bool isComplete() {
			return graphicsFamily.has_value() && presentFamily.has_value();
		}
	};

	/**
	* Find suitable queue family indices on the given physical device.
	*
	* @param device The physical device to check
	*
	* @return A struct holding the queue family indices
	*/
	QueueFamilyIndices findQueueFamilies(vk::PhysicalDevice device, vk::SurfaceKHR surface);
}