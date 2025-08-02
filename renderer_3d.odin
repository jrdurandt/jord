package main

import "core:fmt"

import sdl "vendor:sdl3"

Vertex3D :: struct {
	position:  [3]f32,
	tex_coord: [2]f32,
}

Renderer3D :: struct {
	pipeline: ^sdl.GPUGraphicsPipeline,
}

renderer_3d_init :: proc() -> (renderer: Renderer3D) {
	vertex_shader := load_shader(
		state.device,
		"assets/shaders/compiled/basic.vert.spv",
		num_uniform_buffers = 1,
	)
	defer sdl.ReleaseGPUShader(state.device, vertex_shader)

	fragment_shader := load_shader(
		state.device,
		"assets/shaders/compiled/basic.frag.spv",
		num_samplers = 1,
	)
	defer sdl.ReleaseGPUShader(state.device, fragment_shader)

	vertex_attributes := [?]sdl.GPUVertexAttribute {
		{location = 0, offset = u32(offset_of(Vertex3D, position)), format = .FLOAT3},
		{location = 1, offset = u32(offset_of(Vertex3D, tex_coord)), format = .FLOAT2},
	}

	vertex_buffer_descriptions := [?]sdl.GPUVertexBufferDescription {
		{slot = 0, input_rate = .VERTEX, instance_step_rate = 0, pitch = size_of(Vertex3D)},
	}

	color_target_descriptions := [?]sdl.GPUColorTargetDescription {
		{
			format = sdl.GetGPUSwapchainTextureFormat(state.device, state.window),
			blend_state = {
				enable_blend = true,
				color_blend_op = .ADD,
				alpha_blend_op = .ADD,
				src_color_blendfactor = .ONE,
				dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
				src_alpha_blendfactor = .ONE,
				dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
			},
		},
	}

	create_info := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_input_state = {
			num_vertex_attributes = u32(len(vertex_attributes)),
			vertex_attributes = raw_data(&vertex_attributes),
			num_vertex_buffers = u32(len(vertex_buffer_descriptions)),
			vertex_buffer_descriptions = raw_data(&vertex_buffer_descriptions),
		},
		depth_stencil_state = {
			enable_depth_test = true,
			enable_depth_write = true,
			compare_op = .LESS_OR_EQUAL,
		},
		target_info = {
			num_color_targets = u32(len(color_target_descriptions)),
			color_target_descriptions = raw_data(&color_target_descriptions),
			has_depth_stencil_target = true,
			depth_stencil_format = DEPTH_TEXTURE_FORMAT,
		},
		multisample_state = {sample_count = ._1},
		primitive_type = .TRIANGLELIST,
		vertex_shader = vertex_shader,
		fragment_shader = fragment_shader,
		rasterizer_state = sdl.GPURasterizerState{fill_mode = .FILL},
	}

	renderer.pipeline = sdl.CreateGPUGraphicsPipeline(state.device, create_info)
	assert(renderer.pipeline != nil, "Failed to create 3D graphics pipeline")
	return
}

renderer_3d_destroy :: proc(renderer: Renderer3D) {
	sdl.ReleaseGPUGraphicsPipeline(state.device, renderer.pipeline)
}

renderer_3d_bind :: proc(renderer: Renderer3D) {
	assert(state.current_frame != nil)
	sdl.BindGPUGraphicsPipeline(state.current_frame.render_pass, renderer.pipeline)
}
