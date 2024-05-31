#pragma once
#include "../../../cfg.h"
#include "../../Meshloader/fbx_loader.h"
#include "../../Meshloader/obj_loader.h"

namespace vkMesh {

	static Meshloader::Mesh_Loader* createMeshLoader(std::string filedir, std::string filename, glm::mat4 preTransform) {
		std::vector<std::string> words = split(filename, ".");
		if (words[1] == "obj") {
			return new Meshloader::OBJ_Loader(filedir, filename, preTransform);
		}
		else if (words[1] == "fbx") {
			return new Meshloader::FBX_Loader(filedir, filename, preTransform);
		}
		throw std::invalid_argument("invalid file type");
	}
}