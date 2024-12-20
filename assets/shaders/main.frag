#version 450

struct Light {
    mat4 mvp;
    vec4 position;
    vec4 colourIntensity;
};

layout(binding = 3) readonly buffer LightBuffer {
    Light[] lights;
} lightBuffer;

layout(binding = 4) uniform sampler2DArray albidoArray;
layout(binding = 5) uniform sampler2DArray normalArray;
layout(binding = 6) uniform sampler2D shadowMap;

layout(location = 0) in vec4 inPosition;
layout(location = 1) in vec3 inUV;
layout(location = 2) in vec3 inNormal;

layout(location = 0) out vec4 outColour;

#define ambientLight 0.0

float textureProj(vec4 shadowCoord) {
    float dist = texture(shadowMap, shadowCoord.st).r;
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
    vec3 cumulativeColour = vec3(ambientLight);
    
    vec3 normal = outerProduct(inNormal, vec3(0.0, 0.0, 1.0)) * (texture(normalArray, inUV).xyz - 0.5) * 2.0;
    vec3 relativePosition = lightBuffer.lights[0].position.xyz - inPosition.xyz;
    float lightSquareDistance = dot(relativePosition, relativePosition);
    vec3 negativeLightDirection = normalize(relativePosition);
    float lambertainCoefficient = clamp(dot(normal, negativeLightDirection), 0.0, 1.0);

    vec4 vertexPos = biasMat * lightBuffer.lights[0].mvp * inPosition;

    float shadow = textureProj(vertexPos / vertexPos.w);
    outColour = texture(albidoArray, inUV) * shadow * lambertainCoefficient * lightBuffer.lights[0].colourIntensity / lightSquareDistance;
}