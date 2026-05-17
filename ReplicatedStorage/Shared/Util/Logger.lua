--!strict
-- Logger.lua  —  ReplicatedStorage/Shared/Util/Logger.lua
-- Structured logger with per-tag level filtering. Safe on client and server.
--
-- Usage:
--   local log = Logger.new("MyService")
--   log.Info("Player joined")
--   log.Warn("Slow operation: %.2f s", elapsed)
--   log.Error("Critical failure: %s", reason)
--
-- Global minimum level controlled via Logger.SetMinLevel(level).
-- Levels: DEBUG < INFO < WARN < ERROR < NONE

local Logger = {}

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR" | "NONE"

export type LogInstance = {
	Debug : (fmt: string, ...any) -> (),
	Info  : (fmt: string, ...any) -> (),
	Warn  : (fmt: string, ...any) -> (),
	Error : (fmt: string, ...any) -> (),
	tag   : string,
}

local LEVEL_NUM: { [LogLevel]: number } = {
	DEBUG = 1,
	INFO  = 2,
	WARN  = 3,
	ERROR = 4,
	NONE  = 5,
}

local globalMinLevel: number = LEVEL_NUM.INFO
local tagOverrides: { [string]: number } = {}

local function fmtMsg(template: string, ...: any): string
	local args = { ... }
	if #args == 0 then return template end
	local ok, result = pcall(string.format, template, table.unpack(args))
	return if ok then result else template .. " [fmt error]"
end

local function shouldLog(tag: string, levelNum: number): boolean
	local min = tagOverrides[tag] or globalMinLevel
	return levelNum >= min
end

local function emit(tag: string, level: LogLevel, message: string)
	local line = string.format("[%s][%s] %s", level, tag, message)
	if level == "WARN" or level == "ERROR" then
		warn(line)
	else
		print(line)
	end
end

--- Create a logger instance bound to a tag.
function Logger.new(tag: string): LogInstance
	assert(type(tag) == "string" and tag ~= "", "Logger.new: tag must be a non-empty string.")
	return {
		tag = tag,
		Debug = function(template: string, ...: any)
			if shouldLog(tag, LEVEL_NUM.DEBUG) then emit(tag, "DEBUG", fmtMsg(template, ...)) end
		end,
		Info = function(template: string, ...: any)
			if shouldLog(tag, LEVEL_NUM.INFO) then emit(tag, "INFO", fmtMsg(template, ...)) end
		end,
		Warn = function(template: string, ...: any)
			if shouldLog(tag, LEVEL_NUM.WARN) then emit(tag, "WARN", fmtMsg(template, ...)) end
		end,
		Error = function(template: string, ...: any)
			if shouldLog(tag, LEVEL_NUM.ERROR) then emit(tag, "ERROR", fmtMsg(template, ...)) end
		end,
	}
end

--- Set the global minimum log level.
function Logger.SetMinLevel(level: LogLevel)
	local n = LEVEL_NUM[level]
	assert(n, "Logger.SetMinLevel: unknown level " .. tostring(level))
	globalMinLevel = n
end

--- Override the minimum level for a specific tag.
function Logger.SetTagLevel(tag: string, level: LogLevel)
	local n = LEVEL_NUM[level]
	assert(n, "Logger.SetTagLevel: unknown level " .. tostring(level))
	tagOverrides[tag] = n
end

--- Remove a per-tag override (falls back to global).
function Logger.ClearTagLevel(tag: string)
	tagOverrides[tag] = nil
end

--- Quick one-shot log without creating an instance.
function Logger.Log(tag: string, level: LogLevel, template: string, ...: any)
	local n = LEVEL_NUM[level]
	if n and shouldLog(tag, n) then
		emit(tag, level, fmtMsg(template, ...))
	end
end

return Logger
