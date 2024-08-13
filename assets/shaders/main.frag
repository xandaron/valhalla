#version 450

layout(binding = 3) uniform sampler2DArray samplerArray;

layout(location = 0) in vec3 inUV;
// layout(location = 1) in vec4 inColour;

layout(location = 0) out vec4 outColour;

void main() {
    outColour = texture(samplerArray, inUV) * 2;
    // outColour = fragColour;
}