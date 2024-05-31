#pragma once
#include "../../cfg.h"
#include "../collider.h"
#include "../quaternion.h"
#include "body.h"

namespace PhysicsObject {

	class DynamicBody : public Body {
	public:
		glm::f64vec3 velocity;
		glm::f64vec3 force;

		glm::f64vec3 angularVelocity;
		glm::f64vec3 torque;

		glm::f64mat3 orientationMatrix;

		double invMass;
		glm::f64mat3 invInertia;
		glm::f64mat3 invInertiaOrientated;

		DynamicBody(BodyDescriptor bodyDescriptor);

		bool checkColliding(Body* obj, Collision::CollisionInfo* collisionInfo);

		void updateInvInertiaOrientated();

		void applyForce(glm::f64vec3 force);

		void applyForceAtPoint(glm::f64vec3 force, glm::f64vec3 point);

		void applyCollisionImpulse(glm::f64vec3 force, glm::f64vec3 distance);

		void move(glm::f64vec3 movement);

		void rotate(glm::f64vec3 rotation);

		glm::f64vec3 momentum();

		~DynamicBody();
	};
}