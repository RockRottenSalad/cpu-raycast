package raycaster

// This is fucking stupid.
// Should just use a vec3 for colors.
// Alpha channel is completely unsused.

Color :: struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
}

ColorToARGB :: proc(color: Color) -> u32 {
    r := cast(u32)color.r
    g := cast(u32)color.g
    b := cast(u32)color.b
    a := cast(u32)color.a

    return (a << 24) | (r << 16) | (g << 8) | b
}

// alpha is dropped
ColorToVec3 :: proc(color: Color) -> Vector3 {
    return Vector3{cast(f32)color.r / 255.0, cast(f32)color.g / 255.0, cast(f32)color.b / 255.0}
}

ColorFromVec3 :: proc(color_as_vector: Vector3) -> Color {
    return Color {
        cast(u8)(min(1.0, color_as_vector.x) * 255.0),
        cast(u8)(min(1.0, color_as_vector.y) * 255.0),
        cast(u8)(min(1.0, color_as_vector.z) * 255.0),
        255
    }
}

