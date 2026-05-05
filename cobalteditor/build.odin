package cobalteditor

import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"
import "../cbesdk"

// Stuff for configuring projects and building them
copy_sdk_to_proj :: proc(user_proj_dir: string) {

    // Copy SDK to the project folder (windows)
    copy_cmd := os.Process_Desc{
        command = []string{"xcopy", CBESDK_DIR, strings.concatenate({user_proj_dir, "\\cbesdk"}), "/E", "/I", "/Y"},
    }
    state, stdout, stderr, err_p := os.process_exec(copy_cmd, context.allocator)
    if err_p != nil {
        fmt.eprintln("Error copying SDK to project folder:", err_p)
        return
    }

}

compile_proj_shaders :: proc(settings: cbesdk.ProjectSettings) {

    // Compile all shaders from settings
    for path in settings.shader_paths {

        file_ext := filepath.ext(path)
        
        // If the file is a .frag or .vert it will be compiled to target
        // .glsl and .spv really do nothing but denote whether its compiled or not
        if file_ext == ".frag" || file_ext == ".vert" {

            path_stripped := strings.split(path, "\\")[len(strings.split(path, "\\")) - 1]
            name_stripped := strings.split(path_stripped, ".")[0]
            shader_src    := strings.concatenate({"assets\\", path})
            shader_out    := strings.concatenate({"target\\assets\\", name_stripped, ".spv", file_ext})

            comp_shader_cmd := os.Process_Desc{
                working_dir = settings.abs_proj_path,
                command     = []string{"glslc", shader_src, "-o", shader_out},
            }
            state, stdout, stderr, err_p := os.process_exec(comp_shader_cmd, context.allocator)
            if err_p != nil {
                fmt.eprintln("Error building shaders:", err_p)
                return
            }

        }

    }

}

build_and_run_proj :: proc(settings: cbesdk.ProjectSettings) {

    main_depth      := len(strings.split(settings.odin_main_path, "\\"))
    main_path       := strings.concatenate({"assets\\", settings.odin_main_path})
    proj_path_end   := strings.split(settings.abs_proj_path, "\\")[len(strings.split(settings.abs_proj_path, "\\")) - 1]
    out_path        := strings.concatenate({"-out:target\\", proj_path_end, ".exe"})
    collection_path := strings.concatenate({"-collection:cobalt=", strings.repeat("..\\", main_depth)})
    abs_proj_path   := settings.abs_proj_path

    // Build and run user program
    build_cmd := os.Process_Desc{
        working_dir = settings.abs_proj_path,
        command     = []string{"odin", "run", main_path, collection_path, out_path, "--", abs_proj_path},
    }
    state, stdout, stderr, err_p := os.process_exec(build_cmd, context.allocator)
    if err_p != nil {
        fmt.eprintln("Error building project:", err_p)
        return
    }

    // This can get quite long if the app runs for a while,
    // should redirect this somewhere else soon
    fmt.print(string(stdout))

}