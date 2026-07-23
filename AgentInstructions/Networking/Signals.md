# Roblox Networking Reference: Custom Signals (Same-Context Events)

Reference doc for an AI coding agent building event-driven systems in Roblox. Covers custom `Signal` objects — **not** a replacement for RemoteEvents. Pair with `Remotes.md` (client↔server) and `Networking.md` (payload compaction).

---

## 1. What a Custom Signal Is

- Roblox instances expose built-in **RBXScriptSignals** (e.g. `workspace.ChildAdded`, `instance.DescendantAdded`) — objects with `:Connect()`, `:Once()`, `:Wait()` that notify listeners when something happens.
- A **custom Signal** is the same pattern, implemented in Luau, so your own modules/systems can expose their own events (e.g. `PlayerLeveledUp`, `InventoryChanged`) the same way Roblox's built-in objects do.
- The most common implementation used in the community is **Sleitnick's `Signal` module** (part of his open-source utility library). It's a small, dependency-free ModuleScript that replicates the standard `Connect` / `Once` / `Wait` / `Fire` / `Destroy` API.

---

## 2. Critical Boundary: Same-Context Only

**Custom signals do not cross the client/server boundary.** A signal fired in a server script is only observable by other server-side code (other server scripts / server-side modules); a signal fired on the client is only observable client-side. This applies even though the underlying module script may be shared/required from both sides — each side gets its own independent execution context, so firing on one side does not notify listeners on the other.

- For client↔server communication, you still need `RemoteEvent` / `RemoteFunction` / `UnreliableRemoteEvent` (see companion doc).
- Custom signals are for **intra-context** communication: server-module-to-server-script, or client-module-to-client-script, decoupling systems that live on the same side of the network boundary.

---

## 3. Setup

```lua
-- ModuleScript: ReplicatedStorage/Signal (paste Sleitnick's Signal source)

-- In your system's module:
local Signal = require(ReplicatedStorage.Signal)

local MySystem = {}
MySystem.DidSomething = Signal.new()
MySystem.DidSomethingElse = Signal.new()
```

- `Signal.new()` creates a new signal instance. Attach as many as your system needs as named fields on the module table (e.g. `self.DidSomething`), same as you'd expose a `.Changed` event on a custom object.

---

## 4. Firing and Connecting

```lua
-- Firing (inside the module that owns the signal)
function MySystem.DoSomething()
    -- ... system logic ...
    MySystem.DidSomething:Fire(arg1, arg2)
end

function MySystem.DoSomethingElse()
    -- ... system logic ...
    MySystem.DidSomethingElse:Fire()
end
```

```lua
-- Listening (from another script requiring the same module)
local MySystem = require(ReplicatedStorage.MySystem)

MySystem.DidSomething:Connect(function(arg1, arg2)
    print("DidSomething was fired", arg1, arg2)
end)

MySystem.DidSomethingElse:Once(function()
    -- fires only for the first occurrence, then auto-disconnects
end)
```

- `:Fire(...)` invokes all connected listeners, passing along any arguments — conceptually the same shape as a RemoteEvent's `FireServer`/`FireClient`, but entirely in-process (no network involved, no serialization needed).
- `:Connect(fn)` — persistent listener, fires every time.
- `:Once(fn)` — fires at most once, then disconnects automatically.
- `:Wait()` — yields the calling thread until the signal next fires, returning the fired arguments (same as Roblox's native signals).
- `:Destroy()` — disconnects all listeners and cleans up; call this when the owning system is torn down to avoid dangling connections/memory leaks.

---

## 5. Why Use This Instead of a Plain Callback/Table of Functions

- Decouples the system that *does something* from the code that *reacts to it* — the module firing the signal doesn't need to know who's listening or how many listeners exist.
- Supports multiple independent listeners without the firing code maintaining a list itself.
- Familiar API (`Connect`/`Once`/`Wait`) — reads the same as working with any native Roblox event, lowering cognitive overhead versus a bespoke callback-registration scheme.
- Commonly preferred over `BindableEvent` instances for pure-Luau in-module signaling: no need to create/parent an `Instance`, avoids the (typically minor) overhead of Roblox's Instance-based event system, and keeps the signal as a plain Luau object scoped to the module.

---

## 6. Practical Guidance for Agent Use

When asked to implement event-driven communication within a Roblox system:
1. If the communication is **server-to-client or client-to-server**, use Remotes — a custom Signal will silently fail to notify the other side (no error, listeners just never fire).
2. If the communication is **within the same context** (server-only or client-only) and decouples one module from its consumers, expose a `Signal.new()` field on the module rather than having consumers poll state or the module hold a manual list of callbacks.
3. Name signals descriptively as past-tense events (`PlayerLeveledUp`, `ItemEquipped`) to mirror Roblox's own convention (`ChildAdded`, `Touched`) and make intent clear to other listeners.
4. Call `:Destroy()` on signals owned by objects/systems that can be torn down mid-session (e.g. per-player systems on `PlayerRemoving`) to prevent leaked connections.
5. Don't reach for a custom Signal when a simple direct function call would do — signals are for one-to-many or decoupled notification, not for straightforward request/response within the same module.