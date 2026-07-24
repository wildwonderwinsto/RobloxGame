local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

export type FadeOverlayProps = {
	isFadingIn: boolean, -- true = tween black to clear, false = tween clear to black
	onComplete: (() -> ())?,
}

local function FadeOverlay(props: FadeOverlayProps)
	local frameRef = React.useRef(nil :: Frame?)

	React.useEffect(function()
		local frame = frameRef.current
		if not frame then return end

		-- Snap to starting transparency so there is no flickering
		local startTrans = if props.isFadingIn then 0 else 1
		local endTrans = if props.isFadingIn then 1 else 0
		frame.BackgroundTransparency = startTrans

		local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local tween = TweenService:Create(frame, tweenInfo, { BackgroundTransparency = endTrans })
		tween:Play()

		local connection = tween.Completed:Connect(function()
			if props.onComplete then
				props.onComplete()
			end
		end)

		return function()
			connection:Disconnect()
			tween:Cancel()
		end
	end, { props.isFadingIn } :: { any })

	return e("Frame", {
		ref = frameRef,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 999,
	})
end

return FadeOverlay
