#pragma once
#include "../../../cfg.h"
#include "../vkUtil/frame.h"

namespace vkInit {

	/**
	* Holds properties of the swapchain.
	* capabilities: no. of images and supported sizes.
	* formats: eg. supported pixel formats.
	* present modes: available presentation modes (eg. double buffer, fifo, mailbox).
	*/
	struct SwapchainSupportDetails {
		vk::SurfaceCapabilitiesKHR capabilities;
		std::vector<vk::SurfaceFormatKHR> formats;
		std::vector<vk::PresentModeKHR> presentModes;
	};

	struct SwapchainBundle {
		vk::SwapchainKHR swapchain;
		vk::Format format;
		vk::Extent2D extent;
	};

	/**
	* Create a swapchain.
	*
	* @param logicalDevice  The logical device.
	* @param physicalDevice The physical device.
	* @param surface        The window surface to use the swapchain with.
	* @param width          The requested width.
	* @param height         The requested height.
	*
	* @return a struct holding the swapchain and other associated data structures.
	*
	* @throws std::runtime_error Couldn't create swap chain.
	*/
	SwapchainBundle createSwapchain(vk::Device logicalDevice, vk::PhysicalDevice physicalDevice, vk::SurfaceKHR surface, vk::Extent2D extent, vk::SwapchainKHR oldSwapchain);

	/**
	* Inline get supported swapchain parameters.
	*
	* @param device  The physical device.
	* @param surface The window surface which will use the swapchain.
	*
	* @return A struct holding the details.
	*/
	inline SwapchainSupportDetails querySwapchainSupport(vk::PhysicalDevice device, vk::SurfaceKHR surface);

	/**
	* Choose a surface format for the swapchain.
	*
	* @param formats A vector of surface formats supported by the device.
	*
	* @return the chosen format.
	*/
	vk::SurfaceFormatKHR chooseSwapchainSurfaceFormat(std::vector<vk::SurfaceFormatKHR> formats);

	/**
	* Choose a present mode.
	*
	* @param presentModes A vector of present modes supported by the device
	*
	* @return The chosen present mode
	*/
	vk::PresentModeKHR chooseSwapchainPresentMode(std::vector<vk::PresentModeKHR> presentModes);

	/**
	* Choose an extent for the swapchain.
	*
	* @param width        The requested width.
	* @param height       The requested height.
	* @param capabilities A struct describing the supported capabilities of the device.
	*
	* @return The chosen extent
	*/
	vk::Extent2D chooseSwapchainExtent(vk::Extent2D extent, vk::SurfaceCapabilitiesKHR capabilities);
}