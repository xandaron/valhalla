package Asgard

import "core:math"

Vector2 :: distinct [2]f32
Vector3 :: distinct [3]f32
Vector4 :: distinct [4]f32

Matrix2 :: distinct matrix[2, 2]f32
Matrix3 :: distinct matrix[3, 3]f32
Matrix4 :: distinct matrix[4, 4]f32

IdentityMatrix2 : Matrix2 : {
    1, 0,
    0, 1,
}

IdentityMatrix3 : Matrix3 : {
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
}

IdentityMatrix4 : Matrix4 : {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
}

transpose :: proc{
    transpose4,
}

transpose4 :: proc(m : Matrix4) -> Matrix4 {
    return {
        m[0,0], m[1,0], m[2,0], m[3,0],
        m[0,1], m[1,1], m[2,1], m[3,1],
        m[0,2], m[1,2], m[2,2], m[3,2],
        m[0,3], m[1,3], m[2,3], m[3,3],
    }
}

normalize :: proc{
    normalize2,
    normalize3,
    normalize4,
}

normalize2 :: proc(v : Vector2) -> Vector2 {
    devisor := math.sqrt(v.x*v.x + v.y*v.y)
    assert(devisor != 0, "Math error!")
    return v / devisor
}

normalize3 :: proc(v : Vector3) -> Vector3 {
    devisor := math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
    assert(devisor != 0, "Math error!")
    return v / devisor
}

normalize4 :: proc(v : Vector4) -> Vector4 {
    devisor := math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w)
    assert(devisor != 0, "Math error!")
    return v / devisor
}

cross :: proc{
    cross3,
}

cross3 :: proc(v, u : Vector3) -> Vector3{
    return {
        v.y*u.z - u.y*v.z,
        v.z*u.x - u.z*v.x,
        v.x*u.y - u.x*v.y,
    }
}

dot :: proc{
    dot2,
    dot3,
    dot4,
}

dot2 :: proc(v, u : Vector2) -> f32 {
    return v.x*u.x + v.y*u.y
}

dot3 :: proc(v, u : Vector3) -> f32 {
    return v.x*u.x + v.y*u.y + v.z*u.z
}

dot4 :: proc(v, u : Vector4) -> f32 {
    return v.x*u.x + v.y*u.y + v.z*u.z + v.w*u.w
}

rotation4 :: proc(angles : Vector3) -> Matrix4 {
    result := IdentityMatrix4
    if (angles.z != 0) {
        result = rotationZ4(angles.z) * result
    }
    if (angles.y != 0) {
        result = rotationY4(angles.y) * result
    }
    if (angles.x != 0) {
        result = rotationX4(angles.x) * result
    }
    return result
}

rotationX4 :: proc(angle : f32) -> Matrix4 {
    s := math.sin(angle)
    c := math.cos(angle)
    return {
        1, 0,  0, 0,
        0, c, -s, 0,
        0, s,  c, 0,
        0, 0,  0, 1,
    }
}

rotationY4 :: proc(angle : f32) -> Matrix4 {
    s := math.sin(angle)
    c := math.cos(angle)
    return {
         c, 0, s, 0,
         0, 1, 0, 0,
        -s, 0, c, 0,
         0, 0, 0, 1,
    }
}

rotationZ4 :: proc(angle : f32) -> Matrix4 {
    s := math.sin(angle)
    c := math.cos(angle)
    return {
        c, -s, 0, 0,
        s,  c, 0, 0,
        0,  0, 1, 0,
        0,  0, 0, 1,
    }
}

lookAt :: proc(eye, center, up : Vector3) -> Matrix4 {
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

perspective :: proc(fov, aspect, near, far : f32) -> Matrix4 {
    assert(aspect != 0, "Aspect ratio can't be zero!")
    tanHalfFov : f32 = math.tan(fov / 2)
    return {
        1 / (aspect*tanHalfFov),  0,                0,                    0,
        0,                       -1 / (tanHalfFov), 0,                    0,
        0,                        0,                far / (far - near), -(far * near) / (far - near),
        0,                        0,                1,                    0,
    }
}
