#pragma once
#include "../../../Game/util/file_loader.h"

namespace Fileloader {
	class MTL_Loader : File_Loader {
	public:
		std::unordered_map<std::string, glm::vec3> colorLookup;
		glm::vec3 brushColor;

		MTL_Loader(std::string filedir, std::string filename);

		void load();
	};
}