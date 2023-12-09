#pragma once
#include "../../cfg.h"

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
		glm::vec3 up;
	};

	class Camera {

	public:

		Camera(CameraVectors cameraVectorData, CameraView cameraViewData);

		void moveCamera(float dx, float dy, double delta);

		void rotateCamera(float dt, double delta);

		CameraVectors cameraVectorData;
		CameraView cameraViewData;

		float speed = 5.0f;
	};
}