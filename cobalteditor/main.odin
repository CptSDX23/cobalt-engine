package cobalteditor

import "core:fmt"
import "core:os"
import "core:strings"
import "../cbesdk"

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

    // Get project settings
    settings := cbesdk.load_settings_from_proj(user_proj_dir)

    // Build and run project
    copy_sdk_to_proj(settings.abs_proj_path)
    compile_proj_shaders(settings)
    build_and_run_proj(settings)

}