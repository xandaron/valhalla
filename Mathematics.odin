package Valhalla

import "core:math"
import "core:math/linalg"

sin :: math.sin
cos :: math.cos
tan :: math.tan

floor :: math.floor
log2 :: math.log2

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32

Mat2 :: linalg.Matrix2f32
Mat3 :: linalg.Matrix3f32
Mat4 :: linalg.Matrix4f32

IMat2 : Mat2 : {
    1, 0,
    0, 1,
}

IMat3 : Mat3 : {
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
}

IMat4 : Mat4 : {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
}

radians :: linalg.to_radians

transpose :: linalg.transpose

normalize :: linalg.normalize

cross :: linalg.cross

dot :: linalg.dot

rotation2 :: linalg.matrix2_rotate

rotation3 :: linalg.matrix3_rotate

rotation4 :: linalg.matrix4_rotate

lookAt :: proc(eye, center, up : Vec3) -> Mat4 {
    f := normalize(center - eye)
    s := normalize(cross(up, f))
    u := cross(f, s)
    return {
        s.x, s.y, s.z, -dot(s, eye),
        u.x, u.y, u.z, -dot(u, eye),
        f.x, f.y, f.z, -dot(f, eye),
        0,   0,   0,    1,
    }
}

perspective :: proc(fov, aspect, near, far : f32) -> (m : Mat4) {
    assert(aspect != 0, "Aspect ratio can't be zero!")
	tanHalfFov := tan(0.5 * fov)
	m[0, 0] = 1 / (aspect*tanHalfFov)
	m[1, 1] = 1 / (tanHalfFov)
	m[2, 2] = far / (far - near)
	m[3, 2] = 1
	m[2, 3] = -(far * near) / (far - near)
	return
}
