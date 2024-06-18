#pragma once
#include "mesh_loader.h"

namespace vkUtil {

	class FBXLoader : public MeshLoader {
	public:
		FBXLoader(std::string filepath, glm::mat4 preTransform);

		bool load();
	};
}