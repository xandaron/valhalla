#pragma once
#include "../cfg.h"
#include "vectors.h"
#include "collision/hitboxes.h"

namespace PhysicsObject {

	struct BodyDescriptor {
		std::string name;

		glm::f64vec3* position = new glm::f64vec3(0);
		glm::f64vec3 velocity = glm::f64vec3(0);
		glm::f64vec3 force = glm::f64vec3(0);

		glm::f64vec3 orientation = glm::f64vec3(0);
		glm::f64vec3 rotationAxis = glm::f64vec3(0,0,1);

		double rotationalSpeed = 0.0;

		double mass = 0.0;
		bool locked = false;

		double coefRestitution = 1.0;
		double coefFriction = 1.0;

		Collision::HitboxDescriptor hitboxDescriptor;
	};

	class Body {

	public:

		Body(BodyDescriptor bodyDescriptor);
		~Body();

		std::string name;

		glm::f64vec3 velocity;
		glm::f64vec3 force;
		double mass;

		glm::f64vec3* position;
		glm::f64vec3 orientation;
		glm::f64vec3 rotationAxis;
		double rotationalSpeed;
		bool locked;

		double coefRestitution;
		double coefFriction;

		Collision::Collider* hitbox;

		void init(std::vector<Body*> objs);

		void firstUpdate(double delta);

		bool checkColliding(Body* obj);

		void secondUpdate(double delta, std::vector<Body*> objs);

		void setLock(bool lock);

		void gravitationalForce(std::vector<Body*> objs);

		glm::f64vec3 gravitationalForce(Body* obj);

		void applyForce(glm::f64vec3 f);

		glm::f64vec3 momentum();
	};
}