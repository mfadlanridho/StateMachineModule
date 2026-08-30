--!strict
--[[
    StateMachineModule (init.luau)
    Zero-dependency, standalone OOP State Machine engine with state registration,
    canEnter guards, lifecycle hooks (enter, exit), state time tracking, optional auto-replication, and update tick loop.
--]]

local os = os
local script = script
local RunService = game:GetService("RunService")
local Types = require(script.Types)
local NetworkBridge = require(script.NetworkBridge)

export type StateContext = Types.StateContext
export type StateDefinition = Types.StateDefinition
export type StateMachineOptions = Types.StateMachineOptions
export type NetworkProvider = NetworkBridge.NetworkProvider

local StateMachine = {}
StateMachine.__index = StateMachine
StateMachine.NetworkBridge = NetworkBridge

export type StateMachineInstance = typeof(setmetatable({} :: {
	_states: { [string]: StateDefinition },
	_currentStateName: string?,
	_previousStateName: string?,
	_currentState: StateDefinition?,
	_stateStartTime: number,
	_replicate: boolean,
	_packetName: string,
	_transitions: { [string]: { string } }?,
	_listeners: { (oldState: string?, newState: string?) -> () },
}, StateMachine))

--- Sets a custom network provider (ByteNet, RemoteEvent, or custom) for StateMachineModule
function StateMachine.setNetworkProvider(provider: NetworkProvider)
	NetworkBridge.setProvider(provider)
end

--- Creates a new StateMachine instance.
-- @param options (StateMachineOptions | ((oldState: string?, newState: string?) -> ()))? Optional config options or callback
-- @return StateMachineInstance
function StateMachine.new(options: (StateMachineOptions | ((oldState: string?, newState: string?) -> ()))?): StateMachineInstance
	local replicate = false
	local packetName = "RequestStateChange"
	local transitions: { [string]: { string } }? = nil
	local listeners: { (oldState: string?, newState: string?) -> () } = {}

	if type(options) == "function" then
		table.insert(listeners, options)
	elseif type(options) == "table" then
		replicate = options.replicate == true
		if options.packetName then
			packetName = options.packetName
		end
		if (options :: any).transitions then
			transitions = (options :: any).transitions
		end
		if options.onStateChanged then
			table.insert(listeners, options.onStateChanged)
		end
	end

	local self = setmetatable({
		_states = {},
		_currentStateName = nil,
		_previousStateName = nil,
		_currentState = nil,
		_stateStartTime = 0,
		_replicate = replicate,
		_packetName = packetName,
		_transitions = transitions,
		_listeners = listeners,
	}, StateMachine)

	return self
end

--- Registers a single state definition into the state machine.
-- @param state StateDefinition
function StateMachine:registerState(state: StateDefinition)
	if not state.name then
		error("[StateMachine] State definition missing 'name' property!")
	end
	self._states[state.name] = state
end

--- Registers multiple state definitions at once.
-- @param stateList { StateDefinition }
function StateMachine:registerStates(stateList: { StateDefinition })
	for _, state in ipairs(stateList) do
		self:registerState(state)
	end
end

--- Subscribes a callback listener for state change events.
-- @param callback (oldState: string?, newState: string?) -> ()
-- @return () -> () Disconnect function
function StateMachine:onStateChanged(callback: (oldState: string?, newState: string?) -> ()): () -> ()
	table.insert(self._listeners, callback)
	return function()
		local idx = table.find(self._listeners, callback)
		if idx then
			table.remove(self._listeners, idx)
		end
	end
end

--- Returns the name of the currently active state.
-- @return string?
function StateMachine:getCurrentStateName(): string?
	return self._currentStateName
end

--- Returns the name of the currently active state (Alias for getCurrentStateName).
-- @return string?
function StateMachine:getState(): string?
	return self._currentStateName or "Idle"
end

--- Returns the name of the previous state.
-- @return string?
function StateMachine:getPreviousStateName(): string?
	return self._previousStateName
end

--- Returns elapsed time in seconds spent in the current state.
-- @return number
function StateMachine:getStateTime(): number
	if self._stateStartTime == 0 then
		return 0
	end
	return os.clock() - self._stateStartTime
end

--- Validates if transition to `nextStateName` is allowed by transition matrix & canEnter guard.
function StateMachine:canTransitionTo(nextStateName: string, context: StateContext): (boolean, string?)
	local nextState = self._states[nextStateName]
	if not nextState then
		return false, "unknown_state"
	end

	local currentStateName = self._currentStateName
	if currentStateName == nextStateName then
		return false, "already_in_state"
	end

	-- Check Declarative Transition Matrix if defined
	if self._transitions and currentStateName then
		local allowed = self._transitions[currentStateName]
		if allowed and not table.find(allowed, nextStateName) then
			return false, string.format("transition_not_allowed_from_%s_to_%s", tostring(currentStateName), tostring(nextStateName))
		end
	end

	-- Check state definition canEnter hook
	if nextState.canEnter then
		local canEnter, reason = nextState:canEnter(context, currentStateName)
		if not canEnter then
			return false, reason or "blocked"
		end
	end

	return true, nil
end

--- Attempts to set the active state to `nextStateName`.
-- @param nextStateName string
-- @param context StateContext
-- @return boolean - Whether the state transition succeeded
-- @return string? - Error or blocked reason if failed
function StateMachine:setState(nextStateName: string, context: StateContext): (boolean, string?)
	local nextState = self._states[nextStateName]
	if not nextState then
		warn(string.format("[StateMachine] Unknown state: %q", tostring(nextStateName)))
		return false, "unknown_state"
	end

	local currentStateName = self._currentStateName
	if currentStateName == nextStateName then
		return false, "already_in_state"
	end

	local canEnter, reason = self:canTransitionTo(nextStateName, context)
	if not canEnter then
		return false, reason
	end

	-- Run exit hook on current state
	if self._currentState and self._currentState.exit then
		self._currentState:exit(context, nextStateName)
	end

	-- Transition active state
	self._previousStateName = currentStateName
	self._currentStateName = nextStateName
	self._currentState = nextState
	self._stateStartTime = os.clock()

	-- Run enter hook on new state
	if nextState.enter then
		nextState:enter(context, currentStateName)
	end

	-- Auto Network Replication if enabled (Client -> Server)
	if self._replicate and RunService:IsClient() then
		NetworkBridge.send(self._packetName, {
			stateName = nextStateName,
		})
	end

	-- Notify all listeners
	for _, listener in ipairs(self._listeners) do
		task.spawn(listener, currentStateName, nextStateName)
	end

	return true, nil
end

--- Runs frame/tick update on the current state.
-- @param context StateContext
-- @param dt number - Frame delta time
-- @return string? - Optional requested next state transition name
function StateMachine:update(context: StateContext, dt: number): string?
	if self._currentState and self._currentState.update then
		local stateTime = self:getStateTime()
		local requestedTransition = self._currentState:update(context, dt, stateTime)
		if requestedTransition and requestedTransition ~= self._currentStateName then
			local success, _ = self:setState(requestedTransition, context)
			if success then
				return requestedTransition
			end
		end
	end
	return nil
end

-- ============================================================================
-- LayeredStateMachine (Orthogonal / Parallel Multi-Layer FSM Engine)
-- ============================================================================

local LayeredStateMachine = {}
LayeredStateMachine.__index = LayeredStateMachine

export type LayeredStateMachineInstance = typeof(setmetatable({} :: {
	_layers: { [string]: StateMachineInstance },
	_listeners: { (layerName: string, oldState: string?, newState: string?) -> () },
}, LayeredStateMachine))

--- Creates a new LayeredStateMachine instance with independent, parallel FSM layers.
-- @param layersConfig { [string]: { StateDefinition } } Map of layer names to registered state definitions
-- @param options LayeredStateMachineOptions?
-- @return LayeredStateMachineInstance
function StateMachine.newLayered(layersConfig: { [string]: { StateDefinition } }, options: Types.LayeredStateMachineOptions?): LayeredStateMachineInstance
	local layers: { [string]: StateMachineInstance } = {}
	local listeners: { (layerName: string, oldState: string?, newState: string?) -> () } = {}

	if options and options.onLayerStateChanged then
		table.insert(listeners, options.onLayerStateChanged)
	end

	local self = setmetatable({
		_layers = layers,
		_listeners = listeners,
	}, LayeredStateMachine)

	for layerName, stateList in pairs(layersConfig) do
		local machine = StateMachine.new({
			replicate = options and options.replicate,
			packetName = "Request" .. layerName .. "StateChange",
		})
		machine:registerStates(stateList)
		machine:onStateChanged(function(oldState, newState)
			for _, listener in ipairs(self._listeners) do
				task.spawn(listener, layerName, oldState, newState)
			end
		end)
		layers[layerName] = machine
	end

	return self :: any
end

function LayeredStateMachine:getLayer(layerName: string): StateMachineInstance?
	return self._layers[layerName]
end

function LayeredStateMachine:getState(layerName: string): string?
	local layer = self._layers[layerName]
	return layer and layer:getCurrentStateName()
end

function LayeredStateMachine:setState(layerName: string, stateName: string, context: StateContext): (boolean, string?)
	local layer = self._layers[layerName]
	if not layer then
		warn(string.format("[LayeredStateMachine] Unknown layer: %q", tostring(layerName)))
		return false, "unknown_layer"
	end
	return layer:setState(stateName, context)
end

function LayeredStateMachine:update(context: StateContext, dt: number): { [string]: string? }
	local requestedTransitions: { [string]: string? } = {}
	for layerName, layer in pairs(self._layers) do
		local requested = layer:update(context, dt)
		if requested then
			requestedTransitions[layerName] = requested
		end
	end
	return requestedTransitions
end

function LayeredStateMachine:onLayerStateChanged(callback: (layerName: string, oldState: string?, newState: string?) -> ()): () -> ()
	table.insert(self._listeners, callback)
	return function()
		local idx = table.find(self._listeners, callback)
		if idx then
			table.remove(self._listeners, idx)
		end
	end
end

return StateMachine
