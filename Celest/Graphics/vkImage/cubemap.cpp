#include "cubemap.h"
#include "stb_image.h"
#include "../vkUtil/memory.h"
#include "../vkInit/descriptors.h"
#include "../vkInit/image_views.h"

vkImage::CubeMap::CubeMap(TextureInputChunk input) {

	logicalDevice = input.logicalDevice;
	physicalDevice = input.physicalDevice;
	filenames = input.filenames;
	commandBuffer = input.commandBuffer;
	queue = input.queue;
	layout = input.layout;
	descriptorPool = input.descriptorPool;

	load();

	ImageInputChunk imageInput;
	imageInput.logicalDevice = logicalDevice;
	imageInput.physicalDevice = physicalDevice;
	imageInput.format = vk::Format::eR8G8B8A8Unorm;
	imageInput.arrayCount = 6;
	imageInput.width = width;
	imageInput.height = height;
	imageInput.tiling = vk::ImageTiling::eOptimal;
	imageInput.usage = vk::ImageUsageFlagBits::eTransferDst | vk::ImageUsageFlagBits::eSampled;
	imageInput.memoryProperties = vk::MemoryPropertyFlagBits::eDeviceLocal;
	imageInput.flags = vk::ImageCreateFlagBits::eCubeCompatible;

	image = makeImage(imageInput);
	imageMemory = makeImageMemory(imageInput, image);

	populate();

	for (int i = 0; i < 6; ++i) {
		free(pixels[i]);
	}

	make_view();
	make_sampler();
	make_descriptor_set();
}

vkImage::CubeMap::~CubeMap() {

	logicalDevice.freeMemory(imageMemory);
	logicalDevice.destroyImage(image);
	logicalDevice.destroyImageView(imageView);
	logicalDevice.destroySampler(sampler);
}

void vkImage::CubeMap::load() {
	for (int i = 0; i < 6; ++i) {
		pixels[i] = stbi_load(filenames[i].c_str(), &width, &height, &channels, STBI_rgb_alpha);
		if (!pixels) {
			throw std::runtime_error(std::format("Unable to open file {}.", filenames[i]).c_str());
		}
	}
}

void vkImage::CubeMap::populate() {

	//First create a CPU-visible buffer...
	BufferInputChunk input;
	input.logicalDevice = logicalDevice;
	input.physicalDevice = physicalDevice;
	input.memoryProperties = vk::MemoryPropertyFlagBits::eHostCoherent | vk::MemoryPropertyFlagBits::eHostVisible;
	input.usage = vk::BufferUsageFlagBits::eTransferSrc;
	size_t image_size = width * height * 4;
	input.size = image_size * 6;

	Buffer stagingBuffer = vkUtil::createBuffer(input);

	//...then fill it,
	for (int i = 0; i < 6; ++i) {
		void* writeLocation = logicalDevice.mapMemory(stagingBuffer.bufferMemory, image_size * i, image_size);
		memcpy(writeLocation, pixels[i], image_size);
		logicalDevice.unmapMemory(stagingBuffer.bufferMemory);
	}

	//then transfer it to image memory
	ImageLayoutTransitionJob transitionJob;
	transitionJob.commandBuffer = commandBuffer;
	transitionJob.queue = queue;
	transitionJob.image = image;
	transitionJob.oldLayout = vk::ImageLayout::eUndefined;
	transitionJob.newLayout = vk::ImageLayout::eTransferDstOptimal;
	transitionJob.arrayCount = 6;
	transitionImageLayout(transitionJob);

	BufferImageCopyJob copyJob;
	copyJob.commandBuffer = commandBuffer;
	copyJob.queue = queue;
	copyJob.srcBuffer = stagingBuffer.buffer;
	copyJob.dstImage = image;
	copyJob.width = width;
	copyJob.height = height;
	copyJob.arrayCount = 6;
	copyBufferToImage(copyJob);

	transitionJob.oldLayout = vk::ImageLayout::eTransferDstOptimal;
	transitionJob.newLayout = vk::ImageLayout::eShaderReadOnlyOptimal;
	transitionImageLayout(transitionJob);

	//Now the staging buffer can be destroyed
	logicalDevice.freeMemory(stagingBuffer.bufferMemory);
	logicalDevice.destroyBuffer(stagingBuffer.buffer);
}

void vkImage::CubeMap::make_view() {
	imageView = logicalDevice.createImageView(vkInit::createImageViewCreateInfo(
		image, vk::Format::eR8G8B8A8Unorm, vk::ImageViewType::eCube, vk::ImageAspectFlagBits::eColor, 6
	));
}

void vkImage::CubeMap::make_sampler() {

	/*
	typedef struct VkSamplerCreateInfo {
		VkStructureType         sType;
		const void* pNext;
		VkSamplerCreateFlags    flags;
		VkFilter                magFilter;
		VkFilter                minFilter;
		VkSamplerMipmapMode     mipmapMode;
		VkSamplerAddressMode    addressModeU;
		VkSamplerAddressMode    addressModeV;
		VkSamplerAddressMode    addressModeW;
		float                   mipLodBias;
		VkBool32                anisotropyEnable;
		float                   maxAnisotropy;
		VkBool32                compareEnable;
		VkCompareOp             compareOp;
		float                   minLod;
		float                   maxLod;
		VkBorderColor           borderColor;
		VkBool32                unnormalizedCoordinates;
	} VkSamplerCreateInfo;
	*/
	vk::SamplerCreateInfo samplerInfo;
	samplerInfo.flags = vk::SamplerCreateFlags();
	samplerInfo.minFilter = vk::Filter::eNearest;
	samplerInfo.magFilter = vk::Filter::eLinear;
	samplerInfo.addressModeU = vk::SamplerAddressMode::eRepeat;
	samplerInfo.addressModeV = vk::SamplerAddressMode::eRepeat;
	samplerInfo.addressModeW = vk::SamplerAddressMode::eRepeat;

	samplerInfo.anisotropyEnable = false;
	samplerInfo.maxAnisotropy = 1.0f;

	samplerInfo.borderColor = vk::BorderColor::eIntOpaqueBlack;
	samplerInfo.unnormalizedCoordinates = false;
	samplerInfo.compareEnable = false;
	samplerInfo.compareOp = vk::CompareOp::eAlways;

	samplerInfo.mipmapMode = vk::SamplerMipmapMode::eLinear;
	samplerInfo.mipLodBias = 0.0f;
	samplerInfo.minLod = 0.0f;
	samplerInfo.maxLod = 0.0f;

	try {
		sampler = logicalDevice.createSampler(samplerInfo);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to create sampler. Reason:\n\t{}", err.what()).c_str());
	}

}

void vkImage::CubeMap::make_descriptor_set() {

	descriptorSet = vkInit::allocateDescriptorSet(logicalDevice, descriptorPool, layout);

	vk::DescriptorImageInfo imageDescriptor;
	imageDescriptor.imageLayout = vk::ImageLayout::eShaderReadOnlyOptimal;
	imageDescriptor.imageView = imageView;
	imageDescriptor.sampler = sampler;

	vk::WriteDescriptorSet descriptorWrite;
	descriptorWrite.dstSet = descriptorSet;
	descriptorWrite.dstBinding = 0;
	descriptorWrite.dstArrayElement = 0;
	descriptorWrite.descriptorType = vk::DescriptorType::eCombinedImageSampler;
	descriptorWrite.descriptorCount = 1;
	descriptorWrite.pImageInfo = &imageDescriptor;

	logicalDevice.updateDescriptorSets(descriptorWrite, nullptr);
}

void vkImage::CubeMap::use(vk::CommandBuffer commandBuffer, vk::PipelineLayout pipelineLayout) {

	commandBuffer.bindDescriptorSets(vk::PipelineBindPoint::eGraphics, pipelineLayout, 1, descriptorSet, nullptr);
}