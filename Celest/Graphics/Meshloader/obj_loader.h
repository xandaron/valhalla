#pragma once
#include "mesh_loader.h"

namespace Meshloader {

	class OBJ_Loader : public Mesh_Loader {
	public:
		OBJ_Loader(std::string filedir, std::string filename, glm::mat4 preTransform);

		bool load();
	};
}