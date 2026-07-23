# Roblox Networking Reference: Remotes (RemoteEvent / RemoteFunction / UnreliableRemoteEvent)

Reference doc for an AI coding agent working on Roblox networking tasks. Covers how client/server communication actually happens — the transport layer that buffer-serialized data (see companion doc) gets sent through. Pair with `Networking.md` for payload-level optimization.

---

## 1. The Three Remote Types

| Type | Delivery | Use case |
|---|---|---|
| `RemoteEvent` | Reliable, ordered | Standard client↔server messaging (actions, state changes) |
| `RemoteFunction` | Reliable, ordered, **yields** | Client needs a synchronous return value from server (or vice versa) |
| `UnreliableRemoteEvent` | Unreliable, unordered | High-frequency, loss-tolerant data (continuous position ticks, cosmetic effects) |

- Default choice should almost always be `RemoteEvent`. Reach for `RemoteFunction` only when you truly need a blocking request/response. Reach for `UnreliableRemoteEvent` only for high-frequency data where an occasional dropped packet is harmless and a stale/duplicate packet won't break gameplay logic.

---

## 2. RemoteEvent — Fire-and-Forget Messaging

```lua
-- Server -> instantiate
local remote = Instance.new("RemoteEvent")
remote.Name = "PlayerAction"
remote.Parent = ReplicatedStorage

-- Client -> Server
remote:FireServer(payload)

-- Server listens
remote.OnServerEvent:Connect(function(player, payload)
    -- `player` is always the first arg, injected by the engine
    -- payload is whatever the client sent -- NEVER trust it
end)

-- Server -> specific Client
remote:FireClient(player, payload)

-- Server -> all Clients
remote:FireAllClients(payload)

-- Server -> all Clients except one
for _, plr in Players:GetPlayers() do
    if plr ~= excludedPlayer then
        remote:FireClient(plr, payload)
    end
end

-- Client listens
remote.OnClientEvent:Connect(function(payload)
    -- no `player` arg on the client side
end)
```

- `OnServerEvent` always receives the firing `Player` as the first parameter automatically — the client cannot spoof this identity.
- Everything else in the payload is fully attacker-controlled. Treat all `FireServer` arguments as untrusted input.

---

## 3. RemoteFunction — Request/Response

```lua
local remoteFn = Instance.new("RemoteFunction")

-- Server implements the handler
remoteFn.OnServerInvoke = function(player, payload)
    -- must return a value (or nil)
    return result
end

-- Client calls and yields until response
local result = remoteFn:InvokeServer(payload)
```

**Known risks — read before using:**
- `InvokeServer` **yields the calling thread** until the server responds. If the server is slow, busy, or the handler errors, the client thread can hang or throw.
- A malicious client can simply never call `InvokeClient` back if the server invokes the client, or can flood `OnServerInvoke` with concurrent calls — this can create server-side thread buildup/DoS risk if the handler does expensive work per call.
- Server calling `InvokeClient` on a client is especially risky: a modified client can ignore the invoke, return garbage, or delay indefinitely, and the server thread yields waiting on it. **Avoid `InvokeClient` in security-relevant flows** — assume the client-side handler is fully adversarial or absent.
- For most "I need a response" use cases, an equivalent `RemoteEvent` pair (fire request → fire response, matched by an ID) avoids the yielding/hang risk and is generally preferred in production code, at the cost of slightly more boilerplate (correlating request/response pairs, handling timeouts yourself).

---

## 4. UnreliableRemoteEvent — High-Frequency, Loss-Tolerant Data

```lua
local unreliable = Instance.new("UnreliableRemoteEvent")
unreliable.Parent = ReplicatedStorage

unreliable:FireServer(payload)
unreliable.OnServerEvent:Connect(function(player, payload) ... end)
```

- Same API surface as `RemoteEvent`, but packets can arrive **out of order, duplicated, or not at all** — no delivery guarantee.
- Appropriate for: per-frame position/rotation updates, particle/VFX triggers, camera shake cues, anything where the *next* update supersedes a dropped one.
- **Not appropriate for**: anything transactional — inventory changes, currency, damage application, purchases, or any single event that must land exactly once. Use `RemoteEvent` for those.
- Because packets can arrive out of order, always include a sequence number or timestamp in the payload if ordering matters even loosely (e.g. discard a position update older than the last one applied).

---

## 5. Security: Server-Authoritative Design

The client is never trusted. Baseline rules for any `OnServerEvent` / `OnServerInvoke` handler:

1. **Validate types and ranges** on every argument. Don't assume the payload matches the shape you sent from a legitimate client — exploiters call remotes directly with arbitrary arguments.
2. **Re-derive state server-side** rather than trusting client-sent values. E.g. don't let the client tell the server "I dealt 50 damage" — the server computes damage from server-known state (weapon, hit registration, etc.) and the client only signals *intent* ("I fired").
3. **Rate-limit / throttle** remotes that can be spammed — track last-fired timestamp per player per remote and ignore calls that arrive faster than a legitimate client could produce them.
4. **Sanity-check array/string sizes** before processing — a malicious client can send an oversized table or string to try to cause excessive server-side work (a cheap DoS vector). Cap lengths and bail early.
5. **Never expose privileged actions** (granting currency, admin commands, teleporting other players) on a remote reachable by any client without a server-side permission check.
6. Consider a lightweight **network middleware layer**: a single wrapper module that all remotes route through, handling rate-limiting, type-checking (e.g. against a schema — see `Sera` in the buffer doc), and logging in one place instead of duplicating checks per remote.

---

## 6. Payload Design & Bandwidth

- Prefer **one remote per distinct message type** with a compact, well-defined payload shape over one catch-all remote with a "type" string and a loosely-typed table — the latter is harder to validate and rate-limit per-action.
- For high-frequency or bandwidth-sensitive remotes, send a `buffer` (see companion doc) instead of a Luau table — smaller payload, less per-call overhead.
- Batch when possible: if you need to send many small updates in the same frame/tick, combine them into a single remote call with a packed buffer or array rather than firing the remote once per item.
- Avoid firing remotes every frame/heartbeat for continuous data unless truly necessary — throttle to a fixed update rate (e.g. 10-20Hz) instead of 60Hz, and use `UnreliableRemoteEvent` for that class of data.

---

## 7. Common Pitfalls

- Forgetting the implicit `player` first argument on `OnServerEvent` and misreading the rest of the payload.
- Using `RemoteFunction`/`InvokeClient` for anything security-relevant — a manipulated client fully controls the return value.
- Trusting client-reported outcomes (damage dealt, currency amounts, item ownership) instead of recomputing them server-side.
- No rate limiting — a single remote with no throttle is a common exploit target for spam/DoS.
- Firing large tables or unbounded strings without size caps.
- Using `UnreliableRemoteEvent` for anything that must happen exactly once (it may not arrive, or may arrive twice).
- Creating a new `RemoteEvent` instance dynamically per-use instead of reusing a small, fixed set of remotes defined at startup — dynamic remote creation adds overhead and complicates client-side listener setup.

---

## 8. Practical Guidance for Agent Use

When asked to implement Roblox client/server communication:
1. Default to `RemoteEvent`. Only use `RemoteFunction` for genuine synchronous request/response, and prefer a fire/fire-back `RemoteEvent` pair over `InvokeClient` specifically.
2. Use `UnreliableRemoteEvent` only for continuous, loss-tolerant data (movement ticks, VFX), never for one-shot state changes.
3. Every server-side handler must validate and clamp its inputs — never assume the payload shape or range matches what a legitimate client would send.
4. Recompute security-relevant outcomes (damage, currency, ownership) server-side; treat client payloads as *intent*, not *fact*.
5. Add per-player rate limiting to any remote that could plausibly be spammed.
6. For high-frequency or large payloads, combine this doc with the buffer/Sera reference doc to serialize data compactly before sending.
7. Keep remotes as a small, fixed, named set created at startup (e.g. under a `ReplicatedStorage/Remotes` folder) rather than created ad hoc.