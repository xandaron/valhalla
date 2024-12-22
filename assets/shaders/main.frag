#version 450

layout(binding = 0) readonly uniform UniformBuffer {
	mat4 view;
	mat4 projection;
	mat4 viewProjection;
    uint lightCount;
} uniformBuffer;

struct Light {
    mat4 mvp;
    vec4 position;
    vec4 colourIntensity;
};

layout(binding = 3) readonly buffer LightBuffer {
    Light[] lights;
} lightBuffer;

layout(binding = 4) uniform sampler2DArray albedoArray;
layout(binding = 5) uniform sampler2DArray normalArray;
layout(binding = 6) uniform sampler2DArray shadowMap;

layout(location = 0) in vec4 inPosition;
layout(location = 1) in vec3 inUV;
layout(location = 2) in vec3 inNormal;

layout(location = 0) out vec4 outColour;

#define ambientLight 0.0

float textureProj(vec4 shadowCoord, float arrayIndex) {
    float dist = texture(shadowMap, vec3(shadowCoord.st, arrayIndex)).r;
    if (dist > shadowCoord.z) {
        return 1.0;
    }
    return 0.0;
}

const mat4 biasMat = mat4( 
	0.5, 0.0, 0.0, 0.0,
	0.0, 0.5, 0.0, 0.0,
	0.0, 0.0, 1.0, 0.0,
	0.5, 0.5, 0.0, 1.0 
);

void main() {
    vec3 cumulativeColour = vec3(0.0);
    vec3 albedo = texture(albedoArray, inUV).xyz;
    vec3 normal = outerProduct(inNormal, vec3(0.0, 0.0, 1.0)) * (texture(normalArray, inUV).xyz - 0.5) * 2.0;

    for (uint i = 0; i < uniformBuffer.lightCount; i++) {
        vec3 relativePosition = lightBuffer.lights[i].position.xyz - inPosition.xyz;
        float lightSquareDistance = dot(relativePosition, relativePosition);
        vec3 negativeLightDirection = normalize(relativePosition);
        float lambertainCoefficient = clamp(dot(normal, negativeLightDirection), 0.0, 1.0);

        vec4 vertexPos = biasMat * lightBuffer.lights[i].mvp * inPosition;

        float shadow = textureProj(vertexPos / vertexPos.w, float(i));
        cumulativeColour += albedo * shadow * lambertainCoefficient * lightBuffer.lights[i].colourIntensity.xyz / lightSquareDistance;
    }

    outColour = vec4(cumulativeColour, 1.0);
    // vec4 vertexPos = biasMat * lightBuffer.lights[1].mvp * inPosition;
    // outColour = vec4(textureProj(vertexPos / vertexPos.w, 0.0));
    // outColour = vec4(albedo * textureProj(vertexPos / vertexPos.w, 1.0), 1.0);
}