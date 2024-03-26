#include "body.h"

PhysicsObject::Body::Body(BodyDescriptor bodyDescriptor)
{
	uid = bodyDescriptor.uid;

	position = bodyDescriptor.position;
	velocity = bodyDescriptor.velocity;
	force = glm::f64vec3(0);

	orientation = bodyDescriptor.orientation;
	angularVelocity = bodyDescriptor.angularVelocity;
	torque = glm::f64vec3(0);
	
	if (bodyDescriptor.hitboxDescriptor.type == Collision::HitboxType::AABB) {
		hitbox = new Collision::AABBCollider(&position, bodyDescriptor.hitboxDescriptor.halfDimensions);
	}
	else if (bodyDescriptor.hitboxDescriptor.type == Collision::HitboxType::OBB) {
		hitbox = new Collision::OBBCollider(&position, bodyDescriptor.hitboxDescriptor.halfDimensions, &orientation);
	}
	else {
		hitbox = new Collision::SphereCollider(&position, bodyDescriptor.hitboxDescriptor.halfDimensions.x);
	}

	invMass = bodyDescriptor.invMass;
	invInertia = hitbox->invInertiaMat(invMass);

	coefRestitution = bodyDescriptor.coefRestitution;
	coefFriction = bodyDescriptor.coefFriction;
}

PhysicsObject::Body::~Body() {
	delete hitbox;
}

void PhysicsObject::Body::init(std::vector<Body*> objs) {}

void PhysicsObject::Body::firstUpdate(double delta) {
	velocity += force * invMass * delta / 2.0;
	position.xyz += velocity * delta;
	force = glm::f64vec3(0.0);
	torque = glm::f64vec3(0.0);
}

bool PhysicsObject::Body::checkColliding(Body* obj, Collision::CollisionInfo* collisionInfo) {
	return Collision::CheckColliding(hitbox, obj->hitbox, collisionInfo);
}

void PhysicsObject::Body::secondUpdate(double delta) {
	velocity += force * invMass * delta / 2.0;
	angularVelocity += torque * invInertiaTensor() * delta;
	orientation = (orientation + DataObject::Quaternion(angularVelocity * delta * 0.5) * orientation).normalize();
}

glm::f64mat3 PhysicsObject::Body::invInertiaTensor() {
	glm::f64mat3 orientationMatrix = orientation.toMat3();
	return orientationMatrix * invInertia;

	/*glm::f64mat3 invOrientationMatrix = orientation.conjugate().toMat3();
	glm::f64mat3 orientationMatrix = orientation.toMat3();

	return orientationMatrix * invInertia * invOrientationMatrix;*/
}

void PhysicsObject::Body::applyForce(glm::f64vec3 force) {
	this->force += force;
}

void PhysicsObject::Body::applyForceAtPoint(glm::f64vec3 force, glm::f64vec3 point) {
	this->force += force;
	point -= position;
	torque += glm::cross(point, force);
}

void PhysicsObject::Body::applyCollisionImpulse(glm::f64vec3 force, glm::f64vec3 distance) {
	this->velocity += force * invMass;
	angularVelocity += invInertiaTensor() * glm::cross(distance, force);
}

glm::f64vec3 PhysicsObject::Body::momentum() {
	return velocity / invMass;
}