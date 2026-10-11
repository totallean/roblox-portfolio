--!strict

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage.SpectrumForge.Shared.Assets)

local SoundController = {}

local MASTER = 0.8
local POOLED = { Tap = 4 }

local folder: Folder
local pools: { [string]: { Sound } } = {}
local cursor: { [string]: number } = {}

local State, UI

local function makeSound(name: string, entry: any): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = entry.id
	sound.Volume = entry.volume * MASTER
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.Parent = folder
	return sound
end

function SoundController:Play(name: string)
	local pool = pools[name]
	if not pool or #pool == 0 then
		return
	end

	local index = (cursor[name] or 0) % #pool + 1
	cursor[name] = index

	local sound = pool[index]
	sound.TimePosition = 0
	sound:Play()
end

function SoundController:Init()
	folder = Instance.new("Folder")
	folder.Name = "SpectrumForgeSounds"
	folder.Parent = SoundService

	for name, entry in Assets.Sounds do
		local count = POOLED[name] or 1
		local pool = {}
		for _ = 1, count do
			table.insert(pool, makeSound(name, entry))
		end
		pools[name] = pool
		cursor[name] = 0
	end

	task.spawn(function()
		local list = {}
		for _, pool in pools do
			table.insert(list, pool[1])
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

function SoundController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")

	local hotbar = UI:GetHotbar()
	if hotbar then
		local tapSlot = hotbar:FindFirstChild("hotbar.charge")
		if tapSlot and tapSlot:IsA("TextButton") then
			tapSlot.MouseButton1Down:Connect(function()
				self:Play("Tap")
			end)
		end
	end

	State.Notified:Connect(function(kind, payload)
		if kind == "CrateResult" then
			self:Play("CrateOpen")

		elseif kind == "BattleShow" then
			self:Play("BattleStart")

		elseif kind == "BattleResult" then
			task.delay(0.6, function()
				self:Play(payload.won and "BattleWin" or "BattleLoss")
			end)

		elseif kind == "RebirthResult" then
			self:Play("Rebirth")

		elseif kind == "PurchaseResult" or kind == "GhostWins" then
			self:Play("Purchase")

		elseif kind == "Error" then
			self:Play("Error")
		end
	end)
end

return SoundController
