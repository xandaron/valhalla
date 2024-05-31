#pragma once
#include "../cfg.h"
#include "objects/body.h"

namespace Physics {

	class Engine {

	public:
		Engine();

		void update(double delta);

		void setBodys(std::vector<PhysicsObject::Body*> bodys);

		void clearBodys();

	private:
		std::vector<PhysicsObject::Body*> bodys;

		void updateBodys(double delta);

		/*
		void resolveCollision(PhysicsObject::Body* objA, PhysicsObject::Body* objB, Collision::CollisionInfo* collisionInfo);

		void resolveCollisions(double delta);
		*/
	};
}