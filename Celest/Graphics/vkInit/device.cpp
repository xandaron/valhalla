#include "device.h"
#include "swapchain.h"
#include <map>

vk::PhysicalDevice vkInit::choosePhysicalDevice(const vk::Instance& instance, const vk::SurfaceKHR& surface) {
	std::vector<vk::PhysicalDevice> availableDevices = instance.enumeratePhysicalDevices();

	Debug::Logger::log(Debug::MESSAGE, std::format("{} physical devices available.", availableDevices.size()));
	if (availableDevices.size() == 0) {
		throw std::runtime_error("No GPU with Vulkan support found.");
	}

	std::multimap<uint32_t, VkPhysicalDevice> candidates;
	for (vk::PhysicalDevice device : availableDevices) {
		uint32_t score = rateDeviceSuitability(device, surface);
		candidates.insert(std::make_pair(score, device));
	}

	if (candidates.rbegin()->first > 0) {
		return candidates.rbegin()->second;
	}

	Debug::Logger::log(Debug::MAJOR_ERROR, "No suitable GPU found!");
	throw std::runtime_error("No suitable GPU found.");
}

uint32_t vkInit::rateDeviceSuitability(const vk::PhysicalDevice& device, const vk::SurfaceKHR& surface) {
	const std::vector<const char*> requestedExtensions = {
		VK_KHR_SWAPCHAIN_EXTENSION_NAME
	};

	vk::PhysicalDeviceProperties deviceProperties = device.getProperties();
	vk::PhysicalDeviceFeatures deviceFeatures = device.getFeatures();

	SwapchainSupportDetails swapchainSupport = querySwapchainSupport(device, surface);
	bool swapchainAdequate = !swapchainSupport.formats.empty() && !swapchainSupport.presentModes.empty();
	if (!swapchainAdequate || !deviceFeatures.geometryShader || !checkDeviceExtensionSupport(device, requestedExtensions)) {
		return 0;
	}

	uint32_t score = 0;
	if (deviceProperties.deviceType == vk::PhysicalDeviceType::eDiscreteGpu) {
		score += 1000;
	}
	return score + deviceProperties.limits.maxImageDimension2D;
}

bool vkInit::checkDeviceExtensionSupport(const vk::PhysicalDevice& device, const std::vector<const char*>& requestedExtensions) {
	std::set<std::string> requiredExtensions(requestedExtensions.begin(), requestedExtensions.end());
	for (vk::ExtensionProperties& extension : device.enumerateDeviceExtensionProperties()) {
		requiredExtensions.erase(extension.extensionName);
	}
	return requiredExtensions.empty();
}

vk::Device vkInit::createLogicalDevice(vk::PhysicalDevice physicalDevice, vk::SurfaceKHR surface) {
	vkUtil::QueueFamilyIndices indices = vkUtil::findQueueFamilies(physicalDevice, surface);
	std::vector<uint32_t> uniqueIndices = { indices.graphicsFamily.value() };
	if (indices.graphicsFamily.value() != indices.presentFamily.value()) {
		uniqueIndices.push_back(indices.presentFamily.value());
	}
	size_t length = uniqueIndices.size();
	/**
	* VULKAN_HPP_CONSTEXPR DeviceQueueCreateInfo( 
	*	vk::DeviceQueueCreateFlags flags_            = {},
	*	uint32_t                   queueFamilyIndex_ = {},
	*	uint32_t                   queueCount_       = {},
	*	const float*               pQueuePriorities_ = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	std::vector<vk::DeviceQueueCreateInfo> queueCreateInfo(length);
	float queuePriority = 1.0f;
	for (int i = 0; i < length; i++) {
		queueCreateInfo[i] = {
			vk::DeviceQueueCreateInfo(
				vk::DeviceQueueCreateFlags(),
				uniqueIndices[i],
				1,
				&queuePriority
			)
		};
	}
	vk::PhysicalDeviceFeatures deviceFeatures = vk::PhysicalDeviceFeatures();
	std::vector<const char*> deviceExtensions = {
		VK_KHR_SWAPCHAIN_EXTENSION_NAME
	};
	std::vector<const char*> enabledLayers = { "VK_LAYER_KHRONOS_validation" };
	/*
	* VULKAN_HPP_CONSTEXPR DeviceCreateInfo(
	*	VULKAN_HPP_NAMESPACE::DeviceCreateFlags				 flags_                   = {},
	*	uint32_t											 queueCreateInfoCount_    = {},
	*	const VULKAN_HPP_NAMESPACE::DeviceQueueCreateInfo *  pQueueCreateInfos_		  = {},
	*	uint32_t                                             enabledLayerCount_		  = {},
	*	const char * const *								 ppEnabledLayerNames_     = {},
	*	uint32_t											 enabledExtensionCount_   = {},
	*	const char * const *								 ppEnabledExtensionNames_ = {},
	*	const VULKAN_HPP_NAMESPACE::PhysicalDeviceFeatures * pEnabledFeatures_		  = {})
	*/
	vk::DeviceCreateInfo deviceInfo{
		vk::DeviceCreateFlags(),
		static_cast<uint32_t>(queueCreateInfo.size()),
		queueCreateInfo.data(),
		static_cast<uint32_t>(enabledLayers.size()),
		enabledLayers.data(),
		static_cast<uint32_t>(deviceExtensions.size()),
		deviceExtensions.data(),
		&deviceFeatures
	};

	try {
		return physicalDevice.createDevice(deviceInfo);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to create logical device! Reason:\n\t{}", err.what()).c_str());
	}
}
