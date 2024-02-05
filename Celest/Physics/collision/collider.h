#pragma once

namespace Collision {

	enum class hitboxTypes {
		BASE,
		SPHERE
	};

	class Collider {
	public:
		hitboxTypes type = hitboxTypes::BASE;

		virtual bool checkColliding(Collider* obj) = 0;

	protected:
		glm::f64vec3* origin;
	};
}