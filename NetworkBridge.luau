--!strict
--[[
    NetworkBridge.luau (StateMachineModule)
    Self-contained, dual-compatible network adapter bridge for StateMachineModule.
    Supports ByteNet buffer serialization, standard Roblox RemoteEvents, or Local Standalone mode.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type NetworkProvider = {
	send: (actionName: string, payload: any, targetPlayer: Player?) -> (),
	listen: (actionName: string, callback: (payload: any, player: Player) -> ()) -> (),
}

local NetworkBridge = {}
local customProvider: NetworkProvider? = nil

local function getMode(): "ByteNet" | "RemoteEvent" | "Local"
	if customProvider then
		return "Local"
	end

	local packages = ReplicatedStorage:FindFirstChild("Packages")
	if packages and packages:FindFirstChild("ByteNet") then
		return "ByteNet"
	end

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesFolder or ReplicatedStorage:FindFirstChildOfClass("RemoteEvent") then
		return "RemoteEvent"
	end

	return "Local"
end

function NetworkBridge.setProvider(provider: NetworkProvider)
	customProvider = provider
end

function NetworkBridge.send(actionName: string, payload: any, targetPlayer: Player?)
	if customProvider then
		customProvider.send(actionName, payload, targetPlayer)
		return
	end

	local mode = getMode()
	if mode == "ByteNet" then
		local byteNetModule = require(ReplicatedStorage.Packages.ByteNet) :: any
		if byteNetModule and byteNetModule.NetworkPackets and byteNetModule.NetworkPackets[actionName] then
			local packet = byteNetModule.NetworkPackets[actionName]
			if RunService:IsClient() then
				packet.send(payload)
			elseif RunService:IsServer() and targetPlayer then
				packet.sendTo(payload, targetPlayer)
			elseif RunService:IsServer() then
				packet.sendAll(payload)
			end
		end
	elseif mode == "RemoteEvent" then
		local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
		local remote = remotesFolder:FindFirstChild("StateMachineModule_" .. actionName) :: RemoteEvent?
		if not remote and RunService:IsServer() then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = "StateMachineModule_" .. actionName
			newRemote.Parent = remotesFolder
			remote = newRemote
		end

		if remote then
			if RunService:IsClient() then
				remote:FireServer(payload)
			elseif RunService:IsServer() and targetPlayer then
				remote:FireClient(targetPlayer, payload)
			elseif RunService:IsServer() then
				remote:FireAllClients(payload)
			end
		end
	end
end

function NetworkBridge.listen(actionName: string, callback: (payload: any, player: Player) -> ())
	if customProvider then
		customProvider.listen(actionName, callback)
		return
	end

	local mode = getMode()
	if mode == "ByteNet" then
		local byteNetModule = require(ReplicatedStorage.Packages.ByteNet) :: any
		if byteNetModule and byteNetModule.NetworkPackets and byteNetModule.NetworkPackets[actionName] then
			byteNetModule.NetworkPackets[actionName].listen(callback)
		end
	elseif mode == "RemoteEvent" then
		local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
		if RunService:IsServer() then
			local remote = remotesFolder:FindFirstChild("StateMachineModule_" .. actionName) :: RemoteEvent?
			if not remote then
				remote = Instance.new("RemoteEvent")
				remote.Name = "StateMachineModule_" .. actionName
				remote.Parent = remotesFolder
			end
			remote.OnServerEvent:Connect(function(player, payload)
				callback(payload, player)
			end)
		elseif RunService:IsClient() then
			local remote = remotesFolder:WaitForChild("StateMachineModule_" .. actionName, 5) :: RemoteEvent?
			if remote then
				remote.OnClientEvent:Connect(function(payload)
					callback(payload, nil :: any)
				end)
			end
		end
	end
end

return NetworkBridge
