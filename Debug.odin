package Valhalla

import "base:runtime"

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import t "core:time"
import dt "core:time/datetime"

import vk "vendor:vulkan"

memTracker: mem.Tracking_Allocator

MessageFlag :: enum {
	NONE,
	MESSAGE,
	DEBUG,
	WARNING,
	ERROR,
	UNKNOWN,
}

@(private = "file")
fileLogging := true

@(private = "file")
logPath := getDateTimeToString()

@(init)
initDebuger :: proc() {
	when ODIN_DEBUG {
		debugMemory()
	}
	fmt.println("Debugging:")

	if fileLogging {
		logPath = getDateTimeToString()

		fileHandle, err := os.open(logPath, mode = (os.O_WRONLY | os.O_CREATE))
		if (err != 0) {
			fmt.printfln("Log file could not be created! Filename: {}", logPath)
			return
		}
		os.close(fileHandle)

		log(.MESSAGE, fmt.aprintf("Created log file! Dir: {}", logPath))
	}
}

@(private = "file")
getDateTimeToString :: proc() -> string {
	//To-Do: There has to be a better way of doing this.
	now := t.now()
	year, month, day := t.date(now)
	dateTime: dt.DateTime = {
		date = dt.Date{year = (i64)(year), month = (i8)(month), day = (i8)(day)},
	}
	midnight, _ := t.datetime_to_time(dateTime)
	seconds := math.floor(t.duration_seconds(t.diff(midnight, now)))

	hours := math.floor(seconds / t.SECONDS_PER_HOUR)
	seconds -= hours * t.SECONDS_PER_HOUR
	minutes := math.floor(seconds / t.SECONDS_PER_MINUTE)
	seconds -= minutes * t.SECONDS_PER_MINUTE

	str: string = fmt.aprintf(
		"./logs/{:4i}{:2i}{:2i}{:2.0f}{:2.0f}{:2.0f}{}",
		dateTime.year,
		dateTime.month,
		dateTime.day,
		hours,
		minutes,
		seconds,
		".log",
	)
	return str
}

log :: proc(flag: MessageFlag, message: string) {
	str := fmt.aprintfln(strings.concatenate({"[{}] ", message}), messageFlagToString(flag))
	fmt.print(str)
	if fileLogging {
		fileHandle, err := os.open(logPath, mode = (os.O_WRONLY | os.O_APPEND))
		defer os.close(fileHandle)
		if (err != 0) {
			fmt.println("Log file could not be opened!!!")
			return
		}
		os.write_string(fileHandle, str)
	}
}

@(private = "file")
messageFlagToString :: proc(flag: MessageFlag) -> string {
	#partial switch flag {
	case .MESSAGE:
		return "MESSAGE"
	case .DEBUG:
		return "DEBUG"
	case .WARNING:
		return "WARNING"
	case .ERROR:
		return "ERROR"
	}
	return "UNKNOWN"
}

@(private = "file")
debugMemory :: proc() {
	mem.tracking_allocator_init(&memTracker, context.allocator)
	context.allocator = mem.tracking_allocator(&memTracker)
}

printMemoryInfo :: proc() {
	if len(memTracker.allocation_map) > 0 {
		log(.WARNING, fmt.aprintf("=== %v allocations not freed: ===\n", len(memTracker.allocation_map)))
		for _, entry in memTracker.allocation_map {
			log(.WARNING, fmt.aprintf("- %v bytes @ %v\n", entry.size, entry.location))
		}
	}
	if len(memTracker.bad_free_array) > 0 {
		fmt.eprintf("=== %v incorrect frees: ===\n", len(memTracker.bad_free_array))
		for entry in memTracker.bad_free_array {
			log(.WARNING, fmt.aprintf("- %p @ %v\n", entry.memory, entry.location))
		}
	}
	mem.tracking_allocator_destroy(&memTracker)
}

//########################################################//
//                          GLFW                          //
//########################################################//


glfwErrorCallback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	log(.ERROR, string(desc))
}


//########################################################//
//                         Vulkan                         //
//########################################################//

when ODIN_OS == .Windows {
	vkDebugCallback :: proc "std" (
		messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
		messageType: vk.DebugUtilsMessageTypeFlagsEXT,
		pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
		pUserData: rawptr,
	) -> b32 {
		context = runtime.default_context()
		log(
			vkDecodeSeverity(messageSeverity),
			fmt.aprintf(
				"Vulkan validation layer ({}):\n{}\n",
				vkDecodeMessageTypeFlag(messageType),
				pCallbackData.pMessage,
			),
		)
		return false
	}
}
else {
	vkDebugCallback :: proc "cdecl" (
		messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
		messageType: vk.DebugUtilsMessageTypeFlagsEXT,
		pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
		pUserData: rawptr,
	) -> b32 {
		context = runtime.default_context()
		log(
			vkDecodeSeverity(messageSeverity),
			fmt.aprintf(
				"Vulkan validation layer ({}):\n{}\n",
				vkDecodeMessageTypeFlag(messageType),
				pCallbackData.pMessage,
			),
		)
		return false
	}
}

vkDecodeSeverity :: proc(messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT) -> MessageFlag {
	if vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE in messageSeverity {
		return .MESSAGE
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.INFO in messageSeverity {
		return .DEBUG
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.WARNING in messageSeverity {
		return .WARNING
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.ERROR in messageSeverity {
		return .ERROR
	}
	return .UNKNOWN
}

vkDecodeMessageTypeFlag :: proc(messageType: vk.DebugUtilsMessageTypeFlagsEXT) -> string {
	if vk.DebugUtilsMessageTypeFlagEXT.GENERAL in messageType {
		return "General"
	}
	if vk.DebugUtilsMessageTypeFlagEXT.VALIDATION in messageType {
		return "Validation"
	}
	if vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE in messageType {
		return "Performance"
	}
	return "Unknown"
}

vkSetupDebugMessenger :: proc(graphicsContext: ^GraphicsContext) {
	createInfo := vkPopulateDebugMessengerCreateInfo()
	if vk.CreateDebugUtilsMessengerEXT(
		   graphicsContext^.instance,
		   &createInfo,
		   nil,
		   &graphicsContext^.debugMessenger,
	   ) !=
	   vk.Result.SUCCESS {
		log(.WARNING, "Failed to create vulkan debug callback.")
	}
}

vkPopulateDebugMessengerCreateInfo :: proc() -> (createInfo: vk.DebugUtilsMessengerCreateInfoEXT) {
	createInfo = {
		sType           = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
		pNext           = nil,
		messageSeverity = {.ERROR, .WARNING, .INFO},
		messageType     = {.GENERAL, .PERFORMANCE, .VALIDATION},
		pfnUserCallback = vkDebugCallback,
		pUserData       = nil,
	}
	return
}
