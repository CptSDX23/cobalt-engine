#+feature dynamic-literals

package cbesdk

import "core:debug/trace"
import "core:fmt"
import "core:strings"
import im "shared:imgui"

DockSpace :: struct {
    dock_type:    DockType,
    split_type:   SplitType,
    split_pos:    f32,
    first_child:  ^DockSpace,
    second_child: ^DockSpace,
    content:      DockContent,
}

DockContent :: struct {
    render: proc(draw_list: ^im.DrawList, app: ^Application, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA),
}

DockButton :: struct {
    size:   Vector2f,
    pos:    Vector2f,
    text:   string,
    render: proc(draw_list: ^im.DrawList, start: Vector2f, end: Vector2f, text: string, colors: map[ThemeColor]ColorRGBA),
}

// Variables so docks can communicate
DockVariable :: struct {
    name:  string,
    value: string,
}
dock_vars: [dynamic]^DockVariable

// Types
DockType :: enum {
    Blank,
    Split,
    Content,
}
SplitType :: enum {
    XTop,
    YTop,
    XBottom,
    YBottom,
}
ChildType :: enum {
    First,
    Second,
}
ThemeColor :: enum {
    Accent,
    AccentHover,
    Foreground,
    Highlight,
    Background,
    Text,
    TextDisabled,
}

// Themes
// Default
DARK_THEME := map[ThemeColor]ColorRGBA {
    .Accent       = {0, 0.2, 0.5, 1},
    .AccentHover  = {0.1, 0.3, 0.6, 1},
    .Foreground   = {0.085, 0.085, 0.085, 1},
    .Highlight    = {0.115, 0.115, 0.115, 1},
    .Background   = {0.075, 0.075, 0.075, 1},
    .Text         = {1, 1, 1, 1},
    .TextDisabled = {0.3, 0.3, 0.3, 0.3},
}
// Evil
LIGHT_THEME := map[ThemeColor]ColorRGBA {
    .Accent       = {0, 0.2, 0.5, 1},
    .AccentHover  = {0.1, 0.3, 0.6, 1},
    .Foreground   = {0.875, 0.875, 0.875, 1},
    .Highlight    = {0.8, 0.8, 0.8, 1},
    .Background   = {0.9, 0.9, 0.9, 1},
    .Text         = {0, 0, 0, 1},
    .TextDisabled = {0.5, 0.5, 0.5, 1},
}
// // Odd
// SILVER_THEME := map[ThemeColor]ColorRGBA {
//     .Accent     = {0, 0.2, 0.5, 1},
//     .Foreground = {0.475, 0.475, 0.475, 1},
//     .Background = {0.45, 0.45, 0.45, 1},
//     .Text       = {1, 1, 1, 1},
// }
// // Cool
// OCEAN_THEME := map[ThemeColor]ColorRGBA {
//     .Accent     = {0.1, 0.2, 0.35, 1},
//     .Foreground = {0.35, 0.45, 0.475, 1},
//     .Background = {0.35, 0.425, 0.45, 1},
//     .Text       = {1, 1, 1, 1},
// }

// Dock content types
TITLE_BAR_CONTENT :: DockContent {
    render = proc(draw_list: ^im.DrawList, app: ^Application, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA) {
        
        im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Accent]))

        total_w      := f32(0)
        file_btn     := create_header_text_button(32, {40 + total_w, 0}, "File");      total_w += file_btn.size.x
        edit_btn     := create_header_text_button(32, {40 + total_w, 0}, "Edit");      total_w += edit_btn.size.x
        scene_btn    := create_header_text_button(32, {40 + total_w, 0}, "Scene");     total_w += scene_btn.size.x
        assets_btn   := create_header_text_button(32, {40 + total_w, 0}, "Assets");    total_w += assets_btn.size.x
        window_btn   := create_header_text_button(32, {40 + total_w, 0}, "Window");    total_w += window_btn.size.x
        build_btn    := create_header_text_button(32, {40 + total_w, 0}, "Build");     total_w += build_btn.size.x
        settings_btn := create_header_text_button(32, {40 + total_w, 0}, "Settings");  total_w += settings_btn.size.x

        // Draw
        render_button(draw_list, file_btn, colors)
        render_button(draw_list, edit_btn, colors)
        render_button(draw_list, scene_btn, colors)
        render_button(draw_list, assets_btn, colors)
        render_button(draw_list, window_btn, colors)
        render_button(draw_list, build_btn, colors)
        render_button(draw_list, settings_btn, colors)

        // Menus
        if is_button_clicked(file_btn) {
            fmt.println("File Clicked")
        }

    }
}

STATUS_BAR_CONTENT :: DockContent {
    render = proc(draw_list: ^im.DrawList, app: ^Application, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA) {

        version_text   := strings.clone_to_cstring(strings.concatenate({"Cobalt Engine ", current_version()}))
        proj_path_text := strings.split(app.settings.abs_proj_path, "\\")[len(strings.split(app.settings.abs_proj_path, "\\")) - 1]

        im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Foreground]))
        im.DrawList_AddText(draw_list, start + {8, 2}, im.ColorConvertFloat4ToU32(colors[.TextDisabled]), version_text)
        im.DrawList_AddText(draw_list, start + {200, 2}, im.ColorConvertFloat4ToU32(colors[.TextDisabled]), strings.clone_to_cstring(proj_path_text))
        im.DrawList_AddText(draw_list, {end.x - 125, start.y + 2}, im.ColorConvertFloat4ToU32(colors[.TextDisabled]), "No Tasks Running")

    }
}

INSPECTOR_TAB_CONTENT :: DockContent {
    render = proc(draw_list: ^im.DrawList, app: ^Application, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA) {

        text_size := im.CalcTextSize(strings.clone_to_cstring("Inspector")).x + 14

        im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Background]))
        im.DrawList_AddRectFilled(draw_list, start + {4, 28}, end - {4, 4}, im.ColorConvertFloat4ToU32(colors[.Foreground]))
        im.DrawList_AddRectFilled(draw_list, start + {4, 4}, start + {text_size, 28}, im.ColorConvertFloat4ToU32(colors[.Foreground]))

        im.DrawList_AddText(draw_list, start + {8, 8}, im.ColorConvertFloat4ToU32(colors[.Text]), "Inspector")

    }
}

ASSETS_TAB_CONTENT :: DockContent {
    render = proc(draw_list: ^im.DrawList, app: ^Application, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA) {

        text_size := im.CalcTextSize(strings.clone_to_cstring("Assets")).x + 14

        im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Background]))
        im.DrawList_AddRectFilled(draw_list, start + {4, 28}, end - {4, 4}, im.ColorConvertFloat4ToU32(colors[.Foreground]))
        im.DrawList_AddRectFilled(draw_list, start + {4, 4}, start + {text_size, 28}, im.ColorConvertFloat4ToU32(colors[.Foreground]))

        im.DrawList_AddText(draw_list, start + {8, 8}, im.ColorConvertFloat4ToU32(colors[.Text]), "Assets")

    }
}

SCENE_TAB_CONTENT :: DockContent {
    render = proc(draw_list: ^im.DrawList, app: ^Application, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA) {

        text_size := im.CalcTextSize(strings.clone_to_cstring("Scene")).x + 14

        im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Background]))
        im.DrawList_AddRectFilled(draw_list, start + {4, 28}, end - {4, 4}, im.ColorConvertFloat4ToU32(colors[.Foreground]))
        im.DrawList_AddRectFilled(draw_list, start + {4, 4}, start + {text_size, 28}, im.ColorConvertFloat4ToU32(colors[.Foreground]))

        im.DrawList_AddText(draw_list, start + {8, 8}, im.ColorConvertFloat4ToU32(colors[.Text]), "Scene")

        entities := app.scene.entities
        for entity, i in entities {
            btn := create_bar_text_button({end.x - start.x - 16, 24}, {8, f32(64 + (i * 24))}, entity.name);
            render_button(draw_list, btn, colors)
        }

    }
}

// UI
draw_ui :: proc(app: ^Application) {

    io         := im.GetIO()
    screen_dim := [2]f32{io.DisplaySize.x, io.DisplaySize.y}
    draw_list  := im.GetBackgroundDrawList()

    // Default docking
    size := f32(1)
    fs_dock := create_dock()
    split_blank_dock(fs_dock, TITLE_BAR_CONTENT, .First, .XTop, 32)
    split_blank_dock(fs_dock.second_child, STATUS_BAR_CONTENT, .Second, .XBottom, 20)
    split_blank_dock(fs_dock.second_child.first_child, INSPECTOR_TAB_CONTENT, .Second, .YBottom, 400 * size)
    split_blank_dock(fs_dock.second_child.first_child.first_child, ASSETS_TAB_CONTENT, .Second, .XBottom, 300 * size)
    split_blank_dock(fs_dock.second_child.first_child.first_child.first_child, SCENE_TAB_CONTENT, .First, .YTop, 300 * size)

    draw_dock(fs_dock, draw_list, app, {0, 0}, screen_dim)

}

// On the heap
create_dock :: proc() -> ^DockSpace {
    
    dock := new(DockSpace)
    return dock

}
create_dock_with_content :: proc(content: DockContent) -> ^DockSpace {
    
    dock := new(DockSpace)
    dock.dock_type = .Content
    dock.content   = content
    return dock

}

// Recurse throught a dock to draw it
draw_dock :: proc(dock: ^DockSpace, draw_list: ^im.DrawList, app: ^Application, start: Vector2f, end: Vector2f) {

    if dock.dock_type == .Blank {
        // Nothing to do
    }
    if dock.dock_type == .Content {

        // Draw the content
        dock.content.render(draw_list, app, start, end, DARK_THEME)

    }
    if dock.dock_type == .Split {

        // Draw the two children
        if dock.split_type == .XTop {
            draw_dock(dock.first_child, draw_list, app, start, {end.x, start.y + dock.split_pos})
            draw_dock(dock.second_child, draw_list, app, {start.x, start.y + dock.split_pos}, end)
        }
        if dock.split_type == .YTop {
            draw_dock(dock.first_child, draw_list, app, start, {start.x + dock.split_pos, end.y})
            draw_dock(dock.second_child, draw_list, app, {start.x + dock.split_pos, start.y}, end)
        }
        if dock.split_type == .XBottom {
            draw_dock(dock.first_child, draw_list, app, start, {end.x, end.y - dock.split_pos})
            draw_dock(dock.second_child, draw_list, app, {start.x, end.y - dock.split_pos}, end)
        }
        if dock.split_type == .YBottom {
            draw_dock(dock.first_child, draw_list, app, start, {end.x - dock.split_pos, end.y})
            draw_dock(dock.second_child, draw_list, app, {end.x - dock.split_pos, start.y}, end)
        }

    }

}

// Turns blank docks into split content docks
split_blank_dock :: proc(parent: ^DockSpace, content: DockContent, child: ChildType, split: SplitType, pos: f32) {

    parent.dock_type  = .Split
    parent.split_type = split
    parent.split_pos  = pos
    
    if child == .First {
        parent.first_child  = create_dock_with_content(content)
        parent.second_child = create_dock()
    } else {
        parent.first_child  = create_dock()
        parent.second_child = create_dock_with_content(content)
    }

}

// Mouse detection
detect_mouse :: proc(start: Vector2f, end: Vector2f) -> bool {
    
    pos := im.GetMousePos()

    if (pos.x >= start.x && pos.x <= end.x && pos.y >= start.y && pos.y <= end.y) {
        return true
    } else {
        return false
    }

}

// Makes a header button with text
create_header_text_button :: proc(height: f32, pos: Vector2f, text: string) -> DockButton {

    return DockButton {
        size   = {im.CalcTextSize(strings.clone_to_cstring(text)).x + 20, height},
        pos    = pos,
        text   = text,
        render = proc(draw_list: ^im.DrawList, start: Vector2f, end: Vector2f, text: string, colors: map[ThemeColor]ColorRGBA) {

            end_pos := Vector2f {start.x + im.CalcTextSize(strings.clone_to_cstring(text)).x + 20, end.y}

            if detect_mouse(start, end_pos) {
                im.DrawList_AddRectFilled(draw_list, start, end_pos, im.ColorConvertFloat4ToU32(colors[.AccentHover]))
            } else {
                im.DrawList_AddRectFilled(draw_list, start, end_pos, im.ColorConvertFloat4ToU32(colors[.Accent]))
            }

            im.DrawList_AddText(draw_list, start + {10, 9}, im.ColorConvertFloat4ToU32(colors[.Text]), strings.clone_to_cstring(text))

        },
    }

}

// Makes a bar button with text
create_bar_text_button :: proc(size: Vector2f, pos: Vector2f, text: string) -> DockButton {

    return DockButton {
        size   = size,
        pos    = pos,
        text   = text,
        render = proc(draw_list: ^im.DrawList, start: Vector2f, end: Vector2f, text: string, colors: map[ThemeColor]ColorRGBA) {

            if detect_mouse(start, end) {
                im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Highlight]))
            } else {
                im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Foreground]))
            }

            im.DrawList_AddText(draw_list, start + {4, (end.y - start.y) / 2 - 6}, im.ColorConvertFloat4ToU32(colors[.Text]), strings.clone_to_cstring(text))

        },
    }
}

render_button :: proc(draw_list: ^im.DrawList, button: DockButton, colors: map[ThemeColor]ColorRGBA) {

    button.render(draw_list, button.pos, button.pos + button.size, button.text, colors)

}

is_button_clicked :: proc(button: DockButton) -> bool {

    return detect_mouse(button.pos, button.pos + button.size) && im.IsMouseClicked(.Left)

}