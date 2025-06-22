package main

import "core:log"

import sdl "vendor:sdl3"

DEPTH_TEXTURE_FORMAT :: sdl.GPUTextureFormat.D16_UNORM

EngineContext :: struct {
	window:     ^sdl.Window,
	device:     ^sdl.GPUDevice,
	depth_tex:  ^sdl.GPUTexture,
	is_running: bool,
	last_tick:  f64,
}

Frame :: struct {
	cmd_buff:    ^sdl.GPUCommandBuffer,
	render_pass: ^sdl.GPURenderPass,
}

ctx: ^EngineContext
current_frame: ^Frame

@(private)
create_depth_texture :: proc(width, height: i32) -> ^sdl.GPUTexture {
	return sdl.CreateGPUTexture(
		ctx.device,
		{
			type = .D2,
			format = DEPTH_TEXTURE_FORMAT,
			usage = {.DEPTH_STENCIL_TARGET},
			width = u32(width),
			height = u32(height),
			layer_count_or_depth = 1,
			num_levels = 1,
			sample_count = ._1,
		},
	)
}

init_engine :: proc(title: cstring, config: Config) {
	assert(sdl.Init({.VIDEO}), "Failed to init SDL")

	ctx = new(EngineContext)

	flags: sdl.WindowFlags = {.HIDDEN}
	if config.resizable {
		flags |= {.RESIZABLE}
	}

	ctx.window = sdl.CreateWindow(title, i32(config.width), i32(config.height), flags)
	assert(ctx.window != nil, "Failed to create window")

	ctx.device = sdl.CreateGPUDevice({.SPIRV}, ODIN_DEBUG, nil)
	assert(ctx.device != nil, "Failed to create GPU device")

	assert(
		sdl.ClaimWindowForGPUDevice(ctx.device, ctx.window),
		"Failed to claim window for device",
	)
	log.debugf("GPU device driver: %s", sdl.GetGPUDeviceDriver(ctx.device))

	ctx.depth_tex = create_depth_texture(i32(config.width), i32(config.height))
	ctx.last_tick = f64(sdl.GetTicks())
}

destroy_engine :: proc() {
	if current_frame != nil {
		free(current_frame)
	}
	sdl.ReleaseGPUTexture(ctx.device, ctx.depth_tex)
	sdl.ReleaseWindowFromGPUDevice(ctx.device, ctx.window)
	sdl.DestroyGPUDevice(ctx.device)
	sdl.DestroyWindow(ctx.window)
	sdl.Quit()
	free(ctx)
	ctx = nil
}

run_engine :: proc(delta: ^f64) -> bool {
	ctx.is_running = sdl.ShowWindow(ctx.window)

	curr_tick := f64(sdl.GetTicks())
	delta^ = curr_tick - ctx.last_tick
	ctx.last_tick = curr_tick

	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			ctx.is_running = false
		case .WINDOW_RESIZED:
			sdl.ReleaseGPUTexture(ctx.device, ctx.depth_tex)
			ctx.depth_tex = create_depth_texture(event.window.data1, event.window.data2)
		}
	}

	return ctx.is_running
}

begin_frame :: proc(clear_color: [4]f32) {
	if current_frame == nil {
		current_frame = new(Frame)
	}

	assert(current_frame.cmd_buff == nil)
	current_frame.cmd_buff = sdl.AcquireGPUCommandBuffer(ctx.device)
	assert(current_frame.cmd_buff != nil, "Failed to acquire command buffer")

	swapchain_tex: ^sdl.GPUTexture
	assert(
		sdl.WaitAndAcquireGPUSwapchainTexture(
			current_frame.cmd_buff,
			ctx.window,
			&swapchain_tex,
			nil,
			nil,
		),
		"Failed to acquire swapchain texture",
	)

	if swapchain_tex != nil {
		color_target_info := sdl.GPUColorTargetInfo {
			texture     = swapchain_tex,
			clear_color = cast(sdl.FColor)clear_color,
			load_op     = .CLEAR,
			store_op    = .STORE,
		}

		depth_target_info := sdl.GPUDepthStencilTargetInfo {
			texture     = ctx.depth_tex,
			load_op     = .CLEAR,
			store_op    = .DONT_CARE,
			clear_depth = 1,
		}

		assert(current_frame.render_pass == nil)
		current_frame.render_pass = sdl.BeginGPURenderPass(
			current_frame.cmd_buff,
			&color_target_info,
			1,
			&depth_target_info,
		)
		return
	}
	current_frame = nil
}

end_frame :: proc() {
	sdl.EndGPURenderPass(current_frame.render_pass)
	assert(
		sdl.SubmitGPUCommandBuffer(current_frame.cmd_buff),
		"Failed to submit frame command buffer",
	)
	current_frame.cmd_buff = nil
	current_frame.render_pass = nil
}
