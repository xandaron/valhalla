#include "scene.h"

Game::Scene::Scene(std::vector<SceneObject> sceneObjects) {

	for (SceneObject sceneObject : sceneObjects) {
		
		for (PhysicsObject::Body* object : sceneObject.objects) {
			
			std::vector<PhysicsData::Vector3D<double>*> position = { &object->position, &object->orientation };
			positions[sceneObject.name].push_back(position);
			this->objects.push_back(object);
		}

		assetPack.objectTypes.push_back(sceneObject.name);
		assetPack.model_filenames[sceneObject.name] = sceneObject.model_filenames;
		assetPack.texture_filenames[sceneObject.name] = sceneObject.texture_filenames;
		assetPack.preTransforms[sceneObject.name] = sceneObject.preTransforms;
	}
};

Game::Scene::~Scene() {

	for (std::string type : assetPack.objectTypes) {
		positions[type].clear();
	}

	for (PhysicsObject::Body* object : objects) {
		delete object;
	}
	objects.clear();
}