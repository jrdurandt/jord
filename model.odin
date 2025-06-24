package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:path/filepath"

import gltf "vendor:cgltf"
import sdl "vendor:sdl3"

Material :: struct {
	albedo: Texture,
	normal: Texture,
}

Model :: struct {
	meshes:    [dynamic]Mesh,
	materials: [dynamic]Material,
}

load_model :: proc(path: string) -> (model: Model) {
	base_path := filepath.dir(path, context.temp_allocator)

	options := gltf.options{}
	model_data, result := gltf.parse_file(options, fmt.ctprint(path))
	log.assertf(result == .success, "Failed to parse model: %s", path)
	colors: []u32
	defer delete(colors)
	result = gltf.load_buffers(options, model_data, fmt.ctprint(path))
	log.assertf(result == .success, "Failed to load model buffer data: %s", path)

	load_buffer_view_data :: proc(accessor: ^gltf.accessor, $data_type: typeid) -> [^]data_type {
		buffer_view_offset := accessor.buffer_view.offset / size_of(data_type)
		buffer_offset := accessor.offset / size_of(data_type)
		return(
			cast([^]data_type)mem.ptr_offset(
				cast(^u8)accessor.buffer_view.buffer.data,
				accessor.buffer_view.offset,
			) \
		)
	}

	load_attribute :: proc(
		accessor: ^gltf.accessor,
		$data_type: typeid,
		$num_comp: int,
		dst: ^[][num_comp]data_type,
	) {
		buffer := load_buffer_view_data(accessor, data_type)
		n := 0
		for k in 0 ..< int(accessor.count) {
			v: [num_comp]data_type = {}
			for l in 0 ..< num_comp do v[l] = buffer[n + l]
			dst[k] = v
			n += int(accessor.stride / size_of(data_type))
		}
	}

	//Load meshes
	mesh_count := len(model_data.meshes)
	model.meshes = make([dynamic]Mesh, 0, mesh_count)
	for mesh in model_data.meshes {
		for primitive in mesh.primitives {
			assert(primitive.type == .triangles, "Only triangles are supported")
			assert(primitive.indices != nil, "Indices are required")

			positions: [][3]f32
			defer delete(positions)

			tex_coords: [][2]f32
			defer delete(tex_coords)

			for attrib in primitive.attributes {
				vertex_accessor := attrib.data

				#partial switch attrib.type {
				case .position:
					positions = make([][3]f32, vertex_accessor.count)
					if vertex_accessor.type == .vec3 && vertex_accessor.component_type == .r_32f {
						load_attribute(vertex_accessor, f32, 3, &positions)
					}
				case .texcoord:
					tex_coords = make([][2]f32, vertex_accessor.count)
					if vertex_accessor.type == .vec2 && vertex_accessor.component_type == .r_32f {
						load_attribute(vertex_accessor, f32, 2, &tex_coords)
					}
				}
			}
			index_accessor := primitive.indices
			indices_count := index_accessor.count

			mesh: Mesh
			vertices: #soa[]Vertex3D = soa_zip(positions, tex_coords)
			if index_accessor.component_type == .r_16u {
				indices := load_buffer_view_data(index_accessor, u16)[:indices_count]
				mesh = create_mesh(vertices, indices)
			} else if index_accessor.component_type == .r_32u {
				indices := load_buffer_view_data(index_accessor, u32)[:indices_count]
				mesh = create_mesh(vertices, indices)
			}
			append(&model.meshes, mesh)
		}
	}

	load_image_texture :: proc(image: ^gltf.image, base_path: string) -> Texture {
		if image.uri != nil {
			image_path := filepath.join({base_path, string(image.uri)}, context.temp_allocator)
			return load_texture(image_path)
		}

		size := image.buffer_view.size
		offset := image.buffer_view.offset
		stride := image.buffer_view.stride != 0 ? image.buffer_view.stride : 1

		data := make([]u8, size, context.temp_allocator)
		for i in 0 ..< image.buffer_view.size {
			data[i] = ([^]u8)(image.buffer_view.buffer.data)[offset]
			offset += stride
		}
		return load_texture(data)

		// return load_texture("assets/textures/test.png")
	}

	//Load materials
	material_count := len(model_data.materials)
	model.materials = make([dynamic]Material, 0, material_count)
	for material in model_data.materials {
		mat: Material
		if material.has_pbr_metallic_roughness {
			pbr_metallic_roughness := material.pbr_metallic_roughness
			if pbr_metallic_roughness.base_color_texture.texture != nil {
				image := pbr_metallic_roughness.base_color_texture.texture.image_
				mat.albedo = load_image_texture(image, base_path)
			}
		} else if material.has_pbr_specular_glossiness {
			if material.pbr_specular_glossiness.diffuse_texture.texture != nil {
				image := material.pbr_specular_glossiness.diffuse_texture.texture.image_
				mat.albedo = load_image_texture(image, base_path)
			}
		}

		if material.normal_texture.texture != nil {
			image := material.normal_texture.texture.image_
			mat.normal = load_image_texture(image, base_path)
		}

		append(&model.materials, mat)
	}

	return
}

release_model :: proc(model: Model) {
	for mesh in model.meshes do release_mesh(mesh)
	delete(model.meshes)

	for mat in model.materials {
		release_texture(mat.albedo)
		release_texture(mat.normal)
	}
	delete(model.materials)
}

draw_model :: proc(model: Model) {
	assert(current_frame != nil)

	for i in 0 ..< len(model.meshes) {
		mat := model.materials[i]
		mesh := model.meshes[i]
		bind_textures({mat.albedo, mat.normal})
		draw_mesh(mesh)
	}
}
