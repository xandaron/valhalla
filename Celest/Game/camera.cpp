#include "camera.h"

Game::Camera::Camera(CameraView cameraViewData) :
	initialCameraViewData(cameraViewData),
	cameraViewData(cameraViewData)
{

}

void Game::Camera::updateCamera(glm::f64vec3 movementVector, glm::f64vec3 rotationVector, double delta) {

	if (movementVector != glm::f64vec3(0.0)) {
		moveCamera(movementVector, delta);
	}
	if (rotationVector != glm::f64vec3(0.0)) {
		rotateCamera(rotationVector, delta);
	}
}

void Game::Camera::moveCamera(glm::f64vec3 movementVector, double delta) {

	movementVector *= movementSpeed * delta;
	movementVector = movementVector.x * cameraViewData.forwards
				   + movementVector.y * cameraViewData.right
				   + movementVector.z * cameraViewData.up;
	cameraViewData.eye	  += movementVector;
	cameraViewData.center += movementVector;
}

void Game::Camera::rotateCamera(glm::f64vec3 rotationVector, double delta) {

	glm::f64vec3 w = rotationVector.x * cameraViewData.forwards
				+ rotationVector.y * cameraViewData.right
				+ rotationVector.z * cameraViewData.up;
	
	double theta = rotationSpeed * delta;
	glm::f64mat3 rotationMatrix = glm::rotate(glm::f64mat4(1.0), theta, w);

	cameraViewData.forwards = glm::normalize(rotationMatrix * cameraViewData.forwards);
	cameraViewData.right    = glm::normalize(rotationMatrix * cameraViewData.right);
	cameraViewData.up       = glm::normalize(rotationMatrix * cameraViewData.up);
	cameraViewData.center   = cameraViewData.eye + cameraViewData.forwards;
}

void Game::Camera::reset() {
	cameraViewData = initialCameraViewData;
}