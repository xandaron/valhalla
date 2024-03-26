#include "scene.h"
#include <algorithm> 
#include <cctype>
#include <locale>

// trim from start (in place)
inline void ltrim(std::string& s) {
	s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch) {
		return !std::isspace(ch);
		}));
}

// trim from end (in place)
inline void rtrim(std::string& s) {
	s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch) {
		return !std::isspace(ch);
		}).base(), s.end());
}

// trim from both ends (in place)
inline void trim(std::string& s) {
	rtrim(s);
	ltrim(s);
}

Game::Scene::Scene(const char* filepath) {

	load(filepath);
};

void Game::Scene::load(const std::string& sceneFilepath) {

	std::ifstream file;
	file.open(sceneFilepath);
	std::string line;
	std::vector<std::string> words;

	while (std::getline(file, line)) {
		trim(line);
		words = split(line, " ");

		if (!words[0].compare("camera")) {
			Game::CameraView cameraView;
			while (std::getline(file, line)) {
				if (line.find_first_not_of(" ") == std::string::npos) { continue; }

				trim(line);
				if (!line.compare("}")) {
					camera = new Game::Camera(cameraView);
					break;
				}

				words = split(line, ":");
				trim(words[0]);
				trim(words[1]);
				words[1] = words[1].substr(1, words[1].length() - 2);

				if (!words[0].compare("eye")) {
					std::vector<std::string> values = split(words[1], ",");
					cameraView.eye = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
				}
				else if (!words[0].compare("center")) {
					std::vector<std::string> values = split(words[1], ",");
					cameraView.center = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
				}
				else if (!words[0].compare("forward")) {
					std::vector<std::string> values = split(words[1], ",");
					cameraView.forward = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
				}
				else if (!words[0].compare("right")) {
					std::vector<std::string> values = split(words[1], ",");
					cameraView.right = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
				}
				else if (!words[0].compare("up")) {
					std::vector<std::string> values = split(words[1], ",");
					cameraView.up = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
				}
			}
		}
		else if (!words[0].compare("object")) {
			std::string name;
			int instance = 0;
			std::vector<std::pair<glm::f64vec3*, DataObject::Quaternion*>> instancePositions;

			while (std::getline(file, line)) {
				
				if (line.find_first_not_of(" ") == std::string::npos) { continue; }

				trim(line);

				if (!line.compare("}")) {
					positions[name] = instancePositions;
					assetPack.objectTypes.push_back(name);
					break;
				}
				
				if (line.find(":") != std::string::npos) {
					words = split(line, ":");
					trim(words[0]);
					trim(words[1]);
					words[1] = words[1].substr(1, words[1].length() - 2);

					if (!words[0].compare("name")) {
						name = words[1];
					}
					else if (!words[0].compare("model_filename")) {
						std::string* filepath = new std::string("assets/models/");
						filepath->append(words[1]);
						assetPack.model_filenames.push_back(filepath);
					}
					else if (!words[0].compare("material_filename")) {
						std::string* filepath = new std::string("assets/materials/");
						filepath->append(words[1]);
						assetPack.material_filenames.push_back(filepath);
					}
					else if (!words[0].compare("texture_filename")) {
						std::string* filepath = new std::string("assets/textures/");
						filepath->append(words[1]);
						assetPack.texture_filenames.push_back(filepath);
					}
					else if (!words[0].compare("pre_transform_scalar")) {
						assetPack.preTransforms.push_back(glm::f64mat4(std::stof(words[1])));
					}
				}
				else {
					words = split(line, " ");
					if (!words[0].compare("instance")) {
						PhysicsObject::BodyDescriptor bodyDescriptor;
						bodyDescriptor.uid = name + "_" + std::to_string(instance);

						while (std::getline(file, line)) {
							if (line.find_first_not_of(" ") == std::string::npos) { continue; }
							
							trim(line);

							if (!line.compare("}")) {
								PhysicsObject::Body* object = new PhysicsObject::Body(bodyDescriptor);
								objects.push_back(object);
								instancePositions.push_back({ &object->position, &object->orientation });
								instance++;
								break;
							}

							words = split(line, ":");
							trim(words[0]);
							trim(words[1]);
							words[1] = words[1].substr(1, words[1].length() - 2);

							if (!words[0].compare("position")) {
								std::vector<std::string> values = split(words[1], ",");
								bodyDescriptor.position = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
							}
							else if (!words[0].compare("velocity")) {
								std::vector<std::string> values = split(words[1], ",");
								bodyDescriptor.velocity = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
							}
							else if (!words[0].compare("angular_velocity")) {
								std::vector<std::string> values = split(words[1], ",");
								bodyDescriptor.angularVelocity = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
							}
							else if (!words[0].compare("mass")) {
								if (!words[0].compare("Infinite")) {
									bodyDescriptor.invMass = 0;
								}
								else {
									bodyDescriptor.invMass = 1.0 / std::stof(words[1]);
								}
							}
							else if (!words[0].compare("restitution")) {
								bodyDescriptor.coefRestitution = std::stof(words[1]);
							}
							else if (!words[0].compare("hitbox_type")) {
								if (!words[0].compare("SPHERE")) {
									bodyDescriptor.hitboxDescriptor.type = Collision::HitboxType::SPHERE;
								}
								else if (!words[0].compare("AABB")) {
									bodyDescriptor.hitboxDescriptor.type = Collision::HitboxType::AABB;
								}
								else if (!words[0].compare("OBB")) {
									bodyDescriptor.hitboxDescriptor.type = Collision::HitboxType::OBB;
								}
							}
							else if (!words[0].compare("hitbox_halfdims")) {
								std::vector<std::string> values = split(words[1], ",");
								bodyDescriptor.hitboxDescriptor.halfDimensions = glm::f64vec3(std::stof(values[0]), std::stof(values[1]), std::stof(values[2]));
							}
						}
					}
				}
			}
		}
	}
	file.close();
}

Game::Camera* Game::Scene::GetCamera() {
	return camera;
}

Game::AssetPack Game::Scene::GetAssetPack() {
	return assetPack;
}

std::vector<PhysicsObject::Body*> Game::Scene::GetPhysicsObjects() {
	return objects;
}

std::unordered_map<std::string, std::vector<std::pair<glm::f64vec3*, DataObject::Quaternion*>>> Game::Scene::GetPositions() {
	return positions;
}

Game::Scene::~Scene() {

	for (std::string type : assetPack.objectTypes) {
		positions[type].clear();
	}

	for (PhysicsObject::Body* object : objects) {
		delete object;
	}
	objects.clear();
}