package cbesdk

import "core:fmt"
import "core:reflect"

// Wrappers for maps
// Constructors for components, structs for systems
TypeRegistry :: struct {
    components:   map[string]typeid,
    constructors: map[string]proc(args: [dynamic]string) -> any,
    systems:      map[string]System,
    app_systems:  map[string]AppSystem,
}

// Registry procedures
register_component_data :: proc(registry: ^TypeRegistry, $T: typeid, constructor: proc(args: [dynamic]string) -> any) {

    // Try to get the name of the struct through reflection
    info := type_info_of(T)
    name := ""
    if named, ok := info.variant.(reflect.Type_Info_Named); ok {
        name = named.name
    }
    
    registry.components  [name] = T
    registry.constructors[name] = constructor

}

register_system :: proc(registry: ^TypeRegistry, system: System) {
    registry.systems[system.name] = system
}

register_app_system :: proc(registry: ^TypeRegistry, system: AppSystem) {
    registry.app_systems[system.name] = system
}

create_registry :: proc() -> TypeRegistry {
    return TypeRegistry{}
}

// Debug
print_registry :: proc(registry: TypeRegistry) {

    fmt.println("Registry Components:")
    for component in registry.components {
        fmt.println(component)
    }

    fmt.println("Registry Constructors:")
    for constructor in registry.constructors {
        fmt.println(constructor)
    }

    fmt.println("Registry Systems:")
    for system in registry.systems {
        fmt.println(system)
    }

    fmt.println("Registry App Systems:")
    for system in registry.app_systems {
        fmt.println(system)
    }

}