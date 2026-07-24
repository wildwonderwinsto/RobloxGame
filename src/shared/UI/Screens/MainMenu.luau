local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

export type MainMenuProps = {
	onPlay: () -> (),
}

local function MainMenu(props: MainMenuProps)
	local buttonRef = React.useRef(nil :: TextButton?)
	local strokeRef = React.useRef(nil :: UIStroke?)

	local function onMouseEnter()
		local btn = buttonRef.current
		if btn then
			TweenService:Create(btn, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(0.21, 0.075),
			}):Play()
		end
	end

	local function onMouseLeave()
		local btn = buttonRef.current
		if btn then
			TweenService:Create(btn, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(0.2, 0.07),
			}):Play()
		end
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 800,
	}, {
		Title = e("TextLabel", {
			Size = UDim2.fromScale(0.5, 0.1),
			Position = UDim2.fromScale(0.5, 0.3),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "G A M E   1",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
		}, {
			Shadow = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(0, 4),
				BackgroundTransparency = 1,
				Text = "G A M E   1",
				TextColor3 = Color3.new(0, 0, 0),
				TextTransparency = 0.6,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				ZIndex = 0,
			}),
		}),
		PlayButton = e("TextButton", {
			ref = buttonRef,
			Size = UDim2.fromScale(0.2, 0.07),
			Position = UDim2.fromScale(0.5, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			Text = "Play Game",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			[React.Event.Activated] = props.onPlay,
			[React.Event.MouseEnter] = onMouseEnter,
			[React.Event.MouseLeave] = onMouseLeave,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Stroke = e("UIStroke", {
				ref = strokeRef,
				Color = Color3.new(1, 1, 1),
				Thickness = 2,
				Transparency = 0.5,
			}),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
		}),
	})
end

return MainMenu
