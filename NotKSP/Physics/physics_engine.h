#pragma once
#include "../cfg.h"
#include "body.h"

namespace Physics {

	class PhysicsEngine {

	public:

		PhysicsEngine();

		~PhysicsEngine();

		void update(double delta);

		void setBodys(std::vector<PhysicsObject::Body*> bodys);

		void clearBodys();

	private:

		std::vector<PhysicsObject::Body*> bodys;

		void updateBodys(double delta);
	};
}