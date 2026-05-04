package cbesdk

import "core:fmt"
import "core:os"
import "core:math/linalg"
import sdl "vendor:sdl3"

RenderContext :: struct {
    window:   ^sdl.Window,
    gpu:      ^sdl.GPUDevice,
    pipeline: ^sdl.GPUGraphicsPipeline,
    shaders:  [dynamic]^sdl.GPUShader,
}

UBO :: struct {
    mvp: matrix[4,4]f32,
}

// Defaults
create_render_ctx :: proc() -> RenderContext {
    
    ok     := sdl.Init({.VIDEO}); assert(ok, "Failed to initialize SDL3")
    window := sdl.CreateWindow("Cobalt Engine Game", 1600, 1000, {}); assert(window != nil, "Failed to create window")
    gpu    := sdl.CreateGPUDevice({.SPIRV}, true, nil); assert(gpu != nil, "Failed to create GPU device")

    // This should have been up here a long time ago i wasted so much time
    ok = sdl.ClaimWindowForGPUDevice(gpu, window); assert(ok, "Failed to claim window for GPU device")

    // Load all shaders to create pipeline
    shaders := make([dynamic]^sdl.GPUShader)
    load_all_shaders(gpu, &shaders)

    // Shader offsets hardcoded for now
    pipeline := sdl.CreateGPUGraphicsPipeline(gpu, {
        vertex_shader      = shaders[0],
        fragment_shader    = shaders[1],
        primitive_type     = .TRIANGLELIST,
        vertex_input_state = {
            num_vertex_buffers         = 1,
            vertex_buffer_descriptions = &sdl.GPUVertexBufferDescription {
                slot  = 0,
                pitch = size_of(Vector3f)
            },
            num_vertex_attributes = 1,
            vertex_attributes     = raw_data([]sdl.GPUVertexAttribute {
                { location = 0, format = .FLOAT3, offset = 0 },
            }),
        },
        target_info        = {
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
        model_mat := create_model_matrix({0, 0, 1}, {0, 45, 0})
        ubo       := UBO { mvp = proj_mat * model_mat }

        // Create vertex buffer
        vertices := []Vector3f {
            {-0.5, -0.5, 0},
            {   0,  0.5, 0},
            { 0.5, -0.5, 0},
        }

        vertex_buf := sdl.CreateGPUBuffer(ctx.gpu, {
            usage = {.VERTEX},
            size  = u32(len(vertices) * size_of(Vector3f)),
        })

        // Passes
        color_target := sdl.GPUColorTargetInfo {
            texture     = swapchain,
            load_op     = .CLEAR,
            clear_color = {0, 0.3, 0.6, 1},
            store_op    = .STORE,
        }
        render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)

        // Draw commands
        sdl.BindGPUGraphicsPipeline(render_pass, ctx.pipeline)
        sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding { buffer = vertex_buf }, 1)
        sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))
        sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)

        sdl.EndGPURenderPass(render_pass)

        // Display
        ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok, "Failed to submit command buffer")

        return false

    }

}

// Scans target directory for .spv files
load_all_shaders :: proc(gpu: ^sdl.GPUDevice, shaders: ^[dynamic]^sdl.GPUShader) {

    // Hardcoded for now
    // Also doesnt work for now ill figure it out later
    vert_code, err_v := os.read_entire_file("target/vert_shader.spv.vert", context.allocator)
    if err_v != nil {
        fmt.printfln("Failed to load vert shader from compiled file: %v", err_v)
        return
    }
    append(shaders, load_shader(gpu, vert_code, .VERTEX, 1))


    frag_code, err_f := os.read_entire_file("target/frag_shader.spv.frag", context.allocator)
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

create_model_matrix :: proc(pos: [3]f32, rot: [3]f32) -> matrix[4,4]f32 {

    model_mat: matrix[4,4]f32

    model_mat = linalg.matrix4_translate_f32(pos)
    model_mat = model_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.x), {1, 0, 0})
    model_mat = model_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.y), {0, 1, 0})
    model_mat = model_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.z), {0, 0, 1})

    return model_mat

}