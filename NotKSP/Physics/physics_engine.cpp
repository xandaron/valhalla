#include "physics_engine.h"
#include "vectors.h"
#include <iostream>

namespace Physics {

	PhysicsEngine::PhysicsEngine() {

	}

	void PhysicsEngine::vectorTest() {

		PhysicsData::Vector3D<double> v1 = PhysicsData::Vector3D<double>(0.01, 1, 0.5);
		PhysicsData::Vector3D<double> v2 = PhysicsData::Vector3D<double>(2, 10, 0.001);
		
		PhysicsData::Vector3D<double> v3 = (v1 + v2);
		std::cout << v1.toString() << " + " << v2.toString() << " = " << v3.toString() << std::endl;

		v3 = (v1 - v2);
		std::cout << v1.toString() << " - " << v2.toString() << " = " << v3.toString() << std::endl;

		v3 = v1 * 2;
		std::cout << v1.toString() << " * 2" << " = " << v3.toString() << std::endl;

		v3 = v1 / 0.5;
		std::cout << v1.toString() << " / 0.5" << " = " << v3.toString() << std::endl;
		
		v3 = v1 * v2;
		std::cout << v1.toString() << " * " << v2.toString() << " = " << v3.toString() << std::endl;

		std::cout << v1.toString() << " dot " << v2.toString() << " = " << std::to_string(v1.dot(v2)) << std::endl;

		v3 = v1.norm();
		std::cout << "Original: " << v1.toString() << ", norm: " << v3.toString() << " mag: " << v3.mag() << std::endl;
	}

	PhysicsEngine::~PhysicsEngine() {

	}
}