#include "camera.h"

Game::Camera::Camera(CameraView cameraViewData) :
	initialCameraViewData(cameraViewData),
	cameraViewData(cameraViewData)
{

}

void Game::Camera::update(double delta) {

	if (controller == nullptr) { return; }

	moveCamera(delta);
	rotateCamera(delta);
}

void Game::Camera::moveCamera(double delta) {

	glm::f64vec3 movementVector = controller->movementVector;

	if (movementVector == glm::f64vec3(0.0)) { return; }

	movementVector *= movementSpeed * delta;
	movementVector = movementVector.x * cameraViewData.forward
				   + movementVector.y * cameraViewData.right
				   + movementVector.z * cameraViewData.up;
	cameraViewData.eye	  += movementVector;
	cameraViewData.center += movementVector;
}

void Game::Camera::rotateCamera(double delta) {

	glm::f64vec3 rotationVector = controller->rotationVector;

	if (rotationVector == glm::f64vec3(0.0)) { return; }

	glm::f64vec3 w = rotationVector.x * cameraViewData.forward
				+ rotationVector.y * cameraViewData.right
				+ rotationVector.z * cameraViewData.up;
	
	double theta = rotationSpeed * delta;
	glm::f64mat3 rotationMatrix = glm::rotate(glm::f64mat4(1.0), theta, w);

	cameraViewData.forward = glm::normalize(rotationMatrix * cameraViewData.forward);
	cameraViewData.right   = glm::normalize(rotationMatrix * cameraViewData.right);
	cameraViewData.up      = glm::normalize(rotationMatrix * cameraViewData.up);
	cameraViewData.center  = cameraViewData.eye + cameraViewData.forward;
}

void Game::Camera::reset() {
	cameraViewData = initialCameraViewData;
}

Game::CameraView Game::Camera::getCameraViewData() {
	return cameraViewData;
}