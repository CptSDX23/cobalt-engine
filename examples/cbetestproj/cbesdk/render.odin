package cbesdk

import sdl "vendor:sdl3"

RenderContext :: struct {
    window:   ^sdl.Window,
    gpu:      ^sdl.GPUDevice,
    pipeline: ^sdl.GPUGraphicsPipeline,
    shaders:  [dynamic]sdl.GPUShader,
}

// Defaults
create_render_ctx :: proc() -> RenderContext {
    
    ok       := sdl.Init({.VIDEO}); assert(ok, "Failed to initialize SDL3")
    window   := sdl.CreateWindow("Cobalt Engine Game", 1600, 1000, {}); assert(window != nil, "Failed to create window")
    gpu      := sdl.CreateGPUDevice({.SPIRV}, true, nil); assert(gpu != nil, "Failed to create GPU device")
    pipeline := sdl.CreateGPUGraphicsPipeline(gpu, {
        vertex_shader   = nil,
        fragment_shader = nil,
        primitive_type  = .TRIANGLELIST,
        target_info     = {
            num_color_targets = 1,
            color_target_descriptions = &sdl.GPUColorTargetDescription {
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
            },
        },
    })
    shaders := make([dynamic]sdl.GPUShader)
    //append(&shaders, #load("../target/vert_shader.spv.vert"))

    ok = sdl.ClaimWindowForGPUDevice(gpu, window); assert(ok, "Failed to claim window for GPU device")

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

load_shader :: proc(ctx: ^RenderContext, code: []u8, stage: sdl.GPUShaderStage) -> ^sdl.GPUShader {

    return sdl.CreateGPUShader(ctx.gpu, {
        code_size  = len(code),
        code       = raw_data(code),
        entrypoint = "main",
        format     = {.SPIRV},
        stage      = stage,
    })

}