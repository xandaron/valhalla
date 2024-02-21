#pragma once
#include "../../cfg.h"
#include "../quaternion.h"

namespace Collision {

	enum class HitboxType {
		BASE,
		SPHERE,
		AABB
	};

	struct HitboxDescriptor {
		HitboxType type = HitboxType::BASE;
		glm::f64vec3 halfDimensions = glm::f64vec3(1, 1, 1);
	};

	struct CollisionInfo {
		glm::f64vec3 normal = glm::f64vec3(1);
		double penetration = 0;
		glm::f64vec3 contactPointA = glm::f64vec3(0);
		glm::f64vec3 contactPointB = glm::f64vec3(0);
	};

	class Collider {
	public:
		HitboxType type = HitboxType::BASE;

		virtual glm::f64mat3x3 invInertiaMat(double mass) = 0;

		glm::f64vec3 getPosition() {
			return *position;
		}

	protected:
		glm::f64vec3* position;
	};

	class SphereCollider : public Collider {

	public:
		SphereCollider(glm::f64vec3* position, double radius) {
			type = HitboxType::SPHERE;
			this->position = position;
			this->radius = radius;
		}

		glm::f64mat3 invInertiaMat(double invMass) {
			double i = 2.5 * invMass / (radius * radius);
			return glm::f64mat3(i, 0, 0,
				0, i, 0,
				0, 0, i);
		}

		double getRadius() {
			return radius;
		}

	private:
		double radius;
	};

	class AABBCollider : public Collider {

	public:
		AABBCollider(glm::f64vec3* position, glm::f64vec3 halfDimensions, DataObject::Quaternion* orientation) {
			type = HitboxType::AABB;
			this->position = position;
			this->halfDimensions = halfDimensions;
			this->orientation = orientation;
		}

		glm::f64mat3 invInertiaMat(double invMass) {
			double x2 = halfDimensions.x * halfDimensions.x;
			double y2 = halfDimensions.y * halfDimensions.y;
			double z2 = halfDimensions.z * halfDimensions.z;
			double cm = 12 * invMass;
			return glm::f64mat3(cm / (y2 + z2), 0, 0,
				0, cm / (x2 + z2), 0,
				0, 0, cm / (x2 + y2));
		}

		glm::f64vec3 getHalfDimensions() {
			return halfDimensions;
		}

		DataObject::Quaternion getOrientation() {
			return *orientation;
		}

	private:
		glm::f64vec3 halfDimensions;
		DataObject::Quaternion* orientation;

	};

	static bool SphereCollision(SphereCollider* objA, SphereCollider* objB, CollisionInfo* collisionInfo) {
		glm::f64vec3 relativePos = objB->getPosition() - objA->getPosition();
		double radiusA = objA->getRadius();
		double radiusB = objB->getRadius();
		double penetration = (radiusA + radiusB) - glm::length(relativePos);
		if (penetration > 0) {
			collisionInfo->normal = glm::normalize(relativePos);
			collisionInfo->penetration = penetration;
			collisionInfo->contactPointA = radiusA * collisionInfo->normal;
			collisionInfo->contactPointB = radiusB * -collisionInfo->normal;
			return true;
		}
		return false;
	}

	static bool AABBCollision(AABBCollider* objA, AABBCollider* objB, CollisionInfo* collisionInfo) {
		
		glm::f64vec3 posA = objA->getPosition();
		glm::f64vec3 posB = objB->getPosition();
		glm::f64vec3 relativePos = posB - posA;

		glm::f64vec3 sizeA = objA->getOrientation().toMat3() * objA->getHalfDimensions();
		glm::f64vec3 sizeB = objB->getOrientation().toMat3() * objB->getHalfDimensions();
		glm::f64vec3 totalSize = sizeA + sizeB;

		if (glm::abs(relativePos.x) > totalSize.x ||
			glm::abs(relativePos.y) > totalSize.y ||
			glm::abs(relativePos.z) > totalSize.z) {
			return false;
		}

		static const glm::f64vec3 faces[6] =
		{
			glm::f64vec3(-1, 0, 0), glm::f64vec3(1, 0, 0),
			glm::f64vec3(0, -1, 0), glm::f64vec3(0, 1, 0),
			glm::f64vec3(0, 0, -1), glm::f64vec3(0, 0, 1),
		};

		glm::f64vec3 maxA = posA + sizeA;
		glm::f64vec3 minA = posA - sizeA;

		glm::f64vec3 maxB = posB + sizeB;
		glm::f64vec3 minB = posB - sizeB;

		double distances[6] =
		{
			glm::length(maxB.x - minA.x),
			glm::length(maxA.x - minB.x),
			glm::length(maxB.y - minA.y),
			glm::length(maxA.y - minB.y),
			glm::length(maxB.z - minA.z),
			glm::length(maxA.z - minB.z)
		};

		double penetration = DBL_MAX;
		glm::f64vec3 bestAxis;
		for (int i = 0; i < 6; i++)
		{
			if (distances[i] < penetration) {
				penetration = distances[i];
				bestAxis = faces[i];
			}
		}

		collisionInfo->normal = bestAxis;
		collisionInfo->penetration = penetration;
		collisionInfo->contactPointA = glm::f64vec3(0.0);
		collisionInfo->contactPointB = glm::f64vec3(0.0);
		return true;
	}

	static bool AABBSphereCollision(AABBCollider* objA, SphereCollider* objB, CollisionInfo* collisionInfo) {
		
		glm::f64vec3 posA = objA->getPosition();
		glm::f64vec3 posB = objB->getPosition();
		glm::f64vec3 relativePos = posB - posA;

		glm::f64vec3 sizeA = objA->getOrientation().toMat3() * objA->getHalfDimensions();
		double radiusB = objB->getRadius();

		glm::f64vec3 closestPointOnBox = glm::clamp(relativePos, -sizeA, sizeA);

		glm::f64vec3 localPoint = relativePos - closestPointOnBox;
		double distance = glm::length(localPoint);

		if (distance >= radiusB) {
			return false;
		}

		collisionInfo->normal = glm::normalize(localPoint);
		collisionInfo->penetration = radiusB - distance;
		collisionInfo->contactPointA = glm::f64vec3(0.0);
		collisionInfo->contactPointB = -collisionInfo->normal * radiusB;
		return true;
	}

	static bool SphereAABBCollision(SphereCollider* objA, AABBCollider* objB, CollisionInfo* collisionInfo) {
		
		bool ret = AABBSphereCollision(objB, objA, collisionInfo);
		if (ret) {
			glm::f64vec3 temp = collisionInfo->contactPointA;
			collisionInfo->contactPointA = collisionInfo->contactPointB;
			collisionInfo->contactPointB = temp;
			collisionInfo->normal *= -1;
		}
		return ret;
	}

	static bool CheckColliding(Collider* objA, Collider* objB, CollisionInfo* collisionInfo) {
		int pairType = (int)objA->type | (int)objB->type;

		if (pairType == (int)HitboxType::SPHERE) {
			return SphereCollision(dynamic_cast<SphereCollider*>(objA), dynamic_cast<SphereCollider*>(objB), collisionInfo);
		}
		if (pairType == (int)HitboxType::AABB) {
			return AABBCollision(dynamic_cast<AABBCollider*>(objA), dynamic_cast<AABBCollider*>(objB), collisionInfo);
		}
		if (pairType == ((int)HitboxType::SPHERE | (int)HitboxType::AABB)) {
			if (objA->type == HitboxType::AABB) {
				return AABBSphereCollision(dynamic_cast<AABBCollider*>(objA), dynamic_cast<SphereCollider*>(objB), collisionInfo);
			}
			return SphereAABBCollision(dynamic_cast<SphereCollider*>(objA), dynamic_cast<AABBCollider*>(objB), collisionInfo);
		}

		return false;
	}
}