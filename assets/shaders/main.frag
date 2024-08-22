#version 450

layout(binding = 3) uniform sampler2DArray albidoArray;
layout(binding = 4) uniform sampler2DArray normalArray;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inUV;
layout(location = 2) in vec3 inNormal;

layout(location = 0) out vec3 outColour;

struct Light {
    vec3 position;
    float intensity;
};

Light[] lights = {
    Light(vec3(10, 10, 10), 2000),
    Light(vec3(-10,-10,-10), 700)
};

void main() {
    vec3 cumulativeColour = vec3(0.0);
    for (int i = 0; i < lights.length(); i++) {
        vec3 normal = outerProduct(inNormal, vec3(0, 0, 1)) * (texture(normalArray, inUV).xyz - 0.5) * 2;
        vec3 relativePosition = lights[i].position - inPosition;
        float lightDistance = length(relativePosition);
        vec3 negativeLightDirection = normalize(relativePosition);
        float lambertainCoefficient = clamp(dot(normal, negativeLightDirection), 0, 1);
        cumulativeColour += texture(albidoArray, inUV).xyz * lambertainCoefficient * lights[i].intensity / (lightDistance * lightDistance);
    }
    outColour = cumulativeColour;
}