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
    user_proj_dir = strings.concatenate({user_proj_dir, "\\cbeskd"})

    // Copy SDK to the project folder (windows)
    desc := os.Process_Desc{
        command = []string{"xcopy", CBESDK_DIR, user_proj_dir, "/E", "/I"},
    }

    // Start the process
    state, stdout, stderr, err_p := os.process_exec(desc, context.allocator)
    if err_p != nil {
        fmt.eprintln("Error copying SDK to project folder:", err_p)
        return
    }

}