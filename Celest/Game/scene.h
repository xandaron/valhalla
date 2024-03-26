#pragma once
#include "../cfg.h"
#include "../Physics/body.h"
#include "camera.h"

namespace Game {
	
	struct SceneObject {
		std::string name;
		std::pair<std::string*, std::string*> model_filenames;
		std::string* texture_filenames;
		glm::f64mat4 preTransforms;
		std::vector<PhysicsObject::Body*> objects;
	};

	struct AssetPack {
		std::vector<std::string> objectTypes;
		std::vector<std::string*> model_filenames;
		std::vector<std::string*> material_filenames;
		std::vector<std::string*> texture_filenames;
		std::vector<glm::mat4> preTransforms;
		std::vector<std::string*> skybocks;
	};

	class Scene {

	public:

		Scene(const char* filepath);

		void load(const std::string& sceneFilepath);

		Game::Camera* GetCamera();

		AssetPack GetAssetPack();

		std::vector<PhysicsObject::Body*> GetPhysicsObjects();

		std::unordered_map<std::string, std::vector<std::pair<glm::f64vec3*, DataObject::Quaternion*>>> GetPositions();

		~Scene();

	private:
		AssetPack assetPack;
		Game::Camera* camera;
		std::vector<PhysicsObject::Body*> objects;
		std::unordered_map<std::string, std::vector<std::pair<glm::f64vec3*, DataObject::Quaternion*>>> positions;
	};
}