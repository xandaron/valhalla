#include "dynamic_body.h"

PhysicsObject::DynamicBody::DynamicBody(BodyDescriptor descriptor) : Body(descriptor) {
	type = BodyType::DYNAMIC;

	velocity = descriptor.velocity;
	force = glm::f64vec3(0);

	angularVelocity = descriptor.angularVelocity;
	torque = glm::f64vec3(0);

	orientationMatrix = orientation.toMat3();

	invMass = descriptor.invMass;
	invInertia = hitbox->invInertiaMat(invMass);
	invInertiaOrientated = orientationMatrix * invInertia;
}

bool PhysicsObject::DynamicBody::checkColliding(Body* obj, Collision::CollisionInfo* collisionInfo) {
	return Collision::CheckColliding(hitbox, obj->hitbox, collisionInfo);
}

void PhysicsObject::DynamicBody::updateInvInertiaOrientated() {
	invInertiaOrientated = orientationMatrix * invInertia;
}

void PhysicsObject::DynamicBody::applyForce(glm::f64vec3 force) {
	this->force += force;
}

void PhysicsObject::DynamicBody::applyForceAtPoint(glm::f64vec3 force, glm::f64vec3 point) {
	this->force += force;
	point -= position;
	torque += glm::cross(point, force);
}

void PhysicsObject::DynamicBody::applyCollisionImpulse(glm::f64vec3 force, glm::f64vec3 distance) {
	this->velocity += force * invMass;
	angularVelocity += invInertiaOrientated * glm::cross(distance, force);
}

void PhysicsObject::DynamicBody::move(glm::f64vec3 movement) {
	position += movement;

	translationMatrix[3][0] = position[0];
	translationMatrix[3][1] = position[1];
	translationMatrix[3][2] = position[2];
}

void PhysicsObject::DynamicBody::rotate(glm::f64vec3 rotation) {
	orientation = (orientation + DataObject::Quaternion(rotation) * orientation).normalize();
	orientationMatrix = orientation.toMat3();

	translationMatrix[0][0] = orientationMatrix[0][0];
	translationMatrix[0][1] = orientationMatrix[0][1];
	translationMatrix[0][2] = orientationMatrix[0][2];
	translationMatrix[1][0] = orientationMatrix[1][0];
	translationMatrix[1][1] = orientationMatrix[1][1];
	translationMatrix[1][2] = orientationMatrix[1][2];
	translationMatrix[2][0] = orientationMatrix[2][0];
	translationMatrix[2][1] = orientationMatrix[2][1];
	translationMatrix[2][2] = orientationMatrix[2][2];
}

glm::f64vec3 PhysicsObject::DynamicBody::momentum() {
	return velocity / invMass;
}

PhysicsObject::DynamicBody::~DynamicBody() {
	delete hitbox;
}