package cobalteditor

import "core:fmt"
import "core:os"
import "core:strings"

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

compile_proj_shaders :: proc(settings: ProjectSettings) {

}