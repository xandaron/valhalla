#pragma once
#include "../../cfg.h"
#include "../vkUtil/memory.h"
#include <glm/gtx/hash.hpp>

namespace vkMesh {

    struct Vertex {
        glm::vec3 pos;
        glm::vec3 color;
        glm::vec2 texCoord;
        glm::vec3 normal;

        static vk::VertexInputBindingDescription getBindingDescription() {
            vk::VertexInputBindingDescription bindingDescription{};
            bindingDescription.binding = 0;
            bindingDescription.stride = sizeof(Vertex);
            bindingDescription.inputRate = vk::VertexInputRate::eVertex;

            return bindingDescription;
        }

        static std::vector<vk::VertexInputAttributeDescription> getAttributeDescriptions() {
            std::vector<vk::VertexInputAttributeDescription> attributeDescriptions{};
            vk::VertexInputAttributeDescription attributeDescription;

            attributeDescription.binding = 0;
            attributeDescription.location = 0;
            attributeDescription.format = vk::Format::eR32G32B32Sfloat;
            attributeDescription.offset = offsetof(Vertex, pos);
            attributeDescriptions.push_back(attributeDescription);

            attributeDescription.binding = 0;
            attributeDescription.location = 1;
            attributeDescription.format = vk::Format::eR32G32B32Sfloat;
            attributeDescription.offset = offsetof(Vertex, color);
            attributeDescriptions.push_back(attributeDescription);

            attributeDescription.binding = 0;
            attributeDescription.location = 2;
            attributeDescription.format = vk::Format::eR32G32Sfloat;
            attributeDescription.offset = offsetof(Vertex, texCoord);
            attributeDescriptions.push_back(attributeDescription);

            attributeDescription.binding = 0;
            attributeDescription.location = 3;
            attributeDescription.format = vk::Format::eR32G32B32Sfloat;
            attributeDescription.offset = offsetof(Vertex, normal);
            attributeDescriptions.push_back(attributeDescription);

            return attributeDescriptions;
        }

        bool operator==(const Vertex& other) const {
            return pos == other.pos && color == other.color && texCoord == other.texCoord && normal == other.normal;
        }
    };

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
        void consume(std::string type, std::vector<Vertex>& vertexData, std::vector<uint32_t>& indexData);
        void finalize(vertexBufferFinalizationChunk finalizationChunk);
        Buffer vertexBuffer, indexBuffer;
        std::unordered_map<std::string, uint32_t> firstIndices;
        std::unordered_map<std::string, uint32_t> indexCounts;
    private:
        int indexOffset;
        vk::Device logicalDevice;
        std::vector<float> vertexLump;
        std::vector<uint32_t> indexLump;
    };
}

namespace std {
    template<> struct hash<vkMesh::Vertex> {
        size_t operator()(vkMesh::Vertex const& vertex) const {
            return ((((hash<glm::vec3>()(vertex.pos) ^ (hash<glm::vec3>()(vertex.color) << 1)) >> 1) ^ (hash<glm::vec2>()(vertex.texCoord) << 1)) >> 1) ^ (hash<glm::vec3>()(vertex.normal) << 1);
        }
    };
}