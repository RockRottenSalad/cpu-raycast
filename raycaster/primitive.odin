package raycaster

import "core:math"
import "core:fmt"

Intersection :: struct {
    position: Vector3,
    // t value in "ray = origin + direction * t"
    // Since direction is normalised, t is also the distance between the intersection point and the ray origin.
    ray_t: f32,
}

Sphere :: struct {
    position: Vector3,
    radius: f32,
}

Plane :: struct {
    normal: Vector3,
    point_on_plane: Vector3,
}

GeometryKind :: union #no_nil {
    Sphere,
    Plane,
}

Geometry :: struct {
    color: Color,
    // Makes the object reflective
    is_mirror: bool,
    // Lit objects are always fully lit regardless of light sources.
    // They also don't block lights and don't cast shadows.
    is_lit: bool,

    derived: GeometryKind
}

// Assumes given position is on the sphere.
// Returns sphere surface normal at that position.
FindSphereNormalVector :: proc(sphere: ^Sphere, position: Vector3) -> Vector3 {
    return Vec3Normalize(Vec3Sub(position, sphere.position))
}

// Unused position argument is here so we can create a general overriden proc
FindPlaneNormalVector :: proc(plane: ^Plane, position: Vector3) -> Vector3 {
    return plane.normal
}

FindNormalVector :: proc { FindSphereNormalVector, FindPlaneNormalVector }

FindGeometryNormalVector :: proc(geometry: ^Geometry, position: Vector3) -> Vector3 {
    switch &g in geometry.derived {
    case Sphere:
        return FindNormalVector(&g, position)
    case Plane:
        return FindNormalVector(&g, position)
    }
    panic("UNREACHABLE")
}

// Teturns the smallest non-negative ray_t value at where the ray intersects the sphere or nil if the ray doesn't intersect the sphere.
// Substitutes the ray's equation into the sphere's equation and then solves for ray_t via quadratic formula.
// https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection
FindRaySphereIntersection :: proc(ray: ^Ray, sphere: ^Sphere) -> (Intersection, bool) {
assert(sphere != nil)
    assert(ray != nil)
    result: Intersection
    ray_origin_minus_sphere := Vec3Sub(ray.origin, sphere.position)

    a := Vec3DotProduct(ray.direction, ray.direction)
    b := 2.0 * Vec3DotProduct(ray.direction, ray_origin_minus_sphere)
    c := Vec3DotProduct(ray_origin_minus_sphere, ray_origin_minus_sphere) - (sphere.radius*sphere.radius)

    discriminant := b*b - 4*a*c

    if discriminant < 0.0 {
        return result, false
    }

    discriminant_sqrt := math.sqrt(discriminant)

    t := cast(f32)0.0
    if discriminant > 0.0 {
        t = min((-b + discriminant_sqrt) / 2.0*a, (-b - discriminant_sqrt) / 2.0*a)
    } else /* if discriminant == 0.0 | Discriminant is guaranteed to be 0 here*/ {
        t = (-b + discriminant_sqrt) / 2.0*a
    } 

    result.position = Vec3Add(ray.origin, Vec3Scale(ray.direction, t))
    result.ray_t = t

    // If ray_t is negative, then the ray went backwards and intersected with the sphere.
    // We do not want to render things behind the camera
    return result, t >= 0
}

// Finds the closest object in the scene that intersects with the given ray, ignoring the index of the object at the given `ignore_index`
FindClosestIntersection :: proc(ray: ^Ray, scene: ^Scene, ignore_index: u32 = max(u32)) -> (Intersection, u32, bool) {
    candidate: Intersection
    candidate_t_value := max(f32)
    candidate_index := max(u32)

    for &geometry, index in scene.geometries {
        if cast(u32)index == ignore_index { continue; }

        intersection: Intersection 
        ok: bool 

        switch &v in &geometry.derived {
        case Sphere:
            intersection, ok = FindRayIntersection(ray, &v)
        case Plane:
            intersection, ok = FindRayIntersection(ray, &v)
        } 

        if !ok { continue; }

        if intersection.ray_t < candidate_t_value {
            candidate = intersection
            candidate_t_value = intersection.ray_t
            candidate_index = cast(u32)index
        }
    }

    // Candidate_index is initialized max(u32).
    // If it hasn't been updated, then no intersections have been found 
    return candidate, candidate_index, candidate_index != max(u32)
}

FindRayPlaneIntersection :: proc(ray: ^Ray, plane: ^Plane) -> (Intersection, bool) {
    result: Intersection

    ray_dir_dot_plane_normal := Vec3DotProduct(ray.direction, plane.normal)

    // Doesn't factor in the case where the ray is exactly on the plane
    // But maybe that's okay, we don't really have to render that case
    if ray_dir_dot_plane_normal >= 0.0 {
        return result, false
    }

    result.ray_t = Vec3DotProduct(Vec3Sub(plane.point_on_plane, ray.origin), plane.normal) / ray_dir_dot_plane_normal
    result.position = Vec3Add(ray.origin, Vec3Scale(ray.direction, result.ray_t))

    // If ray_t is negative, then the ray had to go backwards to collide with the plane. We do not care about that case
    return result, result.ray_t >= 0.0
}

FindRayIntersection :: proc{FindRaySphereIntersection, FindRayPlaneIntersection}

// Tries to find the interesction between a ray and an object.
FindRayGeometryIntersection :: proc(ray: ^Ray, geometry: ^Geometry) -> (Intersection, bool) {
    switch &v in &geometry.derived {
    case Sphere:
        return FindRayIntersection(ray, &v)
    case Plane:
        return FindRayIntersection(ray, &v)
    }
    panic("UNREACHABLE")
}


// UNUSED RELIC OF THE PAST
//FindClosestSphereIntersection :: proc(ray: ^Ray, spheres: []Sphere, ignore_index: u32 = max(u32)) -> (intersection: Intersection, sphere_index: u32, ok: bool) {
//    candidate: Intersection
//    candidate_t_value := max(f32)
//    candidate_index := max(u32)
//
//    for &sphere, index in spheres {
//        if cast(u32)index == ignore_index { continue; }
//
//        intersection, ok := FindRayIntersection(ray, &sphere)
//        if !ok { continue; }
//
//        if intersection.ray_t < candidate_t_value {
//            candidate = intersection
//            candidate_t_value = intersection.ray_t
//            candidate_index = cast(u32)index
//        }
//    }
//
//    return candidate, candidate_index, candidate_index != max(u32)
//}
