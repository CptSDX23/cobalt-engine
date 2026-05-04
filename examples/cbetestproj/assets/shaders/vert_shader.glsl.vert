#version 460

layout(set = 1, binding = 0) uniform ubo {
    mat4 mvp;
};

layout(location = 0) in vec3 position;

void main() {

    vec4 pos = vec4(position, 1);
    gl_Position = mvp * pos;
    
}