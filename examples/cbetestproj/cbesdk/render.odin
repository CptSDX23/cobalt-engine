package cbesdk

import "core:fmt"
import "core:os"
import "core:mem"
import "core:math/linalg"
import sdl "vendor:sdl3"
import stb "vendor:stb/image"

// Structs
RenderContext :: struct {
    window:   ^sdl.Window,
    gpu:      ^sdl.GPUDevice,
    pipeline: ^sdl.GPUGraphicsPipeline,
    shaders:  [dynamic]^sdl.GPUShader,
    textures: [dynamic]Texture,
    settings: WindowSettings,
}

WindowSettings :: struct {
    name:      cstring,
    size:      Vector2i,
    clear_col: [4]f32,
}

UBO :: struct {
    mvp: matrix[4,4]f32,
}

VertexData :: struct {
    pos: Vector3f,
    col: sdl.FColor,
}

Texture :: struct {
    tex:    ^sdl.GPUTexture,
    pixels: [^]byte,
    size:   Vector2i,
}

ROTATION := f32(0)

// Defaults
create_render_ctx :: proc(win_settings: WindowSettings) -> RenderContext {
    
    ok     := sdl.Init({.VIDEO}); assert(ok, "Failed to initialize SDL3")
    window := sdl.CreateWindow(win_settings.name, win_settings.size.x, win_settings.size.y, {}); assert(window != nil, "Failed to create window")
    gpu    := sdl.CreateGPUDevice({.SPIRV}, true, nil); assert(gpu != nil, "Failed to create GPU device")

    // This should have been up here a long time ago i wasted so much time
    ok = sdl.ClaimWindowForGPUDevice(gpu, window); assert(ok, "Failed to claim window for GPU device")

    // Load all shaders to create pipeline
    shaders := make([dynamic]^sdl.GPUShader)
    load_all_shaders(gpu, &shaders)

    // Load images
    textures := make([dynamic]Texture)
    append(&textures, load_texture(gpu, "assets/mcStone.png"))

    // Shader offsets hardcoded for now
    pipeline := sdl.CreateGPUGraphicsPipeline(gpu, {
        vertex_shader      = shaders[0],
        fragment_shader    = shaders[1],
        primitive_type     = .TRIANGLELIST,
        vertex_input_state = {
            num_vertex_buffers         = 1,
            vertex_buffer_descriptions = &sdl.GPUVertexBufferDescription {
                slot  = 0,
                pitch = size_of(VertexData)
            },
            num_vertex_attributes = 2,
            vertex_attributes     = raw_data([]sdl.GPUVertexAttribute {
                { location = 0, format = .FLOAT3, offset = u32(offset_of(VertexData, pos)) },
                { location = 1, format = .FLOAT4, offset = u32(offset_of(VertexData, col)) },
            }),
        },
        target_info = {
            num_color_targets         = 1,
            color_target_descriptions = &sdl.GPUColorTargetDescription {
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
            },
        },
    })

    return RenderContext { 
        window   = window, 
        gpu      = gpu, 
        pipeline = pipeline, 
        shaders  = shaders,
        settings = win_settings,
    }

}

// The boolean indicates whether the application should exit
run_render :: proc(ctx: RenderContext) -> bool {

    loop: for {

        // Events
        event: sdl.Event
        for sdl.PollEvent(&event) {
            #partial switch event.type {
                case .QUIT:
                    return true
            }
        }

        ROTATION += 1

        // Render
        cmd_buf   := sdl.AcquireGPUCommandBuffer(ctx.gpu)
        swapchain :  ^sdl.GPUTexture
        ok := sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, ctx.window, &swapchain, nil, nil); assert(ok, "Failed to aquire swapchain texture")

        // For when window is minimized
        if (swapchain == nil) {
            return false
        }

        // Get projection matrix
        win_size: [2]i32
        ok = sdl.GetWindowSize(ctx.window, &win_size.x, &win_size.y); assert(ok, "Failed to get window size for projection matrix")

        // Z+ is away from the camera i dont want to hear about it
        proj_mat  := linalg.matrix4_perspective_f32(linalg.to_radians(f32(70)), f32(win_size.x) / f32(win_size.y), 0.001, 10000, false)
        model_mat := create_model_matrix({0, 0, 3}, {0, ROTATION, 0})
        ubo       := UBO { mvp = proj_mat * model_mat }

        // Create vertex and index buffers
        vertices := []VertexData {
            { pos = {-0.5,  0.5, 0}, col = {1, 0, 0, 1} },
            { pos = { 0.5,  0.5, 0}, col = {0, 1, 0, 1} },
            { pos = {-0.5, -0.5, 0}, col = {0, 0, 1, 1} },
            { pos = { 0.5, -0.5, 0}, col = {1, 1, 0, 1} },
        }
        indices := []u32 {
            0, 1, 2,
            2, 1, 3,
        }

        vertex_buf := sdl.CreateGPUBuffer(ctx.gpu, {
            usage = {.VERTEX},
            size  = u32(get_vert_data_size(vertices)),
        })
        index_buf := sdl.CreateGPUBuffer(ctx.gpu, {
            usage = {.INDEX},
            size  = u32(get_index_data_size(indices)),
        })
        transfer_buf := sdl.CreateGPUTransferBuffer(ctx.gpu, {
            usage = .UPLOAD,
            size  = u32(get_vert_data_size(vertices) + get_index_data_size(indices)),
        })
        tex_transfer_buf := sdl.CreateGPUTransferBuffer(ctx.gpu, {
            usage = .UPLOAD,
            size  = u32(ctx.textures[0].size.x * ctx.textures[0].size.y * 4),
        })
        
        // Crazy odin shit
        transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(ctx.gpu, transfer_buf, true)
        mem.copy(transfer_mem,                                raw_data(vertices), get_vert_data_size(vertices))
        mem.copy(transfer_mem[get_vert_data_size(vertices):], raw_data(indices), get_index_data_size(indices))
        sdl.UnmapGPUTransferBuffer(ctx.gpu, transfer_buf)

        tex_transfer_mem := sdl.MapGPUTransferBuffer(ctx.gpu, tex_transfer_buf, false)
        mem.copy(tex_transfer_mem, ctx.textures[0].pixels, int(ctx.textures[0].size.x * ctx.textures[0].size.y * 4))
        sdl.UnmapGPUTransferBuffer(ctx.gpu, tex_transfer_buf)

        // Vertex and index copy pass
        copy_cmd_buf := sdl.AcquireGPUCommandBuffer(ctx.gpu)
        copy_pass    := sdl.BeginGPUCopyPass(copy_cmd_buf)

        sdl.UploadToGPUBuffer(copy_pass,
            { transfer_buffer = transfer_buf },
            { buffer = vertex_buf, size = u32(get_vert_data_size(vertices)) },
            true,
        )
        sdl.UploadToGPUBuffer(copy_pass,
            { transfer_buffer = transfer_buf, offset = u32(get_vert_data_size(vertices)) },
            { buffer = index_buf, size = u32(get_index_data_size(indices)) },
            true,
        )

        sdl.EndGPUCopyPass(copy_pass)
        ok = sdl.SubmitGPUCommandBuffer(copy_cmd_buf); assert(ok, "Failed to submit copy buffer")

        // Draw passes
        color_target := sdl.GPUColorTargetInfo {
            texture     = swapchain,
            load_op     = .CLEAR,
            clear_color = sdl.FColor(ctx.settings.clear_col),
            store_op    = .STORE,
        }
        render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)

        // Draw commands
        sdl.BindGPUGraphicsPipeline(render_pass, ctx.pipeline)
        sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding { buffer = vertex_buf }, 1)
        sdl.BindGPUIndexBuffer(render_pass, { buffer = index_buf }, ._32BIT)
        sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))
        sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)

        sdl.EndGPURenderPass(render_pass)

        // Display
        ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok, "Failed to submit command buffer")

        return false

    }

}

// Scans target directory for .spv files
load_all_shaders :: proc(gpu: ^sdl.GPUDevice, shaders: ^[dynamic]^sdl.GPUShader) {

    // Hardcoded for now
    vert_code, err_v := os.read_entire_file("target/assets/vert_shader.spv.vert", context.allocator)
    if err_v != nil {
        fmt.printfln("Failed to load vert shader from compiled file: %v", err_v)
        return
    }
    append(shaders, load_shader(gpu, vert_code, .VERTEX, 1))


    frag_code, err_f := os.read_entire_file("target/assets/frag_shader.spv.frag", context.allocator)
    if err_f != nil {
        fmt.printfln("Failed to load frag shader from compiled file: %v", err_f)
        return
    }
    append(shaders, load_shader(gpu, frag_code, .FRAGMENT, 0))

}

load_shader :: proc(gpu: ^sdl.GPUDevice, code: []u8, stage: sdl.GPUShaderStage, num_ubs: u32) -> ^sdl.GPUShader {

    return sdl.CreateGPUShader(gpu, {
        code_size           = len(code),
        code                = raw_data(code),
        entrypoint          = "main",
        format              = {.SPIRV},
        stage               = stage,
        num_uniform_buffers = num_ubs
    })

}

load_texture :: proc(gpu: ^sdl.GPUDevice, path: cstring) -> Texture {

    img_size: [2]i32
    pixels  := stb.load(path, &img_size.x, &img_size.y, nil, 4); assert(pixels != nil, "Failed to load texture")
    texture := sdl.CreateGPUTexture(gpu, {
        type                 = .D2,
        format               = .R8G8B8A8_UNORM,
        usage                = {.SAMPLER},
        width                = u32(img_size.x),
        height               = u32(img_size.y),
        layer_count_or_depth = 1,
        num_levels           = 1,
    })

    return Texture {
        tex    = texture,
        pixels = pixels,
        size   = img_size,
    }

}

create_model_matrix :: proc(pos: [3]f32, rot: [3]f32) -> matrix[4,4]f32 {

    model_mat: matrix[4,4]f32

    model_mat = linalg.matrix4_translate_f32(pos)
    model_mat = model_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.x), {1, 0, 0})
    model_mat = model_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.y), {0, 1, 0})
    model_mat = model_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.z), {0, 0, 1})

    return model_mat

}

get_vert_data_size :: proc(vertices: []VertexData) -> int {
    return len(vertices) * size_of(VertexData)
}

get_index_data_size :: proc(indices: []u32) -> int {
    return len(indices) * size_of(u32)
}