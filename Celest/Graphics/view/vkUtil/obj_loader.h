#pragma once
#include "mesh_loader.h"

namespace vkUtil {

	class OBJLoader : public MeshLoader {
	public:
		OBJLoader(std::string filedir, std::string filename, glm::mat4 preTransform);

		bool load();
	};
}