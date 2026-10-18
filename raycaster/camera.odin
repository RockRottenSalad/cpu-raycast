package raycaster

Camera :: struct {
    position: Vector3,
    // The direction the camera is facing in.
    // This is always a normalised vector
    direction: Vector3,

    // Up vector, always a normalised vector.
    // Points 90 degs up relative to the direction vector.
    // Used for Up/Down movement and ray-cast direction
    pitch_vector: Vector3,
    // Side vector, always a normalised vector.
    // Points 90 degs left of the direction vector.
    // Used for Left/Right movement and ray-cast direction
    yaw_vector: Vector3,

    // Yaw is Left/Right movements
    yaw_in_radians: f32,
    // Pitch is Up/Down movements
    pitch_in_radians: f32,

    // How sensitive the camera is to mouse movements.
    // Mouse motions are scaled by this value
    sensitivity: f32
}

CreateCamera :: proc() -> Camera {
    camera := Camera {
        position = Vector3{0,0,0},
        sensitivity = 0.001,
        // All other fields are calculated from these two values
        yaw_in_radians = DegreesToRadians(90), // Facing (0,0,1), i.e. in the positive z direction
        pitch_in_radians = 0,
    }

    // This ensures all other fields are initialised according to yaw and pitch
    CameraUpdateAccordingToMouseMovement(&camera, mouseDeltaX=0, mouseDeltaY=0)

    return camera
}

CameraUpdateAccordingToMouseMovement :: proc(camera: ^Camera, mouseDeltaX: f32, mouseDeltaY: f32) {
    // TODO: need some timing machanism in main or something to ensure consistent turn speed(maybe just delta-time?)
    // ^ Same issue with regular camera movements
    camera.yaw_in_radians -= mouseDeltaX * camera.sensitivity
    camera.pitch_in_radians -= mouseDeltaY * camera.sensitivity

    // Limit pitch to +-89 degrees
    // If the pitch becomes 90 degrees:
    //   Then camera.direction would be (0,1,0),
    //   which means the cross product of (0,1,0) and camera.direction would be (0,0,0),
    //   thus camera.yaw_vector becomes (0,0,0). (which is bad)
    pitch_upper_limit := DegreesToRadians(89.0)
    pitch_lower_limit := DegreesToRadians(-89.0)
    camera.pitch_in_radians = clamp(camera.pitch_in_radians, pitch_lower_limit, pitch_upper_limit)

    camera.direction = Vec3FromPitchAndYaw(camera.pitch_in_radians, camera.yaw_in_radians)
    camera.yaw_vector = Vec3CrossProduct(Vector3{0,1,0}, camera.direction)
    camera.pitch_vector = Vec3CrossProduct(camera.yaw_vector, camera.direction)
}


// Negative stride value corresponds to moving left, positive is right
CameraMoveHorizontally :: proc(camera: ^Camera, stride: f32) {
    camera.position = Vec3Add(camera.position, Vec3Scale(camera.yaw_vector, stride))
}

// Negative stride value corresponds to moving down, positive is up
CameraMoveVertically :: proc(camera: ^Camera, stride: f32) {
    camera.position = Vec3Add(camera.position, Vec3Scale(camera.pitch_vector, stride))
}

// Negative stride value corresponds to moving backwards, positive is forwards.
CameraMoveStraight :: proc(camera: ^Camera, stride: f32) {
    camera.position = Vec3Add(camera.position, Vec3Scale(camera.direction, stride))
}
