#pragma once
#include "../cfg.h"
#include "../Physics/body.h"

namespace Game {
	
	struct SceneObject {
		std::string name;
		std::vector<const char*> model_filenames;
		std::vector<const char*> texture_filenames;
		glm::f64mat4 preTransforms;
		std::vector<PhysicsObject::Body*> objects;
	};

	struct AssetPack {
		std::vector<std::string> objectTypes;
		std::unordered_map<std::string, std::vector<const char*>> model_filenames;
		std::unordered_map<std::string, std::vector<const char*>> texture_filenames;
		std::unordered_map<std::string, glm::mat4> preTransforms;
	};

	class Scene {

	public:

		Scene(std::vector<SceneObject> sceneObjects);
		~Scene();

		AssetPack assetPack;
		std::vector<PhysicsObject::Body*> objects;
		std::unordered_map<std::string, std::vector<std::pair<glm::f64vec3*, DataObject::Quaternion*>>> positions;
	};
}