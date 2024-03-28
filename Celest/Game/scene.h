#pragma once
#include "../cfg.h"
#include "../Physics/body.h"
#include "camera.h"

namespace Game {

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

		Game::Camera* getCamera();

		AssetPack getAssetPack();

		std::vector<PhysicsObject::Body*> getPhysicsObjects();

		std::unordered_map<std::string, std::vector<PhysicsObject::Body*>> getMappedObjects();

		~Scene();

	private:
		AssetPack assetPack;
		Game::Camera* camera;
		std::vector<PhysicsObject::Body*> physicsObjects;
		std::unordered_map<std::string, std::vector<PhysicsObject::Body*>> mappedObjects;
	};
}