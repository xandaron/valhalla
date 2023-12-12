#pragma once
#include "../cfg.h"
#include "vectors.h"

namespace PhysicsObject {

	class Body {

	public:

		std::string name;

		PhysicsData::Vector3D<double> position;
		PhysicsData::Vector3D<double> velocity;
		PhysicsData::Vector3D<double> force;

		double mass;

		Body(std::string name,
			PhysicsData::Vector3D<double> position = PhysicsData::Vector3D<double>(0.0, 0.0, 0.0),
			PhysicsData::Vector3D<double> velocity = PhysicsData::Vector3D<double>(0.0, 0.0, 0.0),
			PhysicsData::Vector3D<double> force = PhysicsData::Vector3D<double>(0.0, 0.0, 0.0),
			double mass = 0);


		PhysicsData::Vector3D<double> gravitationalForce(std::vector<Body*> objs);

		PhysicsData::Vector3D<double> gravitationalForce(Body* obj);

		PhysicsData::Vector3D<double> momentum();
	};
}