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
    InstanceInfo[] instanceInfo;
} instanceBuffer;

layout(binding = 2) readonly buffer BoneBuffer {
	mat4[] boneTransforms;
} boneBuffer;

struct Light {
    mat4 mvp;
    vec4 position;
    vec4 colourIntensity;
};

layout(binding = 3) readonly buffer LightBuffer {
    Light[] lights;
} lightBuffer;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in uvec4 inBones;
layout(location = 4) in vec4 inWeights;

layout(location = 0) out vec4 outPosition;
layout(location = 1) out vec3 outUV;
layout(location = 2) out vec3 outNormal;

void main() {
    mat4 boneTransform = mat4(0.0);
    uint boneOffset = instanceBuffer.instanceInfo[gl_InstanceIndex].boneOffset;
    
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[0]] * inWeights[0];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[1]] * inWeights[1];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[2]] * inWeights[2];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[3]] * inWeights[3];

    mat4 vertexTransform = instanceBuffer.instanceInfo[gl_InstanceIndex].model * boneTransform;
    outPosition = vertexTransform * vec4(inPosition, 1.0);

    gl_Position = viewProjectionUniform.viewProjection * outPosition;
    outUV = vec3(inUV.xy, instanceBuffer.instanceInfo[gl_InstanceIndex].samplerOffset);
    outNormal = normalize(mat3(vertexTransform) * inNormal);
}