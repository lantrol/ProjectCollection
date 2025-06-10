package main

import "core:fmt"
import "core:time"
import "core:strings"
import glm "core:math/linalg/glsl"
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

	window := sdl.CreateWindow("Example", 800, 800, sdl.WindowFlags{.OPENGL})
	defer sdl.DestroyWindow(window)

	gl_context := sdl.GL_CreateContext(window)
	defer sdl.GL_DestroyContext(gl_context)
	sdl.GL_MakeCurrent(window, gl_context)

	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, sdl.gl_set_proc_address)

	pid, ok := gl.load_shaders_source(vertex_shader, frag_shader)
	if !ok {
		fmt.eprintln("Error creando programa")
		return
	}
	defer gl.DeleteProgram(pid)

	// attrib := strings.clone_to_cstring("tex_coord")
	// fmt.println(gl.GetAttribLocation(program, attrib))
	// delete(attrib)

	// uniforms := gl.get_uniforms_from_program(program)
	// defer delete(uniforms)

	// screen: myGl.Geometry = myGl.createQuadFS()
	// defer myGl.deleteGeometry(&screen)

	program: myGl.Program = {id = pid}
	gl.CreateVertexArrays(1, &program.vao)
	
	screen_vert := []myGl.Vertex {
		{{-1, 1, 0}, {0, 1}},
		{{-1, -1, 0}, {0, 0}},
		{{1, 1, 0}, {1, 1}},
		{{1, -1, 0}, {1, 0}},
	}
	vbo : u32 = myGl.createBuffer(screen_vert)
	fmt.println("Buffer Creado")
	myGl.bindAttributes(program, vbo, {{gl.FLOAT, 3, "vert_position"}, {gl.FLOAT, 2, "tex_coord"}})
	fmt.println("Binding hecho")

	data := []u8{255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 255, 255, 255, 255, 0, 255}
	texture: myGl.Texture = myGl.createTexture(2, 2)
	myGl.writeTexture(texture, data, 4, 2, 2)
	defer gl.DeleteTextures(1, &texture.id)

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
		gl.UseProgram(program.id)
		gl.BindVertexArray(program.vao)
		gl.BindTextureUnit(0, texture.id)
		//gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

		sdl.GL_SwapWindow(window)
	}
}

// layout(location=0)
// layout(location=1)

vertex_shader: string = `
#version 460 core

in vec3 vert_position;
in vec2 tex_coord;

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
