#include "command_pool.h"

vk::CommandPool vkInit::createCommandPool(vk::Device device, vk::PhysicalDevice physicalDevice, vk::SurfaceKHR surface) {
	vkUtil::QueueFamilyIndices queueFamilyIndices = vkUtil::findQueueFamilies(physicalDevice, surface);
	/**
	* CommandPoolCreateInfo(
	*	vk::CommandPoolCreateFlags flags_            = {},
    *	uint32_t                   queueFamilyIndex_ = {},
    *	const void *               pNext_            = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::CommandPoolCreateInfo poolInfo{
		vk::CommandPoolCreateFlags() | vk::CommandPoolCreateFlagBits::eResetCommandBuffer,
		queueFamilyIndices.graphicsFamily.value(),
		nullptr
	};

	try {
		Debug::Logger::log(Debug::MESSAGE, "Allocating main command buffer.");
		return device.createCommandPool(poolInfo);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to create command pool. Reason:\n\t{}", err.what()).c_str());
	}
}

vk::CommandBuffer vkInit::createCommandBuffer(commandBufferInputChunk inputChunk) {
	/**
	* CommandBufferAllocateInfo(
	*	vk::CommandPool        commandPool_ = {},
    *	vk::CommandBufferLevel level_              = vk::CommandBufferLevel::ePrimary,
    *	uint32_t               commandBufferCount_ = {},
    *	const void *           pNext_              = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::CommandBufferAllocateInfo allocInfo{
		inputChunk.commandPool,
		vk::CommandBufferLevel::ePrimary,
		1,
		nullptr
	};

	try {
		Debug::Logger::log(Debug::MESSAGE, "Allocating main command buffer.");
		return inputChunk.device.allocateCommandBuffers(allocInfo)[0];
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to allocate main command buffer. Reason:\n\t{}", err.what()).c_str());
	}
}

void vkInit::createFrameCommandBuffers(commandBufferInputChunk inputChunk) {
	/**
	* CommandBufferAllocateInfo(
	*	vk::CommandPool        commandPool_		   = {},
    *	vk::CommandBufferLevel level_			   = vk::CommandBufferLevel::ePrimary,
    *	uint32_t               commandBufferCount_ = {},
    *	const void *           pNext_              = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::CommandBufferAllocateInfo allocInfo{
		inputChunk.commandPool,
		vk::CommandBufferLevel::ePrimary,
		1,
		nullptr
	};

	for (int i = 0; i < inputChunk.frames.size(); ++i) {
		try {
			inputChunk.frames[i].commandBuffer = inputChunk.device.allocateCommandBuffers(allocInfo)[0];
			Debug::Logger::log(Debug::MESSAGE, std::format("Allocated command buffer for frame {}.", i));
		}
		catch (vk::SystemError err) {
			throw std::runtime_error(std::format("Failed to allocate command buffer for frame {}. Reason:\n\t{}", i, err.what()).c_str());
		}
	}
}