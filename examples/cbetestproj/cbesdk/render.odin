package cbesdk

import "core:fmt"
import "core:os"
import "core:mem"
import "core:math/linalg"

import sdl    "vendor:sdl3"
import stbi   "vendor:stb/image"
import im     "shared:imgui"
import im_sdl "shared:imgui/imgui_impl_sdl3"
import im_gpu "shared:imgui/imgui_impl_sdlgpu3"

// Structs
RenderContext :: struct {
    window:     ^sdl.Window,
    gpu:        ^sdl.GPUDevice,
    pipeline:   ^sdl.GPUGraphicsPipeline,
    depth_tex:  ^sdl.GPUTexture,
    shaders:    [dynamic]^sdl.GPUShader,
    models:     [dynamic]Model,
    camera:     RenderCamera,
    settings:   WindowSettings,
}

WindowSettings :: struct {
    name:      cstring,
    size:      Vector2i,
    clear_col: [4]f32,
}

ProjUBO :: struct {
    view_proj_mat: matrix[4,4]f32,
    model_mat:     matrix[4,4]f32,
    normal_mat:    matrix[4,4]f32,
}

// Must be packed in this order so that shader will work
LightUBO :: struct {
    light_color:     Vector3f,
    light_intensity: f32,
    light_position:  Vector3f,
    light_ambient:   f32,
    cam_position:    Vector3f,
}

MaterialUBO :: struct {
    diffuse_color:  Vector3f,
    shininess:      f32,
    specular_color: Vector3f,
}

VertexData :: struct {
    pos:    Vector3f,
    col:    sdl.FColor,
    uv:     Vector2f,
    normal: Vector3f,
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
    forward:         Vector3f,
}

// Defaults
create_render_ctx :: proc(win_settings: WindowSettings) -> (RenderContext, FPSState) {
    
    ok     := sdl.Init({.VIDEO}); assert(ok, "Failed to initialize SDL3")
    window := sdl.CreateWindow(win_settings.name, win_settings.size.x, win_settings.size.y, {.RESIZABLE, .BORDERLESS, .MAXIMIZED}); assert(window != nil, "Failed to create window")
    gpu    := sdl.CreateGPUDevice({.SPIRV}, true, nil); assert(gpu != nil, "Failed to create GPU device")

    // This should have been up here a long time ago i wasted so much time
    ok = sdl.ClaimWindowForGPUDevice(gpu, window); assert(ok, "Failed to claim window for GPU device")
    //ok = sdl.SetWindowRelativeMouseMode(window, true); assert(ok, "Failed to lock mouse to window")

    // Load all shaders to create pipeline
    shaders := make([dynamic]^sdl.GPUShader)
    load_all_shaders(gpu, &shaders)

    // Load models
    models := make([dynamic]Model)

    // Camera (defaults)
    cam := RenderCamera {
        position        = {0, 0, 0},
        rotation        = {0, 0, 0},
        fov             = 60,
        clipping_planes = {0.01, 100}
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
            num_vertex_attributes = 4,
            vertex_attributes     = raw_data([]sdl.GPUVertexAttribute {
                { location = 0, format = .FLOAT3, offset = u32(offset_of(VertexData, pos)) },
                { location = 1, format = .FLOAT4, offset = u32(offset_of(VertexData, col)) },
                { location = 2, format = .FLOAT2, offset = u32(offset_of(VertexData, uv)) },
                { location = 3, format = .FLOAT3, offset = u32(offset_of(VertexData, normal)) },
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
        rasterizer_state = {
            front_face = .CLOCKWISE,
            cull_mode  = .BACK,
        }
    })

    // Init ImGUI
    im.CHECKVERSION()
    im.CreateContext()
    im_sdl.InitForSDLGPU(window)
    im_gpu.Init(&{
        Device            = gpu,
        ColorTargetFormat = sdl.GetGPUSwapchainTextureFormat(gpu, window),
    })
    //set_ui_style()

    // Now ready to start drawing
    return RenderContext { 
        window     = window, 
        gpu        = gpu, 
        pipeline   = pipeline, 
        depth_tex  = depth_tex,
        shaders    = shaders,
        models     = models,
        camera     = cam,
        settings   = win_settings,
    }, FPSState { last_ticks = sdl.GetTicks(), curr_ticks = sdl.GetTicks() }

}

// The boolean indicates whether the application should exit
run_render :: proc(ctx: RenderContext, input: ^InputState, fps_state: ^FPSState, app: ^Application) -> bool {

        // Stupid reset
        set_mouse_delta(input, {0, 0})

        // Events
        event: sdl.Event
        for sdl.PollEvent(&event) {

            im_sdl.ProcessEvent(&event)

            #partial switch event.type {
                case .QUIT:
                    return true
                case .WINDOW_RESIZED:
                    win_size: [2]i32
                    ok := sdl.GetWindowSize(ctx.window, &win_size.x, &win_size.y); assert(ok, "Failed to get window size")

                case .KEY_DOWN:
                    set_key_down(input, event.key.scancode)
                case .KEY_UP:
                    set_key_up(input, event.key.scancode)
                case .MOUSE_MOTION:
                    set_mouse_delta(input, {event.motion.xrel, event.motion.yrel})
                case .MOUSE_BUTTON_DOWN:
                    set_mouse_down(input, event.button.button)
                case .MOUSE_BUTTON_UP:
                    set_mouse_up(input, event.button.button)
            }

        }

        // FPS
        fps_state.last_ticks = fps_state.curr_ticks
        fps_state.curr_ticks = sdl.GetTicks()

        // ImGUI
        //io := im.GetIO()
        //im.FontAtlas_AddFontDefault(io.Fonts, &im.FontConfig { SizePixels = 16, RasterizerDensity = 1 })
        im_gpu.NewFrame()
        im_sdl.NewFrame()
        im.NewFrame()
        draw_ui(app)

        // Render
        cmd_buf   := sdl.AcquireGPUCommandBuffer(ctx.gpu)
        swapchain :  ^sdl.GPUTexture
        ok := sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, ctx.window, &swapchain, nil, nil); assert(ok, "Failed to aquire swapchain texture")

        im.Render()
        im_data := im.GetDrawData()

        // For when window is minimized
        if (swapchain == nil) {
            return false
        }

        // Get projection and view matrix
        win_size: [2]i32
        ok = sdl.GetWindowSize(ctx.window, &win_size.x, &win_size.y); assert(ok, "Failed to get window size for projection matrix")

        // Z+ is away from the camera i dont want to hear about it
        // Also look_at for the camera is confusing and took me a while to get
        proj_mat := linalg.matrix4_perspective_f32(linalg.to_radians(ctx.camera.fov), f32(win_size.x) / f32(win_size.y), ctx.camera.clipping_planes.x, ctx.camera.clipping_planes.y, false)
        view_mat := linalg.matrix4_look_at_f32(ctx.camera.position, ctx.camera.position + ctx.camera.forward, {0, 1, 0})

        // Light uniform buffer
        lights := LightUBO {
            light_color     = {1, 1, 1},
            light_intensity = 1,
            light_position  = {0, 10, 60},
            light_ambient   = 0.05,
            cam_position    = ctx.camera.position,
        }
        sdl.PushGPUFragmentUniformData(cmd_buf, 0, &lights, size_of(lights))

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
        sdl.BindGPUGraphicsPipeline(render_pass, ctx.pipeline)

        // Draw commands
        for model in ctx.models {

            model_mat := create_transform_matrix(model.position, model.rotation, model.scale)
            projs     := ProjUBO {
                view_proj_mat = proj_mat * view_mat, 
                model_mat     = model_mat,
                normal_mat    = linalg.inverse_transpose(model_mat),
            }
            material := model.material

            sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding { buffer = model.buffers.vertex_buf }, 1)
            sdl.BindGPUIndexBuffer(render_pass, { buffer = model.buffers.index_buf }, ._32BIT)
            sdl.PushGPUVertexUniformData(cmd_buf, 0, &projs, size_of(projs))
            sdl.PushGPUFragmentUniformData(cmd_buf, 1, &material, size_of(material))
            sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding {
                texture = model.texture.tex,
                sampler = model.texture.sampler,
            }, 1)
            sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(model.mesh.verts)), 1, 0, 0, 0)

        }

        sdl.EndGPURenderPass(render_pass)

        // ImGUI pas
        im_color_target := sdl.GPUColorTargetInfo {
            texture  = swapchain,
            load_op  = .LOAD,
            store_op = .STORE,
        }
        im_gpu.PrepareDrawData(im_data, cmd_buf)
        im_render_pass := sdl.BeginGPURenderPass(cmd_buf, &im_color_target, 1, nil)
        im_gpu.RenderDrawData(im_data, cmd_buf, render_pass)
        sdl.EndGPURenderPass(im_render_pass)

        // Display
        ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok, "Failed to submit command buffer")

        return false

}

// Scans target directory for .spv files
load_all_shaders :: proc(gpu: ^sdl.GPUDevice, shaders: ^[dynamic]^sdl.GPUShader) {

    // Hardcoded for now, this is bad because of no reflection and god why did i spend so
    // long remembering i had to change the number of ubos
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
    append(shaders, load_shader(gpu, frag_code, .FRAGMENT, 2, 1))

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
    stbi.set_flip_vertically_on_load(flip)
    pixels := stbi.load(path, &img_size.x, &img_size.y, nil, 4); assert(pixels != nil, "Failed to load texture")
    if (pixels == nil) {
        fmt.println("Failed to load pixels from image")
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

create_transform_matrix :: proc(pos: Vector3f, rot: Vector3f, scale: Vector3f) -> matrix[4,4]f32 {

    transform_mat: matrix[4,4]f32

    transform_mat = linalg.matrix4_translate_f32(pos)
    transform_mat = transform_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.x), {1, 0, 0})
    transform_mat = transform_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.y), {0, 1, 0})
    transform_mat = transform_mat * linalg.matrix4_rotate_f32(linalg.to_radians(rot.z), {0, 0, 1})
    transform_mat = transform_mat * linalg.matrix4_scale_f32(scale)

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

add_model :: proc(ctx: ^RenderContext, model: Model) {
    append(&ctx.models, model)
}

set_model :: proc(ctx: ^RenderContext, model: Model, index: i32) {
    ctx.models[index] = model
}