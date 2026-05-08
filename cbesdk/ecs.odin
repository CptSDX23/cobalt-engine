package cbesdk

import "core:reflect"
import "core:math/rand"

// Mostly used internally
Entity :: struct {
    uuid: i128,
    name: string,
}

// Structs that want to be a component must go in the data field of this struct
Component :: struct {
    entity_uuid: i128,
    name:        string,
    enabled:     bool,
    data:        any,
}

// Override procedures to give system functionality
System :: struct {
    name:   string,
    start:  proc(scene: ^Scene),
    update: proc(scene: ^Scene, deltaTime: f32)
}

// Special system that gets the Application as well
AppSystem :: struct {
    name:   string,
    start:  proc(scene: ^Scene, app: ^Application),
    update: proc(scene: ^Scene, app: ^Application, deltaTime: f32)
}

// Mostly for uuid gen
create_entity :: proc(name: string) -> Entity {

    // This seems weird but it works trust
    uuid := rand.int127()

    return Entity {
        uuid = uuid,
        name = name,
    }

}

create_component :: proc(data: any) -> Component {

    // Try to get the name of the struct through reflection
    info := type_info_of(data.id)
    name := ""
    if named, ok := info.variant.(reflect.Type_Info_Named); ok {
        name = named.name
    }

    return Component {
        entity_uuid = 0,
        name        = name,
        enabled     = true,
        data        = data,
    }

}