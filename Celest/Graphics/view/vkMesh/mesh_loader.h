#pragma once
#include <filesystem>
#include "../../../Game/util/file_loader.h"
#include "mtl_loader.h"

namespace Fileloader {

	class Mesh_Loader : public File_Loader {
	public:
		std::vector<float> vertices;
		std::vector<uint32_t> indices;

		Mesh_Loader(std::string filedir, std::string filename, glm::mat4 preTransform) : File_Loader(filedir, filename) {
			this->preTransform = preTransform;
		}

	protected:
		glm::mat4 preTransform;
		std::vector<glm::f64vec3> v, vn;
		std::vector<glm::f64vec2> vt;
	};
}