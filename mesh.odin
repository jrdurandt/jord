package main

import "core:log"
import "core:mem"

import sdl "vendor:sdl3"

Mesh :: struct {
	vertex_buffer: ^sdl.GPUBuffer,
	index_buffer:  ^sdl.GPUBuffer,
	index_count:   int,
	index_type:    sdl.GPUIndexElementSize,
}

create_mesh_aos :: proc(using state: State, vertices: []$T, indices: []$I) -> (mesh: Mesh) {
	vertex_buffer_size := size_of(T) * len(vertices)
	index_buffer_size := size_of(I) * len(indices)
	mesh.index_count = len(indices)

	when I == u16 {
		mesh.index_type = ._16BIT
	} else when I == u32 {
		mesh.index_type = ._32BIT
	} else {
		#panic("Unsupported index type. Only u16 or u32 are supported")
	}

	mesh.vertex_buffer = sdl.CreateGPUBuffer(
		device,
		{usage = {.VERTEX}, size = u32(vertex_buffer_size)},
	)
	assert(mesh.vertex_buffer != nil, "Failed to create vertex buffer")
	sdl.SetGPUBufferName(device, mesh.vertex_buffer, "VertexBuffer")

	mesh.index_buffer = sdl.CreateGPUBuffer(
		device,
		{usage = {.INDEX}, size = u32(index_buffer_size)},
	)
	assert(mesh.index_buffer != nil, "Failed to create index buffer")
	sdl.SetGPUBufferName(device, mesh.index_buffer, "IndexBuffer")

	//Upload to buffers
	{
		transfer_buffer := sdl.CreateGPUTransferBuffer(
			device,
			{usage = .UPLOAD, size = u32(vertex_buffer_size + index_buffer_size)},
		)
		assert(transfer_buffer != nil, "Failed to create transfer buffer")
		defer sdl.ReleaseGPUTransferBuffer(device, transfer_buffer)

		transfer_buffer_ptr := sdl.MapGPUTransferBuffer(device, transfer_buffer, false)
		mem.copy(transfer_buffer_ptr, raw_data(vertices), vertex_buffer_size)
		index_tranfer_buffer_ptr := mem.ptr_offset(
			cast(^u8)transfer_buffer_ptr,
			vertex_buffer_size,
		)
		mem.copy(index_tranfer_buffer_ptr, raw_data(indices), index_buffer_size)
		sdl.UnmapGPUTransferBuffer(device, transfer_buffer)

		cmd_buff := sdl.AcquireGPUCommandBuffer(device)
		copy_pass := sdl.BeginGPUCopyPass(cmd_buff)

		sdl.UploadToGPUBuffer(
			copy_pass,
			{transfer_buffer = transfer_buffer},
			{buffer = mesh.vertex_buffer, size = u32(vertex_buffer_size)},
			false,
		)

		sdl.UploadToGPUBuffer(
			copy_pass,
			{transfer_buffer = transfer_buffer, offset = u32(vertex_buffer_size)},
			{buffer = mesh.index_buffer, size = u32(index_buffer_size)},
			false,
		)

		sdl.EndGPUCopyPass(copy_pass)
		assert(sdl.SubmitGPUCommandBuffer(cmd_buff), "Failed to submit command buffer")
	}
	return
}

create_mesh_soa :: proc(state: State, vertices: #soa[]$T, indices: []$I) -> Mesh {
	unzip_soa_vertices :: proc(vertices: #soa[]$T) -> (out: []T) {
		count := len(vertices)
		out = make([]T, count, context.temp_allocator)
		for i in 0 ..< count do out[i] = vertices[i]
		return
	}
	vertices := unzip_soa_vertices(vertices)
	return create_mesh_aos(state, vertices, indices)
}

create_mesh :: proc {
	create_mesh_aos,
	create_mesh_soa,
}

release_mesh :: proc(using state: State, mesh: Mesh) {
	sdl.ReleaseGPUBuffer(device, mesh.vertex_buffer)
	sdl.ReleaseGPUBuffer(device, mesh.index_buffer)
}

draw_mesh :: proc(using state: State, mesh: Mesh, index_count: u32 = 0) {
	assert(current_frame != nil)

	vertex_bindings := []sdl.GPUBufferBinding{{buffer = mesh.vertex_buffer}}
	sdl.BindGPUVertexBuffers(
		current_frame.render_pass,
		0,
		raw_data(vertex_bindings),
		u32(len(vertex_bindings)),
	)
	sdl.BindGPUIndexBuffer(
		current_frame.render_pass,
		{buffer = mesh.index_buffer},
		mesh.index_type,
	)
	sdl.DrawGPUIndexedPrimitives(
		current_frame.render_pass,
		index_count == 0 ? u32(mesh.index_count) : index_count,
		1,
		0,
		0,
		0,
	)
}
