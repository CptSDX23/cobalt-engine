package cbetestproj

import "core:fmt"
import "cobalt:cbesdk"

TestComponent :: struct {
    value: f32,
}

test_component_constructor :: proc(args: [dynamic]any) -> any {

    arg0 := args[0].(f32)

    // Have to put stuff on the heap
    comp := TestComponent{value=arg0}
    ptr  := new(TestComponent)
    ptr^  = comp

    return ptr^

}

test_system := cbesdk.System {

    name   = "TestSystem",
    start  = proc(scene: cbesdk.Scene) {
        fmt.println("Started TestSystem")
    },
    update = proc(scene: cbesdk.Scene, deltaTime: f32) {

        matches, indices := cbesdk.query_scene_components(scene, TestComponent)
        fmt.printfln("First match's value before adding: %v", matches[0].value)
        matches[0].value += 10
        cbesdk.write_back_components(scene, TestComponent, matches, indices)

    }

}