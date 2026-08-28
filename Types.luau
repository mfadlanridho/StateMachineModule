--!strict
--[[
    Types.luau
    Type definitions for standalone StateMachineModule.
--]]

export type StateContext = { [string]: any }

export type StateDefinition = {
	name: string,
	canEnter: ((self: StateDefinition, context: StateContext, fromState: string?) -> (boolean, string?))?,
	enter: ((self: StateDefinition, context: StateContext, fromState: string?) -> ())?,
	exit: ((self: StateDefinition, context: StateContext, toState: string?) -> ())?,
	update: ((self: StateDefinition, context: StateContext, dt: number, stateTime: number) -> string?)?,
}

export type StateMachineOptions = {
	onStateChanged: ((oldState: string?, newState: string?) -> ())?,
	replicate: boolean?,
	packetName: string?,
}

export type NetworkProvider = {
	send: (actionName: string, payload: any, targetPlayer: Player?) -> (),
	listen: (actionName: string, callback: (payload: any, player: Player) -> ()) -> (),
}

return {}
