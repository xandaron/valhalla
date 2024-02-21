#pragma once
#include "../cfg.h"
#include "body.h"

namespace Physics {

	class PhysicsEngine {

	public:

		PhysicsEngine();

		~PhysicsEngine();

		void init(std::vector<PhysicsObject::Body*> bodys);

		void update(double delta);

		void setBodys(std::vector<PhysicsObject::Body*> bodys);

		void clearBodys();

	private:

		std::vector<PhysicsObject::Body*> bodys;

		void resolveCollision(PhysicsObject::Body* objA, PhysicsObject::Body* objB, Collision::CollisionInfo* collisionInfo);

		void resolveCollisions(double delta);

		void updateBodys(double delta);

		void gravitationalForce(std::vector<PhysicsObject::Body*> objs);

		glm::f64vec3 calculateGravitationalForce(PhysicsObject::Body* objA, PhysicsObject::Body* objB);
	};
}