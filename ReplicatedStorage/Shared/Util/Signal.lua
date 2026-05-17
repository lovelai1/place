--!strict
-- Lightweight BindableEvent wrapper used for server-side system signals.

local Signal = {}
Signal.__index = Signal

export type Connection = RBXScriptConnection
export type Signal = typeof(setmetatable({} :: {
	_bindable: BindableEvent,
}, Signal))

function Signal.new(): Signal
	local self = setmetatable({}, Signal)
	self._bindable = Instance.new("BindableEvent")
	return self
end

function Signal:Connect(callback: (...any) -> ()): Connection
	return self._bindable.Event:Connect(callback)
end

function Signal:Fire(...: any)
	self._bindable:Fire(...)
end

function Signal:Wait()
	return self._bindable.Event:Wait()
end

function Signal:Destroy()
	self._bindable:Destroy()
end

return Signal