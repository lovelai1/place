--!strict
-- RateLimiter.lua  —  ServerScriptService/Server/Util/RateLimiter.lua
-- Sliding-window rate limiter for RemoteEvent spam protection.
-- Server-only; never require on the client.
--
-- Usage:
--   local limiter = RateLimiter.new(10, 1)   -- 10 requests per 1 second
--   if not limiter:Check(player) then return end

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiterInstance = typeof(setmetatable({} :: {
	_maxRequests   : number,
	_window        : number,
	_buckets       : { [number]: { timestamps: { number }, warnings: number } },
	_warnThreshold : number,
}, RateLimiter))

--- Create a new rate limiter.
-- @param maxRequests    Maximum allowed requests per window.
-- @param windowSeconds  Sliding window size in seconds.
-- @param warnThreshold  Violations before printing a warning (default 5).
function RateLimiter.new(maxRequests: number, windowSeconds: number, warnThreshold: number?): RateLimiterInstance
	assert(maxRequests > 0, "RateLimiter: maxRequests must be > 0")
	assert(windowSeconds > 0, "RateLimiter: windowSeconds must be > 0")
	return setmetatable({
		_maxRequests   = maxRequests,
		_window        = windowSeconds,
		_buckets       = {},
		_warnThreshold = warnThreshold or 5,
	}, RateLimiter) :: RateLimiterInstance
end

--- Returns true if the request is allowed, false if rate-limited.
function RateLimiter.Check(self: RateLimiterInstance, player: Player): boolean
	local userId = player.UserId
	local now    = os.clock()
	local cutoff = now - self._window

	local bucket = self._buckets[userId]
	if not bucket then
		bucket = { timestamps = {}, warnings = 0 }
		self._buckets[userId] = bucket
	end

	-- Prune timestamps outside the window
	local kept = {}
	for _, t in ipairs(bucket.timestamps) do
		if t > cutoff then table.insert(kept, t) end
	end
	bucket.timestamps = kept

	if #kept >= self._maxRequests then
		bucket.warnings += 1
		if bucket.warnings % self._warnThreshold == 1 then
			warn(string.format(
				"[RateLimiter] %s (%d) exceeded limit (%d/%ds). Violation #%d.",
				player.Name, userId, self._maxRequests, self._window, bucket.warnings
			))
		end
		return false
	end

	table.insert(bucket.timestamps, now)
	return true
end

--- Clear tracking data for a player (call on PlayerRemoving).
function RateLimiter.Flush(self: RateLimiterInstance, player: Player)
	self._buckets[player.UserId] = nil
end

--- Wipe all stored state (e.g. test teardown).
function RateLimiter.Clear(self: RateLimiterInstance)
	table.clear(self._buckets)
end

return RateLimiter
