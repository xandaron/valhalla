#include "image.h"
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include "../vkUtil/memory.h"
#include "../vkUtil/single_time_commands.h"
#include "../vkInit/descriptors.h"

vk::Image vkImage::makeImage(ImageInputChunk input) {
	/*
	* ImageCreateInfo(
	*	vk::ImageCreateFlags    flags_                 = {},
    *	vk::ImageType           imageType_             = vk::ImageType::e1D,
    *	vk::Format              format_                = vk::Format::eUndefined,
    *	vk::Extent3D            extent_                = {},
    *	uint32_t                mipLevels_             = {},
    *	uint32_t                arrayLayers_           = {},
    *	vk::SampleCountFlagBits samples_               = vk::SampleCountFlagBits::e1,
    *	vk::ImageTiling         tiling_                = vk::ImageTiling::eOptimal,
    *	vk::ImageUsageFlags     usage_                 = {},
    *	vk::SharingMode         sharingMode_           = vk::SharingMode::eExclusive,
    *	uint32_t                queueFamilyIndexCount_ = {},
    *	const uint32_t *        pQueueFamilyIndices_   = {},
    *	vk::ImageLayout         initialLayout_         = vk::ImageLayout::eUndefined,
    *	const void *            pNext_                 = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::ImageCreateInfo imageInfo{
		vk::ImageCreateFlagBits() | input.flags,
		vk::ImageType::e2D,
		input.format,
		vk::Extent3D(input.width, input.height, 1),
		1,
		input.arrayCount,
		vk::SampleCountFlagBits::e1,
		input.tiling,
		input.usage,
		vk::SharingMode::eExclusive,
		{},
		{},
		imageInfo.initialLayout = vk::ImageLayout::eUndefined,
		nullptr
	};
	
	try {
		return input.logicalDevice.createImage(imageInfo);
	}
	catch (vk::SystemError err) {
		Debug::Logger::log(Debug::WARNING, "Unable to make image.");
	}
}

vk::DeviceMemory vkImage::makeImageMemory(ImageInputChunk input, vk::Image image) {

	vk::MemoryRequirements requirements = input.logicalDevice.getImageMemoryRequirements(image);

	vk::MemoryAllocateInfo allocation;
	allocation.allocationSize = requirements.size;
	allocation.memoryTypeIndex = vkUtil::findMemoryTypeIndex(
		input.physicalDevice, requirements.memoryTypeBits, input.memoryProperties
	);

	try {
		vk::DeviceMemory imageMemory = input.logicalDevice.allocateMemory(allocation);
		input.logicalDevice.bindImageMemory(image, imageMemory, 0);
		return imageMemory;
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Unable to allocate memory for image. Reason:\n\t{}", err.what()).c_str());
	}
}

void vkImage::transitionImageLayout(ImageLayoutTransitionJob transitionJob) {

	vkUtil::startJob(transitionJob.commandBuffer);

	/*
	typedef struct VkImageSubresourceRange {
		VkImageAspectFlags    aspectMask;
		uint32_t              baseMipLevel;
		uint32_t              levelCount;
		uint32_t              baseArrayLayer;
		uint32_t              layerCount;
	} VkImageSubresourceRange;
	*/
	vk::ImageSubresourceRange access;
	access.aspectMask = vk::ImageAspectFlagBits::eColor;
	access.baseMipLevel = 0;
	access.levelCount = 1;
	access.baseArrayLayer = 0;
	access.layerCount = transitionJob.arrayCount;

	/*
	typedef struct VkImageMemoryBarrier {
		VkStructureType            sType;
		const void* pNext;
		VkAccessFlags              srcAccessMask;
		VkAccessFlags              dstAccessMask;
		VkImageLayout              oldLayout;
		VkImageLayout              newLayout;
		uint32_t                   srcQueueFamilyIndex;
		uint32_t                   dstQueueFamilyIndex;
		VkImage                    image;
		VkImageSubresourceRange    subresourceRange;
	} VkImageMemoryBarrier;
	*/
	vk::ImageMemoryBarrier barrier;
	barrier.oldLayout = transitionJob.oldLayout;
	barrier.newLayout = transitionJob.newLayout;
	barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
	barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
	barrier.image = transitionJob.image;
	barrier.subresourceRange = access;

	vk::PipelineStageFlags sourceStage, destinationStage;

	if (transitionJob.oldLayout == vk::ImageLayout::eUndefined
		&& transitionJob.newLayout == vk::ImageLayout::eTransferDstOptimal) {

		barrier.srcAccessMask = vk::AccessFlagBits::eNoneKHR;
		barrier.dstAccessMask = vk::AccessFlagBits::eTransferWrite;

		sourceStage = vk::PipelineStageFlagBits::eTopOfPipe;
		destinationStage = vk::PipelineStageFlagBits::eTransfer;
	}
	else {

		barrier.srcAccessMask = vk::AccessFlagBits::eTransferWrite;
		barrier.dstAccessMask = vk::AccessFlagBits::eShaderRead;

		sourceStage = vk::PipelineStageFlagBits::eTransfer;
		destinationStage = vk::PipelineStageFlagBits::eFragmentShader;
	}

	transitionJob.commandBuffer.pipelineBarrier(sourceStage, destinationStage, vk::DependencyFlags(), nullptr, nullptr, barrier);

	vkUtil::endJob(transitionJob.commandBuffer, transitionJob.queue);
}

void vkImage::copyBufferToImage(BufferImageCopyJob copyJob) {

	vkUtil::startJob(copyJob.commandBuffer);

	/*
	typedef struct VkBufferImageCopy {
		VkDeviceSize                bufferOffset;
		uint32_t                    bufferRowLength;
		uint32_t                    bufferImageHeight;
		VkImageSubresourceLayers    imageSubresource;
		VkOffset3D                  imageOffset;
		VkExtent3D                  imageExtent;
	} VkBufferImageCopy;
	*/
	vk::BufferImageCopy copy;
	copy.bufferOffset = 0;
	copy.bufferRowLength = 0;
	copy.bufferImageHeight = 0;

	vk::ImageSubresourceLayers access;
	access.aspectMask = vk::ImageAspectFlagBits::eColor;
	access.mipLevel = 0;
	access.baseArrayLayer = 0;
	access.layerCount = copyJob.arrayCount;
	copy.imageSubresource = access;

	copy.imageOffset = vk::Offset3D(0, 0, 0);
	copy.imageExtent = vk::Extent3D(
		copyJob.width,
		copyJob.height,
		1
	);

	copyJob.commandBuffer.copyBufferToImage(
		copyJob.srcBuffer, copyJob.dstImage, vk::ImageLayout::eTransferDstOptimal, copy
	);

	vkUtil::endJob(copyJob.commandBuffer, copyJob.queue);
}

//vk::ImageView vkImage::makeImageView(
//	vk::Device logicalDevice, vk::Image image, vk::Format format,
//	vk::ImageAspectFlags aspect, vk::ImageViewType type, uint32_t arrayCount) {
//	/*
//	* ImageViewCreateInfo( 
//	*	vk::ImageViewCreateFlags  flags_			= {},
//	*	vk::Image                 image_			= {},
//	*	vk::ImageViewType         viewType_			= vk::ImageViewType::e1D,
//	*	vk::Format                format_			= vk::Format::eUndefined,
//	*	vk::ComponentMapping	  components_       = {},
//	*	vk::ImageSubresourceRange subresourceRange_ = {}
//	* ) VULKAN_HPP_NOEXCEPT
//	*/
//	vk::ImageViewCreateInfo createInfo{
//		vk::ImageViewCreateFlagBits(),
//		image,
//		type,
//		format,
//		/**
//		* ComponentMapping(
//		*	vk::ComponentSwizzle r_ = vk::ComponentSwizzle::eIdentity,
//        *	vk::ComponentSwizzle g_ = vk::ComponentSwizzle::eIdentity,
//        *	vk::ComponentSwizzle b_ = vk::ComponentSwizzle::eIdentity,
//        *	vk::ComponentSwizzle a_ = vk::ComponentSwizzle::eIdentity
//		* ) VULKAN_HPP_NOEXCEPT
//		*/
//		{
//			vk::ComponentSwizzle::eIdentity,
//			vk::ComponentSwizzle::eIdentity,
//			vk::ComponentSwizzle::eIdentity,
//			vk::ComponentSwizzle::eIdentity
//		},
//		/**
//		* ImageSubresourceRange(
//		*	vk::ImageAspectFlags aspectMask_	 = {},
//        *	uint32_t             baseMipLevel_   = {},
//        *	uint32_t             levelCount_     = {},
//        *	uint32_t             baseArrayLayer_ = {},
//        *	uint32_t             layerCount_     = {}
//		* ) VULKAN_HPP_NOEXCEPT
//		*/
//		{
//			aspect,
//			0,
//			1,
//			0,
//			arrayCount
//		}
//	};
//	try {
//		return logicalDevice.createImageView(createInfo);
//	}
//	catch (vk::SystemError err) {
//		throw std::runtime_error(std::format("Failed to create image view. Reason:\n\t{}", err.what()).c_str());
//	}
//}

vk::Format vkImage::findSupportedFormat(
	vk::PhysicalDevice physicalDevice,
	const std::vector<vk::Format>& candidates,
	vk::ImageTiling tiling, vk::FormatFeatureFlags features) {

	for (vk::Format format : candidates) {
		/*
		* FormatProperties(
		*	vk::FormatFeatureFlags linearTilingFeatures_  = {},
        *	vk::FormatFeatureFlags optimalTilingFeatures_ = {},
        *	vk::FormatFeatureFlags bufferFeatures_        = {}
		* ) VULKAN_HPP_NOEXCEPT
		*/
		vk::FormatProperties properties = physicalDevice.getFormatProperties(format);
		if (tiling == vk::ImageTiling::eLinear
			&& (properties.linearTilingFeatures & features) == features) {
			return format;
		}
		if (tiling == vk::ImageTiling::eOptimal
			&& (properties.optimalTilingFeatures & features) == features) {
			return format;
		}
		throw std::runtime_error("Unable to find suitable format");
	}
}