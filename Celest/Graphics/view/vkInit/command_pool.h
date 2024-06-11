#pragma once
#include "../../../cfg.h"
#include "../vkUtil/queue_family.h"
#include "../vkUtil/frame.h"

namespace vkInit {

	/**
	* Data structures used in creating command buffers
	*/
	struct commandBufferInputChunk {
		vk::Device device;
		vk::CommandPool commandPool;
		std::vector<vkUtil::SwapchainImageView>& frames;
	};

	/**
	* Make a command pool.
	*
	* @param device         The logical device.
	* @param physicalDevice The physical device.
	* @param surface        The windows surface (used for getting the queue families).
	* 
	* @return The created command pool.
	*/
	vk::CommandPool createCommandPool(vk::Device device, vk::PhysicalDevice physicalDevice, vk::SurfaceKHR surface);

	/**
	* Make a main command buffer.
	*
	* @param inputChunk The required input info.
	* 
	* @return The main command buffer.
	*/
	vk::CommandBuffer createCommandBuffer(commandBufferInputChunk inputChunk);

	/**
	* Make a command buffer for each frame
	*
	* @param inputChunk the required input info
	*/
	void createFrameCommandBuffers(commandBufferInputChunk inputChunk);
}