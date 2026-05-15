#+feature dynamic-literals

package cbesdk

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
    render: proc(draw_list: ^im.DrawList, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA),
}

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
    Foreground,
    Background,
    Text,
    TextDisabled,
}

// Themes
// Default
DARK_THEME := map[ThemeColor]ColorRGBA {
    .Accent       = {0, 0.2, 0.5, 1},
    .Foreground   = {0.085, 0.085, 0.085, 1},
    .Background   = {0.075, 0.075, 0.075, 1},
    .Text         = {1, 1, 1, 1},
    .TextDisabled = {0.3, 0.3, 0.3, 0.3},
}
// Evil
LIGHT_THEME := map[ThemeColor]ColorRGBA {
    .Accent       = {0, 0.2, 0.5, 1},
    .Foreground   = {0.875, 0.875, 0.875, 1},
    .Background   = {0.9, 0.9, 0.9, 1},
    .Text         = {0, 0, 0, 0},
    .TextDisabled = {0.5, 0.5, 0.5, 0.5},
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
    render = proc(draw_list: ^im.DrawList, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA) {

        im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Accent]))

        im.DrawList_AddText(draw_list, start + {50, 9}, im.ColorConvertFloat4ToU32(colors[.Text]), "File")
        im.DrawList_AddText(draw_list, start + {100, 9}, im.ColorConvertFloat4ToU32(colors[.Text]), "Edit")
        im.DrawList_AddText(draw_list, start + {150, 9}, im.ColorConvertFloat4ToU32(colors[.Text]), "Scene")
        im.DrawList_AddText(draw_list, start + {210, 9}, im.ColorConvertFloat4ToU32(colors[.Text]), "Assets")
        im.DrawList_AddText(draw_list, start + {275, 9}, im.ColorConvertFloat4ToU32(colors[.Text]), "Window")
        im.DrawList_AddText(draw_list, start + {340, 9}, im.ColorConvertFloat4ToU32(colors[.Text]), "Settings")
    }
}

STATUS_BAR_CONTENT :: DockContent {
    render = proc(draw_list: ^im.DrawList, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA) {

        version_text := strings.clone_to_cstring(strings.concatenate({"Cobalt Engine ", current_version()}))

        im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Foreground]))
        im.DrawList_AddText(draw_list, start + {8, 2}, im.ColorConvertFloat4ToU32(colors[.TextDisabled]), version_text)
        im.DrawList_AddText(draw_list, start + {200, 2}, im.ColorConvertFloat4ToU32(colors[.TextDisabled]), "cbetestproj")
        im.DrawList_AddText(draw_list, {end.x - 125, start.y + 2}, im.ColorConvertFloat4ToU32(colors[.TextDisabled]), "No Tasks Running")

    }
}

TAB_CONTENT :: DockContent {
    render = proc(draw_list: ^im.DrawList, start: Vector2f, end: Vector2f, colors: map[ThemeColor]ColorRGBA) {

        im.DrawList_AddRectFilled(draw_list, start, end, im.ColorConvertFloat4ToU32(colors[.Background]))
        im.DrawList_AddRectFilled(draw_list, start + {4, 4}, end - {4, 4}, im.ColorConvertFloat4ToU32(colors[.Foreground]))
        im.DrawList_AddRectFilled(draw_list, start + {100, 4}, {end.x - 4, start.y + 24}, im.ColorConvertFloat4ToU32(colors[.Background]))

        im.DrawList_AddText(draw_list, start + {8, 6}, im.ColorConvertFloat4ToU32(colors[.Text]), "Inspector")

    }
}

// UI
draw_ui :: proc() {

    io         := im.GetIO()
    screen_dim := [2]f32{io.DisplaySize.x, io.DisplaySize.y}
    draw_list  := im.GetBackgroundDrawList()

    // Default docking
    size := f32(1)
    fs_dock := create_dock()
    split_blank_dock(fs_dock, TITLE_BAR_CONTENT, .First, .XTop, 32)
    split_blank_dock(fs_dock.second_child, STATUS_BAR_CONTENT, .Second, .XBottom, 20)
    split_blank_dock(fs_dock.second_child.first_child, TAB_CONTENT, .Second, .YBottom, 400 * size)
    split_blank_dock(fs_dock.second_child.first_child.first_child, TAB_CONTENT, .Second, .XBottom, 350 * size)
    split_blank_dock(fs_dock.second_child.first_child.first_child.first_child, TAB_CONTENT, .First, .YTop, 300 * size)

    //fmt.println(fs_dock)

    draw_dock(fs_dock, draw_list, {0, 0}, screen_dim)

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
draw_dock :: proc(dock: ^DockSpace, draw_list: ^im.DrawList, start: Vector2f, end: Vector2f) {

    //fmt.println("New dock draw")

    if dock.dock_type == .Blank {
        // Nothing to do
    }
    if dock.dock_type == .Content {

        // Draw the content
        dock.content.render(draw_list, start, end, DARK_THEME)
        //fmt.println("Draw Content")

    }
    if dock.dock_type == .Split {

        //fmt.println(dock.first_child^)
        //fmt.println(dock.second_child^)

        // Draw the two children
        if dock.split_type == .XTop {
            draw_dock(dock.first_child, draw_list, start, {end.x, start.y + dock.split_pos})
            draw_dock(dock.second_child, draw_list, {start.x, start.y + dock.split_pos}, end)
        }
        if dock.split_type == .YTop {
            draw_dock(dock.first_child, draw_list, start, {start.x + dock.split_pos, end.y})
            draw_dock(dock.second_child, draw_list, {start.x + dock.split_pos, start.y}, end)
        }
        if dock.split_type == .XBottom {
            draw_dock(dock.first_child, draw_list, start, {end.x, end.y - dock.split_pos})
            draw_dock(dock.second_child, draw_list, {start.x, end.y - dock.split_pos}, end)
        }
        if dock.split_type == .YBottom {
            draw_dock(dock.first_child, draw_list, start, {end.x - dock.split_pos, end.y})
            draw_dock(dock.second_child, draw_list, {end.x - dock.split_pos, start.y}, end)
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

    //fmt.println(parent.first_child^)
    //fmt.println(parent.second_child^)

}