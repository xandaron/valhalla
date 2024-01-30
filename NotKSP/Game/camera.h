#pragma once
#include "../cfg.h"

namespace Game {

	/**
		Describes the data to send to the shader for each frame.
	*/
	struct CameraMatrices {
		glm::mat4 view;
		glm::mat4 projection;
		glm::mat4 viewProjection;
	};

	struct CameraVectors {
		glm::vec4 forwards;
		glm::vec4 right;
		glm::vec4 up;
	};

	struct CameraView {
		glm::f64vec3 eye;
		glm::f64vec3 center;
		glm::f64vec3 forwards;
		glm::f64vec3 right;
		glm::f64vec3 up;
	};

	class Camera {

	public:

		Camera(CameraView cameraViewData);

		void updateCamera(glm::f64vec3 movementVector, glm::f64vec3 rotationVector, double delta);

		void moveCamera(glm::f64vec3 movementVector, double delta);

		void rotateCamera(glm::f64vec3 rotationVector, double delta);

		void reset();

		double movementSpeed = 15.0;
		double rotationSpeed = 5.0;

		CameraView cameraViewData;
		CameraView initialCameraViewData;
	};
}