#pragma once
#include "../../cfg.h"
#include "collider.h"

namespace Collision {
	class BoundingSphere : public Collider {

	public:
		BoundingSphere(glm::f64vec3* origin, double radius);

		bool checkColliding(Collider* obj);

	private:
		double radius;
	};
}