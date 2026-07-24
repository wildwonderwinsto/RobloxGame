local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local function mount(app: any)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(app)

	return root
end

return mount
