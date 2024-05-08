#pragma once
#include "camera.h"
#include "entity.h"

namespace Game {
	class FollowCamera : public Camera {
	public:
		FollowCamera(CameraView cameraViewData);

		FollowCamera(CameraView cameraViewData, Entitys::Entity* target);

		void setTarget(Entitys::Entity* target);

		CameraView getCameraViewData() override;

		Entitys::Entity* getTarget();

		void setOffset(glm::f64vec3 offset);

	private:
		Entitys::Entity* target;
		glm::f64vec3 offset = glm::f64vec3(0.0);
	};
}