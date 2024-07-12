#version 450

layout(binding = 0) readonly uniform ViewProjectionUniform {
	mat4 view;
	mat4 projection;
	mat4 viewProjection;
} viewProjectionUniform;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in uvec4 inBones;
layout(location = 3) in vec4 inWeights;

layout(location = 0) out vec3 outUVW;

void main() {
	outUVW = inPosition;
	gl_Position = viewProjectionUniform.projection * mat4(mat3(viewProjectionUniform.view)) * vec4(inPosition, 1.0);
}