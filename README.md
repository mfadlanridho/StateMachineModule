# ⚙️ Standalone StateMachineModule

A lightweight, zero-dependency OOP Finite State Machine (FSM) engine for Roblox **Luau**.

---

## 📂 Package Architecture

```text
StateMachineModule/
├── init.luau           -- Core state machine engine, timers & transition solver
├── NetworkBridge.luau  -- Dual-compatible network adapter (ByteNet / RemoteEvents / Local)
├── StateTemplate.luau  -- Template file for defining new states
├── Types.luau          -- Luau type definitions
└── README.md           -- Package documentation & examples
```

---

## 🛠 Features

- 🔌 **100% Plug & Play**: Drop into any project and use immediately with zero setup required.
- ⚡ **Zero Dependencies**: Pure Luau package compatible with Server and Client scripts.
- 🗺 **Declarative Transition Matrix (`transitions`)**: Define strict, secure allowed transition paths per state.
- 🔍 **Transition Validation (`canTransitionTo`)**: Check if a state transition is allowed before executing it.
- 🔀 **Orthogonal Layered FSM (`StateMachine.newLayered`)**: Run multiple parallel/independent state machine layers (`Body`, `Hand`, etc.) without state collisions.
- 🌐 **Dual Networking Adapter**: Built-in auto-detection for **ByteNet** buffer serialization, native **RemoteEvents**, or **Local Standalone** mode.
- 🛡 **Transition Guards (`canEnter`)**: Conditional checks to allow or block transitions dynamically.
- ⏱ **State Time Tracking (`getStateTime`)**: Automatic tracking of seconds spent in the current state (perfect for timeouts).
- 🔄 **Lifecycle Hooks**: `enter(context, fromState)` and `exit(context, toState)`.
- ⏱ **Frame Update Loop (`update`)**: `update(context, dt, stateTime)` can return a requested state name directly to auto-trigger transitions.
- 📡 **Multi-Listener Signal (`onStateChanged` & `onLayerStateChanged`)**: Connect multiple independent event listeners to state changes.

---

## 🚀 Usage Example

```luau
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachineModule)

-- 1. Instantiate state machine with Declarative Transition Matrix
local machine = StateMachine.new({
    transitions = {
        Idle = { "ExecutingMove", "Blocking", "Dashing", "Stunned", "Dead" },
        ExecutingMove = { "ExecutingMove", "Idle", "Blocking", "Dashing", "Stunned", "Dead" },
        Blocking = { "Idle", "Stunned", "Dead" },
        Dashing = { "Idle", "Stunned", "Dead" },
        Stunned = { "Idle", "Dead" },
        Dead = {},
    }
})

-- 2. Subscribe listeners
machine:onStateChanged(function(oldState, newState)
    print(string.format("State changed: %s -> %s", tostring(oldState), tostring(newState)))
end)

-- 3. Register state definitions
local IdleState = require(script.IdleState)
local ExecutingMoveState = require(script.ExecutingMoveState)

machine:registerStates({ IdleState, ExecutingMoveState })

-- 4. Validate and set active state
local context = { character = workspace:FindFirstChild("MyCharacter") }

local canTransition, reason = machine:canTransitionTo("ExecutingMove", context)
if canTransition then
    machine:setState("ExecutingMove", context)
end

-- 5. Query active state name
print(machine:getState()) -- "ExecutingMove"
```

---

## 🔀 Layered State Machine (`StateMachine.newLayered`)

For complex characters or systems requiring parallel state tracks (e.g. `Body` locomotion state and `Hand` action state running simultaneously without state collisions):

```luau
local layeredMachine = StateMachine.newLayered({
    Body = { NormalState.new(), BeingGrabbedState.new(), FlungState.new() },
    Hand = { IdleState.new(), GrabbingState.new() },
}, {
    onLayerStateChanged = function(layerName, oldState, newState)
        print(string.format("[%s Layer] %s -> %s", layerName, tostring(oldState), tostring(newState)))
    end,
})

-- Transition individual layers independently
layeredMachine:setState("Body", "BeingGrabbed", context)
layeredMachine:setState("Hand", "Grabbing", context)

-- Query active state per layer
print(layeredMachine:getState("Body")) -- "BeingGrabbed"
print(layeredMachine:getState("Hand")) -- "Grabbing"
```

---

## 🌐 Dual Networking & Custom Providers

`StateMachineModule` includes a self-contained `NetworkBridge.luau` that automatically detects the host project environment:
1. **ByteNet Mode**: If `ReplicatedStorage.Packages.ByteNet` exists, it routes network events over ByteNet buffers.
2. **RemoteEvent Mode**: If `ReplicatedStorage.Remotes` or `RemoteEvents` exist, it routes over Roblox `RemoteEvents`.
3. **Local Standalone Mode**: If no networking library is found, it runs locally without errors.

```luau
StateMachine.setNetworkProvider({
    send = function(actionName, payload, targetPlayer)
        -- Route through custom network handler
    end,
    listen = function(actionName, callback)
        -- Route listener
    end,
})
```

---

## 📄 License
MIT License - Free for use across all your Roblox projects.
