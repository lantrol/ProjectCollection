package MyGl

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import SDL "vendor:sdl2"

Vertex :: struct {
	pos: glm.vec3,
	tex: glm.vec2,
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

GenTexture :: proc(width, height: i32) -> (texture: Texture) {
	gl.GenTextures(1, &texture.texture)
	gl.TextureParameteri(texture.texture, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TextureParameteri(texture.texture, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TextureParameteri(texture.texture, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TextureParameteri(texture.texture, gl.TEXTURE_WRAP_T, gl.REPEAT)

	return texture
}

CreateQuad :: proc() -> (quad: Geometry) {
	screen_vert := []Vertex {
		{{-1, 1, 0}, {0, 1}},
		{{-1, -1, 0}, {0, 0}},
		{{1, 1, 0}, {1, 1}},
		{{1, -1, 0}, {1, 0}},
	}
	screen_elems := []u32{0, 1, 2, 1, 2, 3}

	gl.CreateVertexArrays(1, &quad.vao)
	gl.EnableVertexArrayAttrib(quad.vao, 0)
	gl.EnableVertexArrayAttrib(quad.vao, 1)

	gl.CreateBuffers(1, &quad.vbo)
	gl.CreateBuffers(1, &quad.vbo)
	gl.NamedBufferStorage(
		quad.vbo,
		size_of(screen_vert[0]) * len(screen_vert),
		raw_data(screen_vert),
		gl.STATIC_DRAW,
	)
	gl.NamedBufferStorage(
		quad.ebo,
		len(screen_elems) * size_of(screen_elems[0]),
		raw_data(screen_elems),
		gl.STATIC_DRAW,
	)

	gl.VertexArrayVertexBuffer(quad.vao, 0, quad.vbo, 3 * size_of(f32), size_of(Vertex))
	gl.VertexArrayAttribFormat(quad.vao, 0, 3, gl.FLOAT)

	return quad
}
