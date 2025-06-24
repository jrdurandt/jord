package main
import "core:log"

import "core:fmt"
import "core:mem"
import "core:os"

import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"

Texture :: struct {
	width, height: i32,
	handle:        ^sdl.GPUTexture,
	sampler:       ^sdl.GPUSampler,
}

load_texture_from_surface :: proc(
	surface: ^sdl.Surface,
	min_filter: sdl.GPUFilter = .NEAREST,
	mag_filter: sdl.GPUFilter = .NEAREST,
	mipmap_mode: sdl.GPUSamplerMipmapMode = .NEAREST,
	address_mode_u: sdl.GPUSamplerAddressMode = .REPEAT,
	address_mode_v: sdl.GPUSamplerAddressMode = .REPEAT,
) -> Texture {
	surface := surface
	defer sdl.DestroySurface(surface)

	//We require an RGBA32 image
	if surface.format != .RGBA32 {
		log.debugf("Converting image from %s into RGBA32", surface.format)
		surface = sdl.ConvertSurface(surface, .RGBA32)
	}

	width := surface.w
	height := surface.h

	texture := sdl.CreateGPUTexture(
		ctx.device,
		{
			type = .D2,
			format = .R8G8B8A8_UNORM,
			width = u32(width),
			height = u32(height),
			layer_count_or_depth = 1,
			num_levels = 1,
			usage = {.SAMPLER},
		},
	)
	assert(texture != nil, "Failed to create GPU texture")
	sdl.SetGPUTextureName(ctx.device, texture, "TODO")

	tex_size := width * height * 4
	//Upload to GPU
	{
		transfer_buffer := sdl.CreateGPUTransferBuffer(
			ctx.device,
			{usage = .UPLOAD, size = u32(tex_size)},
		)
		defer sdl.ReleaseGPUTransferBuffer(ctx.device, transfer_buffer)

		texture_transfer_ptr := sdl.MapGPUTransferBuffer(ctx.device, transfer_buffer, false)
		mem.copy(texture_transfer_ptr, surface.pixels, int(tex_size))
		sdl.UnmapGPUTransferBuffer(ctx.device, transfer_buffer)

		cmd_buff := sdl.AcquireGPUCommandBuffer(ctx.device)
		copy_pass := sdl.BeginGPUCopyPass(cmd_buff)

		sdl.UploadToGPUTexture(
			copy_pass,
			{transfer_buffer = transfer_buffer},
			{texture = texture, w = u32(width), h = u32(height), d = 1},
			false,
		)
		sdl.EndGPUCopyPass(copy_pass)
		assert(sdl.SubmitGPUCommandBuffer(cmd_buff), "Failed to submit command buffer")
	}

	sampler := sdl.CreateGPUSampler(
		ctx.device,
		{
			min_filter = min_filter,
			mag_filter = mag_filter,
			mipmap_mode = mipmap_mode,
			address_mode_u = address_mode_u,
			address_mode_v = address_mode_v,
		},
	)

	return {width = width, height = height, handle = texture, sampler = sampler}
}

load_texture_from_data :: proc(
	data: []u8,
	min_filter: sdl.GPUFilter = .NEAREST,
	mag_filter: sdl.GPUFilter = .NEAREST,
	mipmap_mode: sdl.GPUSamplerMipmapMode = .NEAREST,
	address_mode_u: sdl.GPUSamplerAddressMode = .REPEAT,
	address_mode_v: sdl.GPUSamplerAddressMode = .REPEAT,
) -> Texture {
	stream := sdl.IOFromMem(raw_data(data), len(data))
	log.assertf(stream != nil, "Failed to load: %s", sdl.GetError())
	surface := sdl_image.Load_IO(stream, true)

	return load_texture_from_surface(
		surface,
		min_filter,
		mag_filter,
		mipmap_mode,
		address_mode_u,
		address_mode_v,
	)
}

load_texture_from_path :: proc(
	path: string,
	min_filter: sdl.GPUFilter = .NEAREST,
	mag_filter: sdl.GPUFilter = .NEAREST,
	mipmap_mode: sdl.GPUSamplerMipmapMode = .NEAREST,
	address_mode_u: sdl.GPUSamplerAddressMode = .REPEAT,
	address_mode_v: sdl.GPUSamplerAddressMode = .REPEAT,
) -> Texture {
	stream := sdl.IOFromFile(fmt.ctprint(path), "rb")
	log.assertf(stream != nil, "Failed to load: %s", sdl.GetError())
	surface := sdl_image.Load_IO(stream, true)

	return load_texture_from_surface(
		surface,
		min_filter,
		mag_filter,
		mipmap_mode,
		address_mode_u,
		address_mode_v,
	)
}

load_texture :: proc {
	load_texture_from_surface,
	load_texture_from_data,
	load_texture_from_path,
}

release_texture :: proc(texture: Texture) {
	sdl.ReleaseGPUTexture(ctx.device, texture.handle)
	sdl.ReleaseGPUSampler(ctx.device, texture.sampler)
}

bind_texture :: proc(texture: Texture, slot: int = 0) {
	assert(current_frame != nil)

	sampler_bindings := []sdl.GPUTextureSamplerBinding {
		{texture = texture.handle, sampler = texture.sampler},
	}
	sdl.BindGPUFragmentSamplers(
		current_frame.render_pass,
		u32(slot),
		raw_data(sampler_bindings),
		u32(len(sampler_bindings)),
	)
}

bind_textures :: proc(textures: []Texture) {
	assert(current_frame != nil)

	sampler_bindings := make([]sdl.GPUTextureSamplerBinding, len(textures), context.temp_allocator)
	for i in 0 ..< len(textures) {
		texture := textures[i]
		sampler_bindings[i] = {
			texture = texture.handle,
			sampler = texture.sampler,
		}
	}
	sdl.BindGPUFragmentSamplers(
		current_frame.render_pass,
		0,
		raw_data(sampler_bindings),
		u32(len(sampler_bindings)),
	)
}
