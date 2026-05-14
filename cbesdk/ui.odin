package cbesdk

import "core:fmt"

import im     "shared:imgui"
import im_sdl "shared:imgui/imgui_impl_sdl3"
import im_gpu "shared:imgui/imgui_impl_sdlgpu3"

DockSpace :: struct {
    first_child:  ^DockSpace,
    second_child: ^DockSpace,
    has_children: bool,
    blank:        bool,
    split_type:   SplitType,
    split_pos:    f32,
}

SplitType :: enum {
    X,
    Y,
}

// UI
draw_ui :: proc() {

    io         := im.GetIO()
    screen_dim := [2]f32{io.DisplaySize.x, io.DisplaySize.y}
    draw_list  := im.GetBackgroundDrawList()

    fs_dock := DockSpace { has_children = true, split_type = .X, split_pos = 32 }
    dock1 := &DockSpace { has_children = false }
    dock2 := &DockSpace { has_children = false, blank = true }
    fs_dock.first_child  = dock1
    fs_dock.second_child = dock2

    new := DockSpace { has_children = false }
    add_sub_dock(&fs_dock, &new, true, .X, 100)
    // title_dock  := DockSpace { has_children = false, }
    // status_dock := DockSpace { has_children = false, }
    // fs_dock.first_child  = &title_dock
    // fs_dock.second_child = &DockSpace { has_children = true, split_type = .X, split_pos = 200 }
    // fs_dock.second_child = &DockSpace { blank = true, has_children = false }

    // Traverse docks
    draw_dock(&fs_dock, draw_list, {0, 0}, screen_dim)

    // // Title and Status
    // im.DrawList_AddRectFilled(draw_list, {0, 0}, {screen_dim.x, 32}, accent, 0, 0)
    // im.DrawList_AddRectFilled(draw_list, {0, screen_dim.y - 16}, {screen_dim.x, screen_dim.y}, fg, 0, 0)

    // // Tabs
    // im.DrawList_AddRectFilled(draw_list, {0, 32}, {200, screen_dim.y - 16}, bg, 0, 0)
    // im.DrawList_AddRectFilled(draw_list, {4, 36}, {196, screen_dim.y - 20}, fg, 0, 0)

    // Border
    //im.DrawList_AddRect(draw_list, {0, 0}, screen_dim, accent, 0, 1)
    //im.ShowDemoWindow()

}

draw_dock :: proc(dock: ^DockSpace, draw_list: ^im.DrawList, start: Vector2f, end: Vector2f) {

    // Colors
    accent := im.ColorConvertFloat4ToU32({0, 0.2, 0.6, 1})
    bg     := im.ColorConvertFloat4ToU32({0.1, 0.1, 0.1, 1})
    fg     := im.ColorConvertFloat4ToU32({0.15, 0.15, 0.15, 1})

    if !dock.has_children {

        // Draw entire dock
        if !dock.blank {
            im.DrawList_AddRectFilled(draw_list, start, end, accent, 0, 0)
        }

    } else {

        // Recurse to sub docks
        if dock.split_type == .X {
            draw_dock(dock.first_child, draw_list, {start.x, start.y}, {end.x, start.y + dock.split_pos})
            draw_dock(dock.second_child, draw_list, {start.x, start.y + dock.split_pos}, {end.x, end.y})
        }
        if dock.split_type == .Y {
            draw_dock(dock.first_child, draw_list, {start.x, start.y}, {start.x + dock.split_pos, end.y})
            draw_dock(dock.second_child, draw_list, {start.x + dock.split_pos, start.y}, {end.x, end.y})
        }

    }

}

// Finds the first blank dockspace and adds the dock there
add_sub_dock :: proc(parent_dock: ^DockSpace, new_dock: ^DockSpace, side: bool, split: SplitType, split_pos: f32) {

    searching_dock := parent_dock
    loops          := 0

    fmt.println("abababa")

    // Infinite loop until blank is found or limit hit
    for loops <= 10 {

        if !searching_dock.has_children && searching_dock.blank {

            fmt.println("abababa2")

            // Blank found, insert new dock
            if !side {
                searching_dock.first_child  = new_dock
                searching_dock.second_child = &DockSpace { blank = true, has_children = false }
            } else {
                searching_dock.second_child = new_dock
                searching_dock.first_child  = &DockSpace { blank = true, has_children = false }
            }
            searching_dock.has_children = true
            searching_dock.blank        = false
            searching_dock.split_type   = split
            searching_dock.split_pos    = split_pos

        } else {

            fmt.println(searching_dock.first_child)
            fmt.println(searching_dock.second_child)

            fmt.println("abababa3")

            if searching_dock.second_child == nil {
                fmt.println("BADBADBAD")
            }

            // Traverse to next dock
            if searching_dock.first_child != nil {
                fmt.println("abababa4")
                searching_dock = searching_dock.first_child
                fmt.println("abababa6")
            } else if searching_dock.second_child != nil {
                fmt.println("abababa5")
                searching_dock = searching_dock.second_child
            }
            fmt.println("abababa8")

        }
        
        loops += 1
        fmt.println(loops)

    }

}