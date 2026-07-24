local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Charm = require(ReplicatedStorage.Packages.Charm)

local GameFlowAtoms = require(ReplicatedStorage.Shared.State.GameFlowAtoms)
local LoadingScreen = require(ReplicatedStorage.Shared.UI.Screens.LoadingScreen)
local MainMenu = require(ReplicatedStorage.Shared.UI.Screens.MainMenu)
local FadeOverlay = require(ReplicatedStorage.Shared.UI.FadeOverlay)
local EyeOpenOverlay = require(ReplicatedStorage.Shared.UI.EyeOpenOverlay)

local e = React.createElement

export type RootUIProps = {
	onPlay: () -> (),
	onFadeComplete: (() -> ())?,
}

local function RootUI(props: RootUIProps)
	local phase, setPhase = React.useState(GameFlowAtoms.phase())

	React.useEffect(function()
		local cleanup = Charm.subscribe(GameFlowAtoms.phase, function(newPhase)
			setPhase(newPhase)
		end)
		return cleanup
	end, {})

	local children: { [string]: any } = {}

	-- Show LoadingScreen during Loading and while fading to black from it
	if phase == "Loading" or phase == "FadingToBlackFromLoading" then
		children.LoadingScreen = e(LoadingScreen, { fadingOut = false })
	end

	-- Show MainMenu while fading into it, while in it, and while fading to black from it
	if phase == "FadingInMenu" or phase == "Menu" or phase == "FadingToBlackFromMenu" then
		children.MainMenu = e(MainMenu, {
			onPlay = props.onPlay,
		})
	end

	-- FadeOverlay handles loading/menu transitions
	if phase == "FadingToBlackFromLoading" or phase == "FadingToBlackFromMenu" then
		children.FadeOverlay = e(FadeOverlay, {
			isFadingIn = false,
			onComplete = props.onFadeComplete,
		})
	elseif phase == "FadingInMenu" then
		children.FadeOverlay = e(FadeOverlay, {
			isFadingIn = true,
			onComplete = props.onFadeComplete,
		})
	elseif phase == "FadingInGame" then
		-- Eye-opening effect for spawning into gameplay
		children.EyeOpen = e(EyeOpenOverlay, {
			onComplete = props.onFadeComplete,
		})
	end

	return e(React.Fragment, nil, children)
end

return RootUI
