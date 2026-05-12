package cbesdk

import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"
import "core:strconv"
import sdl "vendor:sdl3"

// Loading .obj models
Mesh :: struct {
    verts:   []VertexData,
    indices: []u32,
}

Model :: struct {
    mesh:     Mesh,
    texture:  Texture,
    material: MaterialUBO,
    buffers:  ModelBufferInfo,
    position: Vector3f,
    rotation: Vector3f,
    scale:    Vector3f,
}

ModelBufferInfo :: struct {
    vertex_buf: ^sdl.GPUBuffer,
    index_buf:  ^sdl.GPUBuffer,
}

FaceIndex :: struct {
    poses:   [3]u32,
    uvs:     [3]u32,
    normals: [3]u32,
}

load_obj_mesh :: proc(path: string) -> Mesh {

    mesh         := Mesh {}
    vert_poses   := make([dynamic]Vector3f)
    vert_cols    := make([dynamic]sdl.FColor)
    vert_uvs     := make([dynamic]Vector2f)
    vert_normals := make([dynamic]Vector3f)
    face_indices := make([dynamic]FaceIndex)
    defer delete(vert_poses)
    defer delete(vert_cols)
    defer delete(vert_uvs)
    defer delete(vert_normals)
    defer delete(face_indices)

    // Read file
    data, err := os.read_entire_file(path, context.allocator)
    
    if err != nil {
        fmt.println("Failed to read obj file")
        return mesh
    }

    // Parse everything
    lines := string(data)
	for line in strings.split_lines_iterator(&lines) {

        // Because splitting is just wrong for some reason?
        parts := strings.fields(line)
        if (len(parts) < 1) {
            continue
        }

        switch parts[0] {

            case "v":
                append(&vert_poses, parse_vert_pos(parts))
            case "vt":
                append(&vert_uvs, parse_vert_uv(parts))
            case "vn":
                append(&vert_normals, parse_vert_normal(parts))
            case "f":
                append(&face_indices, parse_face_index(parts))

        }

    }

    // Because .obj is actually a stupid format, create new vertices
    // Also this entire routine is scuffed my bad
    final_verts   := make([dynamic]VertexData)
    final_indices := make([dynamic]u32)

    for index, i in face_indices {

        for j in 0..<3 {

            // Because some might be missing
            uv     := Vector2f {0, 0}
            normal := Vector3f {0, 0, 0}
            if len(vert_uvs) > 0 {
                uv = vert_uvs[index.uvs[j]]
            }
            if len(vert_normals) > 0 {
                normal = vert_normals[index.normals[j]]
            }

            append(&final_verts, VertexData {
                pos    = vert_poses[index.poses[j]],
                col    = {1, 1, 1, 1},
                uv     = uv,
                normal = normal,
            })
            append(&final_indices, u32(i * 3 + j))

        }

    }

    mesh = Mesh {
        verts   = final_verts[:],
        indices = final_indices[:],
    }

    return mesh

}

load_obj_model :: proc(gpu: ^sdl.GPUDevice, obj_path: string, tex_path: string, flip_tex: i32) -> Model {

    mesh := load_obj_mesh(obj_path)
    tex  := load_texture(gpu, strings.clone_to_cstring(tex_path), flip_tex)

    return Model {
        mesh     = mesh,
        texture  = tex,
        material = {
            diffuse_color  = {1, 1, 1},
            shininess      = 100,
            specular_color = {1, 1, 1}
        }
    }

}

// Upload the data once on model creation, and store it to be draw later
// This combined with changing UBOs is the secret to drawing multiple models!
set_model_buffers :: proc(gpu: ^sdl.GPUDevice, model: ^Model) {

    vertices := model.mesh.verts[:]
    indices  := model.mesh.indices[:]

    vertex_buf := sdl.CreateGPUBuffer(gpu, {
        usage = {.VERTEX},
        size  = u32(get_vert_data_size(vertices)),
    })
    index_buf := sdl.CreateGPUBuffer(gpu, {
        usage = {.INDEX},
        size  = u32(get_index_data_size(indices)),
    })
    geo_transfer_buf := sdl.CreateGPUTransferBuffer(gpu, {
        usage = .UPLOAD,
        size  = u32(get_vert_data_size(vertices) + get_index_data_size(indices)),
    })
    tex_transfer_buf := sdl.CreateGPUTransferBuffer(gpu, {
        usage = .UPLOAD,
        size  = u32(get_tex_data_size(model.texture)),
    })

    // Crazy odin shit
    transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(gpu, geo_transfer_buf, false)
    mem.copy(transfer_mem,                                raw_data(vertices), get_vert_data_size(vertices))
    mem.copy(transfer_mem[get_vert_data_size(vertices):], raw_data(indices), get_index_data_size(indices))
    sdl.UnmapGPUTransferBuffer(gpu, geo_transfer_buf)

    tex_transfer_mem := sdl.MapGPUTransferBuffer(gpu, tex_transfer_buf, false)
    mem.copy(tex_transfer_mem, model.texture.pixels, get_tex_data_size(model.texture))
    sdl.UnmapGPUTransferBuffer(gpu, tex_transfer_buf)

    // Vertex and index copy pass
    copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
    copy_pass    := sdl.BeginGPUCopyPass(copy_cmd_buf)

    sdl.UploadToGPUBuffer(copy_pass,
        { transfer_buffer = geo_transfer_buf },
        { buffer = vertex_buf, size = u32(get_vert_data_size(vertices)) },
        false,
    )
    sdl.UploadToGPUBuffer(copy_pass,
        { transfer_buffer = geo_transfer_buf, offset = u32(get_vert_data_size(vertices)) },
        { buffer = index_buf, size = u32(get_index_data_size(indices)) },
        false,
    )
    sdl.UploadToGPUTexture(copy_pass,
        { transfer_buffer = tex_transfer_buf },
        { texture = model.texture.tex, w = u32(model.texture.size.x), h = u32(model.texture.size.y), d = 1 },
        false,
    )

    sdl.EndGPUCopyPass(copy_pass)
    ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf); assert(ok, "Failed to submit copy buffer")

    // Regular buffers will stay
    model.buffers.vertex_buf = vertex_buf
    model.buffers.index_buf  = index_buf
    sdl.ReleaseGPUTransferBuffer(gpu, geo_transfer_buf)
    sdl.ReleaseGPUTransferBuffer(gpu, tex_transfer_buf)

}

set_model_transform :: proc(model: ^Model, pos: Vector3f, rot: Vector3f, scale: Vector3f) {

    model.position = pos
    model.rotation = rot
    model.scale    = scale

}

set_model_material :: proc (model: ^Model, material: MaterialUBO) {

    model.material = material

}

// Parsers
parse_vert_pos :: proc(parts: []string) -> Vector3f {

    if (len(parts) < 4) {
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

    if (len(parts) < 3) {
        return {0, 0}
    }

    val, ok := strconv.parse_f32(parts[1])
    x := val
    val, ok = strconv.parse_f32(parts[2])
    y := val

    return {x, y}

}

parse_vert_normal :: proc(parts: []string) -> Vector3f {

    if (len(parts) < 4) {
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

parse_face_index :: proc(parts: []string) -> FaceIndex {

    index   := FaceIndex {}
    poses   := [3]u32{0, 0, 0}
    uvs     := [3]u32{0, 0, 0}
    normals := [3]u32{0, 0, 0}

    if (len(parts) != 4) {
        return index
    }

    for i in 1..=3 {
        indices := strings.split(parts[i], "/")
        if len(indices) < 1 {
            return index
        }
        if len(indices) < 2 {
            val, ok := strconv.parse_uint(indices[0])
            poses[i - 1] = u32(val) - 1
        }
        if len(indices) < 3 {
            val, ok := strconv.parse_uint(indices[0])
            poses[i - 1] = u32(val) - 1
            val, ok = strconv.parse_uint(indices[1])
            uvs[i - 1] = u32(val) - 1
        }
        if len(indices) >= 3 {
            val, ok := strconv.parse_uint(indices[0])
            poses[i - 1] = u32(val) - 1
            val, ok = strconv.parse_uint(indices[1])
            uvs[i - 1] = u32(val) - 1
            val, ok = strconv.parse_uint(indices[2])
            normals[i - 1] = u32(val) - 1
        }
    }

    index.poses   = poses
    index.uvs     = uvs
    index.normals = normals

    return index

}

parse_face_uv :: proc(parts: []string) -> []u32 {

    uvs := []u32{0, 0, 0}

    if (len(parts) != 4) {
        return uvs
    }

    for i in 1..=3 {
        indices := strings.split(parts[i], "/")
        if (len(indices) < 2) {
            return uvs
        }
        val, ok := strconv.parse_uint(indices[1])
        uvs[i - 1] = u32(val) - 1
    }

    return uvs

}