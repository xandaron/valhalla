#include "body.h"

PhysicsObject::Body::Body(BodyDescriptor descriptor) {

	uid = descriptor.uid;

	position = descriptor.position;
	orientation = descriptor.orientation;
	glm::f64mat3 orientationMatrix = orientation.toMat3();
	translationMatrix = glm::f64mat4(
		orientationMatrix[0][0], orientationMatrix[0][1], orientationMatrix[0][2], 0,
		orientationMatrix[1][0], orientationMatrix[1][1], orientationMatrix[1][2], 0,
		orientationMatrix[2][0], orientationMatrix[2][1], orientationMatrix[2][2], 0,
		position.x, position.y, position.z, 1
	);

	coefRestitution = descriptor.coefRestitution;
	coefFriction = descriptor.coefFriction;

	if (descriptor.hitboxDescriptor.type == Collision::HitboxType::AABB) {
		hitbox = new Collision::AABBCollider(&position, descriptor.hitboxDescriptor.halfDimensions);
	}
	else if (descriptor.hitboxDescriptor.type == Collision::HitboxType::OBB) {
		hitbox = new Collision::OBBCollider(&position, descriptor.hitboxDescriptor.halfDimensions, &orientation);
	}
	else {
		hitbox = new Collision::SphereCollider(&position, descriptor.hitboxDescriptor.halfDimensions.x);
	}
}

PhysicsObject::Body::~Body() {
	delete hitbox;
}