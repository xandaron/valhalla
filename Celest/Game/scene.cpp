#include "scene.h"
#include <algorithm> 
#include <cctype>
#include <locale>

Game::Scene::Scene(const char* filepath) {
	load(filepath);
};

void Game::Scene::load(const char* sceneFilepath) {
	std::ifstream file;
	file.open(sceneFilepath);
	std::string line;
	std::vector<std::string> words;
	int cameraType = 0;
	std::string cameraTarget;

	while (std::getline(file, line)) {
		trim(line);
		words = split(line, " ");

		if (!words[0].compare("camera")) {
			Game::CameraView cameraView;
			while (std::getline(file, line)) {
				if (line.find_first_not_of(" ") == std::string::npos) { continue; }

				trim(line);
				if (!line.compare("}")) {
					if (cameraType == 1) {
						camera = new Camera(cameraView);
						camera->setMode(Game::Camera::CameraMode::FOLLOW);
						camera->setOffset(glm::f64vec3(-10, 0, 0));
					}
					else {
						camera = new Game::Camera(cameraView);
					}
					cameras.push_back(camera);
					cameraArrayPointer++;
					break;
				}

				words = split(line, ":");
				trim(words[0]);
				trim(words[1]);
				words[1] = words[1].substr(1, words[1].length() - 2);

				if (!words[0].compare("type")) {
					if (!words[1].compare("follow")) {
						cameraType = 1;
					}
				}
				else if (!words[0].compare("target")) {
					cameraTarget = words[1];
				}
				else if (!words[0].compare("eye")) {
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

			while (std::getline(file, line)) {
				
				if (line.find_first_not_of(" ") == std::string::npos) { continue; }

				trim(line);

				if (!line.compare("}")) {
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
						assetPack.model_filenames.push_back(words[1]);
					}
					else if (!words[0].compare("texture_filename")) {
						assetPack.texture_filenames.push_back(words[1]);
					}
					else if (!words[0].compare("pre_transform")) {
						std::vector<std::string> preTransformWords = split(words[1], ",");
						if (preTransformWords.size() == 3) {
							assetPack.preTransforms.push_back(glm::f64mat4(
								std::stof(preTransformWords[0]), 0, 0, 0,
								0, std::stof(preTransformWords[1]), 0, 0,
								0, 0, std::stof(preTransformWords[2]), 0,
								0, 0, 0, 1
							));
						}
						else {
							assetPack.preTransforms.push_back(glm::f64mat4(std::stof(words[1])));
						}
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
								PhysicsObject::DynamicBody* physicsObject = new PhysicsObject::DynamicBody(bodyDescriptor);
								physicsObjects.push_back(physicsObject);
								Entitys::Entity* entity = new Entitys::Entity(physicsObject);
								mappedObjects[name].push_back(entity);
								instance++;

								if (cameraType == 1 && !bodyDescriptor.uid.compare(cameraTarget)) {
									camera->setTarget(entity);
								}
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

void Game::Scene::update(double delta) {
	for (auto obj : mappedObjects) {
		for (auto o : obj.second) {
			o->update(delta);
		}
	}
	camera->update(delta);
}

Game::Camera* Game::Scene::getCamera() {
	return camera;
}

void Game::Scene::setCamera(Camera* camera) {
	this->camera = camera;
}

Game::AssetPack Game::Scene::getAssetPack() {
	return assetPack;
}

std::vector<PhysicsObject::Body*> Game::Scene::getPhysicsObjects() {
	return physicsObjects;
}

std::unordered_map<std::string, std::vector<Entitys::Entity*>> Game::Scene::getMappedObjects() {
	return mappedObjects;
}

void Game::Scene::cycleCamera(Controller::PlayerController* pc) {
	if (camera->getMode() == Game::Camera::CameraMode::FOLLOW) {
		camera->getTarget()->setController(nullptr);
	}
	else {
		camera->setController(nullptr);
	}

	cameraArrayPointer = (cameraArrayPointer + 1) % cameras.size();
	camera = cameras[cameraArrayPointer];

	if (camera->getMode() == Game::Camera::CameraMode::FOLLOW) {
		camera->getTarget()->setController(pc);
	}
	else {
		camera->setController(pc);
	}
}

Game::Scene::~Scene() {
	for (auto obj : physicsObjects) {
		delete obj;
	}

	for (auto obj : mappedObjects) {
		for (auto o : obj.second) {
			delete o;
		}
	}

	mappedObjects.clear();
}