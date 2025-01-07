package Valhalla

import "base:runtime"

import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import t "core:time"
import dt "core:time/datetime"
import vk "vendor:vulkan"


createLogPath :: proc() -> string {
	if !os.exists("./logs") do os.make_directory("./logs")
	
	//TODO: There has to be a better way of doing this. Maybe I can check how many files are in the directory and then create a new file with the next number.
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

	str: string = fmt.tprintf(
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


//########################################################//
//                          GLFW                          //
//########################################################//


glfwErrorCallback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	context.logger = logger
	log.logf(.Error, "[GLFW Error]: {}", string(desc))
}


//########################################################//
//                         Vulkan                         //
//########################################################//

// TODO: There has to be a better way of doing this.
when ODIN_OS == .Windows {
	vkDebugCallback :: proc "std" (
		messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
		messageType: vk.DebugUtilsMessageTypeFlagsEXT,
		pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
		pUserData: rawptr,
	) -> b32 {
		context = runtime.default_context()
		context.logger = logger
		log.logf(
			vkDecodeSeverity(messageSeverity),
			"Vulkan validation layer ({}):\n{}\n",
			vkDecodeMessageTypeFlag(messageType),
			pCallbackData.pMessage,
		)
		return false
	}
} else {
	vkDebugCallback :: proc "cdecl" (
		messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
		messageType: vk.DebugUtilsMessageTypeFlagsEXT,
		pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
		pUserData: rawptr,
	) -> b32 {
		context = runtime.default_context()
		context.logger = logger
		log.logf(
			vkDecodeSeverity(messageSeverity),
			"Vulkan validation layer ({}):\n{}\n",
			vkDecodeMessageTypeFlag(messageType),
			pCallbackData.pMessage,
		)
		return false
	}
}

vkDecodeSeverity :: proc(
	messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
) -> runtime.Logger_Level {
	if vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE in messageSeverity {
		return .Info
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.INFO in messageSeverity {
		return .Debug
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.WARNING in messageSeverity {
		return .Warning
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.ERROR in messageSeverity {
		return .Error
	}
	panic("Unknown severity type!")
}

vkDecodeSeverityString :: proc(messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT) -> string {
	if vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE in messageSeverity {
		return "Info"
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.INFO in messageSeverity {
		return "Debug"
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.WARNING in messageSeverity {
		return "Warning"
	}
	if vk.DebugUtilsMessageSeverityFlagEXT.ERROR in messageSeverity {
		return "Error"
	}
	panic("Unknown severity type!")
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
	   .SUCCESS {
		log.log(.Warning, "Failed to create vulkan debug callback!")
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
