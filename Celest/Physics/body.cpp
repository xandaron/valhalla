#include "constants.h"
#include "body.h"

PhysicsObject::Body::Body(BodyDescriptor bodyDescriptor)
{
	name = bodyDescriptor.name;
	position = bodyDescriptor.position;
	velocity = bodyDescriptor.velocity;
	orientation = bodyDescriptor.orientation;
	rotationAxis = glm::normalize(bodyDescriptor.rotationAxis);
	rotationalSpeed = bodyDescriptor.rotationalSpeed;
	force = bodyDescriptor.force;
	mass = bodyDescriptor.mass;
	locked = bodyDescriptor.locked;
	coefRestitution = bodyDescriptor.coefRestitution;
	coefFriction = bodyDescriptor.coefFriction;
	hitbox = new Collision::BoundingSphere(position, bodyDescriptor.hitboxDescriptor.radius);
}

PhysicsObject::Body::~Body() {
	delete hitbox;
	delete position;
}

void PhysicsObject::Body::init(std::vector<Body*> objs) {
	gravitationalForce(objs);
}

void PhysicsObject::Body::firstUpdate(double delta) {
	if (!locked) {
		velocity += (force / mass) * (delta / 2.0);
		position->xyz += velocity * delta;
		force = glm::f64vec3(0.0);
	}
}

bool PhysicsObject::Body::checkColliding(Body* obj) {
	return hitbox->checkColliding(obj->hitbox);
}

void PhysicsObject::Body::secondUpdate(double delta, std::vector<Body*> objs) {
	if (!locked) {
		gravitationalForce(objs);
		velocity += (force / mass) * (delta / 2.0);
		orientation += (rotationAxis * rotationalSpeed * delta);
	}

	if (orientation.x >= 360) {
		orientation.x -= 360;
	}
	else if (orientation.x < 0) {
		orientation.x += 360;
	}
	if (orientation.y >= 360) {
		orientation.y -= 360;
	}
	else if (orientation.y < 0) {
		orientation.y += 360;
	}
	if (orientation.z >= 360) {
		orientation.z -= 360;
	}
	else if (orientation.z < 0) {
		orientation.z += 360;
	}
}

void PhysicsObject::Body::setLock(bool lock) {
	locked = lock;
}

void PhysicsObject::Body::gravitationalForce(std::vector<Body*> objs) {

	if (locked) { return; }

	glm::f64vec3 resultantForce = glm::f64vec3();
	for (Body* obj : objs) {
		glm::f64vec3 f = gravitationalForce(obj);
		resultantForce += f;
	}
	force += resultantForce;
}

glm::f64vec3 PhysicsObject::Body::gravitationalForce(Body* obj) {

	if (locked) { return glm::f64vec3(0.0); }

	double r = glm::distance(*position, *obj->position);
	if (r == 0.0) { return glm::f64vec3(0.0); }

	double f = PhysicsConstants::gravitationalConstant * (mass * obj->mass) / (r * r);
	glm::f64vec3 norm_dst = glm::normalize(*obj->position - *position);
	return norm_dst * f;
}

void PhysicsObject::Body::applyForce(glm::f64vec3 f) {
	force += f;
}

glm::f64vec3 PhysicsObject::Body::momentum() {
	return velocity * mass;
}