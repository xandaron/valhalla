#include "body.h"
#include "constants.h"

PhysicsObject::Body::Body(BodyDescriptor bodyDescriptor)
{
	name = bodyDescriptor.name;
	position = bodyDescriptor.position;
	velocity = bodyDescriptor.velocity;
	orientation = bodyDescriptor.orientation;
	rotationAxis = bodyDescriptor.rotationAxis.norm();
	rotationalSpeed = bodyDescriptor.rotationalSpeed;
	force = bodyDescriptor.force;
	mass = bodyDescriptor.mass;
	locked = bodyDescriptor.locked;
}

void PhysicsObject::Body::update(double delta) {

	position = position + (velocity * delta);
	orientation = orientation + (rotationAxis * rotationalSpeed * delta);

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

void PhysicsObject::Body::lock() {
	locked = true;
}

void PhysicsObject::Body::unlock() {
	locked = false;
}

PhysicsData::Vector3D<double> PhysicsObject::Body::gravitationalForce(std::vector<Body*> objs) {

	PhysicsData::Vector3D<double> resultantForce = PhysicsData::Vector3D<double>();
	for (Body* obj : objs) {
		PhysicsData::Vector3D<double> f = gravitationalForce(obj);
		resultantForce += f;
	}
	return resultantForce;
}

PhysicsData::Vector3D<double> PhysicsObject::Body::gravitationalForce(Body* obj) {

	double r = position.dst(obj->position);
	double f = PhysicsConstants::gravitationalConstant * (mass * obj->mass) / (r * r);
	PhysicsData::Vector3D norm_dst = (position - obj->position).norm();
	return norm_dst * f;
}

void PhysicsObject::Body::applyForce(PhysicsData::Vector3D<double> f) {
	force += f;
}

PhysicsData::Vector3D<double> PhysicsObject::Body::momentum() {
	return velocity * mass;
}