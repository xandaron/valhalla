#pragma once
#include <vulkan/vulkan.hpp>
#include <GLFW/glfw3.h>

#include <thread>
#include <mutex>

#include "../cfg.h"

/**
*	Data structures used for creating buffers
*	and allocating memory
*/
struct BufferInputChunk {
	size_t size;
	vk::BufferUsageFlags usage;
	vk::Device logicalDevice;
	vk::PhysicalDevice physicalDevice;
	vk::MemoryPropertyFlags memoryProperties;
};

/**
*	holds a vulkan buffer and memory allocation
*/
struct Buffer {
	vk::Buffer buffer;
	vk::DeviceMemory bufferMemory;
};

enum class pipelineType {
	SKY,
	STANDARD
};