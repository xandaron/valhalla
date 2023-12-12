#pragma once
#include "../../../cfg.h"

namespace vkUtil {

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
		glm::vec3 eye;
		glm::vec3 center;
		glm::vec3 forwards;
		glm::vec3 right;
		glm::vec3 up;
	};

	class Camera {

	public:

		Camera(CameraView cameraViewData);

		void moveCamera(glm::vec3 movementVector, double delta);

		void rotateCamera(glm::vec3 rotationVector, double delta);

		void reset();

		float movementSpeed = 15.0f;
		float rotationSpeed = 5.0f;

		CameraView cameraViewData;
		CameraView initialCameraViewData;
	};
}