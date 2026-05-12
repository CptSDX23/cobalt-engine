#version 460

layout(set = 3, binding = 0) uniform lights {
    vec3  lightColor;
    float lightIntensity;
    vec3  lightPosition;
    float lightAmbient;
    vec3  camPosition;
};
layout(set = 3, binding = 1) uniform material {
    vec3  diffuseColor;
    float shininess;
    vec3  specularColor;
};

layout(location = 0) in vec4 color;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec3 position;
layout(location = 3) in vec3 normal;

layout(location = 0) out vec4 frag_color;

layout(set = 2, binding = 0) uniform sampler2D tex_sampler;

vec3 blinnPhong(vec3 dirToLight, vec3 dirToCamera, vec3 surfaceNormal) {

    // Diffuse
    vec3 diffuse = diffuseColor;

    // Specular
    vec3  halfwayDir        = normalize(dirToLight + dirToCamera);
    float specularDir       = max(dot(halfwayDir, surfaceNormal), 0);
    float specularIntensity = pow(specularDir, shininess);
    vec3  specular          = specularColor * specularIntensity;

    return diffuse + specular;
}

void main() {

    // Relation to light
    vec3  vecToLight    = lightPosition - position;
    float distToLight   = length(vecToLight);
    vec3  dirToLight    = vecToLight / distToLight;
    vec3  surfaceNormal = normalize(normal);

    // Angle of reflection
    vec3  incoming      = lightColor * lightIntensity;
    float incomingAngle = dot(dirToLight, surfaceNormal);
    float attenuation   = 1 / ((distToLight) * 0.05);
    //float attenuation   = 1;
    vec3  irradiance    = incoming * incomingAngle * attenuation;

    // Reflection
    vec3 dirToCamera = normalize(camPosition - position);
    vec3 bdrf        = blinnPhong(dirToLight, dirToCamera, surfaceNormal);
    vec3 reflected   = irradiance * bdrf;

    if (incomingAngle <= 0) {
        reflected = vec3(0, 0, 0);
    }
    reflected = max(reflected, lightColor * lightAmbient);

    // Emision
    vec3 emmited = vec3(0, 0, 0);

    vec4 total = vec4(reflected, 1) * texture(tex_sampler, uv) + vec4(emmited, 1);
    //total = vec4(surfaceNormal, 1);
    //total = vec4(uv.x, uv.y, 0, 1);
    //total = vec4(length(reflected), length(reflected), length(reflected), 1);
    frag_color = total;

}