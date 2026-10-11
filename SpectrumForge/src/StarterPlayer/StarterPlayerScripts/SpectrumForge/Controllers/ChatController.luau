--!strict

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Theme = require(script.Parent.Parent.UI.Theme)

local ChatController = {}

local VIP_TAG = ("<font color=\"#%s\">[VIP]</font> "):format(Theme.Color.Charge:ToHex())

local function decorate(message: TextChatMessage): TextChatMessageProperties?
	local source = message.TextSource
	local player = source and Players:GetPlayerByUserId(source.UserId)
	if not player or player:GetAttribute("VIP") ~= true then
		return nil
	end

	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = VIP_TAG .. message.PrefixText
	return properties
end

function ChatController:Init() end

function ChatController:Start()
	TextChatService.OnIncomingMessage = decorate
end

return ChatController
