package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:time"

import gl "vendor:OpenGL"
import SDL "vendor:sdl2"

GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

main :: proc() {
	// SDL and OpenGL Startup
	TEXTURE_WIDTH :: 1920
	TEXTURE_HEIGHT :: 1080
	WINDOW_WIDTH: i32 = 1280
	WINDOW_HEIGHT: i32 = 720

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
	SDL.GL_SetSwapInterval(0)

	// Vertex definition and texture creation
	Vertex :: struct {
		pos: glm.vec3,
		tex: glm.vec2,
	}
	screen_vert := []Vertex {
		{{-1, 1, 0}, {0, 1}},
		{{-1, -1, 0}, {0, 0}},
		{{1, 1, 0}, {1, 1}},
		{{1, -1, 0}, {1, 0}},
	}
	screen_elems := []u32{0, 1, 2, 1, 2, 3}
	texture := make([]u8, TEXTURE_WIDTH * TEXTURE_HEIGHT * 3)

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

	// Screen geometry buffers
	vao: u32
	gl.GenVertexArrays(1, &vao);defer gl.DeleteVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	vbo, ebo: u32
	gl.GenBuffers(1, &vbo);defer gl.DeleteBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		size_of(screen_vert[0]) * len(screen_vert),
		raw_data(screen_vert),
		gl.STATIC_DRAW,
	)
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, tex))


	gl.GenBuffers(1, &ebo);defer gl.DeleteBuffers(1, &ebo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(screen_elems) * size_of(screen_elems[0]),
		raw_data(screen_elems),
		gl.STATIC_DRAW,
	)

	// Creating texture and loading values
	canvas0, canvas1: u32
	gl.GenTextures(1, &canvas0);defer gl.DeleteTextures(1, &canvas0)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, canvas0)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGB,
		TEXTURE_WIDTH,
		TEXTURE_HEIGHT,
		0,
		gl.RGB,
		gl.UNSIGNED_BYTE,
		&texture[0],
	)

	gl.GenTextures(1, &canvas1);defer gl.DeleteTextures(1, &canvas1)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, canvas1)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGB,
		TEXTURE_WIDTH,
		TEXTURE_HEIGHT,
		0,
		gl.RGB,
		gl.UNSIGNED_BYTE,
		&texture[0],
	)

	// Framebuffers for writing to textures
	fbo0, fbo1: u32
	gl.GenFramebuffers(1, &fbo0); defer gl.DeleteFramebuffers(1, &fbo0)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo0)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, canvas0, 0)

	gl.GenFramebuffers(1, &fbo1); defer gl.DeleteFramebuffers(1, &fbo1)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo1)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, canvas1, 0)


	start_tick := time.tick_now()
	mouse_x, mouse_y: i32
	prev_mouse_pos: glm.ivec2 = {0, 0}
	mouse_bits: u32
	paint_radius: i32 = 8
	paint_color: glm.vec3 = {1, 1, 1}
	painting: bool = false
	resizing: bool = false

	gl.Viewport(0, 0, TEXTURE_WIDTH, TEXTURE_HEIGHT)
	loop: for {
		duration := time.tick_since(start_tick)
		t := f32(time.duration_seconds(duration))

		if t < f32(1. / 1000.) {
			continue
		} else {
			start_tick = time.tick_now()
		}

		resizing = false

		// event polling
		event: SDL.Event
		for SDL.PollEvent(&event) {
			// #partial switch tells the compiler not to error if every case is not present
			#partial switch event.type {
			case .KEYDOWN:
				#partial switch event.key.keysym.sym {
				case .ESCAPE:
					break loop
				case .NUM1:
					paint_color = {1, 1, 1}
				case .NUM2:
					paint_color = {0, 0, 0}
				case .NUM3:
					paint_color = {1, 0, 0}
				case .NUM4:
					paint_color = {0, 1, 0}
				case .NUM5:
					paint_color = {0, 0, 1}
				case .NUM8:
					for i: i32 = 0; i < TEXTURE_WIDTH * TEXTURE_HEIGHT * 3; i += 1 {
						texture[i] = 255
					}
					gl.BindTexture(gl.TEXTURE_2D, canvas0)
					gl.TexImage2D(
						gl.TEXTURE_2D,
						0,
						gl.RGB,
						TEXTURE_WIDTH,
						TEXTURE_HEIGHT,
						0,
						gl.RGB,
						gl.UNSIGNED_BYTE,
						&texture[0],
					)
				case .NUM9:
					for i: i32 = 0; i < TEXTURE_WIDTH * TEXTURE_HEIGHT * 3; i += 1 {
						texture[i] = 0
					}
					gl.BindTexture(gl.TEXTURE_2D, canvas0)
					gl.TexImage2D(
						gl.TEXTURE_2D,
						0,
						gl.RGB,
						TEXTURE_WIDTH,
						TEXTURE_HEIGHT,
						0,
						gl.RGB,
						gl.UNSIGNED_BYTE,
						&texture[0],
					)
				}
			case .QUIT:
				break loop
			case .MOUSEWHEEL:
				paint_radius += event.wheel.y
				if paint_radius < 1 do paint_radius = 1
			case .WINDOWEVENT:
				resizing = true
				if event.window.event == .RESIZED {
					WINDOW_WIDTH = event.window.data1
					WINDOW_HEIGHT = event.window.data2
				}
			}
		}

		// Getting values
		prev_mouse_pos = {mouse_x, mouse_y}
		mouse_bits = SDL.GetMouseState(&mouse_x, &mouse_y)
		if mouse_bits == 1 && painting == false {
			painting = true
			prev_mouse_pos = {mouse_x, mouse_y}
		} else if mouse_bits == 0 && painting {
			painting = false
		}

		gl.ClearColor(0.4, 0.4, 0.4, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		if painting {
			gl.UseProgram(program)
			gl.BindVertexArray(vao)
			gl.BindTexture(gl.TEXTURE_2D, canvas0)

			gl.Uniform2i(render_uniforms["mouse_pos"].location, mouse_x, mouse_y)
			gl.Uniform2i(
				render_uniforms["prev_mouse_pos"].location,
				prev_mouse_pos.x,
				prev_mouse_pos.y,
			)
			gl.Uniform1i(render_uniforms["screen_height"].location, WINDOW_HEIGHT)
			gl.Uniform1i(render_uniforms["canvas"].location, 0)
			gl.Uniform3f(
				render_uniforms["paint_color"].location,
				paint_color.x,
				paint_color.y,
				paint_color.z,
			)
			gl.Uniform1i(render_uniforms["paint_radius"].location, paint_radius)
			gl.Uniform1i(render_uniforms["painting"].location, 1)

			gl.BindFramebuffer(gl.FRAMEBUFFER, fbo1)
			gl.DrawElements(gl.TRIANGLES, i32(len(screen_elems)), gl.UNSIGNED_INT, nil)

			gl.BindTexture(gl.TEXTURE_2D, canvas1)
			gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
			gl.DrawElements(gl.TRIANGLES, i32(len(screen_elems)), gl.UNSIGNED_INT, nil)

			fbo0, fbo1 = fbo1, fbo0
			canvas0, canvas1 = canvas1, canvas0
		} else {
			gl.UseProgram(program)
			gl.BindVertexArray(vao)
			gl.BindTexture(gl.TEXTURE_2D, canvas0)

			gl.Uniform2i(render_uniforms["mouse_pos"].location, mouse_x, mouse_y)
			gl.Uniform2i(
				render_uniforms["prev_mouse_pos"].location,
				prev_mouse_pos.x,
				prev_mouse_pos.y,
			)
			gl.Uniform1i(render_uniforms["screen_height"].location, WINDOW_HEIGHT)
			gl.Uniform1i(render_uniforms["canvas"].location, 0)
			gl.Uniform3f(
				render_uniforms["paint_color"].location,
				paint_color.x,
				paint_color.y,
				paint_color.z,
			)
			gl.Uniform1i(render_uniforms["paint_radius"].location, paint_radius)
			gl.Uniform1i(render_uniforms["painting"].location, 0)

			gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

			gl.DrawElements(gl.TRIANGLES, i32(len(screen_elems)), gl.UNSIGNED_INT, nil)
		}
		SDL.GL_SwapWindow(window)
		gl.Finish()
	}
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
