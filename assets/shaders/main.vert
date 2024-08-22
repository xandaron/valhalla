#version 450

layout(binding = 0) readonly uniform ViewProjectionUniform {
	mat4 view;
	mat4 projection;
	mat4 viewProjection;
} viewProjectionUniform;

struct InstanceInfo {
    mat4 model;
    uint boneOffset;
    float samplerOffset;
};

layout(binding = 1) readonly buffer InstanceBuffer {
    InstanceInfo instanceInfo[];
} instanceBuffer;

layout(binding = 2) readonly buffer BoneBuffer {
	mat4[] boneTransforms;
} boneBuffer;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in uvec4 inBones;
layout(location = 4) in vec4 inWeights;

layout(location = 0) out vec3 fragTexCoord;
layout(location = 1) out vec3 outNormal;
// layout(location = 2) out vec4 fragColour;

void main() {
    mat4 boneTransform = mat4(0.0);
    uint boneOffset = instanceBuffer.instanceInfo[gl_InstanceIndex].boneOffset;
    for (int id = 0; id < 4; id++) {
        boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[id]] * inWeights[id];
    }
    mat4 vertexTransform = instanceBuffer.instanceInfo[gl_InstanceIndex].model * boneTransform;
    gl_Position = viewProjectionUniform.viewProjection * vertexTransform * vec4(inPosition, 1.0);
    fragTexCoord = vec3(inUV.xy, instanceBuffer.instanceInfo[gl_InstanceIndex].samplerOffset);
    outNormal = mat3(vertexTransform) * inNormal, 0.0;
    // fragColour = vec4(1.0, 1.0, 1.0, 1.0);
}