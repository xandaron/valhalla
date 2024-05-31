#pragma once
#include "../../Game/util/file_loader.h"
#include "../view/vkMesh/vertex_menagerie.h"

namespace Meshloader {

	inline std::vector<uint32_t> triangulate(uint32_t vertexCount) {
		std::vector<uint32_t> result;
		if (vertexCount < 2) { return result; }
		if (vertexCount == 3) {
			result.push_back(0);
			result.push_back(1);
			result.push_back(2);
		}
		else if (vertexCount == 4) {
			result.push_back(0);
			result.push_back(1);
			result.push_back(2);

			result.push_back(0);
			result.push_back(2);
			result.push_back(3);
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

	class Mesh_Loader : public Fileloader::File_Loader {
	public:
		std::vector<vkMesh::Vertex> vertices;
		std::vector<uint32_t> indices;

		Mesh_Loader(std::string filedir, std::string filename, glm::mat4 preTransform) : File_Loader(filedir, filename) {
			this->preTransform = preTransform;
		}

	protected:
		glm::mat4 preTransform;
	};
}