#pragma once
#include <math.h>
#include <string>

namespace PhysicsData {

	template <class T> 
	class Vector3D {

	public:
		
		Vector3D(T x = 0, T y = 0, T z = 0) {
			this->x = x;
			this->y = y;
			this->z = z;
		}
		
		T x, y, z;
		
		double dst(Vector3D<T> obj) {
			return (this - obj).mag();
		}

		double mag() {
			return sqrt(x*x + y*y + z*z);
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
			return this + obj;
		}

		Vector3D<T> operator+=(T const& obj) {
			return this + obj;
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
			return this - obj;
		}

		Vector3D<T> operator-=(T const& obj) {
			return this - obj;
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
			return this * obj;
		}

		Vector3D<T> operator*=(T const& obj) {
			return this * obj;
		}

		Vector3D<T> operator/(T const& obj) {
			Vector3D<T> ret;
			ret.x = x / obj;
			ret.y = y / obj;
			ret.z = z / obj;
			return ret;
		}

		Vector3D<T> operator/=(T const& obj) {
			return this / obj;
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
	};

	template <class T>
	class Vector2D {

	public:

		Vector2D(T x = 0, T y = 0) {
			this->x = x;
			this->y = y;
		}

		T x, y;

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