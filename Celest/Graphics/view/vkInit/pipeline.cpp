#include "pipeline.h"
#include "../../control/logging.h"

vkInit::GraphicsPipelineOutBundle vkInit::buildPipeline(PipelineBuildInfo& buildInfo) {
	std::vector<vk::PipelineShaderStageCreateInfo> stages;
	createShaderStages(buildInfo.device, buildInfo.shaderStages, stages);
	vk::PipelineLayout layout = createLayout(buildInfo.device, buildInfo.descriptorSetLayouts);
	vk::RenderPass renderPass = createRenderPass(
		buildInfo.device, buildInfo.overwrite, buildInfo.depthAttachmentInfo, buildInfo.colourAttachmentInfo
	);
	/**
	* GraphicsPipelineCreateInfo(
	*	vk::PipelineCreateFlags                         flags_               = {},
	*	uint32_t                                        stageCount_          = {},
	*	const vk::PipelineShaderStageCreateInfo*        pStages_             = {},
	*	const vk::PipelineVertexInputStateCreateInfo*   pVertexInputState_   = {},
	*	const vk::PipelineInputAssemblyStateCreateInfo* pInputAssemblyState_ = {},
	*	const vk::PipelineTessellationStateCreateInfo*  pTessellationState_  = {},
	*	const vk::PipelineViewportStateCreateInfo*      pViewportState_      = {},
	*	const vk::PipelineRasterizationStateCreateInfo* pRasterizationState_ = {},
	*	const vk::PipelineMultisampleStateCreateInfo*   pMultisampleState_   = {},
	*	const vk::PipelineDepthStencilStateCreateInfo*  pDepthStencilState_  = {},
	*	const vk::PipelineColorBlendStateCreateInfo*    pColorBlendState_    = {},
	*	const vk::PipelineDynamicStateCreateInfo*       pDynamicState_       = {},
	*	vk::PipelineLayout                              layout_              = {},
	*	vk::RenderPass                                  renderPass_          = {},
	*	uint32_t                                        subpass_             = {},
	*	vk::Pipeline                                    basePipelineHandle_  = {},
	*	int32_t                                         basePipelineIndex_   = {},
	*	const void *									pNext_               = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	vk::GraphicsPipelineCreateInfo pipelineInfo{
		vk::PipelineCreateFlags(),
		static_cast<uint32_t>(stages.size()),
		stages.data(),
		createVertexInputState(buildInfo.vertexInputInfo),
		createInputAssemblyState(),
		{},
		createViewportState(),
		createRasterizationState(),
		createMultisampleState(),
		(buildInfo.depthAttachmentInfo.format == vk::Format::eUndefined) ? nullptr : createDepthStencilState(),
		createColourBlendState(),
		createDynamicStateInfo(),
		layout,
		renderPass,
		0,
		nullptr,
		{},
		nullptr
	};
	vk::Pipeline pipeline = createPipeline(buildInfo.device, pipelineInfo);
	
	return {
		layout,
		renderPass,
		pipeline,
		stages
	};
}

inline vk::PipelineShaderStageCreateInfo vkInit::makeShaderInfo(vk::Device device, std::string filename, const vk::ShaderStageFlagBits& stage) {
	/**
	* PipelineShaderStageCreateInfo(
	*	vk::PipelineShaderStageCreateFlags flags_				= {},
	*	vk::ShaderStageFlagBits			   stage_				= vk::ShaderStageFlagBits::eVertex,
	*	vk::ShaderModule				   module_				= {},
	*	const char *                       pName_				= {},
	*	const vk::SpecializationInfo *	   pSpecializationInfo_ = {},
	*	const void *                       pNext_               = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return{
		vk::PipelineShaderStageCreateFlags(),
		stage,
		vkUtil::createModule(filename, device),
		"main",
		{},
		nullptr
	};
}

inline void vkInit::createShaderStages(vk::Device device, std::vector<shaderInfo> shaderStages, std::vector<vk::PipelineShaderStageCreateInfo>& stages) {
	stages.resize(shaderStages.size());
	for (int i = 0; i < shaderStages.size(); i++) {
		Debug::Logger::log(Debug::MESSAGE, std::format("Creating shader module: \"{}\"", shaderStages[i].shaderPath));
		stages[i] = makeShaderInfo(device, shaderStages[i].shaderPath, shaderStages[i].flag);
	}
}

inline vk::PipelineVertexInputStateCreateInfo* vkInit::createVertexInputState(const VertexInputInfo& vertexFormatInfo) {
	/**
	* PipelineVertexInputStateCreateInfo(
	*	vk::PipelineVertexInputStateCreateFlags     flags_                           = {},
	*	uint32_t                                    vertexBindingDescriptionCount_   = {},
	*	const vk::VertexInputBindingDescription *   pVertexBindingDescriptions_      = {},
	*	uint32_t                                    vertexAttributeDescriptionCount_ = {},
	*	const vk::VertexInputAttributeDescription * pVertexAttributeDescriptions_    = {},
	*	const void *								pNext_							 = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::PipelineVertexInputStateCreateInfo{
		vk::PipelineVertexInputStateCreateFlags(),
		1,
		&vertexFormatInfo.bindingDescription,
		static_cast<uint32_t>(vertexFormatInfo.attributeDescriptions.size()),
		vertexFormatInfo.attributeDescriptions.data(),
		nullptr
	};
}

inline vk::PipelineInputAssemblyStateCreateInfo* vkInit::createInputAssemblyState() {
	/**
	* PipelineInputAssemblyStateCreateInfo(
	*	vk::PipelineInputAssemblyStateCreateFlags flags_				  = {},
	*	vk::PrimitiveTopology					  topology_		 		  = vk::PrimitiveTopology::ePointList,
	*	vk::Bool32								  primitiveRestartEnable_ = {},
	*	const void *							  pNext_                  = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::PipelineInputAssemblyStateCreateInfo{
		vk::PipelineInputAssemblyStateCreateFlags(),
		vk::PrimitiveTopology::eTriangleList,
		{},
		nullptr
	};
}

inline vk::PipelineViewportStateCreateInfo* vkInit::createViewportState() {
	/**
		* PipelineViewportStateCreateInfo(
		*	vk::PipelineViewportStateCreateFlags flags_         = {},
		*	uint32_t                             viewportCount_ = {},
		*	const vk::Viewport *                 pViewports_    = {},
		*	uint32_t                             scissorCount_  = {},
		*	const vk::Rect2D *                   pScissors_     = {},
		*	const void *                         pNext_         = nullptr
		) VULKAN_HPP_NOEXCEPT
		*/
	return new vk::PipelineViewportStateCreateInfo{
		vk::PipelineViewportStateCreateFlags(),
		1,
		{},
		1,
		{},
		nullptr
	};
}

inline vk::PipelineRasterizationStateCreateInfo* vkInit::createRasterizationState() {
	/**
	* PipelineRasterizationStateCreateInfo(
	*	vk::PipelineRasterizationStateCreateFlags flags_						   = {},
	*	vk::Bool32								  depthClampEnable_				   = {},
	*	vk::Bool32								  rasterizationStateDiscardEnable_ = {},
	*	vk::PolygonMode							  polygonMode_					   = vk::PolygonMode::eFill,
	*	vk::CullModeFlags						  cullMode_						   = {},
	*	vk::FrontFace							  frontFace_					   = vk::FrontFace::eCounterClockwise,
	*	vk::Bool32								  depthBiasEnable_				   = {},
	*	float									  depthBiasConstantFactor_		   = {},
	*	float									  depthBiasClamp_				   = {},
	*	float									  depthBiasSlopeFactor_			   = {},
	*	float									  lineWidth_					   = {},
	*	const void *							  pNext_						   = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::PipelineRasterizationStateCreateInfo{
		vk::PipelineRasterizationStateCreateFlags(),
		VK_FALSE,
		VK_FALSE,
		vk::PolygonMode::eFill,
		vk::CullModeFlagBits::eBack,
		vk::FrontFace::eCounterClockwise,
		VK_FALSE,
		{},
		{},
		{},
		1.0f,
		nullptr
	};
}

inline vk::PipelineMultisampleStateCreateInfo* vkInit::createMultisampleState() {
	/**
	* PipelineMultisampleStateCreateInfo(
	*	vk::PipelineMultisampleStateCreateFlags flags_ = {},
	*	vk::SampleCountFlagBits rasterizationSamples_  = vk::SampleCountFlagBits::e1,
	*	vk::Bool32              sampleShadingEnable_   = {},
	*	float                   minSampleShading_      = {},
	*	const vk::SampleMask *  pSampleMask_           = {},
	*	vk::Bool32              alphaToCoverageEnable_ = {},
	*	vk::Bool32              alphaToOneEnable_      = {},
	*	const void *            pNext_                 = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::PipelineMultisampleStateCreateInfo{
		vk::PipelineMultisampleStateCreateFlags(),
		vk::SampleCountFlagBits::e1,
		VK_FALSE,
		{},
		{},
		{},
		{},
		nullptr
	};
}

inline vk::PipelineDepthStencilStateCreateInfo* vkInit::createDepthStencilState() {
	/**
	* PipelineDepthStencilStateCreateInfo(
	*	vk::PipelineDepthStencilStateCreateFlags flags_					= {},
	*	vk::Bool32                               depthTestEnable_		= {},
	*	vk::Bool32                               depthWriteEnable_		= {},
	*	vk::CompareOp							 depthCompareOp_		= vk::CompareOp::eNever,
	*	vk::Bool32								 depthBoundsTestEnable_ = {},
	*	vk::Bool32								 stencilTestEnable_     = {},
	*	vk::StencilOpState						 front_                 = {},
	*	vk::StencilOpState						 back_                  = {},
	*	float									 minDepthBounds_        = {},
	*	float									 maxDepthBounds_        = {},
	*	const void *							 pNext_                 = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::PipelineDepthStencilStateCreateInfo{
		vk::PipelineDepthStencilStateCreateFlags(),
		true,
		true,
		vk::CompareOp::eLess,
		false,
		false,
		{},
		{},
		{},
		{},
		nullptr
	};
}

inline vk::PipelineColorBlendAttachmentState* vkInit::createColourBlendAttachment() {
	/**
	* PipelineColorBlendAttachmentState(
	*	vk::Bool32      blendEnable_         = {},
	*	vk::BlendFactor srcColorBlendFactor_ = vk::BlendFactor::eZero,
	*	vk::BlendFactor dstColorBlendFactor_ = vk::BlendFactor::eZero,
	*	vk::BlendOp     colorBlendOp_        = vk::BlendOp::eAdd,
	*	vk::BlendFactor srcAlphaBlendFactor_ = vk::BlendFactor::eZero,
	*	vk::BlendFactor dstAlphaBlendFactor_ = vk::BlendFactor::eZero,
	*	vk::BlendOp     alphaBlendOp_        = vk::BlendOp::eAdd,
	*	vk::ColorComponentFlags colorWriteMask_ = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::PipelineColorBlendAttachmentState{
		VK_FALSE,
		vk::BlendFactor::eZero,
		vk::BlendFactor::eZero,
		vk::BlendOp::eAdd,
		vk::BlendFactor::eZero,
		vk::BlendFactor::eZero,
		vk::BlendOp::eAdd,
		vk::ColorComponentFlagBits::eR | vk::ColorComponentFlagBits::eG
		| vk::ColorComponentFlagBits::eB | vk::ColorComponentFlagBits::eA
	};
}

inline vk::PipelineColorBlendStateCreateInfo* vkInit::createColourBlendState() {
	/**
	* PipelineColorBlendStateCreateInfo(
	*	vk::PipelineColorBlendStateCreateFlags		  flags_           = {},
	*	vk::Bool32									  logicOpEnable_   = {},
	*	vk::LogicOp									  logicOp_         = vk::LogicOp::eClear,
	*	uint32_t									  attachmentCount_ = {},
	*	const vk::PipelineColorBlendAttachmentState * pAttachments_    = {},
	*	std::array<float, 4> const &                  blendConstants_  = {},
	*	const void *								  pNext_           = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::PipelineColorBlendStateCreateInfo{
		vk::PipelineColorBlendStateCreateFlags(),
		VK_FALSE,
		vk::LogicOp::eCopy,
		1u,
		createColourBlendAttachment(),
		{ 0.0f, 0.0f, 0.0f, 0.0f },
		nullptr
	};
}

inline vk::DynamicState* vkInit::createDynamicState() {
	return new vk::DynamicState[]{
		vk::DynamicState::eViewport,
		vk::DynamicState::eScissor
	};
}

inline vk::PipelineDynamicStateCreateInfo* vkInit::createDynamicStateInfo() {
	/**
	* PipelineDynamicStateCreateInfo(
	*	vk::PipelineDynamicStateCreateFlags flags_             = {},
    *	uint32_t                            dynamicStateCount_ = {},
    *	const vk::DynamicState*             pDynamicStates_    = {},
    *	const void*                         pNext_             = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::PipelineDynamicStateCreateInfo{
		vk::PipelineDynamicStateCreateFlags(),
		2u,
		createDynamicState(),
		nullptr
	};
}

inline vk::PipelineLayoutCreateInfo vkInit::createLayoutInfo(const std::vector<vk::DescriptorSetLayout>& descriptorSetLayouts) {
	/*
	* PipelineLayoutCreateInfo(
	*	vk::PipelineLayoutCreateFlags   flags_                  = {},
    *	uint32_t                        setLayoutCount_         = {},
    *	const vk::DescriptorSetLayout * pSetLayouts_            = {},
    *	uint32_t                        pushConstantRangeCount_ = {},
    *	const vk::PushConstantRange *   pPushConstantRanges_    = {},
    *	const void *                    pNext_                  = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return{
		vk::PipelineLayoutCreateFlags(),
		static_cast<uint32_t>(descriptorSetLayouts.size()),
		descriptorSetLayouts.data(),
		0,
		{},
		nullptr
	};
}

vk::PipelineLayout vkInit::createLayout(vk::Device device, const std::vector<vk::DescriptorSetLayout>& descriptorSetLayouts) {
	Debug::Logger::log(Debug::MESSAGE, "Creating pipeline layout!");
	try {
		return device.createPipelineLayout(createLayoutInfo(descriptorSetLayouts));
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to create pipeline layout! Reason:\n\t{}", err.what()).c_str());
	}
}

inline std::vector<vk::AttachmentDescription> vkInit::createAttachmentDescriptions(bool overwrite, vk::Format depthAttachmentFormat, vk::Format colourAttachmentFormat) {
	/**
	* AttachmentDescription(
	*	vk::AttachmentDescriptionFlags flags_          = {},
    *	vk::Format                     format_         = vk::Format::eUndefined,
    *	vk::SampleCountFlagBits        samples_        = vk::SampleCountFlagBits::e1,
    *	vk::AttachmentLoadOp           loadOp_         = vk::AttachmentLoadOp::eLoad,
    *	vk::AttachmentStoreOp          storeOp_        = vk::AttachmentStoreOp::eStore,
    *	vk::AttachmentLoadOp           stencilLoadOp_  = vk::AttachmentLoadOp::eLoad,
    *	vk::AttachmentStoreOp          stencilStoreOp_ = vk::AttachmentStoreOp::eStore,
    *	vk::ImageLayout                initialLayout_  = vk::ImageLayout::eUndefined,
    *	vk::ImageLayout                finalLayout_	   = vk::ImageLayout::eUndefined
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return (depthAttachmentFormat == vk::Format::eUndefined) ?
		(std::vector<vk::AttachmentDescription>
		{
			{
				vk::AttachmentDescriptionFlags(),
				colourAttachmentFormat,
				vk::SampleCountFlagBits::e1,
				overwrite ? vk::AttachmentLoadOp::eLoad : vk::AttachmentLoadOp::eDontCare,
				vk::AttachmentStoreOp::eStore,
				vk::AttachmentLoadOp::eDontCare,
				vk::AttachmentStoreOp::eDontCare,
				overwrite ? vk::ImageLayout::ePresentSrcKHR : vk::ImageLayout::eUndefined,
				vk::ImageLayout::ePresentSrcKHR
			}
		}) : (std::vector<vk::AttachmentDescription>
		{
			{
				vk::AttachmentDescriptionFlags(),
				colourAttachmentFormat,
				vk::SampleCountFlagBits::e1,
				overwrite ? vk::AttachmentLoadOp::eLoad : vk::AttachmentLoadOp::eDontCare,
				vk::AttachmentStoreOp::eStore,
				vk::AttachmentLoadOp::eDontCare,
				vk::AttachmentStoreOp::eDontCare,
				overwrite ? vk::ImageLayout::ePresentSrcKHR : vk::ImageLayout::eUndefined,
				vk::ImageLayout::ePresentSrcKHR
			},
			{
				vk::AttachmentDescriptionFlags(),
				depthAttachmentFormat,
				vk::SampleCountFlagBits::e1,
				vk::AttachmentLoadOp::eClear,
				vk::AttachmentStoreOp::eDontCare,
				vk::AttachmentLoadOp::eDontCare,
				vk::AttachmentStoreOp::eDontCare,
				vk::ImageLayout::eUndefined,
				vk::ImageLayout::eDepthStencilAttachmentOptimal
			}
		});
}

inline std::vector<vk::AttachmentReference> vkInit::createAttachmentReferences(AttachmentInfo depthAttachment, uint32_t colourAttachmentIndex) {
	/**
	* AttachmentReference(
	*	uint32_t        attachment_ = {},
    *	vk::ImageLayout layout_     = vk::ImageLayout::eUndefined
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return (depthAttachment.format != vk::Format::eUndefined) ? 
	(std::vector<vk::AttachmentReference>
		{
			{ colourAttachmentIndex, vk::ImageLayout::eColorAttachmentOptimal },
			{ depthAttachment.index, vk::ImageLayout::eDepthStencilAttachmentOptimal }
		}
	) : (std::vector<vk::AttachmentReference> 
		{
			{ colourAttachmentIndex, vk::ImageLayout::eColorAttachmentOptimal }
		}
	);
}

inline vk::SubpassDescription vkInit::createSubpass(const std::vector<vk::AttachmentReference>& attachmentReferences) {
	/**
	* SubpassDescription(
	*	vk::SubpassDescriptionFlags	   flags_					= {},
	*	vk::PipelineBindPoint		   pipelineBindPoint_		= vk::PipelineBindPoint::eGraphics,
	*	uint32_t					   inputAttachmentCount_    = {},
	*	const vk::AttachmentReference* pInputAttachments_       = {},
	*	uint32_t                       colorAttachmentCount_    = {},
	*	const vk::AttachmentReference* pColorAttachments_       = {},
	*	const vk::AttachmentReference* pResolveAttachments_     = {},
	*	const vk::AttachmentReference* pDepthStencilAttachment_ = {},
	*	uint32_t                       preserveAttachmentCount_ = {},
	*	const uint32_t*                pPreserveAttachments_    = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return{
		vk::SubpassDescriptionFlags(),
		vk::PipelineBindPoint::eGraphics,
		{},
		{},
		1,
		&attachmentReferences[0],
		{},
		(attachmentReferences.size() > 1) ? &attachmentReferences[1] : nullptr,
		{},
		{}
	};
}

inline vk::SubpassDependency* vkInit::createSubpassDependence() {
	/**
	* SubpassDependency(
	*	uint32_t               srcSubpass_      = {},
    *	uint32_t               dstSubpass_      = {},
    *	vk::PipelineStageFlags srcStageMask_    = {},
    *	vk::PipelineStageFlags dstStageMask_    = {},
    *	vk::AccessFlags        srcAccessMask_   = {},
    *	vk::AccessFlags        dstAccessMask_   = {},
    *	vk::DependencyFlags    dependencyFlags_ = {}
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return new vk::SubpassDependency{
		vk::SubpassExternal,
		0u,
		vk::PipelineStageFlagBits::eColorAttachmentOutput,
		vk::PipelineStageFlagBits::eColorAttachmentOutput,
		vk::AccessFlagBits::eNone,
		vk::AccessFlagBits::eColorAttachmentWrite,
		{}
	};
}

inline vk::RenderPassCreateInfo vkInit::createRenderPassInfo(const vk::SubpassDescription& subpass, const std::vector<vk::AttachmentDescription>& attachmentDescriptions) {
	/**
	* RenderPassCreateInfo(
	*	vk::RenderPassCreateFlags         flags_           = {},
	*	uint32_t                          attachmentCount_ = {},
	*	const vk::AttachmentDescription*  pAttachments_    = {},
	*	uint32_t                          subpassCount_    = {},
	*	const vk::SubpassDescription*     pSubpasses_      = {},
	*	uint32_t                          dependencyCount_ = {},
	*	const vk::SubpassDependency*      pDependencies_   = {},
	*	const void*                       pNext_           = nullptr
	* ) VULKAN_HPP_NOEXCEPT
	*/
	return{
		vk::RenderPassCreateFlags(),
		static_cast<uint32_t>(attachmentDescriptions.size()),
		attachmentDescriptions.data(),
		1,
		&subpass,
		1,
		createSubpassDependence(),
		nullptr
	};
}

vk::RenderPass vkInit::createRenderPass(vk::Device device, bool overwrite, AttachmentInfo depthAttachmentInfo, AttachmentInfo colourAttachmentInfo) {
	Debug::Logger::log(Debug::MESSAGE, "Creating render pass!");
	try {
		return device.createRenderPass(
			createRenderPassInfo(
				createSubpass(
					createAttachmentReferences(
						depthAttachmentInfo, colourAttachmentInfo.index
					)
				),
				createAttachmentDescriptions(overwrite, depthAttachmentInfo.format, colourAttachmentInfo.format)
			)
		);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Failed to create renderPass! Reason:\n\t{}", err.what()).c_str());
	}
}

vk::Pipeline vkInit::createPipeline(vk::Device device, const vk::GraphicsPipelineCreateInfo& pipelineInfo) {
	Debug::Logger::log(Debug::MESSAGE, "Creating graphics pipeline!");
	try {
		return device.createGraphicsPipeline(nullptr, pipelineInfo).value;
	}
	catch (vk::SystemError err) {
		std::runtime_error(std::format("Failed to create pipeline! Reason:\n\t{}", err.what()).c_str());
	}
}
