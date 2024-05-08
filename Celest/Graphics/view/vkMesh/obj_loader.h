#pragma once
#include "mesh_loader.h"

namespace Fileloader {

	class OBJ_Loader : public Mesh_Loader {
	public:
		OBJ_Loader(std::string filedir, std::string filename, glm::mat4 preTransform);

		void load();

	private:
		std::unordered_map<std::string, uint32_t> history;
		std::unordered_map<std::string, glm::vec3> colorLookup;
		glm::vec3 brushColor;

		void read_vertex_data(const std::vector<std::string>& words);

		void read_texcoord_data(const std::vector<std::string>& words);

		void read_normal_data(const std::vector<std::string>& words);

		void read_face_data(const std::vector<std::string>& words);

		void read_corner(const std::string& vertex_description);
	};
}