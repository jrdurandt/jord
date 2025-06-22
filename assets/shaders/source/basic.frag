#version 460 core

layout(set = 2, binding = 0) uniform sampler2D uAlbedo;

layout(location = 0) in vec2 fragTexCoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 albedo_tex = texture(uAlbedo, fragTexCoord);
    outColor = albedo_tex;
}
