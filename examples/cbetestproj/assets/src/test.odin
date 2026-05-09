package cbetestproj

import "core:relative"
import "core:fmt"
import "core:strconv"
import "core:math/linalg"
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

                transform_matches, t_indices := cbesdk.query_scene_components_uuid(scene^, cbesdk.Transform, cam_uuids[i])

                // Move from input
                move_speed := 25 * deltaTime
                look_sens  := f32(1)
                move_vec   := cbesdk.Vector3f{0, 0, 0}
                if (scene.input_state.key_pressed[.W]) {
                    move_vec += {0, 0, move_speed}
                }
                if (scene.input_state.key_pressed[.S]) {
                    move_vec -= {0, 0, move_speed}
                }
                if (scene.input_state.key_pressed[.A]) {
                    move_vec -= {move_speed, 0, 0}
                }
                if (scene.input_state.key_pressed[.D]) {
                    move_vec += {move_speed, 0, 0}
                }
                if (scene.input_state.key_pressed[.Q]) {
                    move_vec -= {0, move_speed, 0}
                }
                if (scene.input_state.key_pressed[.E]) {
                    move_vec += {0, move_speed, 0}
                }
                if (scene.input_state.key_pressed[.LSHIFT]) {
                    move_vec *= 5
                }
                if (scene.input_state.key_pressed[.LCTRL]) {
                    move_vec *= 0.2
                }

                // Transform to relative
                forward := cbesdk.forward_from_rotation(transform_matches[0].rotation)
                right   := cbesdk.right_from_rotation(transform_matches[0].rotation)
                up      := cbesdk.up_from_rotation(transform_matches[0].rotation)
                transform_matches[0].position += -forward * move_vec.z + right * move_vec.x + up * move_vec.y
                transform_matches[0].rotation += {scene.input_state.mouse_delta.y, scene.input_state.mouse_delta.x, 0} * look_sens

                cbesdk.write_back_components(scene, cbesdk.Transform, transform_matches, t_indices)


            }
        }

    }

}