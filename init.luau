--!strict
--[[
    StateMachineModule (init.luau)
    Zero-dependency, standalone OOP State Machine engine with state registration,
    canEnter guards, lifecycle hooks (enter, exit), state time tracking, and update tick loop.
--]]

local os = os
local script = script
local Types = require(script.Types)
local NetworkBridge = require(script.NetworkBridge)

export type StateContext = Types.StateContext
export type StateDefinition = Types.StateDefinition
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
	_listeners: { (oldState: string?, newState: string?) -> () },
}, StateMachine))

--- Sets a custom network provider (ByteNet, RemoteEvent, or custom) for StateMachineModule
function StateMachine.setNetworkProvider(provider: NetworkProvider)
	NetworkBridge.setProvider(provider)
end

--- Creates a new StateMachine instance.
-- @param onStateChanged ((oldState: string?, newState: string?) -> ())? Optional callback when state changes
-- @return StateMachineInstance
function StateMachine.new(onStateChanged: ((oldState: string?, newState: string?) -> ())?): StateMachineInstance
	local self = setmetatable({
		_states = {},
		_currentStateName = nil,
		_previousStateName = nil,
		_currentState = nil,
		_stateStartTime = 0,
		_listeners = {},
	}, StateMachine)

	if onStateChanged then
		table.insert(self._listeners, onStateChanged)
	end

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

	-- Check transition guard condition
	if nextState.canEnter then
		local canEnter, reason = nextState.canEnter(nextState, context, currentStateName)
		if not canEnter then
			return false, reason or "blocked"
		end
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

return StateMachine
