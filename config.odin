package main

import "core:encoding/ini"
import "core:log"
import "core:strconv"

Config :: struct {
	width:     int,
	height:    int,
	resizable: bool,
}

load_config :: proc(path: string = "config.ini") -> (config: Config, ok: bool) {
	data, err := ini.load_map_from_path(path, context.temp_allocator) or_return
	if err != .None {
		log.errorf("Failed to load config [%v]: %s", err, path)
		return
	}

	config.width = strconv.parse_int(data["window"]["width"]) or_else 1920
	config.height = strconv.parse_int(data["window"]["height"]) or_else 1080
	config.resizable = strconv.parse_bool(data["window"]["resizable"]) or_else false

	return config, true
}
