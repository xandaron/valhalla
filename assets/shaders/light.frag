#version 450

layout(location = 0) in vec4 inVertexPosition;
layout(location = 1) in vec3 inLightPosition;

layout(location = 0) out float outColour;

void main() {
    outColour = length(inVertexPosition.xyz - inLightPosition);
}