#version 450

layout(location = 0) in vec3 fragColor;
layout(location = 1) in vec2 fragTexCoord;
layout(location = 2) in vec3 fragNormal;

layout(set = 1, binding = 0) uniform sampler2D material;

layout(location = 0) out vec4 outColor;

const vec4 ambiantLightColor = vec4(1.0, 1.0, 1.0, 1.0);
const float ambiantLightIntencity = 0.3;
const vec4 sunColor = vec4(1.0, 1.0, 1.0, 1.0);
const vec3 sunDirection = normalize(vec3(1.0, 1.0, -1.0));

void main() {
	outColor = vec4(normalize((fragNormal + 1) / 2), 1.0);
}