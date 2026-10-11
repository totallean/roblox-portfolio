local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(script.Parent.Config)

local Sfx = {}

local FOLDER_NAME = "Sfx"

local cfg = Config.Sound
local pools = {}
local ready = false
local music = nil

local function container(): Folder
	local folder = SoundService:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = SoundService
	end
	return folder
end

function Sfx.Init()
	if ready then
		return
	end
	ready = true

	if not cfg.Enabled then
		return
	end

	if not RunService:IsClient() then
		warn("[Sfx] это клиентский модуль, на сервере он ничего не делает")
		return
	end

	local folder = container()
	local everything = {}

	for name, def in pairs(cfg.Effects) do
		local pool = { Voices = {}, Next = 1, LastPlay = 0 }
		for index = 1, math.max(1, cfg.Voices) do
			local sound = Instance.new("Sound")
			sound.Name = ("%s_%d"):format(name, index)
			sound.SoundId = def.Id
			sound.Volume = (def.Volume or 0.5) * cfg.MasterVolume
			sound.Parent = folder
			table.insert(pool.Voices, sound)
			table.insert(everything, sound)
		end
		pools[name] = pool
	end

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(everything)
		end)
	end)
end

function Sfx.Play(name: string)
	if not cfg.Enabled then
		return
	end
	if not ready then
		Sfx.Init()
	end

	local def = cfg.Effects[name]
	local pool = pools[name]
	if not def or not pool then
		warn(("[Sfx] неизвестный звук %q"):format(tostring(name)))
		return
	end

	local now = os.clock()
	if now - pool.LastPlay < (def.MinInterval or 0) then
		return
	end
	pool.LastPlay = now

	local sound = pool.Voices[pool.Next]
	pool.Next = (pool.Next % #pool.Voices) + 1

	local pitch = def.Pitch
	sound.PlaybackSpeed = pitch and (pitch[1] + math.random() * (pitch[2] - pitch[1])) or 1
	sound.TimePosition = 0
	sound:Play()
end

function Sfx.StartMusic()
	local settings = Config.Music
	if not settings or not settings.Enabled or #settings.Tracks == 0 then
		return
	end
	if music or not RunService:IsClient() then
		return
	end

	music = Instance.new("Sound")
	music.Name = "Music"
	music.Volume = settings.Volume
	music.Looped = false
	music.Parent = container()

	local order = {}
	for index = 1, #settings.Tracks do
		order[index] = index
	end
	if settings.Shuffle then
		for index = #order, 2, -1 do
			local swap = math.random(index)
			order[index], order[swap] = order[swap], order[index]
		end
	end

	task.spawn(function()
		local position = 0
		while music and music.Parent do
			position = (position % #order) + 1
			music.SoundId = settings.Tracks[order[position]].Id
			music.TimePosition = 0
			music:Play()

			local deadline = os.clock() + 8
			while music.Parent and not music.IsPlaying and os.clock() < deadline do
				task.wait(0.25)
			end
			while music.Parent and music.IsPlaying do
				task.wait(1)
			end

			task.wait(settings.Gap or 0)
		end
	end)
end

function Sfx.SetMusicEnabled(on: boolean)
	if not music then
		return
	end
	music.Volume = on and Config.Music.Volume or 0
end

return Sfx
