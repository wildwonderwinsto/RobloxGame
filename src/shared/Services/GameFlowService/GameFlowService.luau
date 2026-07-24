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

local MIN_LOADING_TIME = 2.5 -- Give the beautiful loading screen some time to shine

function GameFlowService.Init(_self: GameFlowService)
	local player = Players.LocalPlayer

	-- Bind for fade completion signaling
	local fadeCompleteEvent = Instance.new("BindableEvent")

	local function onFadeComplete()
		fadeCompleteEvent:Fire()
	end

	local function onPlay()
		-- Transition: Menu -> FadingToBlack
		GameFlowAtoms.phase("FadingToBlack")
	end

	-- Mount UI with callbacks
	mount(e(RootUI, {
		onPlay = onPlay,
		onFadeComplete = onFadeComplete,
	}))

	-- Start the flow
	task.spawn(function()
		-- === LOADING PHASE ===
		GameFlowAtoms.phase("Loading")
		local loadStart = os.clock()

		-- Preload assets
		pcall(function()
			ContentProvider:PreloadAsync(game:GetDescendants())
		end)

		-- Ensure minimum display time
		local elapsed = os.clock() - loadStart
		if elapsed < MIN_LOADING_TIME then
			task.wait(MIN_LOADING_TIME - elapsed)
		end

		-- Start the cinematic camera BEFORE fading the loading screen out, 
		-- so it's already moving dynamically when the menu reveals!
		local useFocus = math.random() > 0.5
		local focusTarget = nil
		if useFocus then
			local cameraPaths = Workspace:FindFirstChild("CameraPaths") or ReplicatedStorage:FindFirstChild("CameraPaths")
			if cameraPaths then
				local introPath = cameraPaths:FindFirstChild("IntroPath")
				if introPath then
					focusTarget = introPath:FindFirstChild("FocusTarget")
				end
			end
		end

		CameraService:Play("IntroPath", { 
			loop = true,
			focusTarget = focusTarget
		})

		-- === FADE FROM LOADING ===
		GameFlowAtoms.phase("FadingFromLoading")
		task.wait(1.5) -- wait for the exact duration of the LoadingScreen fade tween

		-- === MENU PHASE ===
		GameFlowAtoms.phase("Menu")

		-- Wait for Play button press (phase change to FadingToBlack)
		while GameFlowAtoms.phase() ~= "FadingToBlack" do
			task.wait()
		end

		-- Wait for fade-to-black animation to complete
		fadeCompleteEvent.Event:Wait()

		-- === SPAWN ===
		CameraService:Stop()

		local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
		local requestSpawn = remotesFolder:WaitForChild("RequestSpawn")
		requestSpawn:FireServer()

		-- Wait for character to load
		if not player.Character then
			player.CharacterAdded:Wait()
		end

		-- Small delay for character to fully load and the world to stream
		task.wait(0.5)

		-- === FADE IN ===
		GameFlowAtoms.phase("FadingIn")
		fadeCompleteEvent.Event:Wait()

		-- === GAMEPLAY ===
		GameFlowAtoms.phase("Gameplay")
		fadeCompleteEvent:Destroy()
	end)
end

return GameFlowService :: GameFlowService
