#pragma once
#include "../../../cfg.h"
#include "../vkUtil/shaders.h"
#include "../vkUtil/render_structs.h"

namespace vkInit {
	struct VertexInputInfo {
		vk::VertexInputBindingDescription bindingDescription;
		std::vector<vk::VertexInputAttributeDescription> attributeDescriptions;
	};

	struct AttachmentInfo {
		vk::Format format;
		uint32_t index;
	};

	struct shaderInfo {
		vk::ShaderStageFlagBits flag;
		const char* shaderPath;
	};

	struct PipelineBuildInfo {
		vk::Device& device;
		bool overwrite;
		VertexInputInfo vertexInputInfo;
		std::vector<shaderInfo> shaderStages;
		vk::Extent2D swapchainExtent;
		AttachmentInfo colourAttachmentInfo;
		AttachmentInfo depthAttachmentInfo;
		std::vector<vk::DescriptorSetLayout> descriptorSetLayouts;
	};

	/**
	* Used for returning the pipeline, along with associated data structures,
	* after creation.
	*/
	struct GraphicsPipelineOutBundle {
		vk::PipelineLayout layout;
		vk::RenderPass renderpass;
		vk::Pipeline pipeline;
		std::vector<vk::PipelineShaderStageCreateInfo> shaders;
	};

	/**
	* Builds a graphics pipeline.
	* 
	* @param buildInfo A struct containing required data.
	*/
	GraphicsPipelineOutBundle buildPipeline(PipelineBuildInfo& buildInfo);

	/**
	* Configure a programmable shader stage.
	*
	* @param shaderModule The compiled shader module.
	* @param stage		The shader stage which the module is for.
	*
	* @return The shader stage creation info.
	*/
	inline vk::PipelineShaderStageCreateInfo makeShaderInfo(vk::Device device, std::string filename, const vk::ShaderStageFlagBits& stage);

	inline void createShaderStages(vk::Device device, std::vector<shaderInfo> shaderStages, std::vector<vk::PipelineShaderStageCreateInfo>& stages);

	inline vk::PipelineVertexInputStateCreateInfo* createVertexInputState(const VertexInputInfo& vertexFormatInfo);

	inline vk::PipelineInputAssemblyStateCreateInfo* createInputAssemblyState();

	inline vk::PipelineViewportStateCreateInfo* createViewportState();

	inline vk::PipelineRasterizationStateCreateInfo* createRasterizationState();

	inline vk::PipelineMultisampleStateCreateInfo* createMultisampleState();

	inline vk::PipelineDepthStencilStateCreateInfo* createDepthStencilState();

	inline vk::PipelineColorBlendAttachmentState* createColourBlendAttachment();

	inline vk::PipelineColorBlendStateCreateInfo* createColourBlendState();

	inline vk::DynamicState* createDynamicState();

	inline vk::PipelineDynamicStateCreateInfo* createDynamicStateInfo();

	inline vk::PipelineLayoutCreateInfo createLayoutInfo(const std::vector<vk::DescriptorSetLayout>& descriptorSetLayouts);

	vk::PipelineLayout createLayout(vk::Device device, const std::vector<vk::DescriptorSetLayout>& descriptorSetLayouts);

	inline std::vector<vk::AttachmentDescription> createAttachmentDescriptions(bool overwrite, vk::Format depthAttachmentFormat, vk::Format colourAttachmentFormat);

	inline std::vector<vk::AttachmentReference> createAttachmentReferences(AttachmentInfo depthAttachment, uint32_t colourAttachmentIndex);

	inline vk::SubpassDescription createSubpass(const std::vector<vk::AttachmentReference>& attachmentReferences);

	inline vk::SubpassDependency* createSubpassDependence();

	inline vk::RenderPassCreateInfo createRenderPassInfo(const vk::SubpassDescription& subpass, const std::vector<vk::AttachmentDescription>& attachmentDescriptions);

	vk::RenderPass createRenderPass(vk::Device device, bool overwrite, AttachmentInfo depthAttachmentInfo, AttachmentInfo colourAttachmentInfo);

	vk::Pipeline createPipeline(vk::Device device, const vk::GraphicsPipelineCreateInfo& pipelineInfo);
}