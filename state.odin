package main

import "core:fmt"

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

State :: struct {
	window:        ^sdl.Window,
	device:        ^sdl.GPUDevice,
	depth_tex:     ^sdl.GPUTexture,
	is_running:    bool,
	last_tick:     f64,
	current_frame: ^Frame,
	events:        [dynamic]Event,
}

state: ^State

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

init_state :: proc(
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

	state = new(State)

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
}

destroy_state :: proc() {
	if state.current_frame != nil {
		free(state.current_frame)
	}

	delete(state.events)
	sdl.ReleaseGPUTexture(state.device, state.depth_tex)
	sdl.ReleaseWindowFromGPUDevice(state.device, state.window)
	sdl.DestroyGPUDevice(state.device)
	sdl.DestroyWindow(state.window)
	sdl.Quit()
	free(state)
	state = nil
}

run :: proc(delta: ^f64) -> bool {
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
