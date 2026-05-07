package cbesdk

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

Camera :: struct {
    fov:        f32,
    near_plane: f32,
    far_plane:  f32,
    is_main:    bool,
}

cam_system := AppSystem {

    name   = "CameraSystem",
    update = proc(scene: Scene, app: ^Application, deltaTime: f32) {

        cam_matches, indices := query_scene_components(scene, Camera)
        cam_uuids            := query_component_uuids(scene, Camera)

        for cam, i in cam_matches {
            if cam.is_main {

                transform := query_entity_component(scene, Transform, cam_uuids[i])

                set_render_camera(app, RenderCamera {
                    position        = transform.position,
                    rotation        = transform.rotation,
                    fov             = cam.fov,
                    clipping_planes = {cam.near_plane, cam.far_plane}
                })

            }
        }

    }

}