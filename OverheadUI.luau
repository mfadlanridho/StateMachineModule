--!strict
--[[
    OverheadUI.luau
    Reusable 3D BillboardGui State Badge UI component for StateMachineModule.
    Supports binding to Player Attributes (e.g. "FSMState") or directly to StateMachine instances.
--]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

export type StateStyle = {
	text: string,
	color: Color3,
}

export type StateConfigMap = { [string]: StateStyle }

export type OverheadUIOptions = {
	attributeName: string?,
	studsOffset: Vector3?,
	maxDistance: number?,
	alwaysOnTop: boolean?,
	config: StateConfigMap?,
	defaultState: string?,
	size: UDim2?,
	fontSize: number?,
	font: Enum.Font?,
}

local DEFAULT_CONFIG: StateConfigMap = {
	Idle = { text = "⚪ IDLE", color = Color3.fromRGB(189, 195, 199) },
	Normal = { text = "🟢 NORMAL", color = Color3.fromRGB(46, 204, 113) },
}

local OverheadUI = {}

local function applyStateStyle(billboard: BillboardGui, stateName: string, configMap: StateConfigMap, defaultState: string)
	local frame = billboard:FindFirstChild("BadgeFrame") :: Frame?
	if not frame then return end

	local label = frame:FindFirstChild("StateLabel") :: TextLabel?
	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke?
	if not label then return end

	local config = configMap[stateName] or configMap[defaultState] or { text = stateName, color = Color3.fromRGB(200, 200, 200) }
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	label.Text = config.text
	TweenService:Create(label, tweenInfo, { TextColor3 = config.color }):Play()

	if stroke then
		TweenService:Create(stroke, tweenInfo, { Color = config.color }):Play()
	end
end

local function createBillboard(targetPart: BasePart, options: OverheadUIOptions?): BillboardGui
	local opts = options or {}
	local studsOffset = opts.studsOffset or Vector3.new(0, 2.5, 0)
	local maxDistance = opts.maxDistance or 150
	local alwaysOnTop = if opts.alwaysOnTop ~= nil then opts.alwaysOnTop else true
	local size = opts.size or UDim2.fromOffset(140, 32)
	local fontSize = opts.fontSize or 13
	local font = opts.font or Enum.Font.GothamBold

	local existing = targetPart:FindFirstChild("StateBillboardGui")
	if existing and existing:IsA("BillboardGui") then
		return existing
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StateBillboardGui"
	billboard.Size = size
	billboard.StudsOffset = studsOffset
	billboard.AlwaysOnTop = alwaysOnTop
	billboard.MaxDistance = maxDistance
	billboard.Parent = targetPart

	local frame = Instance.new("Frame")
	frame.Name = "BadgeFrame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	frame.BackgroundTransparency = 0.25
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.Color = Color3.fromRGB(46, 204, 113)
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "StateLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "🟢 NORMAL"
	label.TextColor3 = Color3.fromRGB(46, 204, 113)
	label.TextSize = fontSize
	label.Font = font
	label.Parent = frame

	return billboard
end

--- Attaches an Overhead UI to a player's character model, bound to player attribute changes
function OverheadUI.attachPlayer(player: Player, character: Model, options: OverheadUIOptions?): () -> ()
	local head = character:WaitForChild("Head", 5) :: BasePart?
	if not head then return function() end end

	local opts = options or {}
	local attrName = opts.attributeName or "FSMState"
	local configMap = opts.config or DEFAULT_CONFIG
	local defaultState = opts.defaultState or "Normal"

	local billboard = createBillboard(head, opts)

	local initialState = player:GetAttribute(attrName) or defaultState
	if type(initialState) == "string" then
		applyStateStyle(billboard, initialState, configMap, defaultState)
	end

	local conn = player:GetAttributeChangedSignal(attrName):Connect(function()
		local newState = player:GetAttribute(attrName)
		if type(newState) == "string" then
			applyStateStyle(billboard, newState, configMap, defaultState)
		end
	end)

	return function()
		conn:Disconnect()
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end
end

--- Attaches an Overhead UI directly to a target Part, bound to a StateMachine instance's onStateChanged event
function OverheadUI.attachStateMachine(targetPart: BasePart, stateMachine: any, options: OverheadUIOptions?): () -> ()
	local opts = options or {}
	local configMap = opts.config or DEFAULT_CONFIG
	local defaultState = opts.defaultState or "Normal"

	local billboard = createBillboard(targetPart, opts)

	local currentState = if stateMachine.getCurrentStateName then stateMachine:getCurrentStateName() else defaultState
	if currentState then
		applyStateStyle(billboard, currentState, configMap, defaultState)
	end

	local disconnect = stateMachine:onStateChanged(function(_oldState: string?, newState: string?)
		if newState then
			applyStateStyle(billboard, newState, configMap, defaultState)
		end
	end)

	return function()
		disconnect()
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end
end

return OverheadUI
