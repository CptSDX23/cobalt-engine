#version 460

layout(set = 1, binding = 0) uniform ubo {
    mat4 mvp;
};

layout(location = 0) in vec3 position;
layout(location = 1) in vec4 color;

layout(location = 0) out vec4 out_color;

void main() {

    vec4 pos = vec4(position, 1);
    gl_Position = mvp * pos;

    out_color = color;
    
}