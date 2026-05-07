package cbesdk

import "core:fmt"
import "core:os"
import "core:mem"
import "core:math/linalg"
import sdl "vendor:sdl3"
import stb "vendor:stb/image"

// Structs
RenderContext :: struct {
    window:    ^sdl.Window,
    gpu:       ^sdl.GPUDevice,
    pipeline:  ^sdl.GPUGraphicsPipeline,
    depth_tex: ^sdl.GPUTexture,
    shaders:   [dynamic]^sdl.GPUShader,
    textures:  [dynamic]Texture,
    models:    [dynamic]Model,
    camera:    RenderCamera,
    settings:  WindowSettings,
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
    uv:  Vector2f,
}

Texture :: struct {
    tex:     ^sdl.GPUTexture,
    sampler: ^sdl.GPUSampler,
    pixels:  [^]byte,
    size:    Vector2i,
}

RenderCamera :: struct {
    position:        Vector3f,
    rotation:        Vector3f,
    fov:             f32,
    clipping_planes: Vector2f,
}

// Debug
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
    append(&textures, load_texture(gpu, "target/assets/fries.png", 1))

    // Load models
    models := make([dynamic]Model)
    append(&models, load_obj("target/assets/teapot.obj"))

    // Camera
    cam := RenderCamera {
        position        = {0, 0, 0},
        rotation        = {0, 0, 0},
        fov             = 70,
        clipping_planes = {0.001, 10000}
    }

    // Create depth texture
    win_size: [2]i32
    ok = sdl.GetWindowSize(window, &win_size.x, &win_size.y); assert(ok, "Failed to get window size for depth texture")
    depth_tex := sdl.CreateGPUTexture(gpu, {
        type                 = .D2,
        format               = .D24_UNORM,
        usage                = {.DEPTH_STENCIL_TARGET},
        width                = u32(win_size.x),
        height               = u32(win_size.y),
        layer_count_or_depth = 1,
        num_levels           = 1,
    })

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
            num_vertex_attributes = 3,
            vertex_attributes     = raw_data([]sdl.GPUVertexAttribute {
                { location = 0, format = .FLOAT3, offset = u32(offset_of(VertexData, pos)) },
                { location = 1, format = .FLOAT4, offset = u32(offset_of(VertexData, col)) },
                { location = 2, format = .FLOAT2, offset = u32(offset_of(VertexData, uv)) },
            }),
        },
        target_info = {
            num_color_targets         = 1,
            has_depth_stencil_target  = true,
            depth_stencil_format      = .D24_UNORM,
            color_target_descriptions = &sdl.GPUColorTargetDescription {
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
            },
        },
        depth_stencil_state = {
            enable_depth_test  = true,
            enable_depth_write = true,
            compare_op         = .LESS,
        },
    })

    return RenderContext { 
        window    = window, 
        gpu       = gpu, 
        pipeline  = pipeline, 
        depth_tex = depth_tex,
        shaders   = shaders,
        textures  = textures,
        models    = models,
        camera    = cam,
        settings  = win_settings,
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
        proj_mat  := linalg.matrix4_perspective_f32(linalg.to_radians(ctx.camera.fov), f32(win_size.x) / f32(win_size.y), ctx.camera.cliping_planes.x, ctx.camera.cliping_planes.y, false)
        view_mat  := create_transform_matrix(ctx.camera.position, ctx.camera.rotation, true)
        model_mat := create_transform_matrix({0, 0, 25}, {0, ROTATION, 0}, false)
        ubo       := UBO { mvp = proj_mat * view_mat * model_mat }

        vertices := ctx.models[0].verts[:]
        indices  := ctx.models[0].indices[:]

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
            size  = u32(get_tex_data_size(ctx.textures[0])),
        })
        
        // Crazy odin shit
        transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(ctx.gpu, transfer_buf, false)
        mem.copy(transfer_mem,                                raw_data(vertices), get_vert_data_size(vertices))
        mem.copy(transfer_mem[get_vert_data_size(vertices):], raw_data(indices), get_index_data_size(indices))
        sdl.UnmapGPUTransferBuffer(ctx.gpu, transfer_buf)

        tex_transfer_mem := sdl.MapGPUTransferBuffer(ctx.gpu, tex_transfer_buf, false)
        mem.copy(tex_transfer_mem, ctx.textures[0].pixels, get_tex_data_size(ctx.textures[0]))
        sdl.UnmapGPUTransferBuffer(ctx.gpu, tex_transfer_buf)

        // Vertex and index copy pass
        copy_cmd_buf := sdl.AcquireGPUCommandBuffer(ctx.gpu)
        copy_pass    := sdl.BeginGPUCopyPass(copy_cmd_buf)

        sdl.UploadToGPUBuffer(copy_pass,
            { transfer_buffer = transfer_buf },
            { buffer = vertex_buf, size = u32(get_vert_data_size(vertices)) },
            false,
        )
        sdl.UploadToGPUBuffer(copy_pass,
            { transfer_buffer = transfer_buf, offset = u32(get_vert_data_size(vertices)) },
            { buffer = index_buf, size = u32(get_index_data_size(indices)) },
            false,
        )
        sdl.UploadToGPUTexture(copy_pass,
            { transfer_buffer = tex_transfer_buf },
            { texture = ctx.textures[0].tex, w = u32(ctx.textures[0].size.x), h = u32(ctx.textures[0].size.y), d = 1 },
            false,
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
        depth_target := sdl.GPUDepthStencilTargetInfo {
            texture     = ctx.depth_tex,
            load_op     = .CLEAR,
            clear_depth = 1,
            store_op    = .DONT_CARE,
        }
        render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, &depth_target)

        // Draw commands
        sdl.BindGPUGraphicsPipeline(render_pass, ctx.pipeline)
        sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding { buffer = vertex_buf }, 1)
        sdl.BindGPUIndexBuffer(render_pass, { buffer = index_buf }, ._32BIT)
        sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))
        sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding {
            texture = ctx.textures[0].tex,
            sampler = ctx.textures[0].sampler,
        }, 1)
        sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(vertices)), 1, 0, 0, 0)

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
    append(shaders, load_shader(gpu, vert_code, .VERTEX, 1, 0))


    frag_code, err_f := os.read_entire_file("target/assets/frag_shader.spv.frag", context.allocator)
    if err_f != nil {
        fmt.printfln("Failed to load frag shader from compiled file: %v", err_f)
        return
    }
    append(shaders, load_shader(gpu, frag_code, .FRAGMENT, 0, 1))

}

load_shader :: proc(gpu: ^sdl.GPUDevice, code: []u8, stage: sdl.GPUShaderStage, num_ubs: u32, num_samplers: u32) -> ^sdl.GPUShader {

    return sdl.CreateGPUShader(gpu, {
        code_size           = len(code),
        code                = raw_data(code),
        entrypoint          = "main",
        format              = {.SPIRV},
        stage               = stage,
        num_uniform_buffers = num_ubs,
        num_samplers        = num_samplers,
    })

}

load_texture :: proc(gpu: ^sdl.GPUDevice, path: cstring, flip: i32) -> Texture {

    img_size: [2]i32
    stb.set_flip_vertically_on_load(flip)
    pixels  := stb.load(path, &img_size.x, &img_size.y, nil, 4); //assert(pixels != nil, "Failed to load texture")
    if (pixels == nil) {
        fmt.println("Bad")
    }
    texture := sdl.CreateGPUTexture(gpu, {
        type                 = .D2,
        format               = .R8G8B8A8_UNORM,
        usage                = {.SAMPLER},
        width                = u32(img_size.x),
        height               = u32(img_size.y),
        layer_count_or_depth = 1,
        num_levels           = 1,
    })
    sampler := sdl.CreateGPUSampler(gpu, {})

    return Texture {
        tex     = texture,
        sampler = sampler,
        pixels  = pixels,
        size    = img_size,
    }

}

create_transform_matrix :: proc(pos: [3]f32, rot: [3]f32, flip: bool) -> matrix[4,4]f32 {

    transform_mat: matrix[4,4]f32

    if (!flip) {

        transform_mat = linalg.matrix4_translate_f32(pos)
        transform_mat = transform_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.x), {1, 0, 0})
        transform_mat = transform_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.y), {0, 1, 0})
        transform_mat = transform_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.z), {0, 0, 1})

    } else {

        transform_mat = linalg.matrix4_translate_f32(-pos)
        transform_mat = transform_mat * linalg.matrix4_rotate_f32(-linalg.to_radians(rot.x), {1, 0, 0})
        transform_mat = transform_mat * linalg.matrix4_rotate_f32(-linalg.to_radians(rot.y), {0, 1, 0})
        transform_mat = transform_mat * linalg.matrix4_rotate_f32(-linalg.to_radians(rot.z), {0, 0, 1})

    }

    return transform_mat

}

get_vert_data_size :: proc(vertices: []VertexData) -> int {
    return len(vertices) * size_of(VertexData)
}

get_index_data_size :: proc(indices: []u32) -> int {
    return len(indices) * size_of(u32)
}

get_tex_data_size :: proc(texture: Texture) -> int {
    return int(texture.size.x * texture.size.y * 4)
}

// Integration with scripting
set_render_camera :: proc(app: ^Application, render_cam: RenderCamera) {

    app.render_ctx.camera = render_cam;

}