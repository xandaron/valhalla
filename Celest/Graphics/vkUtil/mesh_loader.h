#pragma once
#include "../../Game/util/file_loader.h"
#include "../vkMesh/vertex_menagerie.h"

namespace vkUtil {

	inline std::vector<uint32_t> triangulate(uint32_t vertexCount) {
		std::vector<uint32_t> result;
		if (vertexCount < 2) { return result; }
		if (vertexCount == 3) {
			result.push_back(0);
			result.push_back(1);
			result.push_back(2);
		}
		else {
			for (int tri = 0; tri < vertexCount - 2; ++tri) {
				result.push_back(0);
				result.push_back(1 + tri);
				result.push_back(2 + tri);
			}
		}
		return result;
	}

	class MeshLoader : public util::FileLoader {
	public:
		std::vector<vkMesh::Vertex> vertices;
		std::vector<uint32_t> indices;

		MeshLoader(std::string filepath, glm::mat4 preTransform) : FileLoader(filepath) {
			this->preTransform = preTransform;
		}

	protected:
		glm::mat4 preTransform;
	};
}