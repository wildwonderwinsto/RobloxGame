local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Phase = "Loading" | "FadingFromLoading" | "Menu" | "FadingToBlack" | "FadingIn" | "Gameplay"

local GameFlowAtoms = {
	phase = Charm.atom("Loading" :: Phase),
}

return GameFlowAtoms
