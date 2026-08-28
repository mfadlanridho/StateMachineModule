--!strict
--[[
    Types.luau
    Type definitions for standalone StateMachineModule.
--]]

export type StateContext = { [string]: any }

export type StateDefinition = {
	name: string,
	canEnter: ((context: StateContext, fromState: string?) -> (boolean, string?))?,
	enter: ((context: StateContext, fromState: string?) -> ())?,
	exit: ((context: StateContext, toState: string?) -> ())?,
	update: ((context: StateContext, dt: number, stateTime: number) -> string?)?,
}

export type NetworkProvider = {
	send: (actionName: string, payload: any, targetPlayer: Player?) -> (),
	listen: (actionName: string, callback: (payload: any, player: Player) -> ()) -> (),
}

return {}
