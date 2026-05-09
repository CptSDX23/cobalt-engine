package cbesdk

import sdl "vendor:sdl3"

// Alias to expose sdl.Scancode in cbesdk so users dont have to import sdl
Keycode :: sdl.Scancode

// Records input state from SDL
InputState :: struct {
    key_pressed: #sparse[sdl.Scancode]bool,
    mouse_delta: Vector2f
}

set_key_down :: proc(input: ^InputState, key: sdl.Scancode) {
    input.key_pressed[key] = true
}

set_key_up :: proc(input: ^InputState, key: sdl.Scancode) {
    input.key_pressed[key] = false
}

set_mouse_delta :: proc(input: ^InputState, delta: Vector2f) {
    input.mouse_delta = delta
}

// FPS counting
FPSState :: struct {
    last_ticks: sdl.Uint64,
    curr_ticks: sdl.Uint64,
}

get_fps :: proc(state: FPSState) -> f32 {

    // Convert from ms
    return f32(state.curr_ticks - state.last_ticks) / 1000

}