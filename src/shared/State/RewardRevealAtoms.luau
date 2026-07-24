local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type RewardReveal = {
	ItemName: string,
	RevealId: number, -- increments so repeat items still retrigger the popup
}

local RewardRevealAtoms = {
	reveal = Charm.atom(nil :: RewardReveal?),
}

return RewardRevealAtoms
