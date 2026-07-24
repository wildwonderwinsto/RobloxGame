local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

export type EyeOpenOverlayProps = {
	onComplete: (() -> ())?,
}

local function EyeOpenOverlay(props: EyeOpenOverlayProps)
	local topRef = React.useRef(nil :: Frame?)
	local bottomRef = React.useRef(nil :: Frame?)

	React.useEffect(function()
		local top = topRef.current
		local bottom = bottomRef.current
		if not top or not bottom then
			return
		end

		-- Start fully closed (eyelids covering the screen)
		top.Size = UDim2.fromScale(1, 0.5)
		bottom.Size = UDim2.fromScale(1, 0.5)

		-- Small pause before opening, like waking up
		task.wait(0.3)

		local tweenInfo = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

		local topTween = TweenService:Create(top, tweenInfo, {
			Size = UDim2.fromScale(1, 0),
		})
		local bottomTween = TweenService:Create(bottom, tweenInfo, {
			Size = UDim2.fromScale(1, 0),
		})

		topTween:Play()
		bottomTween:Play()

		local connection = topTween.Completed:Connect(function()
			if props.onComplete then
				props.onComplete()
			end
		end)

		return function()
			connection:Disconnect()
			topTween:Cancel()
			bottomTween:Cancel()
		end
	end, {})

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 999,
	}, {
		TopLid = e("Frame", {
			ref = topRef,
			Size = UDim2.fromScale(1, 0.5),
			Position = UDim2.fromScale(0, 0),
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 999,
		}),
		BottomLid = e("Frame", {
			ref = bottomRef,
			Size = UDim2.fromScale(1, 0.5),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 999,
		}),
	})
end

return EyeOpenOverlay
