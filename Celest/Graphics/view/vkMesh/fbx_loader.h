#pragma once
#include "mesh_loader.h"
#include <zlib.h>
#include "../../../Game/util/tree.h"

namespace Fileloader {

	class FBX_Loader : public Mesh_Loader {
	public:
		FBX_Loader(std::string filedir, std::string filename, glm::mat4 preTransform);

		void load();

	private:
		std::unordered_map<std::string, uint32_t> history;
		std::vector<int32_t> polygons;
		std::vector<glm::vec3> normals;
		std::vector<glm::vec2> texCoords;
		std::vector<int32_t> polygonVertexIndex;
		std::vector<int32_t> uvIndex;

		void decomposPolygon(int from, int to);

		template<typename T>
		T endianSwap(std::vector<uint8_t> bytes);

		std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, util::propertyArray_t>> extractProperties(std::vector<uint8_t> bytes, int propertyCount);

		template<typename T>
		util::propertyArray_t unpackArray(std::vector<uint8_t>& bytes);

		util::propertyArray_t extractString(std::vector<uint8_t>& bytes);
	};
}