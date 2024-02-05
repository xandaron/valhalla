#pragma once
#include "../cfg.h"
#include <math.h>

namespace PhysicsData {

	template <class T>
	class Vector3D {

	public:

		T x, y, z;

		Vector3D(T x = 0.0, T y = 0.0, T z = 0.0) {
			this->x = x;
			this->y = y;
			this->z = z;
		}

		~Vector3D() {

		}

		void rotate(double theta, Vector3D<double> axis) {
			
			glm::f64mat3 antisymmetricMatrix = glm::f64mat3({
				{ 0.0, axis.z, -axis.y },
				{ -axis.z, 0.0, axis.x },
				{ axis.y, -axis.x, 0.0 }
			});
			glm::f64mat3 rotation = glm::f64mat3(1.0)
				+ glm::sin(glm::radians(theta)) * antisymmetricMatrix
				+ (1 - glm::cos(glm::radians(theta))) * antisymmetricMatrix * antisymmetricMatrix;

			glm::f64vec3 r = rotation * toGlm();
			if (r.x >= 360) {
				this->x = r.x - 360;
			}
			else {
				this->x = r.x;
			}
			if (r.y >= 360) {
				this->y = r.y - 360;
			}
			else {
				this->y = r.y;
			}
			if (r.z >= 360) {
				this->z = r.z - 360;
			}
			else {
				this->z = r.z;
			}
		}

		double dst(Vector3D<T> obj) {
			return (operator-(obj)).mag();
		}

		double mag() {
			return sqrt(x * x + y * y + z * z);
		}

		Vector3D<double> norm() {
			double scale = mag();
			return Vector3D<double>(x / scale, y / scale, z / scale);
		}

		T dot(Vector3D<T> const& obj) {
			return x * obj.x + y * obj.y + z * obj.z;
		}

		Vector3D<T> cross(Vector3D<T> const& obj) {
			Vector3D<T> ret;
			ret.x = y * obj.z - z * obj.y;
			ret.y = z * obj.x - x * obj.z;
			ret.z = x * obj.y - y * obj.x;
			return ret;
		}

		Vector3D<T> operator+(Vector3D<T> const& obj) {
			Vector3D<T> ret;
			ret.x = x + obj.x;
			ret.y = y + obj.y;
			ret.z = z + obj.z;
			return ret;
		}

		Vector3D<T> operator+(T const& obj) {
			Vector3D<T> ret;
			ret.x = x + obj;
			ret.y = y + obj;
			ret.z = z + obj;
			return ret;
		}

		Vector3D<T> operator+=(Vector3D<T> const& obj) {
			return operator+(obj);
		}

		Vector3D<T> operator+=(T const& obj) {
			return operator+(obj);
		}

		Vector3D<T> operator-(Vector3D<T> const& obj) {
			Vector3D<T> ret;
			ret.x = x - obj.x;
			ret.y = y - obj.y;
			ret.z = z - obj.z;
			return ret;
		}

		Vector3D<T> operator-(T const& obj) {
			Vector3D<T> ret;
			ret.x = x - obj;
			ret.y = y - obj;
			ret.z = z - obj;
			return ret;
		}

		Vector3D<T> operator-=(Vector3D<T> const& obj) {
			return operator-(obj);
		}

		Vector3D<T> operator-=(T const& obj) {
			return operator-(obj);
		}

		Vector3D<T> operator*(Vector3D<T> const& obj) {
			return cross(obj);
		}

		Vector3D<T> operator*(T const& obj) {
			Vector3D<T> ret;
			ret.x = x * obj;
			ret.y = y * obj;
			ret.z = z * obj;
			return ret;
		}

		Vector3D<T> operator*=(Vector3D<T> const& obj) {
			return cross(obj);
		}

		Vector3D<T> operator*=(T const& obj) {
			return operator*(obj);
		}

		Vector3D<T> operator/(T const& obj) {
			Vector3D<T> ret;
			ret.x = x / obj;
			ret.y = y / obj;
			ret.z = z / obj;
			return ret;
		}

		Vector3D<T> operator/=(T const& obj) {
			return operator/(obj);
		}

		bool operator==(Vector3D<T> const& obj) {
			if (x == obj.x && y == obj.y && z == obj.z) {
				return true;
			}
			return false;
		}

		T& operator[](size_t i)
		{
			switch (i) {
			case 0: return x;
			case 1: return y;
			case 2: return z;
			default: throw "Error: Index out of bounds";
			}
		}

		T operator[](size_t i) const
		{
			return (*const_cast<Vector3D<T>>(this))[i];
		}

		std::string toString() {
			return "(" + std::to_string(x) + ", " + std::to_string(y) + ", " + std::to_string(z) + ")";
		}

		glm::vec3 toGlm() {
			return glm::vec3({ x, y, z });
		}
	};

	template <class T>
	class Vector2D {

	public:

		T x, y;

		Vector2D(T x = 0, T y = 0) {
			this->x = x;
			this->y = y;
		}

		~Vector2D() {

		}

		double dst(Vector2D<T> obj) {
			return (this - obj).mag();
		}

		double mag() {
			return sqrt(x * x + y * y);
		}

		Vector2D<double> norm() {
			double scale = mag();
			return Vector2D<double>(x / scale, y / scale);
		}

		T dot(Vector2D<T> const& obj) {
			return x * obj.x + y * obj.y;
		}

		double cross(Vector2D<T> const& obj) {
			return x * obj.y - y * obj.x;
		}

		Vector2D<T> operator+(Vector2D<T> const& obj) {
			Vector2D<T> ret;
			ret.x = x + obj.x;
			ret.y = y + obj.y;
			return ret;
		}

		Vector2D<T> operator+(T const& obj) {
			Vector2D<T> ret;
			ret.x = x + obj;
			ret.y = y + obj;
			return ret;
		}

		Vector2D<T> operator+=(Vector2D<T> const& obj) {
			return this + obj;
		}

		Vector2D<T> operator+=(T const& obj) {
			return this + obj;
		}

		Vector2D<T> operator-(Vector2D<T> const& obj) {
			Vector2D<T> ret;
			ret.x = x - obj.x;
			ret.y = y - obj.y;
			return ret;
		}

		Vector2D<T> operator-(T const& obj) {
			Vector2D<T> ret;
			ret.x = x - obj;
			ret.y = y - obj;
			return ret;
		}

		Vector2D<T> operator-=(Vector2D<T> const& obj) {
			return this - obj;
		}

		Vector2D<T> operator-=(T const& obj) {
			return this - obj;
		}

		double operator*(Vector2D<T> const& obj) {
			return cross(obj);
		}

		Vector2D<T> operator*(T const& obj) {
			Vector2D<T> ret;
			ret.x = x * obj;
			ret.y = y * obj;
			return ret;
		}

		double operator*=(Vector2D<T> const& obj) {
			return this * obj;
		}

		Vector2D<T> operator*=(T const& obj) {
			return this * obj;
		}

		Vector2D<T> operator/(T const& obj) {
			Vector2D<T> ret;
			ret.x = x / obj;
			ret.y = y / obj;
			return ret;
		}

		Vector2D<T> operator/=(T const& obj) {
			return this / obj;
		}

		bool operator==(Vector2D<T> const& obj) {
			if (x == obj.x && y == obj.y) {
				return true;
			}
			return false;
		}

		T& operator[](size_t i)
		{
			switch (i) {
			case 0: return x;
			case 1: return y;
			default: throw "Error: Index out of bounds";
			}
		}

		T operator[](size_t i) const
		{
			return (*const_cast<Vector3D<T>>(this))[i];
		}

		std::string toString() {
			return "(" + std::to_string(x) + ", " + std::to_string(y) + ")";
		}
	};
}