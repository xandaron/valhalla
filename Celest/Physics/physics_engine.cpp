#include <iostream>
#include "physics_engine.h"
#include "constants.h"

Physics::Engine::Engine() {

}

void Physics::Engine::init(std::vector<PhysicsObject::Body*> bodys) {
	setBodys(bodys);
	for (PhysicsObject::Body* body : bodys) {
		body->init(bodys);
	}
}

void Physics::Engine::update(double delta) {
	updateBodys(delta);
}

void Physics::Engine::resolveCollision(PhysicsObject::Body* objA, PhysicsObject::Body* objB, Collision::CollisionInfo* collisionInfo) {
	double totalMass = objA->invMass + objB->invMass;

	objA->position.xyz -= (collisionInfo->normal * collisionInfo->penetration * (objA->invMass / totalMass));
	objB->position.xyz += (collisionInfo->normal * collisionInfo->penetration * (objB->invMass / totalMass));

	glm::f64vec3 r0 = collisionInfo->contactPointA - objA->position;
	glm::f64vec3 r1 = collisionInfo->contactPointB - objB->position;

	glm::f64vec3 totalVelocity0 = glm::cross(objA->angularVelocity, collisionInfo->contactPointA) + objA->velocity;
	glm::f64vec3 totalVelocity1 = glm::cross(objB->angularVelocity, collisionInfo->contactPointB) + objB->velocity;
	glm::f64vec3 collisionVelocity = totalVelocity1 - totalVelocity0;

	double numerator = -(1 + objA->coefRestitution * objB->coefRestitution) * glm::dot(collisionVelocity, collisionInfo->normal);
	double denominator = totalMass + glm::dot(
		glm::cross(objA->invInertiaOrientated * glm::cross(collisionInfo->contactPointA, collisionInfo->normal), collisionInfo->contactPointA) +
		glm::cross(objB->invInertiaOrientated * glm::cross(collisionInfo->contactPointB, collisionInfo->normal), collisionInfo->contactPointB),
		collisionInfo->normal
	);

	glm::f64vec3 impulse = collisionInfo->normal * (numerator / denominator);
	objA->applyCollisionImpulse(-impulse, collisionInfo->contactPointA);
	objB->applyCollisionImpulse(impulse, collisionInfo->contactPointB);
}

void Physics::Engine::resolveCollisions(double delta) {
	Collision::CollisionInfo collisionInfo;
	for (int i = 0; i < bodys.size() - 1; i++) {
		for (int j = i + 1; j < bodys.size(); j++) {
			if (bodys[i]->checkColliding(bodys[j], &collisionInfo)) {
				resolveCollision(bodys[i], bodys[j], &collisionInfo);
			}
		}
	}
}

void Physics::Engine::updateBodys(double delta) {
	for (PhysicsObject::Body* body : bodys) {
		body->firstUpdate(delta);
	}
	resolveCollisions(delta);
	gravitationalForce(bodys);
	for (PhysicsObject::Body* body : bodys) {
		body->secondUpdate(delta);
	}
}

void Physics::Engine::gravitationalForce(std::vector<PhysicsObject::Body*> objs) {
	for (int i = 0; i < objs.size() - 1; i++) {
		for (int j = i + 1; j < objs.size(); j++) {
			glm::f64vec3 force = calculateGravitationalForce(objs[i], objs[j]);
			objs[i]->applyForce(force);
			objs[j]->applyForce(-force);
		}
	}
}

glm::f64vec3 Physics::Engine::calculateGravitationalForce(PhysicsObject::Body* objA, PhysicsObject::Body* objB)
{

	glm::f64vec3 relativePos = objB->position - objA->position;
	double r = glm::length(relativePos);
	if (r == 0.0) { return glm::f64vec3(0.0); }

	double invMassA = objA->invMass;
	double invMassB = objB->invMass;
	if (invMassA == 0.0) { 
		invMassA = DBL_MIN;
	}
	if (invMassB == 0.0) {
		invMassB = DBL_MIN;
	}

	double f = PhysicsConstants::gravitationalConstant / ((r * r) * (invMassA * invMassB));
	glm::f64vec3 dir = relativePos / r;
	return dir * f;
}

void Physics::Engine::setBodys(std::vector<PhysicsObject::Body*> bodys) {
	this->bodys = bodys;
}

void Physics::Engine::clearBodys() {
	this->bodys.clear();
}

Physics::Engine::~Engine() {

}