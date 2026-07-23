# Roblox Systems Reference: Cleanup Modules (Trove / Maid / Janitor)

Reference doc for an AI coding agent building OOP-style Roblox systems/classes. Covers instance and connection lifecycle management — directly relevant when a class creates `Instance`s, `RunService` connections, or connects to custom Signals (`Signals.md`) or Remotes (`Remotes.md`).

---

## 1. The Problem: Manual Cleanup Is Error-Prone

A typical Roblox class creates resources during its lifetime that don't clean themselves up:

```lua
function Something.new()
    local self = setmetatable({}, Something)
    self.someEvent = Instance.new("BindableEvent")
    self.somePart = Instance.new("Part")
    self.somePart.Parent = workspace
    self.connection = RunService.Stepped:Connect(function(time, deltaTime)
        -- per-frame logic
    end)
    return self
end

function Something:Destroy()
    self.someEvent:Destroy()
    if self.somePart then
        self.somePart:Destroy()
    end
    -- easy to forget: self.connection:Disconnect()
end
```

- Every `Instance.new(...)`, every `:Connect(...)`, every dynamically-spawned part must be explicitly torn down in `Destroy`, or it leaks.
- Forgetting a single disconnect (e.g. a `RunService.Stepped` connection) is a common, easy-to-miss bug: the connection keeps firing forever, even after the owning object is logically "destroyed." Depending on what the connection does, this can range from harmless wasted CPU to repeated errors to unbounded memory growth over a long-running server.
- This gets worse as a class grows — more instances, more connections, more places to forget a line in `Destroy`.

---

## 2. The Fix: Cleanup Modules

Cleanup modules (**Trove**, **Maid**, **Janitor** are the common community options) solve this by giving you a single "trash can" object: you hand it anything that needs cleanup as you create it, and calling one method on the cleanup object tears down everything it was given, in one line.

- **Maid** — the original/oldest of the three, simpler feature set.
- **Trove** — written by Sleitnick, integrates well with his other tooling (e.g. Knit). Adds convenience methods like chained `:Add()` and `:Connect()`.
- **Janitor** — generally considered the most feature-rich of the three.
- Functionally they solve the same core problem; pick one and use it consistently across a project rather than mixing them.

---

## 3. Trove — Basic Usage

```lua
local Trove = require(ReplicatedStorage.Trove)

function Something.new()
    local self = setmetatable({}, Something)
    self._trove = Trove.new() -- underscore = private, other objects shouldn't reach into this

    self.someEvent = self._trove:Add(Instance.new("BindableEvent"))
    self.somePart = self._trove:Add(Instance.new("Part"))
    self.somePart.Parent = workspace

    self._trove:Connect(RunService.Stepped, function(time, deltaTime)
        -- per-frame logic
    end)

    return self
end

function Something:Destroy()
    self._trove:Destroy() -- this should be the only line needed here
end
```

### Key methods
- `Trove.new()` — creates a new trove instance. Typically one per object/class instance, stored as a private field (`self._trove`).
- `trove:Add(object)` — registers `object` for cleanup **and returns it**, which lets you inline creation and registration in one statement (`self.part = self._trove:Add(Instance.new("Part"))`) instead of creating the object, then separately adding it on the next line.
- `trove:Connect(signal, fn)` — convenience wrapper that connects `fn` to `signal` and automatically registers the resulting connection for cleanup, replacing the pattern of storing a connection in a field and manually disconnecting it.
- `trove:Add(function)` — you can also hand the trove a plain function instead of an instance/connection. Useful for cleanup that isn't a `:Destroy()` or `:Disconnect()` call — e.g. unbinding from `RunService:BindToRenderStep`, which requires calling `RunService:UnbindFromRenderStep(name)` rather than destroying an object.
- `trove:Destroy()` — runs cleanup for everything registered (destroys instances, disconnects connections, calls registered functions), then the trove itself is done. Call this from your object's own `Destroy` method.

---

## 4. Why This Matters Beyond Convenience

- Lets you write object creation **linearly**: as you create something that needs cleanup, you immediately register it for cleanup in the same line, instead of context-switching to a separate `Destroy` method to remember what to add.
- Removes an entire class of bugs where a connection or instance is created but the corresponding teardown line is missing, forgotten during a refactor, or never added because the object seemed "simple enough not to need it."
- Particularly important for anything tied to `RunService` connections (`Stepped`, `Heartbeat`, `RenderStepped`) — these fire indefinitely once connected, so an un-cleaned connection silently keeps running (and consuming CPU / potentially erroring) for the lifetime of the server or session, not just until the owning object is logically gone.
- Scales cleanly: a class with a dozen instances/connections still only needs one `_trove:Destroy()` call in its own `Destroy` method, regardless of how many resources it's accumulated.

---

## 5. Interaction With Other Systems

- **Signals** (see companion doc): if a class connects to a custom `Signal`, route that connection through the trove (`self._trove:Add(signal:Connect(fn))` or the trove's connect helper) exactly like a native Roblox event connection — custom signal connections leak the same way native ones do if left unmanaged.
- **Remotes** (see companion doc): connections to `RemoteEvent.OnServerEvent` / `OnClientEvent` inside a per-player or per-object class should also be trove-managed, especially for systems that are created/destroyed repeatedly per player (e.g. a per-player controller object) — otherwise each new object leaks a permanent connection to the shared remote.

---

## 6. Practical Guidance for Agent Use

When implementing an OOP-style Roblox class/system:
1. Give every class with a lifecycle a `_trove` (or equivalent) field created in its constructor, and a `Destroy` method whose only job is `self._trove:Destroy()`.
2. Route every `Instance.new(...)` the object owns through the trove's `Add`, ideally inlined at creation (`self.part = self._trove:Add(Instance.new("Part"))`).
3. Route every event/signal connection (native Roblox signals, custom Signals, Remote listeners) through the trove's connect helper rather than storing a raw connection in a field and manually disconnecting it.
4. For cleanup that isn't `:Destroy()` or `:Disconnect()` (e.g. `RunService:UnbindFromRenderStep`), register a plain cleanup function with the trove instead of hand-rolling a special case in `Destroy`.
5. Pick one cleanup module (Trove, Maid, or Janitor) per project and use it consistently — don't mix libraries for the same purpose across a codebase.
6. Never leave a raw, unmanaged `RunService` connection (`Stepped`/`Heartbeat`/`RenderStepped`) on a class that has a defined end-of-life — these are the most common source of silent leaks since they don't error on their own, they just keep running.