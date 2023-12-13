#include "camera.h"

vkUtil::Camera::Camera(CameraView cameraViewData) :
	initialCameraViewData(cameraViewData),
	cameraViewData(cameraViewData)
{

}

void vkUtil::Camera::moveCamera(glm::vec3 movementVector, double delta) {

	movementVector *= movementSpeed * delta;
	movementVector = movementVector.x * cameraViewData.forwards
				   + movementVector.y * cameraViewData.right
				   + movementVector.z * cameraViewData.up;
	cameraViewData.eye	  += movementVector;
	cameraViewData.center += movementVector;
}

void vkUtil::Camera::rotateCamera(glm::vec3 rotationVector, double delta) {

	glm::vec3 w = rotationVector.x * cameraViewData.forwards
				+ rotationVector.y * cameraViewData.right
				+ rotationVector.z * cameraViewData.up;
	
	float theta = rotationSpeed * delta;
	glm::mat3 rotationMatrix = glm::rotate(glm::mat4(1.0), theta, w);

	cameraViewData.forwards = glm::normalize(rotationMatrix * cameraViewData.forwards);
	cameraViewData.right    = glm::normalize(rotationMatrix * cameraViewData.right);
	cameraViewData.up       = glm::normalize(rotationMatrix * cameraViewData.up);
	cameraViewData.center   = cameraViewData.eye + cameraViewData.forwards;
}

void vkUtil::Camera::reset() {
	cameraViewData = initialCameraViewData;
}