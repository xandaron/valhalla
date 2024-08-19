package Valhalla

import "base:runtime"

import "core:fmt"
import "core:math"
import "core:os"
import t "core:time"
import dt "core:time/datetime"

import vk "vendor:vulkan"

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
	//TODO: There has to be a better way of doing this.
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
		"./logs/{:4i}{:2i}{:2i}{:2.0f}{:2.0f}{:2.0f}.log",
		dateTime.year,
		dateTime.month,
		dateTime.day,
		hours,
		minutes,
		seconds,
	)
	return str
}

log :: proc(flag: MessageFlag, message: string) {
	str := fmt.aprintfln("[{}] {}", messageFlagToString(flag), message)
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

// There has to be a better way of doing this
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
	if .GENERAL in messageType {
		return "General"
	}
	if .VALIDATION in messageType {
		return "Validation"
	}
	if .PERFORMANCE in messageType {
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
