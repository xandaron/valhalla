#pragma once
#include "../../../cfg.h"
#include "../vkUtil/fbx_loader.h"
#include "../vkUtil/obj_loader.h"

namespace vkMesh {
	vkUtil::MeshLoader* createMeshLoader(std::string filedir, std::string filename, glm::mat4 preTransform) {
		std::vector<std::string> words = split(filename, ".");
		if (words[1] == "obj") {
			return new vkUtil::OBJLoader(filedir, filename, preTransform);
		}
		else if (words[1] == "fbx") {
			return new vkUtil::FBXLoader(filedir, filename, preTransform);
		}
		throw std::invalid_argument("invalid file type");
	}
}