#version 460

layout(set = 1, binding = 0) uniform ubo {
    mat4 vp;
    mat4 m;
};

layout(location = 0) in vec3 position;
layout(location = 1) in vec4 color;
layout(location = 2) in vec2 uv;
layout(location = 3) in vec3 normal;

layout(location = 0) out vec4 out_color;
layout(location = 1) out vec2 out_uv;
layout(location = 2) out vec3 out_pos;
layout(location = 3) out vec3 out_normal;

void main() {

    vec4 pos = vec4(position, 1);
    gl_Position = vp * m * pos;

    out_color  = color;
    out_uv     = uv;
    out_pos    = vec3(m * pos);
    out_normal = normalize((m * vec4(normal, 0)).xyz);
    //out_normal = normal;
    
}