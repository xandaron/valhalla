#pragma once
#include "collider.h"
#include "bounding_sphere.h"

namespace Collision {

	struct HitboxDescriptor {
		hitboxTypes type = hitboxTypes::SPHERE;
		double radius = 1;
	};
}