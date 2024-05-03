#pragma once
#include <filesystem>
#include <zlib.h>
#include <variant>
#include "file_loader.h"
#include "tree.h"

namespace util {

	class MeshLoader : public FileLoader {
	public:
		std::vector<float> vertices;
		std::vector<uint32_t> indices;

		MeshLoader(std::string filedir, std::string filename, glm::mat4 preTransform) : FileLoader(filedir, filename) {
			this->preTransform = preTransform;
		}

	protected:
		glm::mat4 preTransform;
		std::vector<glm::f64vec3> v, vn;
		std::vector<glm::f64vec2> vt;
	};

	class MeshLoader_FBX : public MeshLoader {

	public:
		MeshLoader_FBX(std::string filedir, std::string filename, glm::mat4 preTransform) : MeshLoader(filedir, filename, preTransform) {}

		void load() {
			std::filesystem::path filePath{ filepath };
			uint64_t length = std::filesystem::file_size(filePath);
			if (length == 0) {
				throw std::invalid_argument("file { "+ filepath +" } doesn't exist");
			}

			// open file and skip file header
			std::ifstream file(filepath, std::fstream::binary);
			std::vector<uint8_t> buffer(27);
			file.read(reinterpret_cast<char*>(buffer.data()), 27);
			
			uint64_t pointer = 27;

			uint32_t endOffset = 0;
			uint32_t numProperties = 0;
			uint32_t propertyListLen = 0;
			uint8_t nameLen = 0;

			util::Tree tree = util::Tree(length);
			util::Node* node = tree.topOfStack();

			while (pointer < length) {

				if (pointer >= node->getEndOffset()) {
					tree.popFromStack();
					node = tree.topOfStack();
					continue;
				}

				buffer = std::vector<uint8_t>(4);
				file.read(reinterpret_cast<char*>(buffer.data()), 4);
				endOffset = endianSwap<uint32_t>(buffer);
				pointer += 4;

				buffer = std::vector<uint8_t>(4);
				file.read(reinterpret_cast<char*>(buffer.data()), 4);
				numProperties = endianSwap<uint32_t>(buffer);
				pointer += 4;

				buffer = std::vector<uint8_t>(4);
				file.read(reinterpret_cast<char*>(buffer.data()), 4);
				propertyListLen = endianSwap<uint32_t>(buffer);
				pointer += 4;

				buffer = std::vector<uint8_t>(1);
				file.read(reinterpret_cast<char*>(buffer.data()), 1);
				nameLen = (uint8_t)buffer[0];
				pointer++;
				
				if ((endOffset | numProperties | propertyListLen | nameLen) == 0) {
					if (node->getName() == "root") { break; }
					continue; 
				}

				buffer = std::vector<uint8_t>(nameLen);
				file.read(reinterpret_cast<char*>(buffer.data()), nameLen);
				std::string name = std::string(buffer.begin(), buffer.end());
				pointer += nameLen;

				//Skip these nodes
				if (name == "FBXHeaderExtension" || name == "GlobalSettings" || name == "Documents" || 
					name == "References" || name == "Definitions" || name == "Connections" || name == "Takes" || 
					name == "Fileld" || name == "CreationTime" || name == "Creator") {

					buffer = std::vector<uint8_t>(endOffset - pointer);
					file.read(reinterpret_cast<char*>(buffer.data()), endOffset - pointer);
					pointer = endOffset;
					continue;
				}

				Node* newNode = new util::Node(name, endOffset, numProperties);
				node->addNode(newNode);
				tree.addToStack(newNode);
				node = newNode;

				if (numProperties > 0) {
					buffer = std::vector<uint8_t>(propertyListLen);
					file.read(reinterpret_cast<char*>(buffer.data()), propertyListLen);
					pointer += propertyListLen;
					node->addProperties(extractProperties(buffer, numProperties));
				}
			}
			file.close();

			int nMappingType = 0;
			int nRefrenceType = 0;
			int uvMappingType = 0;
			int uvRefrenceType = 0;
			for (Node* i : tree.getRoot()->getChildNodes()) {
				if (i->getName() == "Objects") {
					for (Node* j : i->getChildNodes()) {
						if (j->getName() == "Geometry") {
							for (Node* k : j->getChildNodes()) {
								if (k->getName() == "Vertices") {
									propertyArray_t vertexData = std::get<propertyArray_t>(k->getProperties()[0]);
									for (int i = 0; i < vertexData.size(); i += 3) {
										v.push_back(glm::f64vec3(preTransform * glm::f64vec4(
											std::get<double>(vertexData[i]), std::get<double>(vertexData[i + 1]), std::get<double>(vertexData[i + 2]), 1.0))
										);
									}
								}
								else if (k->getName() == "PolygonVertexIndex") {
									propertyArray_t polygonDataVariant = std::get<propertyArray_t>(k->getProperties()[0]);
									for (int i = 0; i < polygonDataVariant.size(); i++) {
										polygonVertexIndex.push_back(std::get<int32_t>(polygonDataVariant[i]));
									}
								}
								else if (k->getName() == "LayerElementNormal") {
									for (Node* l : k->getChildNodes()) {
										std::string name = l->getName();
										if (name == "MappingInformationType") {
											propertyArray_t property = std::get<propertyArray_t>(l->getProperties()[0]);
											std::vector<char> word;
											for (int i = 0; i < property.size(); i++) {
												word.push_back((char)std::get<int8_t>(property[i]));
											}
											std::string wordS = std::string(word.begin(), word.end());
											if (wordS == "ByPolygonVertex") {
												continue;
											}
											else {
												nMappingType = 1;
											}
										}
										else if (name == "ReferenceInformationType") {
											propertyArray_t property = std::get<propertyArray_t>(l->getProperties()[0]);
											std::vector<char> word;
											for (int i = 0; i < property.size(); i++) {
												word.push_back(std::get<int8_t>(property[i]));
											}
											std::string wordS = std::string(word.begin(), word.end());
											if (wordS == "Direct") {
												continue;
											}
											else {
												nRefrenceType = 1;
											}
										}
										else if (name == "Normals") {
											propertyArray_t normalDataVariant = std::get<propertyArray_t>(l->getProperties()[0]);
											for (int i = 0; i < normalDataVariant.size(); i += 3) {
												vn.push_back(
													preTransform * glm::f64vec4(
													std::get<double>(normalDataVariant[i]),
													std::get<double>(normalDataVariant[i + 1]),
													std::get<double>(normalDataVariant[i + 2]),
													1.0
												));
											}
										}
									}
								}
								else if (k->getName() == "LayerElementUV") {
									for (Node* l : k->getChildNodes()) {
										std::string name = l->getName();
										if (name == "MappingInformationType") {
											propertyArray_t property = std::get<propertyArray_t>(l->getProperties()[0]);
											std::vector<char> word;
											for (int i = 0; i < property.size(); i++) {
												word.push_back((char)std::get<int8_t>(property[i]));
											}
											std::string wordS = std::string(word.begin(), word.end());
											if (wordS == "ByPolygonVertex") {
												continue;
											}
											else {
												uvMappingType = 1;
											}
										}
										else if (name == "ReferenceInformationType") {
											propertyArray_t property = std::get<propertyArray_t>(l->getProperties()[0]);
											std::vector<char> word;
											for (int i = 0; i < property.size(); i++) {
												word.push_back(std::get<int8_t>(property[i]));
											}
											std::string wordS = std::string(word.begin(), word.end());
											if (wordS == "Direct") {
												continue;
											}
											else {
												uvRefrenceType = 1;
											}
										}
										else if (name == "UV") {
											propertyArray_t UVDataVariant = std::get<propertyArray_t>(l->getProperties()[0]);
											for (int i = 0; i < UVDataVariant.size(); i += 2) {
												vt.push_back(glm::f64vec2(
														std::get<double>(UVDataVariant[i]),
														std::get<double>(UVDataVariant[i + 1])
												));
											}
										}
										else if (name == "UVIndex") {
											propertyArray_t UVIndexDataVariant = std::get<propertyArray_t>(l->getProperties()[0]);
											for (int i = 0; i < UVIndexDataVariant.size(); i++) {
												uvIndex.push_back(std::get<int32_t>(UVIndexDataVariant[i]));
											}
										}
									}
								}
							}
						}
					}
				}
			}

			pointer = 0;
			for (int i = 0; i < polygonVertexIndex.size(); i++) {
				if (polygonVertexIndex[i] < 0) {
					polygonVertexIndex[i] ^= -1;
					decomposPolygon(pointer, i);
					i++;
					pointer = i;
				}
			}

			for (int i = 0; i < polygons.size(); i++) {

				glm::vec3 pos = v[polygons[i]];
				glm::vec2 texCoord = texCoords[i];
				glm::vec3 normal = normals[i];
				std::string vertex_description = std::to_string(polygons[i]) + 
					"/" + std::to_string(texCoord[0]) + std::to_string(texCoord[1]) + 
					"/" + std::to_string(normal[0]) + std::to_string(normal[1]) + std::to_string(normal[2]);

				if (history.contains(vertex_description)) {
					indices.push_back(history[vertex_description]);
					continue;
				}

				uint32_t index = static_cast<uint32_t>(history.size());
				history.insert({ vertex_description, index });
				indices.push_back(index);

				//Position
				vertices.push_back(pos[0]);
				vertices.push_back(pos[1]);
				vertices.push_back(pos[2]);

				//Color
				vertices.push_back(0.8);
				vertices.push_back(0.8);
				vertices.push_back(0.8);

				//TexCoords
				vertices.push_back(texCoord[0]);
				vertices.push_back(texCoord[1]);

				//Normal
				vertices.push_back(normal[0]);
				vertices.push_back(normal[1]);
				vertices.push_back(normal[2]);
			}
		}

	private:
		std::unordered_map<std::string, uint32_t> history;
		std::vector<int32_t> polygons;
		std::vector<glm::vec3> normals;
		std::vector<glm::vec2> texCoords;
		std::vector<int32_t> polygonVertexIndex;
		std::vector<int32_t> uvIndex;

		// a really simple method to decompose polygons into triangles
		void decomposPolygon(int from, int to) {
			
			int decompositions = to - from - 2;
			while (decompositions >= 0) {

				polygons.push_back(polygonVertexIndex[from]);
				polygons.push_back(polygonVertexIndex[from + decompositions + 1]);
				polygons.push_back(polygonVertexIndex[from + decompositions + 2]);

				normals.push_back(vn[from]);
				normals.push_back(vn[from + decompositions + 1]);
				normals.push_back(vn[from + decompositions + 2]);

				texCoords.push_back(vt[uvIndex[from]]);
				texCoords.push_back(vt[uvIndex[from + decompositions + 1]]);
				texCoords.push_back(vt[uvIndex[from + decompositions + 2]]);
				decompositions--;
			}
		}

		template<typename T>
		T endianSwap(std::vector<uint8_t> bytes) {
			uint64_t result = 0;
			for (int i = bytes.size() - 1; i >= 0; i--) {
				result = (result << 8) + bytes[i];
			}
			return reinterpret_cast<T&>(result);
		}

		std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> extractProperties(std::vector<uint8_t> bytes, int propertyCount) {
			std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> result(propertyCount);
			int property = 0;
			while (property < propertyCount) {
				char propertyType = bytes[0];
				switch (propertyType) {
				case 'C':
					result[property] = std::bit_cast<uint8_t>(bytes[1]);
					bytes.erase(bytes.begin(), bytes.begin() + 2);
					break;
				case 'Y':
					result[property] = endianSwap<int16_t>(std::vector<uint8_t>(bytes.begin() + 1, bytes.begin() + 3));
					bytes.erase(bytes.begin(), bytes.begin() + 3);
					break;
				case 'I':
					result[property] = endianSwap<int32_t>(std::vector<uint8_t>(bytes.begin() + 1, bytes.begin() + 5));
					bytes.erase(bytes.begin(), bytes.begin() + 5);
					break;
				case 'F':
					result[property] = endianSwap<float>(std::vector<uint8_t>(bytes.begin() + 1, bytes.begin() + 5));
					bytes.erase(bytes.begin(), bytes.begin() + 5);
					break;
				case 'L':
					result[property] = endianSwap<int64_t>(std::vector<uint8_t>(bytes.begin() + 1, bytes.begin() + 9));
					bytes.erase(bytes.begin(), bytes.begin() + 9);
					break;
				case 'D':
					result[property] = endianSwap<double>(std::vector<uint8_t>(bytes.begin() + 1, bytes.begin() + 9));
					bytes.erase(bytes.begin(), bytes.begin() + 9);
					break;
				case 'b':
					bytes.erase(bytes.begin(), bytes.begin() + 1);
					result[property] = unpackArray<uint8_t>(bytes);
					break;
				case 'i':
					bytes.erase(bytes.begin(), bytes.begin() + 1);
					result[property] = unpackArray<int32_t>(bytes);
					break;
				case 'f':
					bytes.erase(bytes.begin(), bytes.begin() + 1);
					result[property] = unpackArray<float>(bytes);
					break;
				case 'l':
					bytes.erase(bytes.begin(), bytes.begin() + 1);
					result[property] = unpackArray<int64_t>(bytes);
					break;
				case 'd':
					bytes.erase(bytes.begin(), bytes.begin() + 1);
					result[property] = unpackArray<double>(bytes);
					break;
				case 'S':
				case 'R':
					bytes.erase(bytes.begin(), bytes.begin() + 1);
					result[property] = extractString(bytes);
					break;
				default:
					throw std::exception("invalid data type!");
				}
				property++;
			}
			return result;
		}

		template<typename T>
		propertyArray_t unpackArray(std::vector<uint8_t> &bytes) {
			uint32_t arrayLength = endianSwap<uint32_t>(std::vector<uint8_t>(bytes.begin(), bytes.begin() + 4));
			uint32_t encoding = endianSwap<uint32_t>(std::vector<uint8_t>(bytes.begin() + 4, bytes.begin() + 8));
			uint32_t compressedLength = endianSwap<uint32_t>(std::vector<uint8_t>(bytes.begin() + 8, bytes.begin() + 12));
			std::vector<uint8_t> data;

			uint32_t numberOfBytesConsumed = 12;
			int dataSize = sizeof(T);

			std::vector<uint8_t>::iterator begin = bytes.begin() + 12;
			if (encoding) {
				const std::vector<uint8_t> encodedData = std::vector<uint8_t>(begin, begin + compressedLength);
				numberOfBytesConsumed += compressedLength;
				uint64_t size = arrayLength * sizeof(T);
				data.resize(size);

				int ret = uncompress(&data[0], reinterpret_cast<uLongf*>(&size), reinterpret_cast<const Bytef*>(&encodedData[0]), encodedData.size());

				if (ret != Z_OK) {
					std::string e = "uncompression error code: " + std::to_string(ret);
					throw std::exception(e.c_str());
				}
			}
			else {
				data = std::vector<uint8_t>(begin, begin + arrayLength * dataSize);
				numberOfBytesConsumed += arrayLength * dataSize;
			}
			bytes.erase(bytes.begin(), bytes.begin() + numberOfBytesConsumed);
			
			propertyArray_t result(arrayLength);
			for (uint32_t i = 0; i < arrayLength; i++) {
				std::vector<uint8_t>::iterator begin = data.begin() + (i * dataSize);
				result[i] = endianSwap<T>(std::vector<uint8_t>(begin, begin + dataSize));
			}

			return result;
		}

		propertyArray_t extractString(std::vector<uint8_t>& bytes) {
			int length = endianSwap<uint32_t>(std::vector<uint8_t>(bytes.begin(), bytes.begin() + 4));
			propertyArray_t result;
			for (int i = 0; i < length; i++) {
				result.push_back((int8_t)bytes[i + 4]);
			}
			bytes.erase(bytes.begin(), bytes.begin() + length + 4);
			return result;
		}
	};

	class MeshLoader_OBJ : public MeshLoader {

	public:

		MeshLoader_OBJ(std::string filedir, std::string filename, glm::mat4 preTransform) : MeshLoader(filedir, filename, preTransform) {}

		void load() {
			std::ifstream file;
			std::string line;
			std::vector<std::string> words;
			file.open(filepath);

			while (std::getline(file, line)) {
				trim(line);
				words = split(line, " ");

				if (!words[0].compare("mtllib")) {
					FileLoader_MTL* mtllib = new FileLoader_MTL(filedir, words[1]);
					mtllib->load();
					colorLookup = mtllib->colorLookup;
					brushColor = mtllib->brushColor;
					delete mtllib;
				}
				if (!words[0].compare("v")) {
					read_vertex_data(words);
				}
				if (!words[0].compare("vt")) {
					read_texcoord_data(words);
				}
				if (!words[0].compare("vn")) {
					read_normal_data(words);
				}
				if (!words[0].compare("usemtl")) {
					if (colorLookup.contains(words[1])) {
						brushColor = colorLookup[words[1]];
					}
					else {
						brushColor = glm::vec3(1.0f);
					}
				}
				if (!words[0].compare("f")) {
					read_face_data(words);
				}
			}

			file.close();
		}

	private:
		std::unordered_map<std::string, uint32_t> history;
		std::unordered_map<std::string, glm::vec3> colorLookup;
		glm::vec3 brushColor;

		void read_vertex_data(const std::vector<std::string>& words) {
			glm::vec4 new_vertex = glm::vec4(std::stof(words[1]), std::stof(words[2]), std::stof(words[3]), 1.0f);
			glm::vec3 transformed_vertex = glm::vec3(preTransform * new_vertex);
			v.push_back(transformed_vertex);
		}

		void read_texcoord_data(const std::vector<std::string>& words) {
			glm::vec2 new_texcoord = glm::vec2(std::stof(words[1]), std::stof(words[2]));
			vt.push_back(new_texcoord);
		}

		void read_normal_data(const std::vector<std::string>& words) {
			glm::vec4 new_normal = glm::vec4(std::stof(words[1]), std::stof(words[2]), std::stof(words[3]), 0.0f);
			glm::vec3 transformed_normal = glm::vec3(preTransform * new_normal);
			vn.push_back(transformed_normal);
		}

		void read_face_data(const std::vector<std::string>& words) {

			size_t triangleCount = words.size() - 3;

			for (int i = 0; i < triangleCount; i++) {
				read_corner(words[1]);
				read_corner(words[2 + i]);
				read_corner(words[3 + i]);
			}
		}

		void read_corner(const std::string& vertex_description) {

			if (history.contains(vertex_description)) {
				indices.push_back(history[vertex_description]);
				return;
			}

			uint32_t index = static_cast<uint32_t>(history.size());
			history.insert({ vertex_description, index });
			indices.push_back(index);


			std::vector<std::string> v_vt_vn = split(vertex_description, "/");

			//Position
			glm::vec3 pos = v[std::stol(v_vt_vn[0]) - 1];
			vertices.push_back(pos[0]);
			vertices.push_back(pos[1]);
			vertices.push_back(pos[2]);

			//Color
			vertices.push_back(brushColor.r);
			vertices.push_back(brushColor.g);
			vertices.push_back(brushColor.b);

			//Texture coord
			glm::vec2 texcoord = glm::vec2(0.0f, 0.0f);
			if (v_vt_vn.size() == 3 && v_vt_vn[1].size() > 0) {
				texcoord = vt[std::stol(v_vt_vn[1]) - 1];
			}
			vertices.push_back(texcoord[0]);
			vertices.push_back(texcoord[1]);

			//Normal
			glm::vec3 normal = vn[std::stol(v_vt_vn[2]) - 1];
			vertices.push_back(normal[0]);
			vertices.push_back(normal[1]);
			vertices.push_back(normal[2]);
		}
	};

	static MeshLoader* createMeshLoader(std::string filedir, std::string filename, glm::mat4 preTransform) {
		std::vector<std::string> words = split(filename, ".");
		if (words[1] == "obj") {
			return new MeshLoader_OBJ(filedir, filename, preTransform);
		}
		else if (words[1] == "fbx") {
			return new MeshLoader_FBX(filedir, filename, preTransform);
		}
		throw std::invalid_argument("invalid file type");
	}
}