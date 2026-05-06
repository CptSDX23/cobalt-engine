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