#version 450

layout(binding = 3) uniform sampler2D texSampler;

layout(location = 0) in vec2 fragTexCoord;
layout(location = 1) in vec4 fragColour;
layout(location = 2) flat in uint samplerOffset;

layout(location = 0) out vec4 outColor;

void main() {
    // uint offset = SamplerOffset.offset[instanceIndex];
    // if (offset == 0) {
    //     outColor = vec4(1,0,0,1);
    // }
    // else if (offset == 1) {
    //     outColor = vec4(0,1,0,1);
    // }
    // else if (offset == 2) {
    //     outColor = vec4(0,0,1,1);
    // }
    // else {
    //     outColor = vec4(1,1,1,1);
    // }
    outColor = texture(texSampler, fragTexCoord);
    // outColor = fragColour;
}