#include "descriptors.h"
#include "../../control/logging.h"

inline vk::DescriptorSetLayoutCreateInfo vkInit::makeDescriptorSetLayoutCreateInfo(
	const std::vector<vk::DescriptorSetLayoutBinding>& layoutBindings
) {
	/**
	* DescriptorSetLayoutCreateInfo(
	*	vk::DescriptorSetLayoutCreateFlags    flags_        = {},
	*	uint32_t                              bindingCount_ = {},
	*	const vk::DescriptorSetLayoutBinding* pBindings_    = {},
	*	const void *                          pNext_        = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return {
			vk::DescriptorSetLayoutCreateFlagBits(),
			static_cast<uint32_t>(layoutBindings.size()),
			layoutBindings.data(),
			nullptr
	};
}

vk::DescriptorSetLayout vkInit::makeDescriptorSetLayout(
	vk::Device device, const descriptorSetLayoutData& bindings
) {
	std::vector<vk::DescriptorSetLayoutBinding> layoutBindings(bindings.count);
	for (int i = 0; i < bindings.count; i++) {
		/**
		* DescriptorSetLayoutBinding(
		*	uint32_t             binding_			 = {},
        *	vk::DescriptorType   descriptorType_	 = vk::DescriptorType::eSampler,
        *	uint32_t             descriptorCount_	 = {},
        *	vk::ShaderStageFlags stageFlags_		 = {},
        *	const vk::Sampler *  pImmutableSamplers_ = {}
		* ) VULKAN_HPP_NOEXCEPT
		*/
		layoutBindings[i] = {
			bindings.indices[i],
			bindings.types[i],
			bindings.counts[i],
			bindings.stages[i],
			{}
		};
	}

	try {
		return device.createDescriptorSetLayout(
			makeDescriptorSetLayoutCreateInfo(layoutBindings)
		);
	}
	catch (vk::SystemError err) {
		Debug::Logger::log(Debug::WARNING, "Failed to create Descriptor Set Layout.");
		return nullptr;
	}
}

vk::DescriptorPool vkInit::makeDescriptorPool(
	vk::Device device, uint32_t size, const descriptorSetLayoutData& bindings) {

	std::vector<vk::DescriptorPoolSize> poolSizes;
	/*
		typedef struct VkDescriptorPoolSize {
			VkDescriptorType    type;
			uint32_t            descriptorCount;
		} VkDescriptorPoolSize;
	*/

	for (int i = 0; i < bindings.count; i++) {

		vk::DescriptorPoolSize poolSize;
		poolSize.type = bindings.types[i];
		poolSize.descriptorCount = size;
		poolSizes.push_back(poolSize);
	}

	vk::DescriptorPoolCreateInfo poolInfo;
	/*
		typedef struct VkDescriptorPoolCreateInfo {
			VkStructureType                sType;
			const void*                    pNext;
			VkDescriptorPoolCreateFlags    flags;
			uint32_t                       maxSets;
			uint32_t                       poolSizeCount;
			const VkDescriptorPoolSize*    pPoolSizes;
		} VkDescriptorPoolCreateInfo;
	*/

	poolInfo.flags = vk::DescriptorPoolCreateFlags();
	poolInfo.maxSets = size;
	poolInfo.poolSizeCount = static_cast<uint32_t>(poolSizes.size());
	poolInfo.pPoolSizes = poolSizes.data();

	try {
		return device.createDescriptorPool(poolInfo);
	}
	catch (vk::SystemError err) {
		vkLogging::Logger::get_logger()->print("Failed to make descriptor pool");
		return nullptr;
	}
}

vk::DescriptorSet vkInit::allocateDescriptorSet(
	vk::Device device, vk::DescriptorPool descriptorPool,
	vk::DescriptorSetLayout layout) {

	vk::DescriptorSetAllocateInfo allocationInfo;
	/*
		typedef struct VkDescriptorSetAllocateInfo {
			VkStructureType                 sType;
			const void*                     pNext;
			VkDescriptorPool                descriptorPool;
			uint32_t                        descriptorSetCount;
			const VkDescriptorSetLayout*    pSetLayouts;
		} VkDescriptorSetAllocateInfo;
	*/

	allocationInfo.descriptorPool = descriptorPool;
	allocationInfo.descriptorSetCount = 1;
	allocationInfo.pSetLayouts = &layout;

	try {
		return device.allocateDescriptorSets(allocationInfo)[0];
	}
	catch (vk::SystemError err) {
		vkLogging::Logger::get_logger()->print("Failed to allocate descriptor set from pool");
		return nullptr;
	}
}