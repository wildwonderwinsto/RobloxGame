local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

export type LoadingScreenProps = {
	fadingOut: boolean,
}

local function LoadingScreen(props: LoadingScreenProps)
	local groupRef = React.useRef(nil :: CanvasGroup?)
	local rotation, setRotation = React.useBinding(0)

	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			setRotation(rotation:getValue() + dt * 180)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local group = groupRef.current
		if not group or not props.fadingOut then
			return
		end

		group.GroupTransparency = 0
		local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(group, tweenInfo, { GroupTransparency = 1 })
		tween:Play()

		return function()
			tween:Cancel()
		end
	end, { props.fadingOut } :: { any })

	return e("CanvasGroup", {
		ref = groupRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BorderSizePixel = 0,
		ZIndex = 900,
	}, {
		Background = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 0,
		}, {
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 50)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15)),
				}),
				Rotation = 90,
			}),
		}),
		Title = e("TextLabel", {
			Size = UDim2.fromScale(0.6, 0.1),
			Position = UDim2.fromScale(0.5, 0.35),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "game1",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
		}, {
			Shadow = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(0, 4),
				BackgroundTransparency = 1,
				Text = "game1",
				TextColor3 = Color3.new(0, 0, 0),
				TextTransparency = 0.5,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				ZIndex = 0,
			}),
		}),
		Spinner = e("Frame", {
			Size = UDim2.fromOffset(60, 60),
			Position = UDim2.fromScale(0.5, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Rotation = rotation,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(220, 220, 255),
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}, {
				Gradient = e("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.5, 0.8),
						NumberSequenceKeypoint.new(1, 1),
					}),
					Rotation = 90,
				}),
			}),
		}),
		Status = e("TextLabel", {
			Size = UDim2.fromScale(0.4, 0.04),
			Position = UDim2.fromScale(0.5, 0.65),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "INITIALIZING WORLD...",
			TextColor3 = Color3.fromRGB(180, 180, 220),
			TextScaled = true,
			Font = Enum.Font.GothamMedium,
		}),
	})
end

return LoadingScreen
