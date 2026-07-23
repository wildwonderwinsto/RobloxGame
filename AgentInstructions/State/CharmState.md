# Roblox State Reference: Charm (Atomic State Management)

Reference doc for an AI coding agent working with Charm (`littensy/charm`), a Roblox state management library. Fills in the "external state" API referenced elsewhere in this doc set — atoms, computed values, subscriptions, and server↔client sync. Pair with `Janitor.md` (cleanup functions returned by Charm need disposal) and `Remotes.md` (`CharmSync` is transport-agnostic — it still needs a Remote underneath).

---

## 1. Core Idea: Atomic, Not a Single Store

Charm decomposes state into independent **atoms** rather than one big central store (contrast with a single "GameState" table). Each atom is its own small container that can be read, written, and observed on its own. This maps naturally onto the kind of ad hoc player-state tables a hand-rolled state manager would otherwise use (e.g. a `states[player][key] = value` pattern) — but reactive, typed, and without manual bookkeeping of listeners.

Updates are immediate and asynchronous by default: writing to an atom notifies its listeners without deferring to the next frame, which keeps UI and downstream logic responsive.

---

## 2. `atom(state, options?)` — Creating State

```lua
local Charm = require(ReplicatedStorage.Charm)

local healthAtom = Charm.atom(100)
local inventoryAtom = Charm.atom({} :: { string })
```

- Calling `atom(initialValue)` returns a function. That function is both the getter and the setter:

```lua
print(healthAtom())        -- read: 100
healthAtom(80)              -- write: sets to 80
healthAtom(function(prev)   -- write via updater: derives new value from old
    return prev - 20
end)
```

- Optional second argument: `{ equals = fn }` — a custom equality check to decide whether a write actually counts as a change (default is `==`). Useful if you're storing tables and want a deep-equal check instead of reference equality.
- For array/table state, don't mutate in place — clone first, then write the clone (`table.clone(inventoryAtom())`), since Charm compares by reference by default and in-place mutation won't be detected as a change.

---

## 3. `subscribe(callback, listener)` — Listening for Changes

```lua
local cleanup = Charm.subscribe(healthAtom, function(newHealth, oldHealth)
    print(newHealth, oldHealth)
end)
```

- `callback` can be an atom directly, **or** a selector function that reads one or more atoms — Charm tracks which atoms the selector touched and only re-runs the listener when those specific dependencies change.
- The listener receives both the new and previous value.
- `subscribe` returns a cleanup function — call it (or route it through a Trove, see companion doc) to stop listening. Unmanaged subscriptions leak the same way an unmanaged `RunService` connection does.

---

## 4. `effect(callback)` — Reactive Side Effects

```lua
local cleanup = Charm.effect(function(cleanupInner)
    print("Health is now", healthAtom())
    return function()
        print("Effect cleaning up before re-run or disposal")
    end
end)
```

- Runs immediately once to discover its dependencies (every atom read inside the callback), then automatically re-runs whenever any of those dependencies change.
- The callback may return its own cleanup function, which runs right before the next re-run or when the effect itself is disposed.
- If the effect needs to disconnect itself from within its own body (not just clean up between runs), use the `cleanup` argument passed into the callback rather than relying on the returned function — effects can run before a returned cleanup function even exists.
- Like `subscribe`, `effect` returns an overall cleanup function that should be disposed when the owning system goes away.

---

## 5. `computed(callback, options?)` — Derived State

```lua
local doubledHealthAtom = Charm.computed(function()
    return healthAtom() * 2
end)
```

- Produces a new, read-only atom whose value is derived from other atoms.
- Memoized: the callback only re-runs when a dependency actually changes, not on every read.
- Prefer `computed` over recomputing the same derived value inside multiple separate `effect`/`subscribe` callbacks — it also helps avoid an effect firing twice when two of its dependencies change in the same tick, by collapsing them into one recomputation.

---

## 6. `peek(value, ...)` — Reading Without Tracking

```lua
Charm.effect(function()
    local health = healthAtom()               -- tracked: re-runs effect on change
    local level = Charm.peek(levelAtom)        -- untracked: read current value, ignore for dependency purposes
end)
```

- Use inside `effect`/`computed` callbacks when you need a value but don't want changes to that particular atom to trigger a re-run.

---

## 7. `observe` and `mapped` — Working With Keyed Collections

For state shaped like a dictionary (e.g. per-player or per-entity state):

```lua
-- Run a factory once per key when it's added; cleanup when removed
local cleanup = Charm.observe(playersAtom, function(playerData, playerId)
    print("added", playerId)
    return function()
        print("removed", playerId)
    end
end)
```
- Requires stable, unique keys — if your data isn't naturally keyed that way, transform it first with `mapped`.

```lua
-- Transform keys/values of a table-shaped atom into a new derived atom
local byIdAtom = Charm.mapped(entriesAtom, function(entry, index)
    return entry, entry.id -- (value, newKey)
end)
```
- The mapper can return just a new value (keeps the original key), a `(value, key)` pair to remap both, or `nil` for the value to drop that entry from the result.

---

## 8. `batch(callback)` — Grouping Writes

```lua
Charm.batch(function()
    healthAtom(80)
    levelAtom(5)
end)
```

- Defers listener notification until every write inside the callback has been applied, so subscribers/effects that depend on both atoms only run once instead of once per atom write.

---

## 9. Charm Sync — Server ↔ Client State Replication

Charm itself has no networking built in — `CharmSync` (a separate package) handles diffing and patching atom state across the client/server boundary, but you still supply the Remote to actually move bytes (see the remotes reference doc).

### Server side

```lua
local syncer = CharmSync.server({
    atoms = sharedAtoms,     -- dictionary of atoms to sync, keyed by name
    interval = 0,            -- batches updates every frame by default
    preserveHistory = false, -- true = send every intermediate change, not just the final state
    autoSerialize = true,    -- false only if your remote layer already serializes args (ByteNet, Zap, etc.)
})

syncer:connect(function(player, payload)
    remotes.syncState:FireClient(player, payload)
end)

remotes.requestState.OnServerEvent:Connect(function(player)
    syncer:hydrate(player) -- sends full current state, typically on player join
end)
```

### Client side

```lua
local syncer = CharmSync.client({
    atoms = sharedAtoms,        -- same keys as the server
    ignoreUnhydrated = true,    -- ignore patches that arrive before the initial hydrate
})

remotes.syncState.OnClientEvent:Connect(function(payload)
    syncer:sync(payload)
end)

remotes.requestState:FireServer() -- ask the server for initial state on join
```

- Only ever sync values that are legal to send over a Remote — no functions, threads, or non-string dictionary keys (see the remotes doc's payload guidance).
- By default only the *final* state per sync interval is sent, not every intermediate write — set `preserveHistory = true` if intermediate changes matter (e.g. a combat log), at a bandwidth cost.
- `CharmSync.isNone(value)` checks whether a value in a patch payload represents a deletion — Charm's partial patches use a special marker for "this key was removed" since a literal `nil` can't survive a Luau table diff cleanly.
- If you're pairing Charm with buffer-based serialization for very high-frequency atoms (see `Networking.md`), set `autoSerialize = false` and handle the byte-level packing yourself — Charm's own auto-serialize workaround targets plain Remote table-argument quirks, not custom binary formats.

---

## 10. Persisting Atoms (Pairing With a Data/Save Service)

Charm has no built-in persistence layer — saving atom state to a DataStore-backed service is a pattern you build on top of `subscribe`/`effect`, not a Charm feature:

```lua
Charm.effect(function()
    local data = playerDataAtom()
    DataService:QueueSave(player, data) -- debounce/save on your own service's terms
end)
```

- Don't save on every single atom write if the atom updates frequently — debounce, save on an interval, or save on specific checkpoints (level up, purchase, session end) rather than firing a DataStore write per tick.
- On player join: load persisted data first, seed the atom with it (`playerDataAtom(loadedData)`), *then* call `syncer:hydrate(player)` so the client's first sync reflects the loaded state rather than the atom's default.
- Route the effect's cleanup function through the owning object's Trove (or call it explicitly on `PlayerRemoving`) so you're not left with a dangling save-effect for a player who's already left.

---

## 11. Practical Guidance for Agent Use

When asked to implement or extend Roblox game state using Charm:
1. Default to one atom per independent piece of state rather than one large atom holding everything — this is the point of the "atomic" design and keeps subscribers/effects narrowly scoped.
2. Use `computed` for any value derived from other atoms instead of recalculating it inline in multiple places.
3. Always capture and dispose the cleanup function from `subscribe`/`effect` — treat it like a connection that belongs in a Trove.
4. Only reach for `CharmSync` when the client genuinely needs to observe server-owned state; client-only state doesn't need syncing at all.
5. For frequently-changing, high-volume atoms synced to many clients, consider `interval` tuning or pairing with buffer serialization rather than syncing raw tables at full frequency.
6. Persistence is a separate concern layered on top via `effect` + your save/data service — don't expect Charm to save anything on its own.
7. Enable `_G.__DEV__ = true` during development for clearer error tracebacks and remote-argument validation; disable it for production builds due to overhead.