package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"

import sdl "vendor:sdl3"

DEPTH_TEXTURE_FORMAT :: sdl.GPUTextureFormat.D16_UNORM

WindowEvent :: sdl.WindowEvent
KeyboardEvent :: sdl.KeyboardEvent
MouseMotionEvent :: sdl.MouseMotionEvent
MouseButtonEvent :: sdl.MouseButtonEvent
MouseWheelEvent :: sdl.MouseWheelEvent

Event :: union {
	WindowEvent,
	KeyboardEvent,
	MouseMotionEvent,
	MouseButtonEvent,
	MouseWheelEvent,
}

EngineState :: struct {
	window:        ^sdl.Window,
	device:        ^sdl.GPUDevice,
	depth_tex:     ^sdl.GPUTexture,
	is_running:    bool,
	last_tick:     f64,
	current_frame: ^Frame,
	events:        [dynamic]Event,
	pipeline_3d:   ^sdl.GPUGraphicsPipeline,
}

Frame :: struct {
	cmd_buff:    ^sdl.GPUCommandBuffer,
	render_pass: ^sdl.GPURenderPass,
}

Vertex3D :: struct {
	position:  [3]f32,
	tex_coord: [2]f32,
}

state: ^EngineState

@(private)
create_depth_texture :: proc(device: ^sdl.GPUDevice, width, height: i32) -> ^sdl.GPUTexture {
	return sdl.CreateGPUTexture(
		device,
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

init_engine :: proc(
	title: cstring,
	width, height: int,
	resizeable: bool = false,
	debug: bool = ODIN_DEBUG,
) {
	fmt.printfln(
		"State init (title: %s, width: %d, height: %d, resizable: %v, debug: %v)",
		title,
		width,
		height,
		resizeable,
		debug,
	)

	fmt.printfln("Using SDL3 version: %d", sdl.GetVersion())
	assert(sdl.Init({.VIDEO}), "Failed to init SDL")

	flags: sdl.WindowFlags = {.HIDDEN}
	if resizeable {
		flags |= {.RESIZABLE}
	}

	state = new(EngineState)

	state.window = sdl.CreateWindow(title, i32(width), i32(height), flags)
	assert(state.window != nil, "Failed to create window")

	state.device = sdl.CreateGPUDevice({.SPIRV}, debug, nil)
	assert(state.device != nil, "Failed to create GPU device")

	assert(
		sdl.ClaimWindowForGPUDevice(state.device, state.window),
		"Failed to claim window for device",
	)
	fmt.printfln("GPU device driver: %s", sdl.GetGPUDeviceDriver(state.device))

	present_mode := sdl.GPUPresentMode.VSYNC
	if sdl.WindowSupportsGPUPresentMode(state.device, state.window, .IMMEDIATE) {
		present_mode = .IMMEDIATE
	} else if sdl.WindowSupportsGPUPresentMode(state.device, state.window, .MAILBOX) {
		present_mode = .MAILBOX
	}
	fmt.printfln("Present mode: %s", present_mode)

	assert(
		sdl.SetGPUSwapchainParameters(state.device, state.window, .SDR, present_mode),
		"Unable to set swapchain params",
	)

	state.events = make([dynamic]Event)
	state.depth_tex = create_depth_texture(state.device, i32(width), i32(height))


	state.pipeline_3d = pipeline_3d_create(state.device, state.window)
}

destroy_engine :: proc() {
	if state.current_frame != nil {
		free(state.current_frame)
	}

	sdl.ReleaseGPUGraphicsPipeline(state.device, state.pipeline_3d)

	delete(state.events)
	sdl.ReleaseGPUTexture(state.device, state.depth_tex)
	sdl.ReleaseWindowFromGPUDevice(state.device, state.window)
	sdl.DestroyGPUDevice(state.device)
	sdl.DestroyWindow(state.window)
	sdl.Quit()
	free(state)
	state = nil
}

run_engine :: proc(delta: ^f64) -> bool {
	state.is_running = sdl.ShowWindow(state.window)

	curr_tick := f64(sdl.GetTicks())
	delta^ = curr_tick - state.last_tick
	state.last_tick = curr_tick

	clear(&state.events)
	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			state.is_running = false
		case .WINDOW_RESIZED:
			sdl.ReleaseGPUTexture(state.device, state.depth_tex)
			state.depth_tex = create_depth_texture(
				state.device,
				event.window.data1,
				event.window.data2,
			)
			append(&state.events, event.window)
		case .KEY_DOWN, .KEY_UP:
			append(&state.events, event.key)
		case .MOUSE_MOTION:
			append(&state.events, event.motion)
		case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
			append(&state.events, event.button)
		case .MOUSE_WHEEL:
			append(&state.events, event.wheel)
		}
	}

	return state.is_running
}

query_event :: proc($T: typeid) -> (event: ^T, found: bool) {
	for e, i in state.events {
		#partial switch event in e {
		case T:
			return &state.events[i].(T), true
		}
	}
	return nil, false
}

is_key_down :: proc(key: sdl.Keycode) -> bool {
	e := query_event(KeyboardEvent) or_return
	return e.key == key && e.down
}

is_key_up :: proc(key: sdl.Keycode) -> bool {
	e := query_event(KeyboardEvent) or_return
	return e.key == key && !e.down
}

is_key_repeat :: proc(key: sdl.Keycode) -> bool {
	e := query_event(KeyboardEvent) or_return
	return e.key == key && e.repeat
}

frame_begin :: proc(clear_color: [4]f32) -> (frame: Frame, ready: bool) {
	frame.cmd_buff = sdl.AcquireGPUCommandBuffer(state.device)
	assert(frame.cmd_buff != nil, "Failed to acquire command buffer")

	swapchain_tex: ^sdl.GPUTexture
	assert(
		sdl.WaitAndAcquireGPUSwapchainTexture(
			frame.cmd_buff,
			state.window,
			&swapchain_tex,
			nil,
			nil,
		),
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
		texture     = state.depth_tex,
		load_op     = .CLEAR,
		store_op    = .DONT_CARE,
		clear_depth = 1,
	}

	frame.render_pass = sdl.BeginGPURenderPass(
		frame.cmd_buff,
		&color_target_info,
		1,
		&depth_target_info,
	)
	ready = true
	return
}

frame_end :: proc(using frame: ^Frame) {
	sdl.EndGPURenderPass(render_pass)
	assert(sdl.SubmitGPUCommandBuffer(cmd_buff), "Failed to submit frame command buffer")
}

@(deferred_in_out = scoped_frame_end)
frame :: proc(clear_color: [4]f32) -> bool {
	frame, ready := frame_begin(clear_color)

	if state.current_frame == nil {
		state.current_frame = new(Frame)
	}

	state.current_frame^ = frame

	sdl.BindGPUGraphicsPipeline(state.current_frame.render_pass, state.pipeline_3d)
	return ready
}

@(private)
scoped_frame_end :: proc(_: [4]f32, ready: bool) {
	if ready {
		frame_end(state.current_frame)
	}
}

@(private)
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

@(private)
pipeline_3d_create :: proc(
	device: ^sdl.GPUDevice,
	window: ^sdl.Window,
) -> ^sdl.GPUGraphicsPipeline {
	vertex_shader := load_shader(
		device,
		"assets/shaders/compiled/basic.vert.spv",
		num_uniform_buffers = 1,
	)
	defer sdl.ReleaseGPUShader(device, vertex_shader)

	fragment_shader := load_shader(
		device,
		"assets/shaders/compiled/basic.frag.spv",
		num_samplers = 1,
	)
	defer sdl.ReleaseGPUShader(device, fragment_shader)

	vertex_attributes := [?]sdl.GPUVertexAttribute {
		{location = 0, offset = u32(offset_of(Vertex3D, position)), format = .FLOAT3},
		{location = 1, offset = u32(offset_of(Vertex3D, tex_coord)), format = .FLOAT2},
	}

	vertex_buffer_descriptions := [?]sdl.GPUVertexBufferDescription {
		{slot = 0, input_rate = .VERTEX, instance_step_rate = 0, pitch = size_of(Vertex3D)},
	}

	color_target_descriptions := [?]sdl.GPUColorTargetDescription {
		{
			format = sdl.GetGPUSwapchainTextureFormat(device, window),
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

	pipeline := sdl.CreateGPUGraphicsPipeline(state.device, create_info)
	assert(pipeline != nil, "Failed to create 3D graphics pipeline")
	return pipeline
}
