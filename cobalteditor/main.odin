package cobalteditor

import "core:fmt"
import "core:os"
import "core:strings"

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

    // Build and run user program
    build_cmd := os.Process_Desc{
        working_dir = user_proj_dir,
        command     = []string{"odin", "run", "assets/src/", "-collection:cobalt=../../", "-out:cbesdk/cbe.exe"},
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