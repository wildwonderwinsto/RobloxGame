local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Charm = require(ReplicatedStorage.Packages.Charm)

local RewardRevealAtoms = require(ReplicatedStorage.Shared.State.RewardRevealAtoms)

local e = React.createElement
local DISPLAY_TIME = 1.6

local function RewardPopup()
	local reveal, setReveal = React.useState(RewardRevealAtoms.reveal())
	local scaleRef = React.useRef(nil :: UIScale?)

	React.useEffect(function()
		return Charm.subscribe(RewardRevealAtoms.reveal, function(newReveal)
			setReveal(newReveal)
		end)
	end, {})

	React.useEffect(function()
		if not reveal then
			return
		end

		local scale = scaleRef.current
		if scale then
			scale.Scale = 0
			TweenService:Create(
				scale,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end

		local hideTimer = task.delay(DISPLAY_TIME, function()
			if scaleRef.current then
				local tween = TweenService:Create(
					scaleRef.current,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Scale = 0 }
				)
				tween.Completed:Connect(function()
					setReveal(nil)
				end)
				tween:Play()
			else
				setReveal(nil)
			end
		end)

		return function()
			task.cancel(hideTimer)
		end
	end, { reveal and reveal.RevealId } :: { any })

	if not reveal then
		return nil
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.25),
		Size = UDim2.fromOffset(280, 80),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 950,
	}, {
		Scale = e("UIScale", { ref = scaleRef, Scale = 0 }),
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 215, 0), Thickness = 2 }),
		Label = e("TextLabel", {
			Size = UDim2.fromScale(0.9, 0.5),
			Position = UDim2.fromScale(0.5, 0.35),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = reveal.ItemName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
		}),
		Subtitle = e("TextLabel", {
			Size = UDim2.fromScale(0.9, 0.3),
			Position = UDim2.fromScale(0.5, 0.72),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "You got a new item!",
			TextColor3 = Color3.fromRGB(200, 200, 210),
			TextScaled = true,
			Font = Enum.Font.GothamMedium,
		}),
	})
end

return RewardPopup
