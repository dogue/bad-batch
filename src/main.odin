package main

import "core:fmt"
import "base:runtime"
import "core:math/linalg"
import sg "../sokol/gfx"
import sapp "../sokol/app"
import sglue "../sokol/glue"

MAX_SPRITES :: 10_000
VERTICES_PER_SPRITE :: 4
INDICES_PER_SPRITE :: 6

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

Entity :: struct {
    using _: Sprite,
    update_proc: proc(^Entity),
}

GameState :: struct {
    entities: [dynamic]Entity,
}

BatchVertex :: struct {
    pos: Vec2,
    color: Vec4,
    world_pos: Vec2,
    world_rot: f32,
    world_scale: Vec2,
    aspect_ratio: f32,
    outline: Vec4,
}

Renderer :: struct {
    pass_action: sg.Pass_Action,
    bind: sg.Bindings,
    pip: sg.Pipeline,

    vertices: [MAX_SPRITES * VERTICES_PER_SPRITE]BatchVertex,
    vertex_count: int,

    indices: [MAX_SPRITES * INDICES_PER_SPRITE]u16,
    index_count: int,

    vertex_buffer: sg.Buffer,
    aspect_ratio: f32,
}

Sprite :: struct {
    pos: Vec2,
    rot: f32,
    scale: Vec2,
    color: Vec4,
    debug: bool,
}

renderer: Renderer

spin :: proc(e: ^Entity) {
    e.rot = total_time
}

update :: proc(gs: ^GameState) {
}

init_renderer :: proc() {
    renderer.vertex_buffer = sg.make_buffer(sg.Buffer_Desc{
        size = size_of(BatchVertex) * MAX_SPRITES * VERTICES_PER_SPRITE,
        usage = .STREAM,
    })

    // pregen quad indices
    for i := 0; i < MAX_SPRITES; i += 1 {
        base := u16(i * 4)
        idx := i * 6
        renderer.indices[idx + 0] = base + 0
        renderer.indices[idx + 1] = base + 1
        renderer.indices[idx + 2] = base + 2
        renderer.indices[idx + 3] = base + 0
        renderer.indices[idx + 4] = base + 2
        renderer.indices[idx + 5] = base + 3
    }

    index_buffer := sg.make_buffer(sg.Buffer_Desc{
        type = .INDEXBUFFER,
        data = sg.Range{ptr = raw_data(renderer.indices[:]), size = size_of(renderer.indices)},
    })

    pip_desc := sg.Pipeline_Desc{
        shader = sg.make_shader(simple_shader_desc(sg.query_backend())),
        layout = {
            attrs = {
                ATTR_simple_position = { format = .FLOAT2 },
                ATTR_simple_color0 = { format = .FLOAT4 },
                ATTR_simple_world_pos = { format = .FLOAT2 },
                ATTR_simple_world_rot = { format = .FLOAT },
                ATTR_simple_world_scale = { format = .FLOAT2 },
                ATTR_simple_aspect_ratio = { format = .FLOAT },
                ATTR_simple_outline0 = { format = .FLOAT4 },
            }
        },
        colors = {
            0 = {
                blend = {
                    enabled = true,
                    src_factor_rgb = .SRC_ALPHA,
                    dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                    op_rgb = .ADD,
                    src_factor_alpha = .ONE,
                    dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
                }
            }
        },
        index_type = .UINT16,
    }

    renderer.pip = sg.make_pipeline(pip_desc)
    renderer.bind.vertex_buffers[0] = renderer.vertex_buffer
    renderer.bind.index_buffer = index_buffer
}

begin_batch :: proc() {
    renderer.vertex_count = 0
    renderer.index_count = 0
}

push_sprite :: proc(sprite: Sprite) {
    if renderer.vertex_count >= MAX_SPRITES * VERTICES_PER_SPRITE do return

    offset := renderer.vertex_count
    outline: Vec4

    if sprite.debug {
        outline = {1, 0, 1, 1}
    } else {
        outline = {0, 0, 0, 0}
    }

     renderer.vertices[offset] = BatchVertex{
        pos = {-0.5, -0.5},
        color = sprite.color,
        world_pos = sprite.pos,
        world_rot = sprite.rot,
        world_scale = sprite.scale,
        aspect_ratio = renderer.aspect_ratio,
        outline = outline,
    }

     renderer.vertices[offset + 1] = BatchVertex{
        pos = {0.5, -0.5},
        color = sprite.color,
        world_pos = sprite.pos,
        world_rot = sprite.rot,
        world_scale = sprite.scale,
        aspect_ratio = renderer.aspect_ratio,
        outline = outline,
    }

     renderer.vertices[offset + 2] = BatchVertex{
        pos = {0.5, 0.5},
        color = sprite.color,
        world_pos = sprite.pos,
        world_rot = sprite.rot,
        world_scale = sprite.scale,
        aspect_ratio = renderer.aspect_ratio,
        outline = outline,
    }

     renderer.vertices[offset + 3] = BatchVertex{
        pos = {-0.5, 0.5},
        color = sprite.color,
        world_pos = sprite.pos,
        world_rot = sprite.rot,
        world_scale = sprite.scale,
        aspect_ratio = renderer.aspect_ratio,
        outline = outline,
    }

    renderer.vertex_count += 4
    renderer.index_count += 6
}

end_batch :: proc() {
    if renderer.vertex_count == 0 do return

    sg.update_buffer(renderer.vertex_buffer, sg.Range{
        ptr = raw_data(renderer.vertices[:renderer.vertex_count]),
        size = uint(size_of(BatchVertex) * renderer.vertex_count),
    })

    sg.draw(0, renderer.index_count, 1)
}

init :: proc "c" () {
    context = runtime.default_context()

    desc := sg.Desc{
        environment = sglue.environment(),
    }
    sg.setup(desc)

    init_renderer()

    renderer.aspect_ratio = f32(sapp.width()) / f32(sapp.height())

    renderer.pass_action = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = {0.1, 0.1, 0.1, 1}},
        }
    }
}

event :: proc "c" (evt: ^sapp.Event) {
    context = runtime.default_context()

    #partial switch evt.type{
    case .RESIZED:
        renderer.aspect_ratio = sapp.widthf() / sapp.heightf()
    }
}

total_time: f32

frame :: proc "c" () {
    context = runtime.default_context()

    total_time += f32(sapp.frame_duration())
    game := cast(^GameState)sapp.userdata()
    update(game)

    sg.begin_pass({ action = renderer.pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(renderer.pip)
    sg.apply_bindings(renderer.bind)

    begin_batch()
    
    for &e in game.entities {
        if e.update_proc != nil {
            e->update_proc()
        }
        push_sprite(e)
    }
    
    end_batch()

    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = runtime.default_context()
    sg.shutdown()
}

main :: proc() {
    gs: GameState
    gs.entities = make([dynamic]Entity)

    append(&gs.entities, Entity{
        scale = {0.5, 0.5},
        color = {1, 1, 1, 1},
        debug = true,
        update_proc = proc(e: ^Entity) {
            e.rot = total_time
        },
    })

    sapp.run({
        init_cb = init,
        frame_cb = frame,
        cleanup_cb = cleanup,
        event_cb = event,
        width = 800,
        height = 600,
        window_title = "Batched Rendering",
        user_data = &gs,
    })
}
