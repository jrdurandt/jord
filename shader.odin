package main

import "core:log"
import "core:os"
import "core:strings"

import sdl "vendor:sdl3"

load_shader :: proc(
	device: ^sdl.GPUDevice,
	path: string,
	num_samplers: u32 = 0,
	num_uniform_buffers: u32 = 0,
	num_storage_buffers: u32 = 0,
	num_storage_textures: u32 = 0,
) -> ^sdl.GPUShader {
	code :=
		os.read_entire_file(path, context.temp_allocator) or_else log.panicf(
			"Failed to load shader: %s",
			path,
		)

	stage: sdl.GPUShaderStage
	if strings.contains(path, ".vert") {
		stage = .VERTEX
	} else if strings.contains(path, ".frag") {
		stage = .FRAGMENT
	} else {
		log.panicf("Failed to load shader. Unable to determine stage")
	}
	log.debugf("Loaded shader [%s]: %s", stage, path)

	create_info := sdl.GPUShaderCreateInfo {
		code                 = raw_data(code),
		code_size            = len(code),
		entrypoint           = "main",
		stage                = stage,
		format               = {.SPIRV},
		num_samplers         = num_samplers,
		num_uniform_buffers  = num_uniform_buffers,
		num_storage_buffers  = num_storage_buffers,
		num_storage_textures = num_storage_textures,
	}

	shader := sdl.CreateGPUShader(device, create_info)
	log.assertf(shader != nil, "Failed to create shader: %s", path)
	return shader
}
