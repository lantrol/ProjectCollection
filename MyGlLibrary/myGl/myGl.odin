package MyGl

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
//import SDL "vendor:sdl2"

Vertex :: struct {
	pos: [3]f32,
	tex: [2]f32,
}

Texture :: struct {
	texture: u32,
	fbo:     u32,
}

Geometry :: struct {
	vao: u32,
	vbo: u32,
	ebo: u32,
}

TextureDesc :: struct {
	wrap:   i32,
	filter: i32,
}

CreateTexture :: proc(
	width, height: i32,
	data: []u8 = nil,
	desc: TextureDesc = TextureDesc{gl.REPEAT, gl.NEAREST},
) -> (
	texture: u32,
) {
	gl.CreateTextures(gl.TEXTURE_2D, 1, &texture)

	gl.TextureParameteri(texture, gl.TEXTURE_WRAP_S, desc.wrap)
	gl.TextureParameteri(texture, gl.TEXTURE_WRAP_T, desc.wrap)
	gl.TextureParameteri(texture, gl.TEXTURE_MIN_FILTER, desc.filter)
	gl.TextureParameteri(texture, gl.TEXTURE_MAG_FILTER, desc.filter)

	gl.TextureStorage2D(texture, 1, gl.RGBA8, width, height)
	if data != nil {
		gl.TextureSubImage2D(
			texture,
			0,
			0,
			0,
			width,
			height,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			raw_data(data),
		)
	}
	return texture
}

CreateQuadFS :: proc() -> (quad: Geometry) {
	screen_vert := []Vertex {
		{{-1, 1, 0}, {0, 1}},
		{{-1, -1, 0}, {0, 0}},
		{{1, 1, 0}, {1, 1}},
		{{1, -1, 0}, {1, 0}},
	}
	screen_elems := []u32{0, 1, 2, 1, 2, 3}

	gl.CreateVertexArrays(1, &quad.vao)
	gl.CreateBuffers(1, &quad.vbo)
	gl.CreateBuffers(1, &quad.ebo)

	gl.NamedBufferData(
		quad.vbo,
		size_of(screen_vert[0]) * len(screen_vert),
		raw_data(screen_vert),
		gl.STATIC_DRAW,
	)
	gl.NamedBufferData(
		quad.ebo,
		size_of(screen_elems[0]) * len(screen_elems),
		raw_data(screen_elems),
		gl.STATIC_DRAW,
	)

	gl.EnableVertexArrayAttrib(quad.vao, 0)
	gl.VertexArrayAttribBinding(quad.vao, 0, 0)
	gl.VertexArrayAttribFormat(quad.vao, 0, 3, gl.FLOAT, false, 0)

	gl.EnableVertexArrayAttrib(quad.vao, 1)
	gl.VertexArrayAttribBinding(quad.vao, 1, 0)
	gl.VertexArrayAttribFormat(quad.vao, 1, 2, gl.FLOAT, false, 3 * size_of(f32))

	gl.VertexArrayVertexBuffer(quad.vao, 0, quad.vbo, 0, 5 * size_of(f32))
	gl.VertexArrayElementBuffer(quad.vao, quad.ebo)

	return quad
}

DeleteGeometry :: proc(quad: ^Geometry) {
	gl.DeleteVertexArrays(1, &(quad.vao))
	gl.DeleteBuffers(1, &(quad.vbo))
	gl.DeleteBuffers(1, &(quad.ebo))
}
