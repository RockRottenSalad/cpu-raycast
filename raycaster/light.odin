package raycaster

import "core:fmt"
import "core:math"

LightSource :: struct {
    // must be normalised
    //direction: Vector3

    position: Vector3,
    color: Vector3
}

// Ambient lighting is the small bit of light that's always there regardless of light source
FindAmbientColor :: proc(light: ^LightSource) -> Vector3 {
    ambient_strength: f32 = 0.1
    return Vec3Scale(light.color, ambient_strength)
}

// Diffuse lighting is determined by the angle between the surface normal and the light direction(from surface to light source)
// At >= 90 degrees, diffuse yields 0 light, at 0 degrees it yields 1(full) light
FindDiffuseColor :: proc(light: ^LightSource, surface_normal: Vector3, point_to_color: Vector3) -> (Vector3, f32) {
    light_direction := Vec3Normalize(Vec3Sub(light.position, point_to_color))
    diffuse_intensifier: f32 = 1.2
    // If the angle between the surface normal and the light is >=90 degrees,
    // then the dot product function returns a number <= 0
    diffuse_strength := max(0.0, Vec3DotProduct(light_direction, surface_normal))
    diffuse := Vec3Scale(light.color, diffuse_strength * diffuse_intensifier)
    return diffuse, diffuse_strength
}

// Specular is the shiny highlights
// Calucation is similar to diffuse.
// It's determined by the angle between the reflected light vector and the camera
FindSpecularColor :: proc(light: ^LightSource, surface_normal: Vector3, camera_position: Vector3, point_to_color: Vector3) -> (Vector3, f32) {
    specular_intensifier: f32 = 0.2
    light_direction := Vec3Normalize(Vec3Sub(light.position, point_to_color))

    surface_to_camera := Vec3Normalize(Vec3Sub(camera_position, point_to_color))
    light_reflection := Vec3Reflect(Vec3Reverse(light_direction), surface_normal)

    // Raised to big exponent to make just a tiny bit of specualr really shiny
    specular_strength := math.pow( max(0.0, Vec3DotProduct(surface_to_camera, light_reflection)), 32 )

    specular := Vec3Scale(light.color, specular_strength * specular_intensifier)
    return specular, specular_strength
}

PhongLighting :: proc(scene: ^Scene, geometry_index: u32, point_to_color: Vector3, ray: ^Ray, recursion_limit: u8) -> Color {
    if recursion_limit == 0 {
        return Color{0,0,0,255}
    }

    geometry := &scene.geometries[geometry_index]
    if geometry.is_lit {
        return geometry.color
    }

    camera_position := ray.origin

    geometry_color := ColorToVec3(geometry.color)
    ambient := FindAmbientColor(&scene.light)

    if IsPointInShadow(point_to_color, scene, geometry_index) {
        return ColorFromVec3(Vec3Multiply(ambient, geometry_color))
    }

    surface_normal := FindGeometryNormalVector(geometry, point_to_color)

    diffuse, diffuse_strength := FindDiffuseColor(&scene.light, surface_normal, point_to_color)
 
    specular, specular_pct := FindSpecularColor(&scene.light, surface_normal, camera_position, point_to_color)

    result := Vec3Multiply(Vec3Add(specular, Vec3Add(ambient, diffuse)), geometry_color)

    if geometry.is_mirror /* && diffuse_strength > 0.0 | no idea if this looks good or not */{
        reflection_ray := Ray {
            origin = point_to_color,
            direction = Vec3Reflect(ray.direction, surface_normal)
        }

        reflected_color := Vec3Clamp(Vec3Scale(ColorToVec3(CastSingleRay(&reflection_ray, scene, recursion_limit - 1)), 0.2 /* spec strength */), 0.0, 1.0)

        result = Vec3Add(result, reflected_color)
    }

    final_color := ColorFromVec3(result)
    return final_color
}

// A point is in shadow if there exists another object between it and the light source.
// geometry_index is the index of the object the `point_to_check` is on
IsPointInShadow :: proc(point_to_check: Vector3, scene: ^Scene, geometry_index: u32) -> bool {
    light_direction := Vec3Normalize(Vec3Sub(scene.light.position, point_to_check))

    ray := Ray {
        origin = point_to_check,
        direction = light_direction
    }

    dist_to_light := Vec3Length(Vec3Sub(scene.light.position, point_to_check))

    for &geometry, index in scene.geometries {
        if cast(u32)index == geometry_index || geometry.is_lit { continue; }
        intersection, ok := FindRayGeometryIntersection(&ray, &geometry)
        if ok && intersection.ray_t < dist_to_light {
            return true
        }
    }
    return false
}


// Determines how brightly lit a spot is by a light source given the spot's surface normal vector.
// The value returned is in the range [0;1] where 0 means absolute darkness and 1 is fully lit.
//
// If spot_light.direction isn't normalized or the surface normal isn't normalized then the output is garbage.
// See `FindDiffuseColor`
//FindLightSourceLightPercentage :: proc(light: ^LightSource, surface_normal: Vector3) -> f32 {
//    // If the angle between the surface normal and the light is >=90 degrees,
//    // then the dot product function returns a number <= 0
//    dot_product := Vec3DotProduct(light.direction, surface_normal)
//    return max(0.0, dot_product)
//}

//ScaleColorByLightPercentage :: proc(color: Color, light_pct: f32) -> Color {
//    factor := cast(u32)(255.0 * light_pct)
//
//    return Color{
//        r = cast(u8)(cast(u32)(color.r) * factor / 255),
//        g = cast(u8)(cast(u32)(color.g) * factor / 255),
//        b = cast(u8)(cast(u32)(color.b) * factor / 255),
//        a = color.a
//    }
//}
