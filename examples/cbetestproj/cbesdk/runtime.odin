package cbesdk

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

// Abstracting away things that regular scene interacters should mess with
Application :: struct {
    scene:      Scene,
    registry:   TypeRegistry,
    render_ctx: RenderContext,
    fps_state:  FPSState,
    settings:   ProjectSettings,
}

// Just the state of an ECS
Scene :: struct {
    entities:    [dynamic]Entity,
    components:  [dynamic]Component,
    systems:     [dynamic]System,
    app_systems: [dynamic]AppSystem,
    input_state: InputState,
}

// Scene procedures
update_scene :: proc(scene: ^Scene, deltaTime: f32) {

    components := scene.components[:]
    systems    := scene.systems[:]

    for system in systems {
        system.update(scene, deltaTime)
    }

}

update_app :: proc(scene: ^Scene, app: ^Application, deltaTime: f32) {

    app_systems := scene.app_systems[:]
    for app_system in app_systems {
        app_system.update(scene, app, deltaTime)
    }

}

start_scene :: proc(scene: ^Scene) {

    components  := scene.components[:]
    systems     := scene.systems[:]
    app_systems := scene.app_systems[:]

    for system in systems {
        system.start(scene)
    }

}

start_app :: proc(scene: ^Scene, app: ^Application) {

    app_systems := scene.app_systems[:]

    for app_system in app_systems {
        app_system.start(scene, app)
    }

}

// Returns an array of copies of the components and indices to write the copies back
query_scene_components :: proc(scene: Scene, $T: typeid) -> ([dynamic]T, [dynamic]i32) {

    matches := make([dynamic]T)
    indices := make([dynamic]i32)

    // If the cast works, its the type wanted
    for component, i in scene.components {
        if v, ok := component.data.(T); ok {
            append(&matches, v)
            append(&indices, i32(i))
        }
    }

    return matches, indices

}

// Returns an array of entity uuids of components
query_component_uuids :: proc(scene: Scene, $T: typeid) -> [dynamic]i128 {

    uuids := make([dynamic]i128)

    // If the cast works, its the type wanted
    for component, i in scene.components {
        if v, ok := component.data.(T); ok {
            append(&uuids, component.entity_uuid)
        }
    }

    return uuids

}

// Returns the component matching the entity uuid
query_scene_components_uuid :: proc(scene: Scene, $T: typeid, uuid: i128) -> ([dynamic]T, [dynamic]i32) {

    matches := make([dynamic]T)
    indices := make([dynamic]i32)

    // If the cast works, its the type wanted
    for component, i in scene.components {
        if v, ok := component.data.(T); ok && component.entity_uuid == uuid {
            append(&matches, v)
            append(&indices, i32(i))
        }
    }

    return matches, indices

}

// Uses components and their indices to write data matched from a query back to the scene
write_back_components :: proc(scene: ^Scene, $T: typeid, components: [dynamic]T, indices: [dynamic]i32) {

    for i, c_index in indices {
        component           := scene.components[i]
        scene.components[i]  = Component {
            entity_uuid = component.entity_uuid,
            name        = component.name,
            enabled     = component.enabled,
            data        = components[c_index],
        }
    }

}

// Uses one index to write back component to scene
write_back_component :: proc(scene: ^Scene, $T: typeid, comp: T, index: i32) {

    component               := scene.components[index]
    scene.components[index]  = Component {
        entity_uuid = component.entity_uuid,
        name        = component.name,
        enabled     = component.enabled,
        data        = comp,
    }

}

add_scene_entity :: proc(scene: ^Scene, entity: Entity) {
    append(&scene.entities, entity)
}

add_scene_component :: proc(scene: ^Scene, component: Component) {
    append(&scene.components, component)
}

add_scene_system :: proc(scene: ^Scene, system: System) {
    append(&scene.systems, system)
}

add_scene_app_system :: proc(scene: ^Scene, system: AppSystem) {
    append(&scene.app_systems, system)
}

// Entities only store a uuid so its a components job to reference it
// Modifies the component to reference the entity and adds it to the scene
bind_entity_component :: proc(scene: ^Scene, entity: Entity, component: Component) {
    
    new_component := Component {
        entity_uuid = entity.uuid,
        name        = component.name,
        enabled     = component.enabled,
        data        = component.data,
    }

    add_scene_component(scene, new_component)

}

// Hardcoded for now
load_scene :: proc(registry: TypeRegistry, path: string) -> Scene {

    scene := Scene { input_state = InputState {} }

    // Add Systems
    for _, system in registry.systems {
        add_scene_system(&scene, system)
    }
    for _, app_system in registry.app_systems {
        add_scene_app_system(&scene, app_system)
    }

    // Read file
    data, err := os.read_entire_file(path, context.allocator)
    
    if err != nil {
        fmt.println("Failed to read scene file")
        return scene
    }

    // Parse the scene
    ParseState :: enum { NONE, ENTITY, COMPONENT, }
    state := ParseState.NONE
    lines := string(data)

    parsing_args      := false
    current_comp_name := ""
    current_comp_uuid := i128(0)
    current_comp_args := make([dynamic]string)
    defer delete(current_comp_args)

	for line in strings.split_lines_iterator(&lines) {

        if strings.starts_with(line, "//") {
            continue
        }

        // Check state
        if strings.starts_with(line, "[entities]") {
            state = .ENTITY
            continue
        }
        if strings.starts_with(line, "[components]") {
            state = .COMPONENT
            continue 
        }

        if state == .NONE {
            continue
        }

        // Entity parsing
        if state == .ENTITY {

            split := strings.split(line, ":")
            if (len(split) != 2) {
                continue
            }
            key       := strings.trim_space(split[0])
            value, ok := strconv.parse_i128(strings.trim_space(split[1]))

            entity := create_entity_uuid(key, value)
            add_scene_entity(&scene, entity)

        }

        // Component parsing
        if state == .COMPONENT {

            // Component metadata
            if strings.starts_with(line, "- ") {

                // If a component was being parsed, finish it
                if parsing_args {

                    parsing_args  = false
                    data_struct  := registry.constructors[current_comp_name](current_comp_args)
                    add_scene_component(&scene, create_component_uuid(data_struct, current_comp_uuid))
                    clear(&current_comp_args)

                }

                split := strings.split(line[2:], ":")
                if (len(split) != 2) {
                    current_comp_name = ""
                    current_comp_uuid = 0
                    continue
                }
                key       := strings.trim_space(split[0])
                value, ok := strconv.parse_i128(strings.trim_space(split[1]))

                current_comp_name = key
                current_comp_uuid = value

            }

            // Component args
            if strings.starts_with(line, "\" ") {

                parsing_args = true
                append(&current_comp_args, line[2:])

            }

        }

    }

    // One final check
    if parsing_args {

        parsing_args  = false
        data_struct  := registry.constructors[current_comp_name](current_comp_args)
        add_scene_component(&scene, create_component_uuid(data_struct, current_comp_uuid))
        clear(&current_comp_args)

    }

    return scene

}

// Application procedures
create_application :: proc(registry: ^TypeRegistry, abs_proj_path: string) -> Application {

    settings := load_settings_from_proj(abs_proj_path)

    // Load builtins
    register_component_data(registry, Transform, TRANSFORM_CONSTRUCTOR)
    register_component_data(registry, Camera, CAMERA_CONSTRUCTOR)
    register_component_data(registry, MeshRenderer, MESH_RENDERER_CONSTRUCTOR)
    register_app_system(registry, CAM_APP_SYSTEM)
    register_app_system(registry, MESH_RENDERER_APP_SYSTEM)

    // Init FPS as well
    render_ctx, fps_state := create_render_ctx(settings.win_settings)

    return Application {
        scene      = load_scene(registry^, strings.concatenate({abs_proj_path, "\\assets\\", settings.scene_paths[0]})),
        registry   = registry^,
        render_ctx = render_ctx,
        fps_state  = fps_state,
        settings   = settings,
    }

}

run_application :: proc(app: ^Application) {
    
    start_app(&app.scene, app)
    start_scene(&app.scene)
    
    loop: for {

        update_app(&app.scene, app, get_fps(app.fps_state))
        update_scene(&app.scene, get_fps(app.fps_state))
        quit := run_render(app.render_ctx, &app.scene.input_state, &app.fps_state, app)

        // Exit app
        if quit {
            break loop
        }

    }

}