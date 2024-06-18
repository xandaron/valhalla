#pragma once
#include "../vkCfg.h"
#include "../vkUtil/queue_family.h"

namespace vkInit {
	

	/**
	* Choose a physical device for the vulkan instance.
	*
	* @param  instance The vulkan instance to use.
	*
	* @return	The chosen physical device.
	*
	* @throws std::runtime_error if no usable device is found.
	*/
	vk::PhysicalDevice choosePhysicalDevice(const vk::Instance& instance, const vk::SurfaceKHR& surface);

	/**
	* Check whether the given physical device is suitable for use.
	*
	* @param device The physical device
	*
	* @return Whether the device is suitable
	*/
	uint32_t rateDeviceSuitability(const vk::PhysicalDevice& device, const vk::SurfaceKHR& surface);

	/**
	* Check whether the physical device can support the given extensions.
	*
	* @param device			   The physical device to check.
	* @param requestedExtensions A list of extension names to check against.
	*
	* @return Whether all of the requested extensions are supported by the device
	*/
	bool checkDeviceExtensionSupport(const vk::PhysicalDevice& device, const std::vector<const char*>& requestedExtensions);
	
	/**
	* Create a Vulkan device
	*
	* @param physicalDevice The Physical Device to represent
	* @param surface		  The window surface
	*
	* @return The created device
	*
	* @throws std::runtime_error If a logical device could not be created.
	*/
	vk::Device createLogicalDevice(vk::PhysicalDevice physicalDevice, vk::SurfaceKHR surface);
}