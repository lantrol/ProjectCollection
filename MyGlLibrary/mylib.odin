package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:time"
import "myGl"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

GL_VERSION_MAJOR :: 4
GL_VERSION_MINOR :: 6

main :: proc() {
	if !sdl.Init({.VIDEO, .EVENTS}) {
		fmt.eprintln("Error inicializando SDL3")
		return
	}
	defer sdl.Quit()

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, GL_VERSION_MAJOR)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, GL_VERSION_MINOR)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, gl.CONTEXT_CORE_PROFILE_BIT)

	window := sdl.CreateWindow("Sex", 800, 800, sdl.WindowFlags{.OPENGL})
	defer sdl.DestroyWindow(window)

	gl_context := sdl.GL_CreateContext(window)
	defer sdl.GL_DestroyContext(gl_context)
	sdl.GL_MakeCurrent(window, gl_context)

	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, sdl.gl_set_proc_address)

	program, ok := gl.load_shaders_source(vertex_shader, frag_shader)
	if !ok {
		fmt.eprintln("Error creando programa")
		return
	}
	defer gl.DeleteProgram(program)

	uniforms := gl.get_uniforms_from_program(program)
	defer delete(uniforms)
	fmt.println(uniforms)

	screen: myGl.Geometry = myGl.CreateQuadFS()
	defer myGl.DeleteGeometry(&screen)

	data := []u8{255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255}
	texture: u32 = myGl.CreateTexture(2, 2, data)
	defer gl.DeleteTextures(1, &texture)

	loop: for {
		event: sdl.Event
		for sdl.PollEvent(&event) {
			if event.type == .QUIT {
				break loop
			} else if event.type == .KEY_DOWN {
				if event.key.key == sdl.K_ESCAPE {
					break loop
				}
			}
		}
		gl.ClearColor(0.5, 0.5, 0.5, 1.)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// Draw
		gl.UseProgram(program)
		gl.BindVertexArray(screen.vao)
		gl.BindTextureUnit(0, texture)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

		sdl.GL_SwapWindow(window)
	}
}

vertex_shader: string = `
#version 460 core

layout(location=0) in vec3 vert_position;
layout(location=1) in vec2 tex_coord;

out vec2 uvs;

void main() {
    uvs = tex_coord;
    gl_Position = vec4(vert_position, 1.0);
}
`


frag_shader: string = `
#version 460 core

layout(binding = 0) uniform sampler2D textura;
in vec2 uvs;
out vec4 frag_color;

void main() {
    frag_color = texture(textura, uvs);
}

`
