#pragma once
#include "../cfg.h"
#include "vectors.h"

namespace PhysicsObject {

	struct BodyDescriptor {
		std::string name;

		PhysicsData::Vector3D<double> position = PhysicsData::Vector3D<double>();
		PhysicsData::Vector3D<double> velocity = PhysicsData::Vector3D<double>();
		PhysicsData::Vector3D<double> force = PhysicsData::Vector3D<double>();

		PhysicsData::Vector3D<double> orientation = PhysicsData::Vector3D<double>();
		PhysicsData::Vector3D<double> rotationAxis = PhysicsData::Vector3D<double>();

		double rotationalSpeed = 0.0;

		double mass = 0.0;
		bool locked = false;
	};

	class Body {

	public:

		Body(BodyDescriptor bodyDescriptor);

		std::string name;

		PhysicsData::Vector3D<double> position;
		PhysicsData::Vector3D<double> velocity;
		PhysicsData::Vector3D<double> force;

		PhysicsData::Vector3D<double> orientation;
		PhysicsData::Vector3D<double> rotationAxis;
		double rotationalSpeed;

		double mass;

		bool locked;

		void update(double delta);

		void lock();

		void unlock();

		PhysicsData::Vector3D<double> gravitationalForce(std::vector<Body*> objs);

		PhysicsData::Vector3D<double> gravitationalForce(Body* obj);

		void applyForce(PhysicsData::Vector3D<double> f);

		PhysicsData::Vector3D<double> momentum();
	};
}