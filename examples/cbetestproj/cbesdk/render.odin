package cbesdk

import "core:fmt"
import "core:os"
import sdl "vendor:sdl3"

RenderContext :: struct {
    window:   ^sdl.Window,
    gpu:      ^sdl.GPUDevice,
    pipeline: ^sdl.GPUGraphicsPipeline,
    shaders:  [dynamic]sdl.GPUShader,
}

// Defaults
create_render_ctx :: proc() -> RenderContext {
    
    ok     := sdl.Init({.VIDEO}); assert(ok, "Failed to initialize SDL3")
    window := sdl.CreateWindow("Cobalt Engine Game", 1600, 1000, {}); assert(window != nil, "Failed to create window")
    gpu    := sdl.CreateGPUDevice({.SPIRV}, true, nil); assert(gpu != nil, "Failed to create GPU device")

    // This should have been up here a long time ago i wasted so much time
    ok = sdl.ClaimWindowForGPUDevice(gpu, window); assert(ok, "Failed to claim window for GPU device")

    // Load all shaders to create pipeline
    shaders := make([dynamic]sdl.GPUShader)
    
    vert_code, err_v := os.read_entire_file("target/vert_shader.spv.vert", context.allocator)
    if err_v != nil {
        fmt.printfln("Failed to load vert shader from compiled file: %v", err_v)
    }
    vert_shader := load_shader(gpu, vert_code, .VERTEX)

    frag_code, err_f := os.read_entire_file("target/frag_shader.spv.frag", context.allocator)
    if err_f != nil {
        fmt.printfln("Failed to load frag shader from compiled file: %v", err_f)
    }
    frag_shader := load_shader(gpu, frag_code, .FRAGMENT)

    // Shader offsets hardcoded for now
    pipeline := sdl.CreateGPUGraphicsPipeline(gpu, {
        vertex_shader   = vert_shader,
        fragment_shader = frag_shader,
        primitive_type  = .TRIANGLELIST,
        target_info     = {
            num_color_targets = 1,
            color_target_descriptions = &(sdl.GPUColorTargetDescription {
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
            }),
        },
    })

    return RenderContext { window = window, gpu = gpu }

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

        // Passes
        color_target := sdl.GPUColorTargetInfo {
            texture     = swapchain,
            load_op     = .CLEAR,
            clear_color = {0, 0.2, 0.4, 1},
            store_op    = .STORE,
        }
        render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)

        // Draw commands
        // to do

        sdl.EndGPURenderPass(render_pass)

        // Display
        ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok, "Failed to submit command buffer")

        return false

    }

}

// Scans target directory for .spv files
load_all_shaders :: proc(gpu: ^sdl.GPUDevice, shaders: ^[dynamic]sdl.GPUShader) {

    // Hardcoded for now
    // Also doesnt work for now ill figure it out later
    vert_code, err_v := os.read_entire_file("target/vert_shader.spv.vert", context.allocator)
    if err_v != nil {
        fmt.printfln("Failed to load vert shader from compiled file: %v", err_v)
        return
    }
    //append(shaders, load_shader(gpu, vert_code, .VERTEX))


    frag_code, err_f := os.read_entire_file("target/frag_shader.spv.frag", context.allocator)
    if err_f != nil {
        fmt.printfln("Failed to load frag shader from compiled file: %v", err_f)
        return
    }
    //append(shaders, load_shader(gpu, frag_code, .FRAGMENT))

}

load_shader :: proc(gpu: ^sdl.GPUDevice, code: []u8, stage: sdl.GPUShaderStage) -> ^sdl.GPUShader {

    return sdl.CreateGPUShader(gpu, {
        code_size  = len(code),
        code       = raw_data(code),
        entrypoint = "main",
        format     = {.SPIRV},
        stage      = stage,
    })

}