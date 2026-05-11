#version 460

layout(location = 0) in vec4 color;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec3 position;
// layout(location = 3) in vec3 normal;

layout(location = 0) out vec4 frag_color;

layout(set = 2, binding = 0) uniform sampler2D tex_sampler;

void main() {

    // // Sample and gamma correct
    // vec4 final = texture(tex_sampler, uv);
    // final.rgb  = pow(final.rgb, vec3(2.2));
    // 
    // // Lighting
    // 
    // final      = final * color;
    // final.rgb  = pow(final.rgb, vec3(1 / 2.2));
    // frag_color = final;

    // Temp Lighting
    vec3  lightColor     = vec3(1, 1, 1);
    float lightIntensity = 1;
    vec3  lightPosition  = vec3(0, 10, 40);

    // Relation to light
    vec3  vecToLight    = lightPosition - position;
    float distToLight   = length(vecToLight);
    vec3  dirToLight    = vecToLight / distToLight;
    vec3  surfaceNormal = normalize(vec3(0, 1, 0));

    // Angle of reflection
    vec3  incoming      = lightColor * lightIntensity;
    float incomingAngle = dot(dirToLight, surfaceNormal);
    //float attenuation   = 1 / (distToLight * distToLight);
    float attenuation   = 1;
    vec3  irradiance    = incoming * incomingAngle * attenuation;

    // Reflection
    float bdrf      = 1;
    vec3  reflected = irradiance * bdrf;

    if (incomingAngle <= 0) {
        reflected = vec3(0, 0, 0);
    }

    // Emision
    vec3 emmited = vec3(0, 0, 0);

    vec3 total = emmited + reflected;
    frag_color = vec4(total, 1);

}