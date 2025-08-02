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

state_init :: proc(
	title: cstring,
	width, height: int,
	resizeable: bool = false,
	debug: bool = ODIN_DEBUG,
) -> (
	s: State,
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

	s.window = sdl.CreateWindow(title, i32(width), i32(height), flags)
	assert(s.window != nil, "Failed to create window")

	s.device = sdl.CreateGPUDevice({.SPIRV}, debug, nil)
	assert(s.device != nil, "Failed to create GPU device")

	assert(sdl.ClaimWindowForGPUDevice(s.device, s.window), "Failed to claim window for device")
	fmt.printfln("GPU device driver: %s", sdl.GetGPUDeviceDriver(s.device))

	present_mode := sdl.GPUPresentMode.VSYNC
	if sdl.WindowSupportsGPUPresentMode(s.device, s.window, .IMMEDIATE) {
		present_mode = .IMMEDIATE
	} else if sdl.WindowSupportsGPUPresentMode(s.device, s.window, .MAILBOX) {
		present_mode = .MAILBOX
	}
	fmt.printfln("Present mode: %s", present_mode)

	assert(
		sdl.SetGPUSwapchainParameters(s.device, s.window, .SDR, present_mode),
		"Unable to set swapchain params",
	)

	s.events = make([dynamic]Event)
	s.depth_tex = create_depth_texture(s.device, i32(width), i32(height))

	return
}

state_destroy :: proc(using state: State) {
	if current_frame != nil {
		free(current_frame)
	}

	delete(events)
	sdl.ReleaseGPUTexture(device, depth_tex)
	sdl.ReleaseWindowFromGPUDevice(device, window)
	sdl.DestroyGPUDevice(device)
	sdl.DestroyWindow(window)
	sdl.Quit()
}

state_run :: proc(using state: ^State, delta: ^f64) -> bool {
	is_running = sdl.ShowWindow(window)

	curr_tick := f64(sdl.GetTicks())
	delta^ = curr_tick - last_tick
	last_tick = curr_tick

	clear(&events)
	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			is_running = false
		case .WINDOW_RESIZED:
			sdl.ReleaseGPUTexture(device, depth_tex)
			depth_tex = create_depth_texture(device, event.window.data1, event.window.data2)
			append(&events, event.window)
		case .KEY_DOWN, .KEY_UP:
			append(&events, event.key)
		case .MOUSE_MOTION:
			append(&events, event.motion)
		case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
			append(&events, event.button)
		case .MOUSE_WHEEL:
			append(&events, event.wheel)
		}
	}

	return is_running
}

query_event :: proc(using state: State, $T: typeid) -> (event: ^T, found: bool) {
	for e, i in events {
		#partial switch event in e {
		case T:
			return &events[i].(T), true
		}
	}
	return nil, false
}

is_key_down :: proc(state: State, key: sdl.Keycode) -> bool {
	e := query_event(state, KeyboardEvent) or_return
	return e.key == key && e.down
}

is_key_up :: proc(state: State, key: sdl.Keycode) -> bool {
	e := query_event(state, KeyboardEvent) or_return
	return e.key == key && !e.down
}

is_key_repeat :: proc(state: State, key: sdl.Keycode) -> bool {
	e := query_event(state, KeyboardEvent) or_return
	return e.key == key && e.repeat
}
