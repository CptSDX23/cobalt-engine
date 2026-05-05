package cbesdk

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

// Non absolute paths should be relative to /assets
ProjectSettings :: struct {
    abs_proj_path:  string,
    win_settings:   WindowSettings,
    odin_main_path: string,
    shader_paths:   [dynamic]string,
    scene_paths:    [dynamic]string,
}

load_settings_from_proj :: proc(proj_path: string) -> ProjectSettings {

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

        key   := strings.trim_space(split[0])
        value := strings.trim_space(split[1])

        // Possible settings featuring lazy parsing
        if key == "win_name" {
            settings.win_settings.name = strings.clone_to_cstring(value)
        }
        if key == "win_size_x" {
            val, ok := strconv.parse_int(value)
            settings.win_settings.size.x = i32(val)
        }
        if key == "win_size_y" {
            val, ok := strconv.parse_int(value)
            settings.win_settings.size.y = i32(val)
        }
        if key == "win_col_r" {
            val, ok := strconv.parse_f32(value)
            settings.win_settings.clear_col.r = val
        }
        if key == "win_col_g" {
            val, ok := strconv.parse_f32(value)
            settings.win_settings.clear_col.g = val
        }
        if key == "win_col_b" {
            val, ok := strconv.parse_f32(value)
            settings.win_settings.clear_col.b = val
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