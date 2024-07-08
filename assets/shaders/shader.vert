#version 450

layout(binding = 0) readonly uniform UniformBufferObject {
    mat4 view;
    mat4 projection;
    mat4 viewProjection;
} ubo;

layout(binding = 1) readonly buffer modelBuffer {
    mat4[] model;
} ModelBuffer;

layout(binding = 2) readonly buffer boneOffsetBuffer {
	uint[] boneOffsets;
} BoneOffsetBuffer;

layout(binding = 3) readonly buffer boneBuffer {
	mat4[] boneTransforms;
} BoneBuffer;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;
layout(location = 2) in uvec4 inBones;
layout(location = 3) in vec4 inWeights;

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec4 fragColour;

void main() {
    mat4 transform = mat4(0.0);
    uint boneOffset = BoneOffsetBuffer.boneOffsets[gl_InstanceIndex];
    for (int id = 0; id < 4; id++) {
        if (inWeights[id] > 0.0) {
            transform += BoneBuffer.boneTransforms[boneOffset + inBones[id]] * inWeights[id];
        }
    }

    gl_Position = ubo.viewProjection * ModelBuffer.model[gl_InstanceIndex] * transform * vec4(inPosition, 1.0);
    fragTexCoord = inTexCoord;
    fragColour = vec4(1.0, 1.0, 1.0, 1.0);
}