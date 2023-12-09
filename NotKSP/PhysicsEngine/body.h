#pragma once
#include "constants.h"
#include "vectors.h"

namespace PhysicsObject {

	class Body {

	public:

		Body(PhysicsData::Vector3D<double> position = PhysicsData::Vector3D<double>(), 
			 PhysicsData::Vector3D<double> velocity = PhysicsData::Vector3D<double>(), 
			 double mass = 0,
			 PhysicsData::Vector3D<double> force = PhysicsData::Vector3D<double>()) {
			this->position = position;
			this->velocity = velocity;
			this->mass = mass;
			this->force = force;
		}

		PhysicsData::Vector3D<double> position;
		PhysicsData::Vector3D<double> velocity;
		PhysicsData::Vector3D<double> force;

		double mass;

		PhysicsData::Vector3D<double> gravitationalForce(Body obj[]) {

			PhysicsData::Vector3D<double> resultantForce = PhysicsData::Vector3D<double>();
			int len = sizeof(obj) / sizeof(Body);
			for (int i = 0; i < len; i++) {
				PhysicsData::Vector3D f = gravitationalForce(obj[i]);
				resultantForce += f;
			}
			return resultantForce;
		}

		PhysicsData::Vector3D<double> gravitationalForce(Body obj) {

			double r = position.dst(obj.position);
			double f = PhysicsConstants::gravitationalConstant * (mass * obj.mass) / (r * r);
			PhysicsData::Vector3D norm_dst = (position - obj.position).norm();
			return norm_dst * f;
		}

		PhysicsData::Vector3D<double> momentum() {
			return velocity * mass;
		}
	};
}