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

		void resolveCollision(PhysicsObject::Body* obj_0, PhysicsObject::Body* obj_1);

		void resolveCollisions(double delta);

		void updateBodys(double delta);
	};
}