package main

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"

import sdl "vendor:sdl3"

main :: proc() {
	context.logger = log.create_console_logger(.Info)
	defer log.destroy_console_logger(context.logger)

	when ODIN_DEBUG {
		context.logger.lowest_level = .Debug

		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				log.errorf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					log.errorf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}

			if len(track.bad_free_array) > 0 {
				log.errorf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					log.errorf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}
	log.debug("Debug enabled")

	config := load_config() or_else panic("Failed to load config")
	log.debugf("Config: %v", config)

	init_engine("Jord", config.width, config.height, config.resizable)
	defer destroy_engine()

	width, height := get_window_size()
	aspect_ratio := f32(width) / f32(height)
	camera := Camera3D {
		position     = {0, 5, 5},
		target       = {0, 1, 0},
		up           = {0, 1, 0},
		fov          = linalg.PI / 4,
		aspect_ratio = aspect_ratio,
		near         = 0.1,
		far          = 100.0,
	}

	damaged_helm := load_model("assets/models/island_tree_02/island_tree.glb")
	defer release_model(damaged_helm)

	rotation: f32 = 0

	delta: f64
	main_loop: for run_engine(&delta) {
		update_camera(&camera)

		if e, ok := query_event(WindowEvent); ok {
			aspect_ratio := f32(e.data1) / f32(e.data2)
			camera.aspect_ratio = aspect_ratio
		}

		if is_key_down(sdl.K_ESCAPE) {
			state.is_running = false
			break main_loop
		}

		rotation += 90 * f32(delta) / 1000.0
		camera.model = linalg.matrix4_rotate_f32(linalg.to_radians(rotation), {0, 1, 0})

		if frame({0.15, 0.15, 0.25, 1.0}) {
			bind_camera(camera)
			draw_model(damaged_helm)
		}
	}
}
