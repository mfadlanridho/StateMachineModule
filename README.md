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
- 🌐 **Dual Networking Adapter**: Built-in auto-detection for **ByteNet** buffer serialization, native **RemoteEvents**, or **Local Standalone** mode.
- 🛡 **Transition Guards (`canEnter`)**: Conditional checks to allow or block transitions dynamically.
- ⏱ **State Time Tracking (`getStateTime`)**: Automatic tracking of seconds spent in the current state (perfect for timeouts).
- 🔄 **Lifecycle Hooks**: `enter(context, fromState)` and `exit(context, toState)`.
- ⏱ **Frame Update Loop (`update`)**: `update(context, dt, stateTime)` can return a requested state name directly to auto-trigger transitions.
- 📡 **Multi-Listener Signal (`onStateChanged`)**: Connect multiple independent event listeners to state changes.

---

## 🚀 Usage Example

```luau
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Packages.StateMachineModule)

-- 1. Instantiate state machine
local machine = StateMachine.new()

-- 2. Subscribe listeners
machine:onStateChanged(function(oldState, newState)
    print(string.format("State changed: %s -> %s", tostring(oldState), tostring(newState)))
end)

-- 3. Register state definitions
local IdleState = require(script.IdleState)
local WalkState = require(script.WalkState)

machine:registerStates({ IdleState, WalkState })

-- 4. Define shared context & trigger state
local context = { speed = 0, character = workspace:FindFirstChild("MyCharacter") }
machine:setState("Idle", context)

-- 5. Update tick loop (optional)
RunService.Heartbeat:Connect(function(dt)
    machine:update(context, dt)
end)
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
