package cbetestproj

import "core:fmt"
import "core:strconv"
import "cobalt:cbesdk"

TestComponent :: struct {
    value: f32,
}

test_component_constructor :: proc(args: [dynamic]string) -> any {

    if len(args) != 1 {
        return nil
    }

    arg0, ok0 := strconv.parse_f32(args[0])

    // Have to put stuff on the heap
    comp := TestComponent { value = arg0 }
    ptr  := new(TestComponent)
    ptr^  = comp

    return ptr^

}

test_system := cbesdk.System {

    name   = "TestSystem",
    start  = proc(scene: ^cbesdk.Scene) {
        fmt.println("Started TestSystem")
    },
    update = proc(scene: ^cbesdk.Scene, deltaTime: f32) {

        // matches, indices := cbesdk.query_scene_components(scene, TestComponent)
        // fmt.printfln("First match's value before adding: %v", matches[0].value)
        // matches[0].value += 10
        // cbesdk.write_back_components(scene, TestComponent, matches, indices)

        // The idea is to query all cameras and their entity uuids, find which one is main, get a transform
        // on the same entity, modify its value, and write only the transform back
        cam_matches, c_indices := cbesdk.query_scene_components(scene^, cbesdk.Camera)
        cam_uuids              := cbesdk.query_component_uuids(scene^, cbesdk.Camera)

        for cam, i in cam_matches {
            if cam.is_main {

                transform_matches, t_indices  := cbesdk.query_scene_components_uuid(scene^, cbesdk.Transform, cam_uuids[i])

                // Move from input
                move_speed := 10 * deltaTime;
                if (scene.input_state.key_pressed[.W]) {
                    transform_matches[0].position += {0, 0, move_speed}
                }
                if (scene.input_state.key_pressed[.S]) {
                    transform_matches[0].position -= {0, 0, move_speed}
                }
                if (scene.input_state.key_pressed[.A]) {
                    transform_matches[0].position -= {move_speed, 0, 0}
                }
                if (scene.input_state.key_pressed[.D]) {
                    transform_matches[0].position += {move_speed, 0, 0}
                }

                transform_matches[0].rotation += {0, 0, 0}

                cbesdk.write_back_components(scene, cbesdk.Transform, transform_matches, t_indices)


            }
        }

    }

}