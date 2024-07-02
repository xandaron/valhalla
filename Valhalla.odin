package Valhalla

import "core:os"
import t "core:time"
import "core:fmt"
import "core:strings"

import "vendor:glfw"

APP_VERSION : u32 : (0<<22) | (0<<12) | (1)

frameCount : u16 = 0
fpsTimer : t.Time = t.now()

mouseMode : bool = false
mousePos, mouseDelta : f64Vec2 = { 0, 0 }, { 0, 0 }
mouseSensitivity : f64 = 1
scrollDelta : f64Vec2 = { 0, 0 }

cameraSpeed : f64 = 1

EngineState :: struct {
    camera          : Camera,
    graphicsContext : GraphicsContext,
}

main :: proc() {
    glfw.SetErrorCallback(glfwErrorCallback)

    if !glfw.Init() {
        log(.ERROR, "Failed to initalize glfw, quitting application.")
        panic("Failed to initalize glfw, quitting application.")
    }
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API);

    width : i32 = 800
    height : i32 = 600
    name : cstring : "New Innsmouth"
    monitor : glfw.MonitorHandle = nil
    window : glfw.WindowHandle = glfw.CreateWindow(width, height, name, monitor, nil)
    if window == nil {
        log(.ERROR, "Failed to create window, quitting application.")
        panic("Failed to create window, quitting application.")
    }
    defer glfw.DestroyWindow(window)

    glfw.SetKeyCallback(window, keyCallback)
    glfw.SetMouseButtonCallback(window, glfwMouseButtonCallback)
    glfw.SetCursorPosCallback(window, glfwCursorPosCallback)
    glfw.SetScrollCallback(window, glfwScrollCallback)
    glfw.SetFramebufferSizeCallback(window, framebufferResizeCallback)
    
    engineState : EngineState = {
        camera = {
            eye      = { 0, 2, 2 },
            center   = { 0, 0, 0 },
            up       = { 0, 1,-1 },
        },
        graphicsContext = {
            window = window,
        },
    }
    engineState.camera.distance = distance(engineState.camera.center, engineState.camera.eye)

    glfw.SetWindowUserPointer(window, &engineState)
    initVkGraphics(&engineState.graphicsContext)
    defer clanupVkGraphics(&engineState.graphicsContext)

    lastFrameTime := t.now()
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()

        if mouseMode {
            if mouseDelta != { 0, 0 } {
                axis : Vec3 = { 0, 0, 0 }
                forward := engineState.camera.center - engineState.camera.eye
                if mouseDelta.x < 0 {
                    axis += engineState.camera.up
                }
                else if mouseDelta.x > 0 {
                    axis -= engineState.camera.up
                }
                if mouseDelta.y > 0 {
                    axis += cross(engineState.camera.up, forward)
                }
                else if mouseDelta.y < 0 {
                    axis -= cross(engineState.camera.up, forward)
                }
                rotation := rotation3(f32(radians(cameraSpeed)), axis)
                engineState.camera.up = rotation * engineState.camera.up
                forward = rotation * forward
                engineState.camera.eye = engineState.camera.center - forward
                mouseDelta = { 0, 0 }
            }
            if scrollDelta.y != 0 {
                forward := (engineState.camera.center - engineState.camera.eye) / engineState.camera.distance
                engineState.camera.distance *= 1 + f32(-scrollDelta.y * 0.1)
                engineState.camera.eye = engineState.camera.center - forward * engineState.camera.distance
                scrollDelta = { 0, 0 }
            }
        }

        drawFrame(&engineState.graphicsContext, engineState.camera)
        lastFrameTime = t.now()
        calcFrameRate(window)
    }
}

calcFrameRate :: proc(window : glfw.WindowHandle) {
    frameCount += 1
    if timeDelta := t.duration_seconds(t.since(fpsTimer)); timeDelta >= 1 {
        glfw.SetWindowTitle(window, strings.clone_to_cstring(fmt.aprintf("{:.2f}", (f64)(frameCount) / timeDelta)))
        frameCount = 0
        fpsTimer = t.now()
    }
}

keyCallback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
		glfw.SetWindowShouldClose(window, glfw.TRUE)
	}
}

glfwMouseButtonCallback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
    if button == glfw.MOUSE_BUTTON_MIDDLE && action == glfw.PRESS {
        if mouseMode {
            glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL);
        }
        else {
            glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED);
        }
        mouseMode = !mouseMode
    }
}

glfwCursorPosCallback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
    newPos : f64Vec2 = { xpos, ypos } * mouseSensitivity
    mouseDelta += newPos - mousePos
    mousePos = newPos
}

glfwScrollCallback :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset : f64) {
    scrollDelta = { xoffset, yoffset }
}

framebufferResizeCallback :: proc "c" (window : glfw.WindowHandle, width : i32, height : i32) {
    engineState := (^EngineState)(glfw.GetWindowUserPointer(window))
    engineState^.graphicsContext.framebufferResized = true
}