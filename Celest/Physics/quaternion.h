#pragma once
#include "../cfg.h"

namespace DataObject {

	class Quaternion {
	public:
		double x, y, z, w;

		Quaternion() {
			x = 0;
			y = 0;
			z = 0;
			w = 1;
		}

		Quaternion(double x, double y, double z, double w) {
			this->x = x;
			this->y = y;
			this->z = z;
			this->w = w;
		}

		Quaternion(glm::f64vec3 vector) {
			this->x = vector.x;
			this->y = vector.y;
			this->z = vector.z;
			this->w = 0;
		}

		Quaternion(glm::f64vec3 axis, double angle) {
			double s = glm::sin(angle / 2);
			this->x = axis.x * s;
			this->y = axis.y * s;
			this->z = axis.z * s;
			this->w = glm::cos(angle / 2);
		}

		Quaternion(glm::f64vec4 vec) {
			this->x = vec.x;
			this->y = vec.y;
			this->z = vec.z;
			this->w = vec.w;
		}

		Quaternion normalize() const {
			return Quaternion(glm::normalize(glm::f64vec4(x, y, z, w)));
		}

		Quaternion conjugate() const {
			return Quaternion(-x, -y, -z, w);
		}

		glm::f64mat4 toMat4() const {
			double x2 = x + x;
			double y2 = y + y;
			double z2 = z + z;
			double xx2 = x * x2;
			double xy2 = x * y2;
			double xz2 = x * z2;
			double yy2 = y * y2;
			double yz2 = y * z2;
			double zz2 = z * z2;
			double wx2 = w * x2;
			double wy2 = w * y2;
			double wz2 = w * z2;

			return glm::f64mat4(1 - (yy2 + zz2), xy2 + wz2,		  xz2 - wy2,	   0,
								xy2 - wz2,		 1 - (xx2 + zz2), yz2 + wx2,	   0,
								xz2 + wy2,		 yz2 - wx2,		  1 - (xx2 + yy2), 0,
								0,				 0,				  0,			   1
			);
		}

		glm::f64mat3 toMat3() const {
			double x2 = x + x;
			double y2 = y + y;
			double z2 = z + z;
			double xx2 = x * x2;
			double xy2 = x * y2;
			double xz2 = x * z2;
			double yy2 = y * y2;
			double yz2 = y * z2;
			double zz2 = z * z2;
			double wx2 = w * x2;
			double wy2 = w * y2;
			double wz2 = w * z2;

			return glm::f64mat3(1 - (yy2 + zz2), xy2 + wz2,		  xz2 - wy2,
								xy2 - wz2,		 1 - (xx2 + zz2), yz2 + wx2,
								xz2 + wy2,		 yz2 - wx2,		  1 - (xx2 + yy2)
			);
		}

		Quaternion operator+ (Quaternion const& obj) {
			return Quaternion(x + obj.x, y + obj.y, z + obj.z, w + obj.w);
		}

		Quaternion operator+= (Quaternion const& obj) {
			return operator+(obj);
		}

		Quaternion operator* (Quaternion const& obj) {
			double a = x * obj.w + w * obj.x + y * obj.z - z * obj.y;
			double b = y * obj.w + w * obj.y + z * obj.x - x * obj.z;
			double c = z * obj.w + w * obj.z + x * obj.y - y * obj.x;
			double d = w * obj.w - x * obj.x - y * obj.y - z * obj.z;
			return Quaternion(a, b, c, d);
		}
	};
}