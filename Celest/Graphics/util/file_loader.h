#pragma once
#include "../../cfg.h"

namespace util {
	class FileLoader {

	public:
		FileLoader(std::string filedir, std::string filename) {
			this->filedir = filedir;
			this->filepath = filedir + filename;
		}

		virtual void load() = 0;

	protected:
		std::string filedir;
		std::string filepath;
	};

	class FileLoader_MTL : FileLoader {

	public:
		std::unordered_map<std::string, glm::vec3> colorLookup;
		glm::vec3 brushColor;

		FileLoader_MTL(std::string filedir, std::string filename) : FileLoader(filedir, filename) {}
		
		void load() {
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
	};
}