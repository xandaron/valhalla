#include "body.h"
#include "constants.h"

PhysicsObject::Body::Body(std::string name,
						  PhysicsData::Vector3D<double> position,
						  PhysicsData::Vector3D<double> velocity,
						  PhysicsData::Vector3D<double> force,
						  double mass)
{
	this->name = name;
	this->position = position;
	this->velocity = velocity;
	this->force = force;
	this->mass = mass;
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

PhysicsData::Vector3D<double> PhysicsObject::Body::momentum() {
	return velocity * mass;
}