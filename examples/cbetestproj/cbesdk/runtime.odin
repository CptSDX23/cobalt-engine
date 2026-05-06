package cbesdk

import "core:strings"

Application :: struct {
    scene:      Scene,
    registry:   TypeRegistry,
    render_ctx: RenderContext,
}

// Just the state of an ECS
Scene :: struct {
    enities:    [dynamic]Entity,
    components: [dynamic]Component,
    systems:    [dynamic]System,
}

// Scene procedures
update_scene :: proc(scene: Scene) {

    components := scene.components[:]
    systems    := scene.systems[:]

    for system in systems {
        system.update(scene, 0.01)
    }

}

start_scene :: proc(scene: Scene) {

    components := scene.components[:]
    systems    := scene.systems[:]

    for system in systems {
        system.start(scene)
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

// Uses components and their indices to write data matched from a query back to the scene
write_back_components :: proc(scene: Scene, $T: typeid, components: [dynamic]T, indices: [dynamic]i32) {

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

add_scene_entity :: proc(scene: ^Scene, entity: Entity) {
    append(&scene.enities, entity)
}

add_scene_component :: proc(scene: ^Scene, component: Component) {
    append(&scene.components, component)
}

add_scene_system :: proc(scene: ^Scene, system: System) {
    append(&scene.systems, system)
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

    scene := Scene{}

    // Make entity
    entity := create_entity("Test")
    args   := make([dynamic]any); append(&args, f32(42))
    defer delete(args)

    // Bind component generated from constructor
    user_struct := registry.constructors["TestComponent"](args)
    bind_entity_component(&scene, entity, create_component(user_struct))
    add_scene_entity(&scene, entity)

    // Systems
    system := registry.systems["TestSystem"]
    add_scene_system(&scene, system)

    return scene

}

// Application procedures
create_application :: proc(registry: TypeRegistry, abs_proj_path: string) -> Application {

    settings := load_settings_from_proj(abs_proj_path)

    return Application {
        scene      = load_scene(registry),
        registry   = registry,
        render_ctx = create_render_ctx(settings.win_settings),
    }

}

run_application :: proc(app: Application) {

    start_scene(app.scene)
    
    loop: for {

        // update_scene(app.scene)
        quit := run_render(app.render_ctx)

        // Exit app
        if quit {
            break loop
        }

    }

}