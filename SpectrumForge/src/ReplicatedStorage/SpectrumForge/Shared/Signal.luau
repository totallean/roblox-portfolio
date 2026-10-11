--!strict

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (Connection) -> () }
export type Class = typeof(setmetatable({} :: {
	_handlers: { (...any) -> () },
}, Signal))

function Signal.new(): Class
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Class, fn: (...any) -> ()): Connection
	table.insert(self._handlers, fn)
	local connection
	connection = {
		Disconnect = function()
			local i = table.find(self._handlers, fn)
			if i then
				table.remove(self._handlers, i)
			end
		end,
	}
	return connection
end

function Signal.Fire(self: Class, ...: any): ()
	for _, fn in table.clone(self._handlers) do
		task.spawn(fn, ...)
	end
end

function Signal.Destroy(self: Class): ()
	table.clear(self._handlers)
end

return Signal
