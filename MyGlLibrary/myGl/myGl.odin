package MyGl

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "core:strings"
import "core:slice"

Vertex :: struct {
	pos: [3]f32,
	tex: [2]f32,
}

Geometry :: struct {
	ssbo: 		u32,
	amount: 	i32,
	mode: 		u32,
	program: 	u32,
	texture: 	Texture,
}

Texture :: struct {
	id:             u32,
	width:          i32,
	height:         i32,
	internalformat: u32,
}

createTexture :: proc(
	width, height: i32,
	internalformat: u32 = gl.RGBA8,
	wrap: i32 = gl.REPEAT,
	filter: i32 = gl.NEAREST,
) -> (
	texture: Texture,
) {
	gl.CreateTextures(gl.TEXTURE_2D, 1, &texture.id)

	gl.TextureParameteri(texture.id, gl.TEXTURE_WRAP_S, wrap)
	gl.TextureParameteri(texture.id, gl.TEXTURE_WRAP_T, wrap)
	gl.TextureParameteri(texture.id, gl.TEXTURE_MIN_FILTER, filter)
	gl.TextureParameteri(texture.id, gl.TEXTURE_MAG_FILTER, filter)

	gl.TextureStorage2D(texture.id, 1, internalformat, width, height)

	texture.internalformat = internalformat
	texture.width = width
	texture.height = height
	return texture
}

writeTexture :: proc(texture: Texture, data: []$T, components: u32, width, height: i32) {
	format, type: u32

	switch typeid_of(T) {
	case u8:
		type = gl.UNSIGNED_BYTE
	case u16:
		type = gl.UNSIGNED_SHORT
	case u32:
		type = gl.UNSIGNED_INT
	case i8:
		type = gl.BYTE
	case i16:
		type = gl.SHORT
	case i32:
		type = gl.INT
	case f16:
		type = gl.HALF_FLOAT
	case f32:
		type = gl.FLOAT
	case f64:
		type = gl.DOUBLE
	case:
		fmt.eprintln("ERROR: Tipo de dato inválido")
		return
	}

	switch components {
	case 1:
		format = gl.RED
	case 2:
		format = gl.RG
	case 3:
		format = gl.RGB
	case 4:
		format = gl.RGBA
	case:
		fmt.eprintln("ERROR: Numero de componentes inválido")
		return
	}

	if data != nil {
		gl.TextureSubImage2D(
			texture.id,
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
}

createBuffer :: proc(data: []$T, usage: u32 = gl.STATIC_DRAW) -> (vbo: u32) {
	gl.CreateBuffers(1, &vbo)
	gl.NamedBufferData(
		vbo,
		size_of(data[0]) * len(data),
		raw_data(slice.to_bytes(data)),
		usage,
	)
	return vbo
}


Program :: struct {
	id: u32,
	vao: u32
}

bindAttributes :: proc(program: Program, vbo: u32, attributes: []struct {
		type: u32,
		amount: i32,
		name: string,
	}) -> (ok: bool) {

	offset: i32 = 0
	for attribute, index in attributes {
		attribName: cstring = strings.clone_to_cstring(attribute.name)
		defer delete(attribName)
		attribLocation := gl.GetAttribLocation(program.id, attribName)

		if attribLocation == -1 {
			fmt.eprintln("ERROR: atributo no encontrado")
			return false
		}
		gl.EnableVertexArrayAttrib(program.vao, u32(index))
		gl.VertexArrayAttribBinding(program.vao, u32(attribLocation), 0)

		typeSize, ok := getTypeSize(attribute.type)
		gl.VertexArrayAttribFormat(
			program.vao,
			u32(attribLocation),
			attribute.amount,
			attribute.type,
			false,
			u32(offset * typeSize)
		)
		offset += attribute.amount
	}
	typeSize, okay := getTypeSize(attributes[0].type)
	gl.VertexArrayVertexBuffer(program.vao, 0, vbo, 0, offset * typeSize)
	return true
}


// createQuadFS :: proc() -> (quad: Geometry) {
// 	screen_vert := []Vertex {
// 		{{-1, 1, 0}, {0, 1}},
// 		{{-1, -1, 0}, {0, 0}},
// 		{{1, 1, 0}, {1, 1}},
// 		{{1, -1, 0}, {1, 0}},
// 	}
// 	screen_elems := []u32{0, 1, 2, 1, 2, 3}

// 	gl.CreateVertexArrays(1, &quad.vao)
// 	gl.CreateBuffers(1, &quad.vbo)
// 	gl.CreateBuffers(1, &quad.ebo)

// 	gl.NamedBufferData(
// 		quad.vbo,
// 		size_of(screen_vert[0]) * len(screen_vert),
// 		raw_data(screen_vert),
// 		gl.STATIC_DRAW,
// 	)
// 	gl.NamedBufferData(
// 		quad.ebo,
// 		size_of(screen_elems[0]) * len(screen_elems),
// 		raw_data(screen_elems),
// 		gl.STATIC_DRAW,
// 	)

// 	gl.EnableVertexArrayAttrib(quad.vao, 0)
// 	gl.VertexArrayAttribBinding(quad.vao, 0, 0)
// 	gl.VertexArrayAttribFormat(quad.vao, 0, 3, gl.FLOAT, false, 0)

// 	gl.EnableVertexArrayAttrib(quad.vao, 1)
// 	gl.VertexArrayAttribBinding(quad.vao, 1, 0)
// 	gl.VertexArrayAttribFormat(quad.vao, 1, 2, gl.FLOAT, false, 3 * size_of(f32))

// 	gl.VertexArrayVertexBuffer(quad.vao, 0, quad.vbo, 0, 5 * size_of(f32))
// 	gl.VertexArrayElementBuffer(quad.vao, quad.ebo)

// 	return quad
// }

createGeometry :: proc(data: []$T, usage: u32 = gl.DYNAMIC_STORAGE_BIT) -> (geo: Geometry) {
	ssbo: u32
	gl.CreateBuffers(1, &ssbo)
	gl.NamedBufferStorage(
		ssbo,
		size_of(data[0]) * len(data),
		raw_data(data),
		usage,
	)
	geo.mode = gl.TRIANGLE_STRIP
	geo.ssbo = ssbo
	geo.amount = i32(len(data))
	return geo
}

drawGeometry :: proc(geo: Geometry) {
	gl.UseProgram(geo.program)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, geo.ssbo)
	gl.BindTextureUnit(0, geo.texture.id)
	gl.DrawArrays(geo.mode, 0, geo.amount)
}

deleteGeometry :: proc(geo: ^Geometry) {
	gl.DeleteBuffers(1, &(geo.ssbo))
	geo^ = {}
}

createQuadFS :: proc() -> (geo: Geometry) {
	screen_vert := []Vertex {
		{{-1, 1, 0}, {0, 1}},
		{{-1, -1, 0}, {0, 0}},
		{{1, 1, 0}, {1, 1}},
		{{1, -1, 0}, {1, 0}},
	}
	return createGeometry(screen_vert)
}
