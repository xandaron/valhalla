package Asgard

import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:mem"
import "core:os"
import dt "core:time/datetime"
import vk "vendor:vulkan"

MessageFlag :: enum {
    MESSAGE,
    DEBUG,
    WARNING,
    ERROR,
    UNKNOWN
}

@(private="file")
logPath : string = getDateTimeToString()

@(init)
initDebuger :: proc() {
    debugMemory()

    fmt.println("Hello World!")
    logPath = getDateTimeToString()

    fileHandle, err := os.open(logPath, mode=(os.O_WRONLY|os.O_CREATE))
    if (err != 0) {
        fmt.print("Log file could not be created!!!")
        return
    }
    os.close(fileHandle)
    
    log(.MESSAGE, "Created log file! Dir: {}", logPath)
}

@(private="file")
getDateTimeToString :: proc() -> string {
    dateTime : dt.DateTime
    str : string = fmt.aprint("./logs/", dateTime.year, dateTime.month, dateTime.day, dateTime.hour, dateTime.minute, dateTime.second, ".log", sep="")
    return str
}

log :: proc(flag : MessageFlag, message : string, args : ..any) {
    str : string = fmt.aprintfln(strings.concatenate({"[{}] ", message}), args={messageFlagToString(flag), args[:]})
    defer delete(str)
    fmt.print(str)
    fileHandle, err := os.open(logPath, mode=(os.O_WRONLY|os.O_APPEND))
    defer os.close(fileHandle)
    if (err != 0) {
        fmt.print("Log file could not be opened!!!")
        return
    }
    os.write_string(fileHandle, str)
}

@(private="file")
messageFlagToString :: proc(flag : MessageFlag) -> string {
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

@(private="file")
debugMemory :: proc() {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
        if len(track.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        if len(track.bad_free_array) > 0 {
            fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
            for entry in track.bad_free_array {
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }
}


//########################################################//
//                          GLFW                          //
//########################################################//


glfwErrorCallback :: proc "c" (code : i32, desc : cstring) {
    context = runtime.default_context()
	log(.ERROR, string(desc))
}


//########################################################//
//                         Vulkan                         //
//########################################################//


vkDebugCallback :: proc "std" (
    messageSeverity : vk.DebugUtilsMessageSeverityFlagsEXT,
    messageType     : vk.DebugUtilsMessageTypeFlagsEXT,
    pCallbackData   : ^vk.DebugUtilsMessengerCallbackDataEXT,
    pUserData       : rawptr
) -> b32 {
    context = runtime.default_context()
    log(vkDecodeSeverity(messageSeverity), "Vulkan validation layer ({}):\n\t{}", vkDecodeMessageTypeFlag(messageType), pCallbackData.pMessage);
    return false
}

vkDecodeSeverity :: proc(messageSeverity : vk.DebugUtilsMessageSeverityFlagsEXT) -> MessageFlag {
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

vkDecodeMessageTypeFlag :: proc(messageType : vk.DebugUtilsMessageTypeFlagsEXT) -> string {
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

vkSetupDebugMessenger :: proc(graphicsContext : ^GraphicsContext) {
    createInfo := vkPopulateDebugMessengerCreateInfo()
    if vk.CreateDebugUtilsMessengerEXT(graphicsContext^.instance, &createInfo, nil, &graphicsContext^.debugMessenger) != vk.Result.SUCCESS {
        log(.WARNING, "Failed to create vulkan debug callback.")
    }
}

vkPopulateDebugMessengerCreateInfo :: proc() -> (createInfo : vk.DebugUtilsMessengerCreateInfoEXT){
    createInfo = {
        sType           = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        pNext           = nil,
        messageSeverity = { .ERROR, .WARNING, .INFO },
        messageType     = { .GENERAL, .PERFORMANCE, .VALIDATION },
        pfnUserCallback = vkDebugCallback,
        pUserData       = nil
    }
    return
}