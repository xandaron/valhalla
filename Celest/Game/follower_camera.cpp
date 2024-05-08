#include "follower_camera.h"

Game::FollowCamera::FollowCamera(CameraView cameraViewData) : Camera(cameraViewData) {
	type = CameraType::FOLLOW;
}

Game::FollowCamera::FollowCamera(CameraView cameraViewData, Entitys::Entity* target) : Camera(cameraViewData) {
	this->target = target;
}

void Game::FollowCamera::setTarget(Entitys::Entity* target) {
	this->target = target;
}

Game::CameraView Game::FollowCamera::getCameraViewData() {
	CameraView result;
	result.eye = target->getPosition() + target->orientateVector(offset);
	result.forward = target->getForwards();
	result.right = target->getRight();
	result.up = target->getUp();
	result.center = result.eye + result.forward;
	return result;
}

Entitys::Entity* Game::FollowCamera::getTarget() {
	return target;
}

void Game::FollowCamera::setOffset(glm::f64vec3 offset) {
	this->offset = offset;
}