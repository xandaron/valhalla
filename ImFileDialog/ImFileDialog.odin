package ImFileDialog

import "core:c"
import "vendor:stb/image"

when ODIN_OS == .Windows {
    @(require) foreign import advapi32 "system:advapi32.lib"
	when ODIN_ARCH == .amd64 {foreign import lib "ImFileDialog_x64.lib"} else {foreign import lib "ImFileDialog_arm64.lib"}
} else {
	when ODIN_OS == .Linux {
		@(require) foreign import stdcpp "system:stdc++"
	}
	else when ODIN_OS == .Darwin {
		@(require) foreign import stdcpp "system:c++"
	}
	when ODIN_ARCH == .amd64 {foreign import lib "ImFileDialog_x64.a"} else {foreign import lib "ImFileDialog_arm64.a"}
}

CreateTexture :: #type proc "system" (data: ^c.uint8_t, width, height: c.int, format: c.char) -> rawptr
DeleteTexture :: #type proc "system" (imagePtr: rawptr)

@(default_calling_convention = "system")
@(link_prefix = "file_dialog_")
foreign lib {
	// Create a new FileDialog instance
	init :: proc(create: CreateTexture, destroy: DeleteTexture) ---

	// Destroy a FileDialog instance
	shutdown :: proc() ---

	save :: proc(key, title, filter, starting_dir: cstring) -> c.bool ---

	open :: proc(key, title, filter: cstring, is_multiselect: c.bool, starting_dir: cstring) -> c.bool ---

	is_done :: proc(key: cstring) -> c.bool ---

	has_result :: proc() -> c.bool ---

	get_result :: proc() -> cstring ---

	get_results :: proc(count: ^c.int) -> [^]cstring ---

	close :: proc() ---

	remove_favorite :: proc(path: cstring) ---

	add_favorite :: proc(path: cstring) ---

	get_favorites :: proc(count: ^c.int) -> [^]cstring ---

	set_zoom :: proc(zoom: c.float) ---

	get_zoom :: proc() -> c.float ---
}
