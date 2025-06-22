package main

import "core:log"
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

	vertices := [?]Vertex3D {
		{position = {-0.5, 0.5, 0.0}, tex_coord = {0.0, 0.0}},
		{position = {0.5, 0.5, 0.0}, tex_coord = {1.0, 0.0}},
		{position = {0.5, -0.5, 0.0}, tex_coord = {1.0, 1.0}},
		{position = {-0.5, -0.5, 0.0}, tex_coord = {0.0, 1.0}},
	}

	indices := [?]u16{0, 1, 2, 2, 3, 0}

	quad := create_mesh(vertices[:], indices[:])
	defer release_mesh(quad)

	delta: f64
	for run_engine(&delta) {
		begin_frame({0.15, 0.15, 0.25, 1.0})
		bind_3d_pipeline()
		draw_mesh(quad)
		end_frame()
	}
}
