package ImFileDialog

import "core:c"
import "vendor:stb/image"

when ODIN_OS == .Windows {
    @(require) foreign import advapi32 "system:advapi32.lib"
	when ODIN_ARCH == .amd64 {foreign import lib "ImFileDialog_windows_x64.lib"} else {foreign import lib "ImFileDialog_windows_arm64.lib"}
} else when ODIN_OS == .Linux {
	@(require) foreign import stdcpp "system:stdc++"
	when ODIN_ARCH == .amd64 {foreign import lib "ImFileDialog_linux_x64.a"} else {foreign import lib "ImFileDialog_linux_arm64.a"}
}
else when ODIN_OS == .Darwin {
	@(require) foreign import stdcpp "system:c++"
	when ODIN_ARCH == .amd64 {foreign import lib "ImFileDialog_mac_x64.a"} else {foreign import lib "ImFileDialog_mac_arm64.a"}
}

CreateTexture :: #type proc "system" (data: [^]c.uint8_t, width, height: c.int, format: c.char) -> rawptr
DeleteTexture :: #type proc "system" (imagePtr: rawptr)

@(default_calling_convention = "system")
@(link_prefix = "FileDialog")
foreign lib {
	// Create a new FileDialog instance
	Init :: proc(create: CreateTexture, destroy: DeleteTexture) ---

	// Destroy a FileDialog instance
	Shutdown :: proc() ---

	Save :: proc(key, title, filter, starting_dir: cstring) -> c.bool ---

	Open :: proc(key, title, filter: cstring, is_multiselect: c.bool, starting_dir: cstring) -> c.bool ---

	IsDone :: proc(key: cstring) -> c.bool ---

	HasResult :: proc() -> c.bool ---

	GetResult :: proc() -> cstring ---

	GetResults :: proc(count: ^c.int) -> [^]cstring ---

	Close :: proc() ---

	RemoveFavorite :: proc(path: cstring) ---

	AddFavorite :: proc(path: cstring) ---

	GetFavorites :: proc(count: ^c.int) -> [^]cstring ---

	SetZoom :: proc(zoom: c.float) ---

	GetZoom :: proc() -> c.float ---
}
