#version 450

struct InstanceInfo {
    mat4 model;
    uint boneOffset;
    float samplerOffset;
};

layout(binding = 0) readonly buffer InstanceBuffer {
    InstanceInfo[] instanceInfo;
} instanceBuffer;

layout(binding = 1) readonly buffer BoneBuffer {
    mat4[] boneTransforms;
} boneBuffer;

struct Light {
    mat4 mvp;
    vec4 position;
    vec4 colourIntensity;
};

layout(binding = 2) readonly buffer LightBuffer {
    Light[] lights;
} lightBuffer;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in uvec4 inBones;
layout(location = 4) in vec4 inWeights;

void main() {
    mat4 boneTransform = mat4(0.0);
    uint boneOffset = instanceBuffer.instanceInfo[gl_InstanceIndex].boneOffset;
    
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[0]] * inWeights[0];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[1]] * inWeights[1];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[2]] * inWeights[2];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[3]] * inWeights[3];

    mat4 vertexTransform = instanceBuffer.instanceInfo[gl_InstanceIndex].model * boneTransform;
    gl_Position = lightBuffer.lights[0].mvp * vertexTransform * vec4(inPosition, 1.0);
}