#include "vertex_menagerie.h"

vkMesh::VertexMenagerie::VertexMenagerie() {
	indexOffset = 0;
}

void vkMesh::VertexMenagerie::consume(std::string type, std::vector<Vertex>& vertexData, std::vector<uint32_t>& indexData) {

	int indexCount = static_cast<uint32_t>(indexData.size());
	int vertexCount = static_cast<uint32_t>(vertexData.size() / 11);
	int lastIndex = static_cast<uint32_t>(indexLump.size());

	firstIndices.insert(std::make_pair(type, lastIndex));
	indexCounts.insert(std::make_pair(type, indexCount));

	for (Vertex vertex : vertexData) {
		glm::vec3& p = vertex.pos;
		glm::vec3& c = vertex.color;
		glm::vec2& t = vertex.texCoord;
		glm::vec3& n = vertex.normal;

		vertexLump.push_back(p.x);
		vertexLump.push_back(p.y);
		vertexLump.push_back(p.z);

		vertexLump.push_back(c.x);
		vertexLump.push_back(c.y);
		vertexLump.push_back(c.z);

		vertexLump.push_back(t.x);
		vertexLump.push_back(t.y);

		vertexLump.push_back(n.x);
		vertexLump.push_back(n.y);
		vertexLump.push_back(n.z);
	}
	for (uint32_t index : indexData) {
		indexLump.push_back(index + indexOffset);
	}

	indexOffset += vertexCount;
}

void vkMesh::VertexMenagerie::finalize(vertexBufferFinalizationChunk finalizationChunk) {

	logicalDevice = finalizationChunk.logicalDevice;

	//make a staging buffer for vertices
	BufferInputChunk inputChunk;
	inputChunk.logicalDevice = finalizationChunk.logicalDevice;
	inputChunk.physicalDevice = finalizationChunk.physicalDevice;
	inputChunk.size = sizeof(float) * vertexLump.size();
	inputChunk.usage = vk::BufferUsageFlagBits::eTransferSrc;
	inputChunk.memoryProperties = vk::MemoryPropertyFlagBits::eHostVisible | vk::MemoryPropertyFlagBits::eHostCoherent;
	Buffer stagingBuffer = vkUtil::createBuffer(inputChunk);

	//fill it with vertex data
	void* memoryLocation = logicalDevice.mapMemory(stagingBuffer.bufferMemory, 0, inputChunk.size);
	memcpy(memoryLocation, vertexLump.data(), inputChunk.size);
	logicalDevice.unmapMemory(stagingBuffer.bufferMemory);

	//make the vertex buffer
	inputChunk.usage = vk::BufferUsageFlagBits::eTransferDst | vk::BufferUsageFlagBits::eVertexBuffer;
	inputChunk.memoryProperties = vk::MemoryPropertyFlagBits::eDeviceLocal;
	vertexBuffer = vkUtil::createBuffer(inputChunk);

	//copy to it
	vkUtil::copyBuffer(
		stagingBuffer, vertexBuffer, inputChunk.size,
		finalizationChunk.queue, finalizationChunk.commandBuffer
	);

	//destroy staging buffer
	logicalDevice.destroyBuffer(stagingBuffer.buffer);
	logicalDevice.freeMemory(stagingBuffer.bufferMemory);

	//make a staging buffer for indices
	inputChunk.size = sizeof(uint32_t) * indexLump.size();
	inputChunk.usage = vk::BufferUsageFlagBits::eTransferSrc;
	inputChunk.memoryProperties = vk::MemoryPropertyFlagBits::eHostVisible | vk::MemoryPropertyFlagBits::eHostCoherent;
	stagingBuffer = vkUtil::createBuffer(inputChunk);

	//fill it with index data
	memoryLocation = logicalDevice.mapMemory(stagingBuffer.bufferMemory, 0, inputChunk.size);
	memcpy(memoryLocation, indexLump.data(), inputChunk.size);
	logicalDevice.unmapMemory(stagingBuffer.bufferMemory);

	//make the vertex buffer
	inputChunk.usage = vk::BufferUsageFlagBits::eTransferDst | vk::BufferUsageFlagBits::eIndexBuffer;
	inputChunk.memoryProperties = vk::MemoryPropertyFlagBits::eDeviceLocal;
	indexBuffer = vkUtil::createBuffer(inputChunk);

	//copy to it
	vkUtil::copyBuffer(
		stagingBuffer, indexBuffer, inputChunk.size,
		finalizationChunk.queue, finalizationChunk.commandBuffer
	);

	//destroy staging buffer
	logicalDevice.destroyBuffer(stagingBuffer.buffer);
	logicalDevice.freeMemory(stagingBuffer.bufferMemory);

	vertexLump.clear();
}

vkMesh::VertexMenagerie::~VertexMenagerie() {

	//destroy vertex buffer
	logicalDevice.destroyBuffer(vertexBuffer.buffer);
	logicalDevice.freeMemory(vertexBuffer.bufferMemory);

	//destroy index buffer
	logicalDevice.destroyBuffer(indexBuffer.buffer);
	logicalDevice.freeMemory(indexBuffer.bufferMemory);

}