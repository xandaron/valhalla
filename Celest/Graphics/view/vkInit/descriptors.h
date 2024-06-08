#pragma once
#include "../../../cfg.h"

namespace vkInit {
	/**
	* Describes the bindings of a descriptor set layout.
	*/
	struct descriptorSetLayoutData {
		int count;
		std::vector<uint32_t> indices;
		std::vector<vk::DescriptorType> types;
		std::vector<uint32_t> counts;
		std::vector<vk::ShaderStageFlags> stages;
	};

	/**
	* Inline make a vk::DesctiptorSetLayoutCreateInfo.
	*
	* @param count    The number of bindings.
	* @param bindings A struct describing the bindings used in the shader.
	*
	* @return The created descriptor set layout.
	*/
	inline vk::DescriptorSetLayoutCreateInfo makeDescriptorSetLayoutCreateInfo(
		const std::vector<vk::DescriptorSetLayoutBinding>& layoutBindings
	);

	/**
	* Make a descriptor set layout from the given descriptions.
	*
	* @param device   The logical device.
	* @param bindings A struct describing the bindings used in the shader.
	* 
	* @return The created descriptor set layout.
	*/
	vk::DescriptorSetLayout makeDescriptorSetLayout(
		vk::Device device, const descriptorSetLayoutData& bindings
	);

	/**
	* Make a descriptor pool.
	*
	* @param device   The logical device.
	* @param size     The number of descriptor sets to allocate from the pool.
	* @param bindings Used to get the descriptor types.
	* 
	* @return The created descriptor pool.
	*/
	vk::DescriptorPool makeDescriptorPool(
		vk::Device device, uint32_t size, const descriptorSetLayoutData& bindings
	);

	/**
	* Allocate a descriptor set from a pool.
	*
	* @param device         The logical device.
	* @param descriptorPool The pool to allocate from.
	* @param layout			The descriptor set layout which the set must adhere to.
	* 
	* @return The allocated descriptor set.
	*/
	vk::DescriptorSet allocateDescriptorSet(
		vk::Device device, vk::DescriptorPool descriptorPool,
		vk::DescriptorSetLayout layout);
}