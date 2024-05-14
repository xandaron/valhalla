#pragma once
#include "../cfg.h"
#include "player_controller.h"
#include "entity.h"

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
		glm::vec4 forward;
		glm::vec4 right;
		glm::vec4 up;
	};

	struct CameraView {
		glm::f64vec3 eye = glm::f64vec3(0, 0, 0);
		glm::f64vec3 center = glm::f64vec3(1, 0, 0);
		glm::f64vec3 forward = glm::f64vec3(1, 0, 0);
		glm::f64vec3 right = glm::f64vec3(0, 1, 0);
		glm::f64vec3 up = glm::f64vec3(0, 0, 1);
	};

	class Camera {
	public:
		enum CameraMode {
			FREE,
			FOLLOW
		};

		Camera(CameraView cameraViewData);

		Camera(CameraView cameraViewData, Entitys::Entity* target);

		void update(double delta);

		void moveCamera(double delta);

		void rotateCamera(double delta);

		void reset();

		virtual CameraView getCameraViewData();

		CameraMode getMode();

		void setMode(Game::Camera::CameraMode mode);

		void setController(Controller::Controller* controller);

		Entitys::Entity* getTarget();

		void setTarget(Entitys::Entity* target);

		void setOffset(glm::f64vec3 offset);

	protected:
		CameraView cameraViewData;
		CameraView initialCameraViewData;

		double movementSpeed = 15.0;
		double rotationSpeed = 5.0;

		CameraMode mode;

		Controller::Controller* controller;

		Entitys::Entity* target;
		glm::f64vec3 offset = glm::f64vec3(0.0);
	};
}