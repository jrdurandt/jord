package main

import "core:fmt"

import sdl "vendor:sdl3"

Frame :: struct {
	cmd_buff:    ^sdl.GPUCommandBuffer,
	render_pass: ^sdl.GPURenderPass,
}

frame_begin :: proc(using state: ^State, clear_color: [4]f32) -> (frame: Frame, ready: bool) {
	frame.cmd_buff = sdl.AcquireGPUCommandBuffer(device)
	assert(frame.cmd_buff != nil, "Failed to acquire command buffer")

	swapchain_tex: ^sdl.GPUTexture
	assert(
		sdl.WaitAndAcquireGPUSwapchainTexture(frame.cmd_buff, window, &swapchain_tex, nil, nil),
		"Failed to acquire swapchain texture",
	)

	if swapchain_tex == nil {
		return {}, false
	}

	color_target_info := sdl.GPUColorTargetInfo {
		texture     = swapchain_tex,
		clear_color = cast(sdl.FColor)clear_color,
		load_op     = .CLEAR,
		store_op    = .STORE,
	}

	depth_target_info := sdl.GPUDepthStencilTargetInfo {
		texture     = depth_tex,
		load_op     = .CLEAR,
		store_op    = .DONT_CARE,
		clear_depth = 1,
	}

	frame.render_pass = sdl.BeginGPURenderPass(frame.cmd_buff, &color_target_info, 1, &depth_target_info)
	ready = true
	return
}

frame_end :: proc(using frame: ^Frame) {
	sdl.EndGPURenderPass(render_pass)
	assert(sdl.SubmitGPUCommandBuffer(cmd_buff), "Failed to submit frame command buffer")
}

@(deferred_in_out = scoped_frame_end)
frame :: proc(state: ^State, clear_color: [4]f32) -> bool {
	frame, ready := frame_begin(state, clear_color)

	if state.current_frame == nil {
		state.current_frame = new(Frame)
	}

	state.current_frame^ = frame
	return ready
}

scoped_frame_end :: proc(state: ^State, _: [4]f32, ready: bool) {
	if ready {
		frame_end(state.current_frame)
	}
}
