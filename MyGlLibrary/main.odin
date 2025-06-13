package main

import "core:fmt"
import "core:os"
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

	program, ok := gl.load_shaders_source(vertex_shader, frag_shader)
	if !ok {
		fmt.eprintln("Error creando programa")
		return
	}
	defer gl.DeleteProgram(program)

	// uniforms := gl.get_uniforms_from_program(program)
	// defer delete(uniforms)

	// screen: myGl.Geometry = myGl.createQuadFS()
	// defer myGl.deleteGeometry(&screen)

	emptyVao: u32
	gl.GenVertexArrays(1, &emptyVao)

	quadMesh := myGl.createQuadFS()
	defer myGl.deleteMesh(&quadMesh)

	data := []f32{1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1}
	texture: myGl.Texture = myGl.createTexture2D(2, 2, gl.RGBA32F)
	myGl.writeTexture2D(texture, data, 4, 2, 2)
	defer gl.DeleteTextures(1, &texture.id)

	quadFS := myGl.createRenderable(quadMesh, program, texture)

	// Compute Shader
	compute: u32
	compute, ok = gl.load_compute_source(compute_shader)
	if !ok {
		fmt.eprintln("ERROR: compute shader no creado correctamente")
		os.exit(-1)
	}
	defer gl.DeleteProgram(compute)


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

		// empty vao to avoid no rendering
		gl.BindVertexArray(emptyVao)

		// Compute
		gl.UseProgram(compute)
		gl.BindImageTexture(0, texture.id, 0, false, 0, gl.WRITE_ONLY, gl.RGBA32F)
		gl.DispatchCompute(2, 2, 1)
		//gl.MemoryBarrier(gl.SHADER_IMAGE_ACCESS_BARRIER_BIT)
		gl.MemoryBarrier(gl.ALL_BARRIER_BITS)


		// Draw
		//myGl.drawGeometry(geo)
		//myGl.renderMesh(quadMesh, program, texture)
		myGl.setUniform(quadFS.material.shader, "color", []f32{0.5, 0.5, 1})
		myGl.renderMesh(quadMesh, program, texture)
		//myGl.render(quadFS)

		sdl.GL_SwapWindow(window)
	}
}

// layout(location=0)
// layout(location=1)

vertex_shader2: string = `
#version 460 core

in vec3 vert_position;
in vec2 tex_coord;

out vec2 uvs;

void main() {
    uvs = tex_coord;
    gl_Position = vec4(vert_position, 1.0);
}
`

vertex_shader: string = `
#version 460 core

struct VertexData {
	float position[3];
	float uv[2];
};

layout(binding = 0, std430) readonly buffer ssbo1 {
	VertexData data[];
};

out vec2 uvs;

vec3 getPosition(int index) {
    return vec3(
        data[index].position[0], 
        data[index].position[1], 
        data[index].position[2]
    );
}

vec2 getUV(int index) {
    return vec2(
        data[index].uv[0], 
        data[index].uv[1]
    );
}

void main() {
    uvs = getUV(gl_VertexID);
    gl_Position = vec4(getPosition(gl_VertexID), 1.0);
}
`

frag_shader: string = `
#version 460 core

layout(binding = 0) uniform sampler2D textura;
uniform vec3 color;

in vec2 uvs;
out vec4 frag_color;

void main() {
    frag_color = texture(textura, uvs);
    frag_color.xyz = frag_color.xyz*color;
}

`

compute_shader: string = `
#version 460 core
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f, binding = 0) uniform image2D img_output;

void main() {
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
	vec4 color = vec4(1., 1., 1., 1.);
	imageStore(img_output, pixel_coords, color);
}

`
