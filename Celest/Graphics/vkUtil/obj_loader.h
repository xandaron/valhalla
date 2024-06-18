#pragma once
#include "mesh_loader.h"

namespace vkUtil {

	class OBJLoader : public MeshLoader {
	public:
		OBJLoader(std::string filepath, glm::mat4 preTransform);

		bool load();
	};
}