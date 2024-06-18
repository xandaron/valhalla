#pragma once
#include "../vkCfg.h"


namespace vkInit {
	/**
	* Make a semaphore.
	*
	* @param device The logical device.
	* 
	* @return The created semaphore.
	*/
	vk::Semaphore makeSemaphore(vk::Device device);

	/**
	* Make a fence.
	*
	* @param device The logical device.
	*
	* @return The created fence.
	*/
	vk::Fence makeFence(vk::Device device);
}