#include <iostream>
#include "physics_engine.h"
#include "collision/hitboxes.h"

Physics::PhysicsEngine::PhysicsEngine() {

}

void Physics::PhysicsEngine::init(std::vector<PhysicsObject::Body*> bodys) {
	setBodys(bodys);
	for (PhysicsObject::Body* body : bodys) {
		body->init(bodys);
	}
}

void Physics::PhysicsEngine::update(double delta) {
	updateBodys(delta);
}

void Physics::PhysicsEngine::resolveCollision(PhysicsObject::Body* obj_0, PhysicsObject::Body* obj_1) {
	std::cout << "Collision!!!" << std::endl;
	glm::f64vec3 n = glm::normalize(*obj_0->position - *obj_1->position);
	double restitution = obj_0->coefRestitution * obj_1->coefRestitution;
	obj_0->velocity -= (1 + restitution) * (glm::dot(obj_0->velocity, n)) * n;
	obj_1->velocity -= (1 + restitution) * (glm::dot(obj_1->velocity, n)) * n;
}

void Physics::PhysicsEngine::resolveCollisions(double delta) {
	for (int i = 0; i < bodys.size() - 1; i++) {
		for (int j = i + 1; j < bodys.size(); j++) {
			if (bodys[i]->checkColliding(bodys[j])) {
				/*std::pair<PhysicsObject::Body*, PhysicsObject::Body*> collidingBodies{ bodys[i] , bodys[j] };
				double collisionTime = getCollisionTime(collidingBodies);
				collisions.push_back({ collisionTime, collidingBodies });*/
				resolveCollision(bodys[i], bodys[j]);
			}
		}
	}
}

void Physics::PhysicsEngine::updateBodys(double delta) {
	for (PhysicsObject::Body* body : bodys) {
		body->firstUpdate(delta);
	}
	resolveCollisions(delta);
	for (PhysicsObject::Body* body : bodys) {
		body->secondUpdate(delta, bodys);
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