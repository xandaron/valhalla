#include "sync.h"

vk::Semaphore vkInit::makeSemaphore(vk::Device device) {
	/**
	* SemaphoreCreateInfo(
	*	vk::SemaphoreCreateFlags flags_ = {},
	*	const void*				 pNext_ = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::SemaphoreCreateInfo semaphoreInfo{
		vk::SemaphoreCreateFlags(),
		nullptr
	};

	try {
		return device.createSemaphore(semaphoreInfo);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to create semaphore. Reason\n\t{}", err.what()).c_str());
	}
}

vk::Fence vkInit::makeFence(vk::Device device) {
	/**
	* FenceCreateInfo(
	*	vk::FenceCreateFlags flags_ = {},
	*	const void*          pNext_ = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::FenceCreateInfo fenceInfo{
		vk::FenceCreateFlags() | vk::FenceCreateFlagBits::eSignaled,
		nullptr
	};

	try {
		return device.createFence(fenceInfo);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to create fence. Reason:\n\t{}", err.what()).c_str());
	}
}
