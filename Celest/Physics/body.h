#pragma once
#include "../cfg.h"
#include "collision/collider.h"
#include "quaternion.h"

namespace PhysicsObject {

	struct BodyDescriptor {
		std::string uid;

		glm::f64vec3 position = glm::f64vec3(0);
		glm::f64vec3 velocity = glm::f64vec3(0);

		DataObject::Quaternion orientation = DataObject::Quaternion();
		glm::f64vec3 angularVelocity = glm::f64vec3(0);

		double invMass = 1.0;

		double coefRestitution = 1.0;
		double coefFriction = 1.0;

		Collision::HitboxDescriptor hitboxDescriptor;
	};

	class Body {

	public:

		Body(BodyDescriptor bodyDescriptor);
		~Body();

		std::string uid;
		
		glm::f64vec3 position;
		glm::f64vec3 velocity;
		glm::f64vec3 force;

		DataObject::Quaternion orientation;
		glm::f64vec3 angularVelocity;
		glm::f64vec3 torque;
		
		double invMass;
		glm::f64mat3 invInertia;

		double coefRestitution;
		double coefFriction;

		Collision::Collider* hitbox;

		void init(std::vector<Body*> objs);

		void firstUpdate(double delta);

		bool checkColliding(Body* obj, Collision::CollisionInfo* collisionInfo);

		void secondUpdate(double delta);

		glm::f64mat3 invInertiaTensor();

		void applyForce(glm::f64vec3 force);

		void applyForceAtPoint(glm::f64vec3 force, glm::f64vec3 point);

		void applyCollisionImpulse(glm::f64vec3 force, glm::f64vec3 distance);

		glm::f64vec3 momentum();
	};
}