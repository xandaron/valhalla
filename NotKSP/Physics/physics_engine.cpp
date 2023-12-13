#include "physics_engine.h"
#include <iostream>

Physics::PhysicsEngine::PhysicsEngine() {

}

void Physics::PhysicsEngine::update(double delta) {

	updateBodys(delta);
}

void Physics::PhysicsEngine::updateBodys(double delta) {

	for (PhysicsObject::Body* body : bodys) {
		body->update(delta);
	}
}

void Physics::PhysicsEngine::setBodys(std::vector<PhysicsObject::Body*> bodys) {
	this->bodys = bodys;
}

void Physics::PhysicsEngine::clearBodys() {
	this->bodys.clear();
}

Physics::PhysicsEngine::~PhysicsEngine() {

}