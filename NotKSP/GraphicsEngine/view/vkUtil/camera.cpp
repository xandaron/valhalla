#include "camera.h"

vkUtil::Camera::Camera(CameraVectors cameraVectorData, CameraView cameraViewData):
	cameraVectorData(cameraVectorData),
	cameraViewData(cameraViewData)
{

}

void vkUtil::Camera::moveCamera(float dx, float dy, double delta) {
	dx *= speed * delta;
	dy *= speed * delta;
	cameraViewData.eye += dx * cameraVectorData.forwards.xyz() + dy * cameraVectorData.right.xyz();
	cameraViewData.center += dx * cameraVectorData.forwards.xyz() + dy * cameraVectorData.right.xyz();
}

void vkUtil::Camera::rotateCamera(float dt, double delta) {
	dt *= delta;
}