package cobalteditor

import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"

// Constants for now, actually installing the engine later in
// developement will make this look different
CBESDK_DIR :: "..\\cbesdk"

main :: proc() {

    // Get project dir from user
    fmt.println("Enter a project absolute path (C:/path/to/proj/):")
    buf: [256]byte
    n, err_i := os.read(os.stdin, buf[:])
    if err_i != nil {
        fmt.eprintln("Error reading input:", err_i)
        return
    }

    user_proj_dir := strings.trim_space(string(buf[:n]))
    fmt.printfln("Using project folder '%v'", user_proj_dir)

    // Copy SDK to the project folder (windows)
    copy_cmd := os.Process_Desc{
        command = []string{"xcopy", CBESDK_DIR, strings.concatenate({user_proj_dir, "\\cbesdk"}), "/E", "/I", "/Y"},
    }
    state, stdout, stderr, err_p := os.process_exec(copy_cmd, context.allocator)
    if err_p != nil {
        fmt.eprintln("Error copying SDK to project folder:", err_p)
        return
    }

    // Compile all shaders in assets/shaders
    handle, err_so := os.open(strings.concatenate({user_proj_dir, "\\assets\\shaders"}))
    if err_so != os.ERROR_NONE {
        fmt.eprintln("Error opening shader directory:", err_so)
        return
    }
    defer os.close(handle)

    infos, err_sr := os.read_directory(handle, -1, context.allocator)
    if err_sr != 0 {
        fmt.eprintln("Error reading shader directory")
        return
    }
    defer delete(infos)

    // If the file is a .frag or .vert it will be compiled to target
    // .glsl and .spv really do nothing but denote whether its compiled or not
    for info in infos {

        file_ext := filepath.ext(info.name)
        
        if file_ext == ".frag" || file_ext == ".vert" {

            name_stripped := strings.split(info.name, ".")[0]
            shader_src    := strings.concatenate({"assets\\shaders\\", info.name})
            shader_out    := strings.concatenate({"target\\assets\\", name_stripped, ".spv", file_ext})

            comp_shader_cmd := os.Process_Desc{
                working_dir = user_proj_dir,
                command     = []string{"glslc", shader_src, "-o", shader_out},
            }
            state, stdout, stderr, err_p = os.process_exec(comp_shader_cmd, context.allocator)
            if err_p != nil {
                fmt.eprintln("Error building shaders:", err_p)
                return
            }

        }

    }

    // Build and run user program
    build_cmd := os.Process_Desc{
        working_dir = user_proj_dir,
        command     = []string{"odin", "run", "assets/src/", "-collection:cobalt=../../", "-out:target/cbe.exe"},
    }
    state, stdout, stderr, err_p = os.process_exec(build_cmd, context.allocator)
    if err_p != nil {
        fmt.eprintln("Error building project:", err_p)
        return
    }

    // This can get quite long if the app runs for a while,
    // should redirect this somewhere else soon
    fmt.print(string(stdout))

}