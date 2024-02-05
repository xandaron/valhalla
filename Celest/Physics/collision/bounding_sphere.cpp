#include "bounding_sphere.h"

Collision::BoundingSphere::BoundingSphere(glm::f64vec3* origin, double radius) {
	type = hitboxTypes::SPHERE;
	this->origin = origin;
	this->radius = radius;
}

bool Collision::BoundingSphere::checkColliding(Collider* obj) {
	if (obj->type == hitboxTypes::SPHERE) {
		BoundingSphere* objSphere = dynamic_cast<BoundingSphere*>(obj);
		if (glm::abs(glm::distance(*origin, *objSphere->origin)) <= radius + objSphere->radius) {
			return true;
		}
		return false;
	}

	std::cout << "Collision detection of this type not defined" << std::endl;
	return false;
}