#pragma once
#include "../cfg.h"
#include "controller.h"
#include "../Physics/body.h"

namespace Entitys {
	class Entity {
	public:
		Entity(PhysicsObject::Body* physicsBody) {
			this->physicsBody = physicsBody;
		}

		void update(double delta) {
			if (controller == nullptr) { return; }

			move(delta);
			rotate(delta);
		}

		void move(double delta) {
			glm::f64vec3 movementVector = controller->movementVector;

			if (movementVector == glm::f64vec3(0.0)) { return; }

			movementVector = orientateVector(movementVector);
			movementVector *= movementSpeed * delta;

			physicsBody->position += movementVector;
		}

		void rotate(double delta) {
			glm::f64vec3 rotationVector = controller->rotationVector;

			if (rotationVector == glm::f64vec3(0.0)) { return; }

			rotationVector *= rotationSpeed * delta;
			rotationVector = orientateVector(rotationVector);

			physicsBody->rotate(rotationVector);
		}

		glm::f64vec3 getPosition() {
			return physicsBody->position;
		}

		glm::f64vec3 getForwards() {
			return orientateVector(glm::f64vec3(1.0, 0.0, 0.0));
		}

		glm::f64vec3 getRight() {
			return orientateVector(glm::f64vec3(0.0, 1.0, 0.0));
		}

		glm::f64vec3 getUp() {
			return orientateVector(glm::f64vec3(0.0, 0.0, 1.0));
		}

		glm::f64vec3 orientateVector(glm::f64vec3 v) {
			return physicsBody->orientationMatrix * v;
		}

		PhysicsObject::Body* getPhysicsObject() {
			return physicsBody;
		}

		void setController(Controller::Controller* controller) {
			this->controller = controller;
		}

	protected:
		int movementSpeed = 10;
		int rotationSpeed = 10;
		PhysicsObject::Body* physicsBody;
		Controller::Controller* controller;

	private:
	};
}