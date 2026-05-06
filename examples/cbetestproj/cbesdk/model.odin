package cbesdk

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import sdl "vendor:sdl3"

// Loading .obj models
Model :: struct {
    verts:   []VertexData,
    indices: []u32,
}

load_obj :: proc(path: string) -> Model {

    model      := Model {}
    vert_poses := make([dynamic]Vector3f)
    vert_cols  := make([dynamic]sdl.FColor)
    vert_uvs   := make([dynamic]Vector2f)
    face_poses := make([dynamic]u32)
    face_uvs   := make([dynamic]u32)
    defer delete(vert_poses)
    defer delete(vert_cols)
    defer delete(vert_uvs)
    defer delete(face_poses)
    defer delete(face_uvs)

    // Read file
    data, err := os.read_entire_file(path, context.allocator)
    
    if err != nil {
        fmt.println("Failed to read project settings file")
        return model
    }

    // Parse everything
    lines := string(data)
	for line in strings.split_lines_iterator(&lines) {

        parts := strings.split(line, " ")
        if (len(parts) < 1) {
            continue
        }

        switch parts[0] {

            case "v":
                append(&vert_poses, parse_vert_pos(parts))
            case "vt":
                append(&vert_uvs, parse_vert_uv(parts))
            case "f":
                append_elems(&face_poses, ..parse_face_pos(parts))
                append_elems(&face_uvs, ..parse_face_uv(parts))

        }

    }

    // Because .obj is actually a stupid format, create new vertices
    model.verts   = make([]VertexData, len(face_poses) * 3)
    model.indices = make([]u32, len(face_poses) * 3)

    for face, i in face_poses {

        model.verts[i] = VertexData {
            pos = vert_poses[face_poses[i]],
            col = {1, 1, 1, 1},
            uv  = vert_uvs[face_uvs[i]],
        }
        model.indices[i] = u32(i)

    }

    return model

}

// Parsers
parse_vert_pos :: proc(parts: []string) -> Vector3f {

    if (len(parts) != 4) {
        return {0, 0, 0}
    }

    val, ok := strconv.parse_f32(parts[1])
    x := val
    val, ok = strconv.parse_f32(parts[2])
    y := val
    val, ok = strconv.parse_f32(parts[3])
    z := val

    return {x, y, z}

}

parse_vert_uv :: proc(parts: []string) -> Vector2f {

    if (len(parts) != 3) {
        return {0, 0}
    }

    val, ok := strconv.parse_f32(parts[1])
    x := val
    val, ok = strconv.parse_f32(parts[2])
    y := val

    return {x, y}

}

parse_face_pos :: proc(parts: []string) -> []u32 {

    poses := []u32{0, 0, 0}

    if (len(parts) != 4) {
        return poses
    }

    for i in 1..=3 {
        indices := strings.split(parts[i], "/")
        if (len(indices) < 1) {
            return poses
        }
        val, ok := strconv.parse_uint(indices[0])
        poses[i - 1] = u32(val) - 1
    }

    return poses

}

parse_face_uv :: proc(parts: []string) -> []u32 {

    uvs := []u32{0, 0}

    if (len(parts) != 4) {
        return uvs
    }

    for i in 1..=3 {
        indices := strings.split(parts[i], "/")
        if (len(indices) < 2) {
            return uvs
        }
        val, ok := strconv.parse_uint(indices[1])
        uvs[i - 1] = u32(val)
    }

    return uvs

}