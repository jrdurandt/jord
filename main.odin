package main

import "core:log"
import "core:math/linalg"
import "core:mem"

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

	init_engine("Jord", config)
	defer destroy_engine()

	aspect_ratio := f32(config.width) / f32(config.height)
	ubo := UBO {
		view       = linalg.matrix4_look_at_f32({0, 0, 5}, {0, 0, 0}, {0, 1, 0}),
		projection = linalg.matrix4_perspective_f32(linalg.PI / 4, aspect_ratio, 0.1, 100.0),
	}

	damaged_helm := load_model("assets/models/DamagedHelmet.glb")
	defer release_model(damaged_helm)

	rotation: f32 = 0

	delta: f64
	for run_engine(&delta) {
		rotation += 90 * f32(delta) / 1000.0
		ubo.model =
			linalg.matrix4_rotate_f32(linalg.to_radians(rotation), {0, 1, 0}) *
			linalg.matrix4_rotate_f32(linalg.PI / 2, {1, 0, 0})

		begin_frame({0.15, 0.15, 0.25, 1.0})
		bind_3d_pipeline()
		bind_ubo(ubo)
		draw_model(damaged_helm)
		end_frame()
	}
}
