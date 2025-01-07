#+build darwin
package imgui_impl_osx

when      ODIN_OS == .Windows { foreign import lib "../imgui_windows_x64.lib" }
else when ODIN_OS == .Linux   { foreign import lib "../imgui_linux_x64.a" }
else when ODIN_OS == .Darwin  {
	when ODIN_ARCH == .amd64 { foreign import lib "../imgui_darwin_x64.a" } else { foreign import lib "../imgui_darwin_arm64.a" }
}

// imgui_impl_osx.h
// Last checked `v1.91.1-docking` (6df1a0)
@(link_prefix="ImGui_ImplOSX_")
foreign lib {
	Init     :: proc(view: rawptr) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc(view: rawptr) ---
}
