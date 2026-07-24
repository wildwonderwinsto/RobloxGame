local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Phase = 
	"Loading" 
	| "FadingToBlackFromLoading" 
	| "FadingInMenu" 
	| "Menu" 
	| "FadingToBlackFromMenu" 
	| "FadingInGame" 
	| "Gameplay"

local GameFlowAtoms = {
	phase = Charm.atom("Loading" :: Phase),
}

return GameFlowAtoms
