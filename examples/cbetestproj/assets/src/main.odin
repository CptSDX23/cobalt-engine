package cbetestproj

import "core:fmt"
import "core:os"
import "cobalt:cbesdk"

main :: proc() {

    // Register
    registry := cbesdk.create_registry()
    cbesdk.register_component_data(&registry, TestComponent, test_component_constructor)
    cbesdk.register_component_data(&registry, Rotator, rotator_constructor)
    cbesdk.register_system(&registry, test_system)
    cbesdk.register_system(&registry, rotator_system)

    // Start application
    app := cbesdk.create_application(&registry, os.args[1])
    cbesdk.run_application(&app)

}
