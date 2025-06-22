#version 460 core

layout(set = 1, binding = 0) uniform Camera {
    mat4 model;
    mat4 view;
    mat4 projection;
};

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;

layout(location = 0) out vec2 fragTexCoord;

void main() {
    gl_Position = projection * view * model * vec4(inPosition, 1.0);
    fragTexCoord = inTexCoord;
}
