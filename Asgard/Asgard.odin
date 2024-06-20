package Asgard

import "vendor:glfw"

APP_VERSION : u32 : (0<<22) | (0<<12) | (1)

Vector2 :: distinct [2]f32
Vector3 :: distinct [3]f32
Vector4 :: distinct [4]f32

main :: proc() {
    glfw.SetErrorCallback(glfwErrorCallback)

    if(!glfw.Init()) {
        log(.ERROR, "Failed to initalize glfw, quitting application.")
        panic("Failed to initalize glfw, quitting application.")
    }
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API);
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE);

    width : i32 = 800
    height : i32 = 600
    name : cstring : "New Innsmouth"
    monitor : glfw.MonitorHandle = nil
    window : glfw.WindowHandle = glfw.CreateWindow(width, height, name, monitor, nil)
    if (window == nil) {
        log(.ERROR, "Failed to create window, quitting application.")
        panic("Failed to create window, quitting application.")
    }
    defer glfw.DestroyWindow(window)

    glfw.SetKeyCallback(window, glfwKeyCallback)
    // glfw.SetMouseButtonCallback(window, glfwMouseButtonCallback)
    // glfw.SetScrollCallback(window, glfwScrollCallback)

    graphicsContext : GraphicsContext = {
        window = window
    }
    initVkGraphics(&graphicsContext)
    defer clanupVkGraphics(&graphicsContext)

    for (!glfw.WindowShouldClose(window)) {
        glfw.PollEvents()
    }
}

glfwKeyCallback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
		glfw.SetWindowShouldClose(window, glfw.TRUE)
	}
}