#pragma once
#include "mesh_loader.h"

namespace vkUtil {

	class FBXLoader : public MeshLoader {
	public:
		FBXLoader(std::string filedir, std::string filename, glm::mat4 preTransform);

		bool load();
	};
}