package cbesdk

import "core:fmt"

// Abstracting away things that regular scene interacters should mess with
Application :: struct {
    scene:      Scene,
    registry:   TypeRegistry,
    render_ctx: RenderContext,
    fps_state:  FPSState,
}

// Just the state of an ECS
Scene :: struct {
    enities:     [dynamic]Entity,
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
    append(&scene.enities, entity)
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
load_scene :: proc(registry: TypeRegistry) -> Scene {

    scene := Scene { input_state = InputState {} }

    // Make entity
    entity    := create_entity("Test")
    user_args := make([dynamic]string); append(&user_args, "42")
    tran_args := make([dynamic]string); append_elems(&tran_args, "-5", "0", "0", "0", "0", "0", "1", "1", "1")
    cam_args  := make([dynamic]string); append_elems(&cam_args, "60", "0.001", "10000", "true")
    defer delete(user_args)
    defer delete(tran_args)
    defer delete(cam_args)

    // Bind component generated from constructor
    user_struct := registry.constructors["TestComponent"](user_args)
    tran_struct := registry.constructors["Transform"](tran_args)
    cam_struct  := registry.constructors["Camera"](cam_args)
    bind_entity_component(&scene, entity, create_component(user_struct))
    bind_entity_component(&scene, entity, create_component(tran_struct))
    bind_entity_component(&scene, entity, create_component(cam_struct))
    add_scene_entity(&scene, entity)

    // Systems
    user_system := registry.systems["TestSystem"]
    cam_system  := registry.app_systems["CameraSystem"]
    add_scene_system(&scene, user_system)
    add_scene_app_system(&scene, cam_system)

    return scene

}

// Application procedures
create_application :: proc(registry: ^TypeRegistry, abs_proj_path: string) -> Application {

    settings := load_settings_from_proj(abs_proj_path)

    // Load builtins
    register_component_data(registry, Transform, TRANSFORM_CONSTRUCTOR)
    register_component_data(registry, Camera, CAMERA_CONSTRUCTOR)
    register_app_system(registry, CAM_APP_SYSTEM)

    // Init FPS as well
    render_ctx, fps_state := create_render_ctx(settings.win_settings)

    return Application {
        scene      = load_scene(registry^),
        registry   = registry^,
        render_ctx = render_ctx,
        fps_state  = fps_state,
    }

}

run_application :: proc(app: ^Application) {

    start_scene(&app.scene)
    
    loop: for {

        update_app(&app.scene, app, get_fps(app.fps_state))
        update_scene(&app.scene, get_fps(app.fps_state))
        quit := run_render(app.render_ctx, &app.scene.input_state, &app.fps_state)

        // Exit app
        if quit {
            break loop
        }

    }

}