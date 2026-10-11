--!strict

local Release = {}

Release.MODE = true

Release.VERSION = "0.1.0"

function Release.isDev(): boolean
	return not Release.MODE
end

return Release
