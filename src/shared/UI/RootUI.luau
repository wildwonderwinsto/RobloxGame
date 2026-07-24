local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Charm = require(ReplicatedStorage.Packages.Charm)

local GameFlowAtoms = require(ReplicatedStorage.Shared.State.GameFlowAtoms)
local LoadingScreen = require(ReplicatedStorage.Shared.UI.Screens.LoadingScreen)
local MainMenu = require(ReplicatedStorage.Shared.UI.Screens.MainMenu)
local FadeOverlay = require(ReplicatedStorage.Shared.UI.FadeOverlay)

local e = React.createElement

export type RootUIProps = {
	onPlay: () -> (),
	onFadeComplete: (() -> ())?,
}

local function RootUI(props: RootUIProps)
	local phase, setPhase = React.useState(GameFlowAtoms.phase())

	-- Subscribe to the Charm atom for phase changes
	React.useEffect(function()
		local cleanup = Charm.subscribe(GameFlowAtoms.phase, function(newPhase)
			setPhase(newPhase)
		end)
		return cleanup
	end, {})

	local children: { [string]: any } = {}

	-- FadingFromLoading shows the menu BEHIND the loading screen as it fades out!
	if phase == "Loading" or phase == "FadingFromLoading" then
		children.LoadingScreen = e(LoadingScreen, {
			fadingOut = (phase == "FadingFromLoading")
		})
	end

	if phase == "Menu" or phase == "FadingFromLoading" or phase == "FadingToBlack" then
		children.MainMenu = e(MainMenu, {
			onPlay = props.onPlay,
		})
	end

	-- FadeOverlay for transitions
	if phase == "FadingToBlack" then
		children.FadeOverlay = e(FadeOverlay, {
			isFadingIn = false, -- tween from clear to black
			onComplete = props.onFadeComplete,
		})
	elseif phase == "FadingIn" then
		children.FadeOverlay = e(FadeOverlay, {
			isFadingIn = true, -- tween from black to clear
			onComplete = props.onFadeComplete,
		})
	end

	return e(React.Fragment, nil, children)
end

return RootUI
