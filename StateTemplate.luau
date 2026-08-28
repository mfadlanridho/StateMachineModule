--!strict
--[[
    StateTemplate.luau
    Template file for creating new StateMachineModule states.
--]]

local Types = require(script.Parent.Types)

export type StateContext = Types.StateContext

local StateTemplate = {}
StateTemplate.name = "TemplateState"

--- Optional guard condition to allow or block entry into this state.
-- @param context StateContext
-- @param fromState string? Name of state transitioning from
-- @return boolean - True if allowed, False if blocked
-- @return string? - Optional reason if blocked
function StateTemplate.canEnter(context: StateContext, fromState: string?): (boolean, string?)
	return true, nil
end

--- Called when entering this state.
-- @param context StateContext
-- @param fromState string? Name of state transitioning from
function StateTemplate.enter(context: StateContext, fromState: string?)
end

--- Called when exiting this state.
-- @param context StateContext
-- @param toState string? Name of state transitioning to
function StateTemplate.exit(context: StateContext, toState: string?)
end

--- Called on per-frame/tick update.
-- @param context StateContext
-- @param dt number Frame delta time
-- @param stateTime number Seconds spent in current state
-- @return string? Optional requested next state transition name
function StateTemplate.update(context: StateContext, dt: number, stateTime: number): string?
	return nil
end

return StateTemplate
