package cobalteditor

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "../cbesdk"

ProjectSettings :: struct {
    abs_proj_path:  string,
    win_settings:   cbesdk.WindowSettings,
    odin_main_path: string,
    shader_paths:   [dynamic]string,
    scene_paths:    [dynamic]string,
}

load_settings_from_file :: proc(proj_path: string) -> ProjectSettings {

    // Because some things may be missing
    settings := ProjectSettings {
        abs_proj_path = proj_path,
    }

    // Read file
    data, err := os.read_entire_file(strings.concatenate({proj_path, "\\.cbesettings"}), context.allocator)
    
    if err != nil {
        fmt.println("Failed to read project settings file")
        return settings
    }

    // Key value pairs split by line
    lines := string(data)
	for line in strings.split_lines_iterator(&lines) {
        
        // Lazy error checking
        split := strings.split(line, ":")
        if (len(split) != 2) {
            continue
        }

        key   := split[0]
        value := split[1]

        // Possible settings
        if key == "win_name" {
            settings.win_settings.name = strings.clone_to_cstring(value)
        }
        if key == "win_size_x" {
            settings.win_settings.size.x = i32(strconv.atoi(value))
        }
        if key == "win_size_y" {
            settings.win_settings.size.y = i32(strconv.atoi(value))
        }
        if key == "win_col_r" {
            settings.win_settings.clear_col.r = f32(strconv.atof(value))
        }
        if key == "win_col_g" {
            settings.win_settings.clear_col.g = f32(strconv.atof(value))
        }
        if key == "win_col_b" {
            settings.win_settings.clear_col.b = f32(strconv.atof(value))
        }
        if key == "odin_main_path" {
            settings.odin_main_path = value
        }
        if key == "shader_path_entry" {
            append(&settings.shader_paths, value)
        }
        if key == "scene_path_entry" {
            append(&settings.shader_paths, value)
        }

	}

    return settings

}