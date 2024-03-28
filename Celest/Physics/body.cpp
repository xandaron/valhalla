#include "body.h"

PhysicsObject::Body::Body(BodyDescriptor bodyDescriptor)
{
	uid = bodyDescriptor.uid;

	position = bodyDescriptor.position;
	velocity = bodyDescriptor.velocity;
	force = glm::f64vec3(0);

	angularVelocity = bodyDescriptor.angularVelocity;
	torque = glm::f64vec3(0);

	orientation = bodyDescriptor.orientation;
	orientationMatrix = orientation.toMat3();
	
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
	invInertiaOrientated = orientationMatrix * invInertia;
	
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
	angularVelocity +=  invInertiaOrientated * delta * torque;
	if (angularVelocity.length() > 0) {
		orientation = (orientation + DataObject::Quaternion(angularVelocity * delta * 0.5) * orientation).normalize();
		orientationMatrix = orientation.toMat3();
		updateInvInertiaOrientated();
	}
}

void PhysicsObject::Body::updateInvInertiaOrientated() {
	invInertiaOrientated = orientationMatrix * invInertia;
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
	angularVelocity += invInertiaOrientated * glm::cross(distance, force);
}

glm::f64vec3 PhysicsObject::Body::momentum() {
	return velocity / invMass;
}

glm::f64mat4 PhysicsObject::Body::translationMatrix() {
	return glm::f64mat4(
		orientationMatrix[0][0], orientationMatrix[0][1], orientationMatrix[0][2], 0,
		orientationMatrix[1][0], orientationMatrix[1][1], orientationMatrix[1][2], 0,
		orientationMatrix[2][0], orientationMatrix[2][1], orientationMatrix[2][2], 0,
		position.x,				 position.y,			  position.z,			   1
	);
}