local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local GameFlowAtoms = require(ReplicatedStorage.Shared.State.GameFlowAtoms)
local CameraService = require(ReplicatedStorage.Shared.Services.CameraService.CameraService)
local RootUI = require(ReplicatedStorage.Shared.UI.RootUI)
local mount = require(ReplicatedStorage.Shared.UI.Mount)

local e = React.createElement

type GameFlowService = {
	Init: (self: GameFlowService) -> (),
}

local GameFlowService = {} :: GameFlowService & typeof(setmetatable({}, {}))

local MIN_LOADING_TIME = 2.5

function GameFlowService.Init(_self: GameFlowService)
	local player = Players.LocalPlayer

	local fadeCompleteEvent = Instance.new("BindableEvent")

	local function onFadeComplete()
		fadeCompleteEvent:Fire()
	end

	local function onPlay()
		GameFlowAtoms.phase("FadingToBlackFromMenu")
	end

	mount(e(RootUI, {
		onPlay = onPlay,
		onFadeComplete = onFadeComplete,
	}))

	task.spawn(function()
		-- === LOADING PHASE ===
		GameFlowAtoms.phase("Loading")
		local loadStart = os.clock()

		pcall(function()
			ContentProvider:PreloadAsync(game:GetDescendants())
		end)

		local elapsed = os.clock() - loadStart
		if elapsed < MIN_LOADING_TIME then
			task.wait(MIN_LOADING_TIME - elapsed)
		end

		-- Start the camera path while the screen is still black
		local useFocus = math.random() > 0.5
		local focusTarget = nil
		if useFocus then
			local cameraPaths = Workspace:FindFirstChild("CameraPaths")
				or ReplicatedStorage:FindFirstChild("CameraPaths")
			if cameraPaths then
				local introPath = cameraPaths:FindFirstChild("IntroPath")
				if introPath then
					focusTarget = introPath:FindFirstChild("FocusTarget")
				end
			end
		end

		CameraService:Play("IntroPath", {
			loop = true,
			focusTarget = focusTarget,
		})

		-- === FADE TO BLACK FROM LOADING ===
		-- Screen goes black over the loading screen, hiding it cleanly
		GameFlowAtoms.phase("FadingToBlackFromLoading")
		fadeCompleteEvent.Event:Wait()

		-- === FADE IN TO MENU ===
		-- Now the menu is mounted behind the black overlay; fade reveals it
		GameFlowAtoms.phase("FadingInMenu")
		fadeCompleteEvent.Event:Wait()

		-- === MENU PHASE ===
		GameFlowAtoms.phase("Menu")

		-- Wait for Play button press
		while GameFlowAtoms.phase() ~= "FadingToBlackFromMenu" do
			task.wait()
		end

		-- Wait for fade-to-black to finish
		fadeCompleteEvent.Event:Wait()

		-- === SPAWN ===
		CameraService:Stop()

		local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
		local requestSpawn = remotesFolder:WaitForChild("RequestSpawn")
		requestSpawn:FireServer()

		if not player.Character then
			player.CharacterAdded:Wait()
		end

		task.wait(0.5)

		-- === FADE IN TO GAMEPLAY ===
		GameFlowAtoms.phase("FadingInGame")
		fadeCompleteEvent.Event:Wait()

		-- === GAMEPLAY ===
		GameFlowAtoms.phase("Gameplay")
		fadeCompleteEvent:Destroy()
	end)
end

return GameFlowService :: GameFlowService
