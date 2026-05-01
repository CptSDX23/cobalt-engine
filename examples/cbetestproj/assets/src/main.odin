package cbetestproj

import "../../../cbesdk"

main :: proc() {

    // Register
    registry := cbesdk.create_registry()
    cbesdk.register_component_data(&registry, TestComponent, test_component_constructor)
    cbesdk.register_system(&registry, test_system)

    //cbesdk.print_registry(registry)

    // Start application
    app := cbesdk.create_application(registry)
    cbesdk.run_application(app)

}
