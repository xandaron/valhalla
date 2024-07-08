#version 450

layout(binding = 0) uniform UniformBufferObject {
    mat4 model;
    mat4 view;
    mat4 projection;
} ubo;

layout(binding = 1) readonly buffer storageBuffer {
	mat4 boneTransforms[];
} BoneBuffer;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;
layout(location = 2) in uvec4 inBones;
layout(location = 3) in vec4 inWeights;

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec4 fragColour;

void main() {
    mat4 transform = mat4(0.0);

    for (int id = 0; id < 4; id++) {
        if (inWeights[id] > 0.0) {
            transform += BoneBuffer.boneTransforms[inBones[id]] * inWeights[id];
        }
    }

    gl_Position = ubo.projection * ubo.view * ubo.model * transform * vec4(inPosition, 1.0);
    fragTexCoord = inTexCoord;
    fragColour = vec4(1.0, 1.0, 1.0, 1.0);
}