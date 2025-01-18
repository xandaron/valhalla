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
    vec4 position;
    vec4 colourIntensity;
    float near;
    float far;
};

layout(binding = 2) readonly buffer LightBuffer {
    Light[] lights;
} lightBuffer;

layout(push_constant) uniform PushConstants {
	uint lightIndex;
    uint faceIndex;
} pushConstants;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in uvec4 inBones;
layout(location = 4) in vec4 inWeights;

layout(location = 0) out vec4 outVertexPosition;
layout(location = 1) out vec3 outLightPosition;

#define PI 3.14159265358979323846264338327950288
#define tanHalfFOVReciprocal (1.0 / tan(PI / 4.0))

void main() {
    // This should be done as part of a precompute step ---------------------------------------
    mat4 boneTransform = mat4(0.0);
    uint boneOffset = instanceBuffer.instanceInfo[gl_InstanceIndex].boneOffset;
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[0]] * inWeights[0];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[1]] * inWeights[1];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[2]] * inWeights[2];
    boneTransform += boneBuffer.boneTransforms[boneOffset + inBones[3]] * inWeights[3];
    mat4 vertexTransform = instanceBuffer.instanceInfo[gl_InstanceIndex].model * boneTransform;
    // ----------------------------------------------------------------------------------------

    const Light light = lightBuffer.lights[pushConstants.lightIndex];
    mat4 projection = mat4(
        vec4(tanHalfFOVReciprocal, 0.0, 0.0, 0.0),
        vec4(0.0, -tanHalfFOVReciprocal, 0.0, 0.0),
        vec4(0.0, 0.0, light.far / (light.far - light.near), 1.0),
        vec4(0.0, 0.0, -(light.far * light.near) / (light.far - light.near), 0.0)
    );

    mat4 view;
    switch(pushConstants.faceIndex) {
    case 0: // POSITIVE_X
        view = mat4(
            vec4( 0,  0,  1, 0),
            vec4( 0,  1,  0, 0),
            vec4(-1,  0,  0, 0),
            vec4( light.position.z, -light.position.yx, 1.0)
        );
        break;
    case 1: // NEGATIVE_X
        view = mat4(
            vec4( 0,  0, -1, 0),
            vec4( 0,  1,  0, 0),
            vec4( 1,  0,  0, 0),
            vec4(-light.position.zy, light.position.x, 1.0)

        );
        break;
    case 2: // POSITIVE_Y
        view = mat4(
            vec4( 1,  0,  0, 0),
            vec4( 0,  0,  1, 0),
            vec4( 0, -1,  0, 0),
            vec4(-light.position.x, light.position.z, -light.position.y, 1.0)
        );
        break;
    case 3: // NEGATIVE_Y
        view = mat4(
            vec4( 1,  0,  0, 0),
            vec4( 0,  0, -1, 0),
            vec4( 0,  1,  0, 0),
            vec4(-light.position.xz, light.position.y, 1.0)
        );
        break;
    case 4: // POSITIVE_Z
        view = mat4(
            vec4( 1.0,  0.0,  0.0, 0.0),
            vec4( 0.0,  1.0,  0.0, 0.0),
            vec4( 0.0,  0.0,  1.0, 0.0),
            vec4(-light.position.xyz, 1.0)
        );
        break;
    case 5: // NEGATIVE_Z
        view = mat4(
            vec4(-1.0,  0.0,  0.0, 0.0),
            vec4( 0.0,  1.0,  0.0, 0.0),
            vec4( 0.0,  0.0, -1.0, 0.0),
            vec4( light.position.x, -light.position.y, light.position.z, 1.0)
        );
        break;
    }

    outVertexPosition = vertexTransform * vec4(inPosition, 1.0);
    outLightPosition = light.position.xyz;
    gl_Position = projection * view * outVertexPosition;
}