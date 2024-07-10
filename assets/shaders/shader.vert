#version 450

layout(binding = 0) readonly uniform ViewProjectionUniform {
    mat4 viewProjection;
} viewProjectionUniform;

struct InstanceInfo {
    mat4 model;
    uint boneOffset;
    uint samplerOffset;
};

layout(binding = 1) readonly buffer InstanceBuffer {
    InstanceInfo instanceInfo[];
} instanceBuffer;

layout(binding = 2) readonly buffer BoneBuffer {
	mat4[] boneTransforms;
} boneBuffer;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;
layout(location = 2) in uvec4 inBones;
layout(location = 3) in vec4 inWeights;

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec4 fragColour;
layout(location = 2) out uint samplerOffset;

void main() {
    mat4 transform = mat4(0.0);
    uint boneOffset = instanceBuffer.instanceInfo[gl_InstanceIndex].boneOffset;
    for (int id = 0; id < 4; id++) {
        if (inWeights[id] > 0.0) {
            transform += boneBuffer.boneTransforms[boneOffset + inBones[id]] * inWeights[id];
        }
    }

    gl_Position = viewProjectionUniform.viewProjection * instanceBuffer.instanceInfo[gl_InstanceIndex].model * transform * vec4(inPosition, 1.0);
    fragTexCoord = inTexCoord;
    fragColour = vec4(1.0, 1.0, 1.0, 1.0);
    samplerOffset = instanceBuffer.instanceInfo[gl_InstanceIndex].samplerOffset;
}