package main

import "core:math/linalg"
import sdl "vendor:sdl3"

Camera :: struct {
	model:      matrix[4, 4]f32,
	view:       matrix[4, 4]f32,
	projection: matrix[4, 4]f32,
}

Camera3D :: struct {
	using base:   Camera,
	position:     [3]f32,
	target:       [3]f32,
	up:           [3]f32,
	fov:          f32,
	aspect_ratio: f32,
	near, far:    f32,
}

update_camera :: proc(camera: ^Camera3D) {
	camera.view = linalg.matrix4_look_at_f32(camera.position, camera.target, camera.up)
	camera.projection = linalg.matrix4_perspective_f32(
		camera.fov,
		camera.aspect_ratio,
		camera.near,
		camera.far,
	)
}

bind_camera :: proc(camera: Camera, slot: int = 0) {
	assert(state.current_frame != nil)
	camera := camera
	sdl.PushGPUVertexUniformData(state.current_frame.cmd_buff, u32(slot), &camera, size_of(camera))
}
