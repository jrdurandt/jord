package main

import sdl "vendor:sdl3"

UBO :: struct {
	model:      matrix[4, 4]f32,
	view:       matrix[4, 4]f32,
	projection: matrix[4, 4]f32,
}

bind_ubo :: proc(using state: State, ubo: UBO, slot: int = 0) {
	assert(current_frame != nil)
	ubo := ubo
	sdl.PushGPUVertexUniformData(current_frame.cmd_buff, u32(slot), &ubo, size_of(ubo))
}
