#version 450

layout(binding = 4) uniform samplerCube samplerCubeMap;

layout(location = 0) in vec3 inUVW;

layout(location = 0) out vec4 outColour;

void main() {
	outColour = texture(samplerCubeMap, inUVW);
	// outColour = vec4(1.0, 1.0, 1.0, 0.0);
}