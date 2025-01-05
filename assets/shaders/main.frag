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

#define ambientLight 0.1

float textureProj(vec4 shadowCoord, float arrayIndex) {
    float dist = texture(shadowMap, vec3(shadowCoord.xy, arrayIndex)).r;
    if (dist > shadowCoord.z) {
        return 1.0;
    }
    return 0.0;
}

float filterPCF(vec4 shadowCoord, float arrayIndex) {
	vec2 texDim = textureSize(shadowMap, 0).xy;
	vec2 scale = 1.0 / texDim;

	float sum = 0.0;
	const float range = 1.5;
	for (float x = -range; x <= range; x++) {
		for (float y = -range; y <= range; y++) {

			sum += textureProj(shadowCoord + vec4(vec2(x, y) * scale, 0.0, 0.0), arrayIndex);
		}
	}
	return sum / ((2 * range + 1) * (2 * range + 1));
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
    outColour =  vec4(clamp(pow(cumulativeColour, vec3(1 / 2.4)), ambientLight, 1.0), 1.0);
}