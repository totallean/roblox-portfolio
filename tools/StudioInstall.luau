-- Paste into the Studio command bar while `python3 -m http.server 8765 --bind 127.0.0.1` runs in the
-- Portfolio folder. Pulls <Place>/out/manifest.json (made by make_installer.py) and recreates every script.
-- HttpEnabled is switched on only for the duration of the download and restored afterwards.

local PLACE = "WebSwing"
local BASE = "http://127.0.0.1:8765/" .. PLACE .. "/"

local HttpService = game:GetService("HttpService")

local function container(service: string, path: { string }): Instance
	local node = game:GetService(service)
	for _, name in path do
		local child = node:FindFirstChild(name)
		if not child then
			child = Instance.new("Folder")
			child.Name = name
			child.Parent = node
		end
		node = child
	end
	return node
end

local previous = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, result = pcall(function()
	local manifest = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "out/manifest.json", true))
	for _, root in manifest.roots do
		local old = container(root.service, root.container):FindFirstChild(root.name)
		if old then
			old:Destroy()
		end
	end
	for _, entry in manifest.scripts do
		local script = Instance.new(entry.className)
		script.Name = entry.name
		script.Source = HttpService:GetAsync(BASE .. entry.file, true)
		script.Parent = container(entry.service, entry.path)
	end
	return #manifest.scripts
end)
HttpService.HttpEnabled = previous
print(if ok then ("Installed " .. result .. " scripts for " .. PLACE) else ("Install failed: " .. tostring(result)))
