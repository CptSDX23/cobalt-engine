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

cam_system := System {

    name   = "CameraSystem",
    update = proc(scene: Scene, deltaTime: f32) {

        matches, indices := query_scene_components(scene, Camera)
        for cam, i in matches {
            if cam.is_main {
                
            }
        }

    }

}