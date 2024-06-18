package Asgard

import "core:fmt"
import "core:strings"
import "core:mem"
import "core:os"
import dt "core:time/datetime"

@(private="file")
logPath : string = getDateTimeToString()

initDebuger :: proc() {
    debugMemory()

    logPath = getDateTimeToString()
    debugMessage(.MESSAGE, "Created log file!")
}

@(private="file")
getDateTimeToString :: proc() -> string {
    dateTime : dt.DateTime
    str : string = fmt.aprint(dateTime.year, dateTime.month, dateTime.day, dateTime.hour, dateTime.minute, dateTime.second, sep="")
    return str
}

MessageFlag :: enum {
    MESSAGE,
    DEBUG,
    WARNING,
    ERROR
}

debugMessage :: proc(flag : MessageFlag, message : string, args : ..any) {
    str : string = fmt.aprintfln(strings.concatenate({"[{}] ", message}), messageFlagToString(flag), args)
    defer delete(str)
    fmt.println(str)

    fileHandle, err := os.open(logPath)
    if (err != 0) {
        fmt.print("Log file could not be created/opened!!!")
    }
    os.write_string(fileHandle, str)
    os.close(fileHandle)
}

@(private="file")
messageFlagToString :: proc(flag : MessageFlag) -> string {
    switch flag {
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