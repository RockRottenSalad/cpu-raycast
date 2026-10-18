package raycaster

import "core:math"

DegreesToRadians :: proc(degrees: f32) -> f32 {
    return degrees * cast(f32)(math.PI / 180.0)
}

RadiansToDegrees :: proc(radians: f32) -> f32 {
    return radians * cast(f32)(180.0 / math.PI)
}

Vector3 :: struct {
    x: f32,
    y: f32,
    z: f32,
}

Vec3Multiply :: proc(a: Vector3, b: Vector3) -> Vector3 {
    return Vector3{a.x*b.x, a.y*b.y, a.z*b.z}
}

Vec3DotProduct :: proc(a: Vector3, b: Vector3) -> f32 {
    return a.x*b.x + a.y*b.y + a.z*b.z
}

Vec3Sub :: proc(a: Vector3, b: Vector3) -> Vector3 {
    return Vector3{a.x-b.x, a.y-b.y, a.z-b.z}
}

Vec3Add :: proc(a: Vector3, b: Vector3) -> Vector3 {
    return Vector3{a.x+b.x, a.y+b.y, a.z+b.z}
}

Vec3Scale :: proc(v: Vector3, scalar: f32) -> Vector3 {
    return Vector3{v.x*scalar, v.y*scalar, v.z*scalar}
}

Vec3Reverse :: proc(v: Vector3) -> Vector3 {
    return Vector3{-v.x, -v.y, -v.z}
}

Vec3Length :: proc(v: Vector3) -> f32 {
    return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
}

Vec3Normalize :: proc(v: Vector3) -> Vector3 {
    length := Vec3Length(v)
    return Vector3{v.x/length, v.y/length, v.z/length}
}

Vec3CrossProduct :: proc(a: Vector3, b: Vector3) -> Vector3 {
    return Vector3{
        a.y*b.z - a.z*b.y,
        -(a.x*b.z - a.z*b.x),
        a.x*b.y - a.y*b.x
    };
}

Vec3FromPitchAndYaw :: proc(pitch_in_radians: f32, yaw_in_radians: f32) -> Vector3 {
    return Vector3{
        math.cos(yaw_in_radians) * math.cos(pitch_in_radians),
        math.sin(pitch_in_radians),
        math.sin(yaw_in_radians) * math.cos(pitch_in_radians)
    }
}

Vec3FromYaw :: proc(yaw_in_radians: f32) -> Vector3 {
    return Vector3{
        math.cos(yaw_in_radians), 0, math.sin(yaw_in_radians)
    }
}

// Equivalent to the `reflect` function from GLSL
// Taken from OpenGL docs: I - 2.0 * dot(N, I) * N.
// calculate the reflection direction for an incident vector
Vec3Reflect :: proc(incident: Vector3, normal: Vector3) -> Vector3 {
    return Vec3Sub(incident, Vec3Scale(normal, 2.0 * Vec3DotProduct(normal, incident)))
}

Vec3Clamp :: proc(v: Vector3, lower_limit: f32, upper_limit: f32) -> Vector3 {
    return Vector3 {
        clamp(v.x, lower_limit, upper_limit),
        clamp(v.y, lower_limit, upper_limit),
        clamp(v.z, lower_limit, upper_limit),
    }
}
