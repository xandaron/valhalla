#version 450

layout(binding = 3) uniform sampler2DArray albidoArray;
layout(binding = 4) uniform sampler2DArray normalArray;

layout(location = 0) in vec3 inUV;
layout(location = 1) in vec3 inNormal;
// layout(location = 2) in vec4 inColour;

layout(location = 0) out vec3 outColour;

void main() {
    outColour = cross(texture(normalArray, inUV).xyz, normalize(inNormal));
    // outColour = vec4(inUV, 0.0);
    // outColour = inColour;
}