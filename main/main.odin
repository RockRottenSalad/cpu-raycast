package main

import rc "shared:raycaster"
import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"

CopyRayCasterPixelsToSurface :: proc(ray_caster: ^rc.RayCaster, surface: ^sdl.Surface) {
    assert(ray_caster.height == cast(u32)surface.h)
    assert(ray_caster.width == cast(u32)surface.w)
    assert(surface.pixels != nil)

    pixels_slice := cast([^]u8)surface.pixels;
    for y in 0..<ray_caster.height {
        for x in 0..<ray_caster.width {
            dest := &pixels_slice[y * cast(u32)(surface.pitch) + x * 4]
            pixel := cast(^u32)dest;
            pixel^ = rc.ColorToARGB(ray_caster.pixels[ y*ray_caster.width + x ]);
        }
    }
}

main :: proc() {
    win := sdl.CreateWindow(title="SDL3", w=900, h=900, flags=sdl.WINDOW_ALWAYS_ON_TOP)
    defer sdl.DestroyWindow(win)

    camera := rc.CreateCamera()

    plane := rc.Geometry {
        color = rc.Color{r = 255, g = 255, b = 255, a = 255},
        is_mirror = true,
        is_lit = false,
        derived = rc.Plane {
            normal = rc.Vector3{0,1,0},
            point_on_plane = rc.Vector3{0,-150,0}, 
         }
    }

    sphere_a := rc.Geometry {
        color = rc.Color{r = 150, g = 50, b = 200, a = 255},
        is_mirror = true,
        is_lit = false,
        derived = rc.Sphere { 
            position = rc.Vector3{0,0,600},
            radius = 100.0,
        }
    }

    sphere_b := rc.Geometry {
        color = rc.Color{r = 50, g = 200, b = 50, a = 255},
        is_mirror = true,
        is_lit = false,
        derived = rc.Sphere { 
            position = rc.Vector3{0,200,600},
            radius = 50.0,
        }
    }

    sphere_c := rc.Geometry {
        color = rc.Color{r = 200, g = 50, b = 50, a = 255},
        is_mirror = true,
        is_lit = false,
        derived = rc.Sphere { 
            position = rc.Vector3{100,-20,400},
            radius = 40.0,
        }
    }

    light_position := rc.Vector3{300,40,100}
    sphere_d := rc.Geometry {
        color = rc.Color{r = 255, g = 255, b = 255, a = 255},
        is_mirror = true,
        is_lit = true,
        derived = rc.Sphere { 
            position = light_position,
            radius = 10.0,
        }
    }

    

    geometries := [?]rc.Geometry{plane, sphere_a, sphere_b, sphere_c, sphere_d}

    spot_light := rc.LightSource { position = light_position, color = rc.Vector3{0.9, 0.5, 0.8}}

    scene := rc.Scene {
        geometries[:],
        spot_light
    }


    // From SDL docs: "This surface will be freed when the window is destroyed. Do not free this surface."
    surf := sdl.GetWindowSurface(win)

    // This must be after we get the surface or it just gets disabled again
    _ = sdl.SetWindowRelativeMouseMode(win, true)

    // Surface dimensions may be smaller than window.
    // This is due to things like window decorations i.e. window borders.
    // This means the actual drawable area can be smaller than the full window size,
    // so we use surface dimensions for the raycaster and not the window dimensions
    ray_caster := rc.CreateRayCaster(height = cast(u32)surf.h, width = cast(u32)surf.w)
    rc.RayCasterInitializeMultiThreading(raycaster=&ray_caster, thread_count=4)
    defer rc.DestroyRayCaster(&ray_caster)

    t0: sdl.Time
    _ = sdl.GetCurrentTime(&t0)

    running := true
    dirty := true
    multi_thread := true
    i := 0
    event: sdl.Event
    for running {
        for sdl.PollEvent(&event) {
            #partial switch event.type {
                case .QUIT: running = false
                case .KEY_DOWN: #partial switch event.key.scancode {
                    case .Q: running = false

                    case .W: rc.CameraMoveStraight(&camera, 8.0);      /* dirty = true */ 
                    case .S: rc.CameraMoveStraight(&camera, -8.0);     /* dirty = true */
                    case .A: rc.CameraMoveHorizontally(&camera, -8.0); /* dirty = true */
                    case .D: rc.CameraMoveHorizontally(&camera, 8.0); /* dirty = true */

                    case .J: rc.CameraMoveVertically(&camera, 4.0);    /* dirty = true */
                    case .K: rc.CameraMoveVertically(&camera, -4.0);   /* dirty = true */

                    case .L: camera.sensitivity = 0
                    case .U: camera.sensitivity = 0.001

                    case .M: multi_thread = !multi_thread; fmt.println("Multi-threading: ", multi_thread)
                }
                case .MOUSE_MOTION: {
                    rc.CameraUpdateAccordingToMouseMovement(&camera, event.motion.xrel, event.motion.yrel);
                    dirty = true
                }
            }
        }

        t1: sdl.Time
        _ = sdl.GetCurrentTime(&t1)
        if t1 - t0 > 1e5 {
            i = i + 1

            rad := 0.01 * cast(f32)i
            scene.light.position = rc.Vec3Add(rc.Vector3{math.cos(rad)*400, 0, math.sin(rad)*400}, rc.Vector3{0,0,600})

            s1 := &scene.geometries[4].derived.(rc.Sphere)
            s1.position = scene.light.position
            _ = sdl.GetCurrentTime(&t0)
            dirty = true
        }

        if dirty {
            if multi_thread {
                rc.RayCastMultiThreaded(&ray_caster, &camera, &scene)
            } else {
                rc.RayCastSingleThreaded(&ray_caster, &camera, &scene)
            }
            CopyRayCasterPixelsToSurface(&ray_caster, surf)
            dirty = false
        }

        sdl.UpdateWindowSurface(win)
    }
}

