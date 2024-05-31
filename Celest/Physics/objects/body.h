#pragma once
#include "../../cfg.h"
#include "../collider.h"
#include "../quaternion.h"

namespace PhysicsObject {

	struct BodyDescriptor {
		std::string uid;

		glm::f64vec3 position = glm::f64vec3(0);
		DataObject::Quaternion orientation = DataObject::Quaternion();

		glm::f64vec3 velocity = glm::f64vec3(0);
		glm::f64vec3 angularVelocity = glm::f64vec3(0);

		double invMass = 1.0;

		double coefRestitution = 1.0;
		double coefFriction = 1.0;

		Collision::HitboxDescriptor hitboxDescriptor;
	};

	enum BodyType {
		STATIC,
		DYNAMIC
	};

	class Body {
	public:
		std::string uid;
		BodyType type = BodyType::STATIC;

		glm::f64vec3 position;
		DataObject::Quaternion orientation;
		glm::f64mat4 translationMatrix;

		double coefRestitution;
		double coefFriction;

		Collision::Collider* hitbox;

		Body(BodyDescriptor bodyDescriptor);

		bool checkColliding(Body* obj, Collision::CollisionInfo* collisionInfo);

		~Body();
	};
}