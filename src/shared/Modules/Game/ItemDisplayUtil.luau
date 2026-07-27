local RunService = game:GetService("RunService")
local ItemDisplayUtil = {}

local TARGET_SCALE = 0.5 -- 50% scale

function ItemDisplayUtil.normalizeSize(clone: Instance)
	if clone:IsA("Model") then
		clone:ScaleTo(clone:GetScale() * TARGET_SCALE)
	elseif clone:IsA("BasePart") then
		clone.Size = clone.Size * TARGET_SCALE
	end
end

function ItemDisplayUtil.applyContinuousMotion(clone: Instance, baseCFrame: CFrame, startTime: number, itemRotationOffset: CFrame?)
	itemRotationOffset = itemRotationOffset or CFrame.Angles(0, 0, 0)
	
	local function updateMotion()
		local elapsed = os.clock() - startTime
		-- Base speed: 1 full revolution every 4.0 seconds
		local baseSpinSpeed = (2 * math.pi) / 4.0
		-- Use coprime integer multipliers (3, 5, -2) to create a chaotic, non-repeating 3D tumble
		-- Because they are integers, at exactly t=4.0s, all axes complete full revolutions and perfectly zero out.
		local spinRotation = CFrame.Angles(elapsed * baseSpinSpeed * 3, elapsed * baseSpinSpeed * 5, elapsed * baseSpinSpeed * -2)
		
		-- Mix two different sine waves (with frequencies that still resolve to integers at t=4) 
		-- to create a complex, bouncy, "random-looking" bobbing motion.
		-- At t=4.0: 1.25 * 4 = 5pi, and 2.75 * 4 = 11pi. Both sines will equal exactly 0.
		local complexBob = math.sin(elapsed * math.pi * 1.25) * 0.35 + math.sin(elapsed * math.pi * 2.75) * 0.15
		
		-- Add a constant base hover (e.g., 0.8 studs higher), but use an easing curve 
		-- so that it rapidly drops back down to exactly 0 height at exactly t=4.0 seconds.
		local extraHover = math.max(0, 1 - (elapsed / 4.0)^8) * 0.8
		
		local bobOffset = CFrame.new(0, complexBob + extraHover, 0)
		
		local targetCFrame = baseCFrame * bobOffset * spinRotation * itemRotationOffset
		
		if clone:IsA("Model") then
			clone:PivotTo(targetCFrame)
		elseif clone:IsA("BasePart") then
			clone.CFrame = targetCFrame
		end
	end

	updateMotion()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not clone or not clone.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end
		updateMotion()
	end)
	
	return function()
		if connection then
			connection:Disconnect()
		end
	end
end

return ItemDisplayUtil
