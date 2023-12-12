#include "scene.h"

Game::Scene::Scene(std::vector<SceneObject> sceneObjects) {

	for (SceneObject sceneObject : sceneObjects) {
		
		std::vector<PhysicsData::Vector3D<double>*> objectPositions;
		for (PhysicsObject::Body* object : sceneObject.objects) {
			objectPositions.push_back(&object->position);
			this->objects.push_back(object);
		}
		positions[sceneObject.name] = objectPositions;

		assetPack.objectTypes.push_back(sceneObject.name);
		assetPack.model_filenames[sceneObject.name] = sceneObject.model_filenames;
		assetPack.texture_filenames[sceneObject.name] = sceneObject.texture_filenames;
		assetPack.preTransforms[sceneObject.name] = sceneObject.preTransforms;
	}
};

Game::Scene::~Scene() {

	for (std::string type : assetPack.objectTypes) {
		for (PhysicsData::Vector3D<double>* position : positions[type]) {
			delete position;
		}
	}

	for (PhysicsObject::Body* object : objects) {
		delete object;
	}
}