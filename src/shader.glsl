@header package main
@header import sg "../sokol/gfx"

@vs vs
in vec2 position;
in vec3 color0;
in vec2 world_pos;
in float world_rot;
in vec2 world_scale;
in float aspect_ratio;

out vec3 color;

void main() {
    float c = cos(world_rot);
    float s = sin(world_rot);

    vec2 scaled = position * world_scale;

    vec2 rotated;
    rotated.x = scaled.x * c - scaled.y * s;
    rotated.y = scaled.x * s + scaled.y * c;

    vec2 final_pos = rotated + world_pos;
    final_pos.x /= aspect_ratio;

    gl_Position = vec4(final_pos, 0.0, 1.0);
    color = color0;
}
@end

@fs fs
in vec3 color;
out vec4 frag_color;

void main() {
    frag_color = vec4(color, 1.0);
}
@end

@program simple vs fs
