package cbesdk

import "core:fmt"
import "core:strconv"

// Builtin components and systems
Vector2f :: [2]f32
Vector2i :: [2]i32
Vector3f :: [3]f32
Vector3i :: [3]i32

Transform :: struct {
    position: Vector3f,
    rotation: Vector3f,
    scale:    Vector3f,
}
TRANSFORM_CONSTRUCTOR :: proc(args: [dynamic]string) -> any {

    if len(args) != 9 {
        return nil
    }

    // I need to find a bettwer way to do this
    arg0, ok0 := strconv.parse_f32(args[0])
    arg1, ok1 := strconv.parse_f32(args[1])
    arg2, ok2 := strconv.parse_f32(args[2])
    arg3, ok3 := strconv.parse_f32(args[3])
    arg4, ok4 := strconv.parse_f32(args[4])
    arg5, ok5 := strconv.parse_f32(args[5])
    arg6, ok6 := strconv.parse_f32(args[6])
    arg7, ok7 := strconv.parse_f32(args[7])
    arg8, ok8 := strconv.parse_f32(args[8])

    // Have to put stuff on the heap
    comp := Transform {
        position = { arg0, arg1, arg2 },
        rotation = { arg3, arg4, arg5 },
        scale    = { arg6, arg7, arg8 },
    }
    ptr  := new(Transform)
    ptr^  = comp

    return ptr^

}

Camera :: struct {
    fov:        f32,
    near_plane: f32,
    far_plane:  f32,
    is_main:    bool,
}
CAMERA_CONSTRUCTOR :: proc(args: [dynamic]string) -> any {

    if len(args) != 4 {
        return nil
    }

    // Like really i do
    arg0, ok0 := strconv.parse_f32(args[0])
    arg1, ok1 := strconv.parse_f32(args[1])
    arg2, ok2 := strconv.parse_f32(args[2])
    arg3 := false
    if (args[3] == "true") {
        arg3 = true
    }

    // Have to put stuff on the heap
    comp := Camera {
        fov        = arg0,
        near_plane = arg1,
        far_plane  = arg2,
        is_main    = arg3,
    }
    ptr  := new(Camera)
    ptr^  = comp

    return ptr^

}

CAM_APP_SYSTEM :: AppSystem {

    name   = "CameraSystem",
    update = proc(scene: ^Scene, app: ^Application, deltaTime: f32) {

        cam_matches, c_indices := query_scene_components(scene^, Camera)
        cam_uuids              := query_component_uuids(scene^, Camera)

        for cam, i in cam_matches {
            if cam.is_main {

                transform_matches, m_indices := query_scene_components_uuid(scene^, Transform, cam_uuids[i])

                set_render_camera(app, RenderCamera {
                    position        = transform_matches[0].position,
                    rotation        = transform_matches[0].rotation,
                    fov             = cam.fov,
                    clipping_planes = {cam.near_plane, cam.far_plane}
                })

            }
        }

    }

}