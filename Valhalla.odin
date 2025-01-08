package Valhalla

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "vendor:glfw"

APP_VERSION: u32 : (0 << 22) | (0 << 12) | (1)

frameCount: u16 = 0
fpsTimer := time.now()

paused := false
delta: f64 = 0.0
lastFrameTime := time.now()

mouseMode := false
mousePos, mouseDelta: f64Vec2 = {0, 0}, {0, 0}
mouseSensitivity: f64 = 1
scrollDelta: f64Vec2 = {0, 0}

cameraSpeed: f64 = 1
cameraMoveSpeed: f32 = 0.0003
cameraMove: Vec3 = {0, 0, 0}

logger: runtime.Logger

EngineState :: struct {
	activeCamera:    ^u32,
	cameras:         ^[]Camera,
	graphicsContext: ^GraphicsContext,
}

main :: proc() {
	{
		dashCount: u32 = 0
		filePath, _ := filepath.abs(os.args[0])
		for i := len(filePath) - 1; i >= 0; i -= 1 {
			if filepath.is_separator(filePath[i]) {
				dashCount += 1
				if dashCount == 2 {
					if err := os.set_current_directory(filePath[:i]); err != os.ERROR_NONE {
						fmt.printfln(
							"Failed to set current directory to '{}': {}",
							filePath[:i],
							err,
						)
					}
					break
				}
			}
		}
	}

	when ODIN_DEBUG {
		logPath := createLogPath()
		if logHandle, err := os.open(logPath, os.O_WRONLY | os.O_CREATE); err == 0 {
			logger = log.create_multi_logger(
				log.create_console_logger(),
				log.create_file_logger(logHandle),
			)
		} else {
			logger = log.create_multi_logger(log.create_console_logger())
			log.logf(.Warning, "Log file could not be created! Filename: {}", logPath)
		}
		context.logger = logger
		defer log.destroy_multi_logger(context.logger)

		tracker: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracker, context.allocator)
		context.allocator = mem.tracking_allocator(&tracker)

		defer {
			if len(tracker.allocation_map) > 0 {
				log.logf(.Debug, "=== %v allocations not freed: ===", len(tracker.allocation_map))
				for _, entry in tracker.allocation_map {
					log.logf(.Debug, "- %v bytes @ %v", entry.size, entry.location)
				}
			}
			if len(tracker.bad_free_array) > 0 {
				log.logf(.Debug, "=== %v incorrect frees: ===", len(tracker.bad_free_array))
				for entry in tracker.bad_free_array {
					log.logf(.Debug, "- %p @ %v", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&tracker)
		}
	}

	glfw.SetErrorCallback(glfwErrorCallback)

	if !glfw.Init() {
		log.log(.Fatal, "Failed to initalize glfw, quitting application.")
		return
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	width: i32 = 800
	height: i32 = 600
	name: cstring : "Valhalla"
	monitor: glfw.MonitorHandle = nil
	window := glfw.CreateWindow(width, height, name, monitor, nil)
	if window == nil {
		log.log(.Fatal, "Failed to create window, quitting application.")
		return
	}
	defer glfw.DestroyWindow(window)

	glfw.SetKeyCallback(window, keyCallback)
	glfw.SetMouseButtonCallback(window, glfwMouseButtonCallback)
	glfw.SetCursorPosCallback(window, glfwCursorPosCallback)
	glfw.SetScrollCallback(window, glfwScrollCallback)
	glfw.SetFramebufferSizeCallback(window, framebufferResizeCallback)

	engineState: EngineState = {
		graphicsContext = &{window = window},
	}
	glfw.SetWindowUserPointer(window, &engineState)
	
	initVkGraphics(engineState.graphicsContext)
	defer clanupVkGraphics(engineState.graphicsContext)

	if err := loadScene(engineState.graphicsContext, "./assets/scenes/bunny_box.json"); err != .None {
		log.logf(.Fatal, "Failed to load scene: {}", err)
		panic("Failed to load scene")
	}
	engineState.cameras = &engineState.graphicsContext.scenes[engineState.graphicsContext.activeScene].cameras
	engineState.activeCamera = &engineState.graphicsContext.scenes[engineState.graphicsContext.activeScene].activeCamera

	setActiveScene(engineState.graphicsContext, 0)

	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		if mouseMode {
			if mouseDelta != {0, 0} {
				axis: Vec3 = {0, 0, 0}
				forward := engineState.cameras[engineState.activeCamera^].center - engineState.cameras[engineState.activeCamera^].eye
				if mouseDelta.x < 0 {
					axis -= engineState.cameras[engineState.activeCamera^].up
				} else if mouseDelta.x > 0 {
					axis += engineState.cameras[engineState.activeCamera^].up
				}
				if mouseDelta.y > 0 {
					axis += cross(engineState.cameras[engineState.activeCamera^].up, forward)
				} else if mouseDelta.y < 0 {
					axis -= cross(engineState.cameras[engineState.activeCamera^].up, forward)
				}
				rotation := rotation3(f32(radians(cameraSpeed)), axis)
				engineState.cameras[engineState.activeCamera^].up = rotation * engineState.cameras[engineState.activeCamera^].up
				forward = rotation * forward
				engineState.cameras[engineState.activeCamera^].eye = engineState.cameras[engineState.activeCamera^].center - forward
				mouseDelta = {0, 0}
			}
			if scrollDelta.y != 0 {
				forward :=
					(engineState.cameras[engineState.activeCamera^].center - engineState.cameras[engineState.activeCamera^].eye) /
					engineState.cameras[engineState.activeCamera^].distance
				engineState.cameras[engineState.activeCamera^].distance *= 1 + f32(-scrollDelta.y * 0.1)
				engineState.cameras[engineState.activeCamera^].eye =
					engineState.cameras[engineState.activeCamera^].center - forward * engineState.cameras[engineState.activeCamera^].distance
				scrollDelta = {0, 0}
			}
		}

		if cameraMove.x != 0 {
			right := normalize(
				cross(
					engineState.cameras[engineState.activeCamera^].up,
					(engineState.cameras[engineState.activeCamera^].center - engineState.cameras[engineState.activeCamera^].eye) /
					engineState.cameras[engineState.activeCamera^].distance,
				),
			)
			movement := cameraMoveSpeed * cameraMove.x * right
			engineState.cameras[engineState.activeCamera^].eye += movement
			engineState.cameras[engineState.activeCamera^].center += movement
		}
		if cameraMove.y != 0 {
			movement := cameraMoveSpeed * cameraMove.y * engineState.cameras[engineState.activeCamera^].up
			engineState.cameras[engineState.activeCamera^].eye += movement
			engineState.cameras[engineState.activeCamera^].center += movement
		}
		if cameraMove.z != 0 {
			movement :=
				cameraMoveSpeed *
				cameraMove.z *
				(engineState.cameras[engineState.activeCamera^].center - engineState.cameras[engineState.activeCamera^].eye) /
				engineState.cameras[engineState.activeCamera^].distance
			engineState.cameras[engineState.activeCamera^].eye += movement
			engineState.cameras[engineState.activeCamera^].center += movement
		}

		delta := f32(time.duration_seconds(time.since(lastFrameTime)))
		lastFrameTime = time.now()
		drawFrame(engineState.graphicsContext, delta if !paused else 0.0)
		calcFrameRate(window)

		free_all(context.temp_allocator)
	}
}

calcFrameRate :: proc(window: glfw.WindowHandle) {
	frameCount += 1
	if timeDelta := time.duration_seconds(time.since(fpsTimer)); timeDelta >= 1 {
		glfw.SetWindowTitle(
			window,
			strings.clone_to_cstring(
				fmt.tprintf("{:.2f}", (f64)(frameCount) / timeDelta),
				context.temp_allocator,
			),
		)
		frameCount = 0
		fpsTimer = time.now()
	}
}

keyCallback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()
	context.logger = logger
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
		engineState := (^EngineState)(glfw.GetWindowUserPointer(window))
		camera := engineState.cameras[engineState.activeCamera^]
		log.logf(
			.Debug,
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
