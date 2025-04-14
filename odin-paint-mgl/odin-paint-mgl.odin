package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:time"
import "myGl"

import gl "vendor:OpenGL"
import SDL "vendor:sdl2"

GL_VERSION_MAJOR :: 4
GL_VERSION_MINOR :: 6

main :: proc() {
	WINDOW_WIDTH: i32 = 1280
	WINDOW_HEIGHT: i32 = 720
	TEXTURE_WIDTH: i32 = 1920
	TEXTURE_HEIGHT: i32 = 1080

	SDL.Init({.VIDEO})
	defer SDL.Quit()

	window := SDL.CreateWindow(
		"PIZARRA",
		SDL.WINDOWPOS_UNDEFINED,
		SDL.WINDOWPOS_UNDEFINED,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		{.OPENGL, .RESIZABLE},
	)
	if window == nil {
		fmt.eprintln("Error creando ventana")
		return
	}
	defer SDL.DestroyWindow(window)

	SDL.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(SDL.GLprofile.CORE))
	SDL.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, GL_VERSION_MAJOR)
	SDL.GL_SetAttribute(.CONTEXT_MINOR_VERSION, GL_VERSION_MINOR)

	gl_context := SDL.GL_CreateContext(window)
	defer SDL.GL_DeleteContext(gl_context)

	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, SDL.gl_set_proc_address)

	// Uncap FrameRate
	// SDL.GL_SetSwapInterval(0)

	// Vertex definition and texture creation
	screen_vert := []myGl.Vertex {
		{{-1, 1, 0}, {0, 1}},
		{{-1, -1, 0}, {0, 0}},
		{{1, 1, 0}, {1, 1}},
		{{1, -1, 0}, {1, 0}},
	}
	screen_elems := []u32{0, 1, 2, 1, 2, 3}
	texture := make([]u8, TEXTURE_WIDTH * TEXTURE_HEIGHT * 3)
	defer delete(texture)

	// Program creation
	program, paint_program: u32
	program_ok: bool

	program, program_ok = gl.load_shaders_source(vert_shader, frag_shader)
	if !program_ok {
		fmt.eprintln("Error cargando shaders")
		return
	}
	defer gl.DeleteProgram(program)

	// Getting program uniforms
	render_uniforms := gl.get_uniforms_from_program(program)
	defer delete(render_uniforms)
	paint_uniforms := gl.get_uniforms_from_program(paint_program)
	defer delete(paint_uniforms)
}

vert_shader := `
#version 330 core

layout(location=0) in vec3 vert_position;
layout(location=1) in vec2 in_tex_coord;

out vec2 texCoord;

void main() {
    gl_Position = vec4(vert_position, 1.0);
    texCoord = in_tex_coord;
}
`


frag_shader := `
#version 330 core

uniform ivec2 mouse_pos;
uniform ivec2 prev_mouse_pos;
uniform vec3 paint_color;
uniform int screen_height;
uniform int paint_radius;
uniform int painting;
uniform sampler2D canvas;

in vec2 texCoord;
out vec4 out_color;

void main() {
    ivec2 cur_pos = ivec2(gl_FragCoord.x, screen_height-gl_FragCoord.y);
    out_color = vec4(0., 0., 0., 1.);
    if (length(vec2(cur_pos - mouse_pos)) < paint_radius) {
        out_color = vec4(paint_color, 1.0);
    }
    else {
        out_color = vec4(texture(canvas, texCoord).xyz, 1.0);
    }

    if (painting == 1) {
        vec2 p1 = vec2(prev_mouse_pos);
        vec2 p2 = vec2(mouse_pos);

        vec2 p3 = vec2(cur_pos);
        vec2 p12 = p2 - p1;
        vec2 p13 = p3 - p1;

        float d = dot(p12, p13) / length(p12); // = length(p13) * cos(angle)
        vec2 p4 = p1 + normalize(p12) * d;
        if (length(p4 - p3) < paint_radius/* * sin01(iTime * 4.0 + length(p4 - p1)* 0.02)*/
              && length(p4 - p1) <= length(p12)
              && length(p4 - p2) <= length(p12)) {
            out_color = vec4(paint_color, 1.0);
        }
    }
}
`
