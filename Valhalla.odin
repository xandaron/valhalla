package Valhalla

import "base:runtime"

import "core:fmt"
import "core:os"
import "core:strings"
import t "core:time"
import "core:mem"

import "vendor:glfw"

APP_VERSION: u32 : (0 << 22) | (0 << 12) | (1)

frameCount: u16 = 0
fpsTimer: t.Time = t.now()

mouseMode: bool = false
mousePos, mouseDelta: f64Vec2 = {0, 0}, {0, 0}
mouseSensitivity: f64 = 1
scrollDelta: f64Vec2 = {0, 0}

cameraSpeed: f64 = 1
cameraMoveSpeed: f32 = 0.0001
cameraMove: Vec3 = {0, 0, 0}

EngineState :: struct {
	camera:          Camera,
	graphicsContext: GraphicsContext,
}

main :: proc() {
	when ODIN_DEBUG {
		tracker: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracker, context.allocator)
		context.allocator = mem.tracking_allocator(&tracker)

		defer {
			if len(tracker.allocation_map) > 0 {
				log(.WARNING, fmt.aprintf("=== %v allocations not freed: ===\n", len(tracker.allocation_map)))
				for _, entry in tracker.allocation_map {
					log(.WARNING, fmt.aprintf("- %v bytes @ %v\n", entry.size, entry.location))
				}
			}
			if len(tracker.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(tracker.bad_free_array))
				for entry in tracker.bad_free_array {
					log(.WARNING, fmt.aprintf("- %p @ %v\n", entry.memory, entry.location))
				}
			}
			mem.tracking_allocator_destroy(&tracker)
		}
	}

	glfw.SetErrorCallback(glfwErrorCallback)

	if !glfw.Init() {
		log(.ERROR, "Failed to initalize glfw, quitting application.")
		panic("Failed to initalize glfw, quitting application.")
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	width: i32 = 800
	height: i32 = 600
	name: cstring : "New Innsmouth"
	monitor: glfw.MonitorHandle = nil
	window: glfw.WindowHandle = glfw.CreateWindow(width, height, name, monitor, nil)
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

	engineState: EngineState = {
		camera = {
			eye = {0.0, 0.45, -1.3},
			center = {0.0, 0.45, 0.0},
			up = {0.0, 1.0, 0.0},
			mode = .ORTHOGRAPHIC,
		},
		graphicsContext = {window = window},
	}
	engineState.camera.distance = distance(engineState.camera.center, engineState.camera.eye)

	glfw.SetWindowUserPointer(window, &engineState)
	initVkGraphics(&engineState.graphicsContext)
	defer clanupVkGraphics(&engineState.graphicsContext)

	lastFrameTime := t.now()
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		if mouseMode {
			if mouseDelta != {0, 0} {
				axis: Vec3 = {0, 0, 0}
				forward := engineState.camera.center - engineState.camera.eye
				if mouseDelta.x < 0 {
					axis -= engineState.camera.up
				} else if mouseDelta.x > 0 {
					axis += engineState.camera.up
				}
				if mouseDelta.y > 0 {
					axis += cross(engineState.camera.up, forward)
				} else if mouseDelta.y < 0 {
					axis -= cross(engineState.camera.up, forward)
				}
				rotation := rotation3(f32(radians(cameraSpeed)), axis)
				engineState.camera.up = rotation * engineState.camera.up
				forward = rotation * forward
				engineState.camera.eye = engineState.camera.center - forward
				mouseDelta = {0, 0}
			}
			if scrollDelta.y != 0 {
				forward :=
					(engineState.camera.center - engineState.camera.eye) /
					engineState.camera.distance
				engineState.camera.distance *= 1 + f32(-scrollDelta.y * 0.1)
				engineState.camera.eye =
					engineState.camera.center - forward * engineState.camera.distance
				scrollDelta = {0, 0}
			}
		}

		if cameraMove.x != 0 {
			right := normalize(
				cross(
					engineState.camera.up,
					(engineState.camera.center - engineState.camera.eye) /
					engineState.camera.distance,
				),
			)
			movement := cameraMoveSpeed * cameraMove.x * right
			engineState.camera.eye += movement
			engineState.camera.center += movement
		}
		if cameraMove.y != 0 {
			movement := cameraMoveSpeed * cameraMove.y * engineState.camera.up
			engineState.camera.eye += movement
			engineState.camera.center += movement
		}
		if cameraMove.z != 0 {
			movement :=
				cameraMoveSpeed *
				cameraMove.z *
				(engineState.camera.center - engineState.camera.eye) /
				engineState.camera.distance
			engineState.camera.eye += movement
			engineState.camera.center += movement
		}

		drawFrame(&engineState.graphicsContext, engineState.camera)
		lastFrameTime = t.now()
		calcFrameRate(window)
	}
}

calcFrameRate :: proc(window: glfw.WindowHandle) {
	frameCount += 1
	if timeDelta := t.duration_seconds(t.since(fpsTimer)); timeDelta >= 1 {
		title := strings.clone_to_cstring(fmt.aprintf("{:.2f}", (f64)(frameCount) / timeDelta))
		glfw.SetWindowTitle(
			window,
			title,
		)
		delete(title)
		frameCount = 0
		fpsTimer = t.now()
	}
}

keyCallback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()
	if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
		glfw.SetWindowShouldClose(window, glfw.TRUE)
	}
	if key == glfw.KEY_D {
		if action == glfw.PRESS {
			cameraMove.x += 1
		} else if action == glfw.RELEASE {
			cameraMove.x -= 1
		}
	}
	if key == glfw.KEY_A {
		if action == glfw.PRESS {
			cameraMove.x -= 1
		} else if action == glfw.RELEASE {
			cameraMove.x += 1
		}
	}
	if key == glfw.KEY_SPACE {
		if action == glfw.PRESS {
			cameraMove.y += 1
		} else if action == glfw.RELEASE {
			cameraMove.y -= 1
		}
	}
	if key == glfw.KEY_LEFT_SHIFT {
		if action == glfw.PRESS {
			cameraMove.y -= 1
		} else if action == glfw.RELEASE {
			cameraMove.y += 1
		}
	}
	if key == glfw.KEY_W {
		if action == glfw.PRESS {
			cameraMove.z += 1
		} else if action == glfw.RELEASE {
			cameraMove.z -= 1
		}
	}
	if key == glfw.KEY_S {
		if action == glfw.PRESS {
			cameraMove.z -= 1
		} else if action == glfw.RELEASE {
			cameraMove.z += 1
		}
	}
	if key == glfw.KEY_C && action == glfw.PRESS {
		camera := (^EngineState)(glfw.GetWindowUserPointer(window))^.camera
		log(
			.DEBUG,
			fmt.aprintf(
				"eye: ({}, {}, {}), center: ({}, {}, {}), up: ({}, {}, {})",
				camera.eye.x,
				camera.eye.y,
				camera.eye.z,
				camera.center.x,
				camera.center.y,
				camera.center.z,
				camera.up.x,
				camera.up.y,
				camera.up.z,
			),
		)
	}
}

glfwMouseButtonCallback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	if button == glfw.MOUSE_BUTTON_MIDDLE && action == glfw.PRESS {
		if mouseMode {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)
		} else {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
		}
		mouseMode = !mouseMode
	}
}

glfwCursorPosCallback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	newPos: f64Vec2 = {xpos, ypos} * mouseSensitivity
	vector1 := mousePos
	mouseDelta = newPos - vector1
	mousePos = newPos
}

glfwScrollCallback :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
	scrollDelta = {xoffset, yoffset}
}

framebufferResizeCallback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	engineState := (^EngineState)(glfw.GetWindowUserPointer(window))
	engineState^.graphicsContext.framebufferResized = true
}
