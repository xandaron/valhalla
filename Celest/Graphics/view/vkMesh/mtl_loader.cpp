#include "mtl_loader.h"

Fileloader::MTL_Loader::MTL_Loader(std::string filedir, std::string filename) : File_Loader(filedir, filename) {
	brushColor = glm::vec3(0);
}

void Fileloader::MTL_Loader::load() {

	std::ifstream file;
	file.open(filepath);

	std::string line;
	std::string materialName;
	std::vector<std::string> words;

	while (std::getline(file, line)) {
		trim(line);
		words = split(line, " ");

		if (!words[0].compare("newmtl")) {
			materialName = words[1];
		}
		if (!words[0].compare("Kd")) {
			brushColor = glm::vec3(std::stof(words[1]), std::stof(words[2]), std::stof(words[3]));
			colorLookup.insert({ materialName, brushColor });
		}
	}
	file.close();
}