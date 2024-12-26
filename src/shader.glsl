@header package main
@header import sg "../sokol/gfx"

@vs vs
in vec2 position;
in vec4 color0;
in vec2 world_pos;
in float world_rot;
in vec2 world_scale;
in float aspect_ratio;
in vec4 outline0;

out vec4 color;
out vec2 uv;
out vec4 outline;

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
    uv = position + 0.5;
    outline = outline0;
}
@end

@fs fs
in vec4 color;
in vec2 uv;
in vec4 outline;
out vec4 frag_color;

void main() {
    float thickness = 0.005;
    vec2 uv_center = uv - 0.5;
    float dist = max(abs(uv_center.x), abs(uv_center.y));
    if (dist > (0.5 - thickness) && dist < 0.5) {
        frag_color = outline;
    } else {
        frag_color = color;
    }
}
@end

@program simple vs fs
