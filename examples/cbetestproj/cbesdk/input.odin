package cbesdk

import sdl "vendor:sdl3"

// Alias to expose sdl.Scancode in cbesdk so users dont have to import sdl
Keycode :: sdl.Scancode

// Records input state from SDL
InputState :: struct {
    key_pressed: #sparse[sdl.Scancode]bool,
}

set_key_down :: proc(input: ^InputState, key: sdl.Scancode) {
    input.key_pressed[key] = true
}

set_key_up :: proc(input: ^InputState, key: sdl.Scancode) {
    input.key_pressed[key] = false
}