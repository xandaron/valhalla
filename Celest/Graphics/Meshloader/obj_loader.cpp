#include "obj_loader.h"
#define TINYOBJLOADER_IMPLEMENTATION
#include <TinyOBJ/tiny_obj_loader.h>

Meshloader::OBJ_Loader::OBJ_Loader(std::string filedir, std::string filename, glm::mat4 preTransform) : Mesh_Loader(filedir, filename, preTransform) {}

bool Meshloader::OBJ_Loader::load() {
	tinyobj::attrib_t attrib;
	std::vector<tinyobj::shape_t> shapes;
	std::vector<tinyobj::material_t> materials;
	std::string warn, err;

	if (!tinyobj::LoadObj(&attrib, &shapes, &materials, &warn, &err, filepath.c_str())) {
		throw std::runtime_error(warn + err);
	}

	std::unordered_map<vkMesh::Vertex, uint32_t> vertexLookup{};

	for (const auto& shape : shapes) {
		for (const auto& index : shape.mesh.indices) {
			vkMesh::Vertex vertex{};

			vertex.pos = (preTransform * glm::vec4(
				attrib.vertices[3 * index.vertex_index + 0],
				attrib.vertices[3 * index.vertex_index + 1],
				attrib.vertices[3 * index.vertex_index + 2],
				0
			)).xyz;

			vertex.color = { 1.0f, 1.0f, 1.0f };

			vertex.texCoord = {
				attrib.texcoords[2 * index.texcoord_index + 0],
				1.0f - attrib.texcoords[2 * index.texcoord_index + 1]
			};

			vertex.normal = (preTransform * glm::vec4(
				attrib.normals[3 * index.normal_index + 0],
				attrib.normals[3 * index.normal_index + 1],
				attrib.normals[3 * index.normal_index + 2],
				0
			)).xyz;

			if (vertexLookup.count(vertex) == 0) {
				vertexLookup[vertex] = static_cast<uint32_t>(vertices.size());
				vertices.push_back(vertex);
			}

			indices.push_back(vertexLookup[vertex]);
		}
	}

	return true;
}