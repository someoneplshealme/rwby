--!strict
--[[
	Minimal synchronous signal for module-to-module events (no Instances, no yielding surprises).
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
	connected: boolean,
}

export type Signal<T...> = typeof(setmetatable(
	{} :: {
		_handlers: { (T...) -> () },
	},
	Signal
))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal.Connect<T...>(self: Signal<T...>, handler: (T...) -> ()): Connection
	table.insert(self._handlers, handler)
	local connection = { connected = true }
	function connection.Disconnect(conn: Connection)
		if not conn.connected then
			return
		end
		conn.connected = false
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection :: any
end

-- Each handler runs in its own thread, so one failing handler cannot break the others.
function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

function Signal.DisconnectAll<T...>(self: Signal<T...>)
	table.clear(self._handlers)
end

return Signal
