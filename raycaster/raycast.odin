package raycaster

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:thread"
import "core:sync"
import "core:time"

Ray :: struct {
    origin: Vector3,
    direction: Vector3,
}

RayCaster :: struct {
    threads: []^thread.Thread,
    thread_data: []RayCasterThreadData,
    pixels: []Color,
    height: u32,
    width: u32,
}


CreateRayCaster :: proc(height: u32, width: u32) -> RayCaster {
    pixels := make([]Color, height * width)

    return RayCaster {
        threads = nil,
        thread_data = nil,
        pixels = pixels,
        height = height,
        width = width
    }
}

DestroyRayCaster :: proc(ray: ^RayCaster) {
    if ray.threads != nil {
        for &thread_data in ray.thread_data {
            thread_data.should_exit = true
            sync.sema_post(&thread_data.wakeup_semaphore)
        }

        for &th in ray.threads {
            thread.join(th)
        }
        delete(ray.threads)
        delete(ray.thread_data)
    }

    delete(ray.pixels)
}

// returns bool indicating success
RayCasterInitializeMultiThreading :: proc (raycaster: ^RayCaster, thread_count: u32 = 8) -> bool {
    if thread_count == 0 {
        return false
    }

    threads := make([]^thread.Thread, thread_count)
    thread_data := make([]RayCasterThreadData, thread_count)

    for i in 0..<thread_count {
        threads[i] = thread.create_and_start_with_poly_data(&thread_data[i], RayCasterThread)
    }

    raycaster.threads = threads
    raycaster.thread_data = thread_data
    return true
}

// <THREAD SAFE>
CastSingleRay :: proc(ray: ^Ray, scene: ^Scene, recursion_limit: u8 = 8) -> Color {
    intersection, index, ok := FindClosestIntersection(ray, scene)

    if !ok {
        return Color{r = 0, g = 0, b = 0, a = 255}
    } 

    // PhongLighting may or may not recursively call CastSingleRay if the object is reflective
    return PhongLighting(scene, index, intersection.position, ray, recursion_limit)
}

// <THREAD SAFE>
// Grid center can be found from camera alone.
// However, that is wasteful computation since it needs to be known for each ray
// It's better that the caller finds the value themselves and provides it to save computation.
CreatePerspectiveRay :: proc(ray_caster: ^RayCaster, camera: ^Camera, pixel_x: u32, pixel_y: u32, grid_center: Vector3) -> Ray {
    // everything to the left of the center needs to be moved in the -x direction and vice-versa
    rayx_t := cast(f32)pixel_x - cast(f32)ray_caster.width/2
    x_offset := Vec3Scale(camera.yaw_vector, rayx_t)

    rayy_t := cast(f32)pixel_y - cast(f32)ray_caster.height/2
    y_offset := Vec3Scale(camera.pitch_vector, rayy_t)

    // Denotes relative position of grid cell(relative to grid center)
    xy_offset := Vec3Add(x_offset, y_offset)

    grid_cell_vector := Vec3Add(grid_center, xy_offset)
    ray := Ray {
        // orthographic projection
        //origin = Vec3Add(Vector3{cast(f32)x,cast(f32)y,0}, camera.position),
        //direction = camera.direction

        // perspective projection 
        origin = camera.position,
        direction = Vec3Normalize(Vec3Sub(grid_cell_vector, camera.position))
    }

    return ray
}


RayCasterThreadData :: struct {
    ray_caster: ^RayCaster,
    camera: ^Camera,
    scene: ^Scene,

    // See the comment about perspective projection in `RayCastSingleThreaded`
    grid_center: Vector3,

    // Refers to the index of the first pixel to start ray casting from
    pixel_start_index: u32,
    // The total number of pixels to draw starting from the start index
    pixels_to_draw: u32,
    // When this is set to true and the thread is awakened via the semaphore, it exists
    should_exit: bool,

    // When the thread is finished, it will let the main thread know via this wait group
    wait_group: ^sync.Wait_Group,
    // The main thread notifies the thread via this semaphore when it's time to start working
    wakeup_semaphore: sync.Sema
}

// As long as the given `pixel_start_index` and `pixels_to_draw` don't overlap with another task, then no data races can occur
RayCasterThread :: proc(data: ^RayCasterThreadData) {
    for {
        // The main thread is responsible for performing the post when it's time to draw.
        // It should also make sure data is correctly updated so this thread doesn't do anything stupid
        sync.sema_wait(&data.wakeup_semaphore)

        if data.should_exit {
            return
        }

        height := data.ray_caster.height
        width := data.ray_caster.width

        start := data.pixel_start_index
        end := start + data.pixels_to_draw

        assert(start < height * width)
        assert(end-1 < height * width)

        for index in start..<end {
            x := index % width
            y := index / height
            ray := CreatePerspectiveRay(data.ray_caster, data.camera, x, y, data.grid_center)

            data.ray_caster.pixels[index] = CastSingleRay(&ray, data.scene)
        }

        sync.wait_group_done(data.wait_group)
    }
}

RayCastMultiThreaded :: proc(ray_caster: ^RayCaster, camera: ^Camera, scene: ^Scene) {
    // make sure multi-threading stuff has been initialized
    assert(ray_caster.threads != nil)

    grid_center := Vec3Add(camera.position, Vec3Scale(camera.direction, 2500))

    // TODO: All of this assumes that the number of pixels is greater than than the number of threads,
    // which will be the case 99% of the time.
    // But if it isn't due to the window temporarily being resized and squished, this blows up so it should be fixed
    wait_group: sync.Wait_Group
    sync.wait_group_add(&wait_group, len(ray_caster.threads))

    total_size := ray_caster.width * ray_caster.height
    num_of_chunks := cast(u32)len(ray_caster.threads)
    chunk_size := total_size / num_of_chunks

    for chunk_number in 0..<num_of_chunks {
        pixel_start := chunk_size * chunk_number
        pixels_count := chunk_size

        data := &ray_caster.thread_data[chunk_number]

        // Overriding one field at a time rather than with a whole struct to ensure we don't fuck up the semaphore
        data.ray_caster = ray_caster
        data.camera = camera
        data.scene = scene
        data.grid_center = grid_center
        data.pixel_start_index = pixel_start
        data.pixels_to_draw = chunk_size
        data.should_exit=false
        data.wait_group=&wait_group
    }

    // separating the post from the data copying yielded noticable performance difference
    for chunk_number in 0..<num_of_chunks {
        sync.sema_post(&ray_caster.thread_data[chunk_number].wakeup_semaphore)
    }

    // TODO: Soooo, what about these pixels??
    remainder := total_size % chunk_size
    //fmt.println("Remainder: ", remainder)

    // Pray that no thread gets stuck in a weird infinite reflection ray-casting bug that I've yet to find
    sync.wait_group_wait(&wait_group)
}

RayCastSingleThreaded :: proc(ray_caster: ^RayCaster, camera: ^Camera, scene: ^Scene) {
    // Perpsective projection:
    // Imagine a grid placed some distance infront of the eye origin.
    // If we shoot a ray from the eye origin through each cell in the grid, we get a perspective projection.
    // 
    // We create this grid by first finding the grid center(camera position + camera direction * distance to grid).
    // Then using the camera.yaw_vector and camera.pitch_vector, we calculate the coordinate of each cell in the grid
    // relative to the grid center

    grid_center := Vec3Add(camera.position, Vec3Scale(camera.direction, 2500))
    for y in 0..<ray_caster.height {
        for x in 0..<ray_caster.width {
            ray := CreatePerspectiveRay(ray_caster, camera, x, y, grid_center)
            ray_caster.pixels[y*ray_caster.width + x] = CastSingleRay(&ray, scene)
        }
    }
}

