#pragma once
#include "../vkCfg.h"
#include "../vkUtil/fbx_loader.h"
#include "../vkUtil/obj_loader.h"

namespace vkMesh {
	vkUtil::MeshLoader* createMeshLoader(std::string filepath, glm::mat4 preTransform) {
		std::vector<std::string> words = split(filepath, ".");
		if (words[1] == "obj") {
			return new vkUtil::OBJLoader(filepath, preTransform);
		}
		else if (words[1] == "fbx") {
			return new vkUtil::FBXLoader(filepath, preTransform);
		}
		throw std::invalid_argument("invalid file type");
	}
}