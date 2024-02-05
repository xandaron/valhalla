#pragma once
#include "../../cfg.h"
#include "../view/vkUtil/memory.h"

struct vertexBufferFinalizationChunk {
	vk::Device logicalDevice;
	vk::PhysicalDevice physicalDevice;
	vk::Queue queue;
	vk::CommandBuffer commandBuffer;
};

class VertexMenagerie {
public:
	VertexMenagerie();
	~VertexMenagerie();
	void consume(std::string type, std::vector<float>& vertexData, std::vector<uint32_t>& indexData);
	void finalize(vertexBufferFinalizationChunk finalizationChunk);
	Buffer vertexBuffer, indexBuffer;
	std::unordered_map<std::string, int> firstIndices;
	std::unordered_map<std::string, int> indexCounts;
private:
	int indexOffset;
	vk::Device logicalDevice;
	std::vector<float> vertexLump;
	std::vector<uint32_t> indexLump;
};