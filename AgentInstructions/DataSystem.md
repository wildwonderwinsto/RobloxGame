# DataService — Player Data System Context

**Purpose:** reference context for any AI agent or contributor working with player data in this repo. Describes what DataService is, how to set it up, and the conventions this project follows when reading/writing/replicating player data. Pairs with `roblox-structure-agent.md` and `roblox-workflow-setup-context.md`.

**Source reference:** based on the walkthrough in this video: https://www.youtube.com/watch?v=YSNAFlRF96o

---

## 1. What DataService Is

DataService is a wrapper around **ProfileStore** that removes the usual boilerplate around `DataStoreService`, `MessagingService`, session locking, and manual client replication. It automatically:

- Saves player data.
- Replicates player data to the client.
- Exposes change-signals per value so UI/logic can react to updates.

**Agent rule:** never write raw `DataStoreService` calls, manual session-locking, or a hand-rolled replication remote for player data in this project. All persistent player data goes through DataService.

---

## 2. Installation

Available via GitHub, Wally, or the Roblox Creator Store. In this project it's managed the same way as other packages — see `roblox-workflow-setup-context.md` §6 (Wally). Since it's used on both client and server, it belongs in the shared `Packages/` folder, not `ServerPackages/`.

---

## 3. Setup

DataService has separate **server** and **client** entry points from the same require.

**Server** (in a `ServerScriptService` startup/service script):

```lua
local DataService = require(Packages.DataService).Server

DataService:Init({
	Template = DataTemplate, -- REQUIRED: shape of a player's data on first join
})
```

**Client** (in a `StarterPlayerScripts` startup script):

```lua
local DataService = require(ReplicatedStorage.Packages.DataService).Client

DataService:Init()
```

- `Template` is the **only mandatory** init option. It defines what a player's data table looks like the first time they join.
- Per the project structure convention, keep the `Template` table in its own module (see §6) rather than inlining it in the init call.

---

## 4. Core API

| Function | Side | Purpose |
|---|---|---|
| `DataService:Get(player, path)` | Server | Read a value by path. |
| `DataService:Get(path)` | Client | Read a value for the local player (no `player` arg needed). |
| `DataService:Set(player, path, value)` | Server | Overwrite a value. |
| `DataService:Update(player, path, fn)` | Server | Read-modify-write: `fn` receives the current value and returns the new value. Use this instead of `Get` + `Set` for anything additive/incremental to avoid race conditions. |
| `DataService:GetChangeSignal(path)` | Client (and server) | Returns a signal you can `:Connect()` to; fires with the new value whenever it changes. |

**Paths:** nested values are addressed as an array/table path, e.g. `{"Inventory", "Apples"}` rather than a dotted string.

**Agent rule:** prefer `Update` over manual `Get` + `Set` for any increment/decrement/append operation on player data — this project uses `Update` as the standard pattern for that (see the currency/gems examples below).

### Examples

```lua
-- Server: set + get
DataService:Set(player, {"Currency"}, 50)
print(DataService:Get(player, {"Currency"})) --> 50

-- Server: nested value
local apples = DataService:Get(player, {"Inventory", "Apples"})

-- Server: additive update
DataService:Update(player, {"Oranges"}, function(current)
	return current + 10
end)
```

```lua
-- Client: read (player is implied)
print("I have " .. DataService:Get({"Currency"}))

-- Client: subscribe to changes and drive UI
DataService:GetChangeSignal({"Currency"}):Connect(function(newValue)
	counterLabel.Text = tostring(newValue)
end)
```

```lua
-- Server: incrementing loop example
while true do
	task.wait(1)
	DataService:Update(player, {"Currency"}, function(current)
		return current + 1
	end)
end
```

---

## 5. Init Options (beyond Template)

| Option | Effect |
|---|---|
| `UseMock` | Loads fresh, unsaved "first time playing" mock data — does not touch real saved data. Useful for local testing without corrupting real profiles. |
| `ResetData` | Wipes the player's real saved data on the next play session. **Destructive** — only use intentionally, then set back to `false`. |
| `ViewedUserId` | Lets you play a Studio session *viewing* another user's real data, without saving to it. Useful for support/debugging a specific player's issue. |
| `OverriddenUserId` | Same as `ViewedUserId`, but changes made **do** save to that user's data. Use with caution — this writes to a real player's saved data. |
| `OnPlayerInit` | Callback to run custom logic when a player's data is first initialized (e.g. stamp session start time, increment join count). |
| `OnPlayerRemoving` | Callback to run custom logic as a player leaves (e.g. record play time, expire temporary boosts). |

**Agent rule:** never leave `ResetData = true` or `OverriddenUserId` set in a commit — these are debugging-only settings and are destructive/data-affecting if left enabled.

---

## 6. Data Template Convention

Keep the player-data shape in its own module rather than inline:

```
Shared/
└── DataTemplate.luau     -- template table + associated types
```

- As a game grows, this table gets large — isolating it keeps `Init` calls clean and gives one canonical place to look up the full data shape.
- Define Luau types for each piece of data alongside the template (e.g. a `DailyGems` type) so other scripts get IntelliSense/type-checking when reading/writing those paths.

```lua
-- Shared/DataTemplate.luau
export type DailyGems = {
	Amount: number,
	LastClaimed: number, -- unix timestamp
}

export type PlayerData = {
	Currency: number,
	Oranges: number,
	Inventory: { Apples: number },
	DailyGems: DailyGems,
}

return {
	Currency = 0,
	Oranges = 0,
	Inventory = { Apples = 0 },
	DailyGems = { Amount = 0, LastClaimed = 0 },
} :: PlayerData
```

Real-world pattern (e.g. a daily-gems claim function): read the current `DailyGems` value, `Update` it to subtract the claimed amount, stamp `LastClaimed` with the current time, and `Update` the player's currency/gem count in the same flow.

---

## 7. Advanced / Out of Scope Here

DataService also supports **global updates** and other advanced functionality not covered in this context doc. Consult the official DataService documentation before implementing anything beyond the basic get/set/update/signal/init-options flow described above.

---

## 8. Agent Directives Checklist

When working with player data in this repo:

- [ ] All persistent player data reads/writes go through DataService — never raw `DataStoreService`.
- [ ] Increment/append/decrement operations use `DataService:Update`, not `Get` followed by `Set`.
- [ ] The player data shape lives in a single `DataTemplate` module with accompanying types — not inlined in the `Init` call.
- [ ] Client code never passes a `player` argument to `Get`/`GetChangeSignal` — it's implied on the client.
- [ ] `ResetData` and `OverriddenUserId` are never left enabled outside of an active, intentional debugging session.
- [ ] UI elements that reflect player data are wired through `GetChangeSignal`, not polled manually.
- [ ] New persistent fields are added to `DataTemplate` (with a type) before being read/written elsewhere.

# DataService Typed — Player Data System Context

**Purpose:** reference context for any AI agent or contributor working with player data in this repo, if this project uses **DataService Typed** instead of (or alongside) base DataService. Describes the proxy-table API and how it differs from base DataService. Pairs with `roblox-data-service-context.md`, `roblox-structure-agent.md`, and `roblox-workflow-setup-context.md`.

**Relationship to DataService:** DataService Typed is built on the same underlying stack as DataService (ProfileStore, automatic saving, automatic client replication). It is not a different backend — it's a different, fully-typed **interaction API** on top of the same guarantees. If this project has adopted DataService Typed, do not also hand-roll calls against base DataService's `Get`/`Set`/`Update`/`GetChangeSignal` API — pick one convention and use it consistently. Check which package is actually installed (`DataService` vs `DataServiceTyped` in `wally.toml`) before writing data-access code.

---

## 1. What's Different From Base DataService

- **No manual `Init()` call and no separate "DataService" object to interact with.** You define a template, call `DataServiceTyped(options)`, and export the returned module. From then on, you interact with *that returned table* directly — not a service singleton.
- **No string/array paths.** Instead of `Get(player, {"Inventory", "Apples"})`, you access data as if it were a real nested Luau table: `Data.Inventory.Apples`.
- **Full IntelliSense/type-checking** derived automatically from the template's type — every field, and every operation available on it (get/set/update/changed/insert/remove), is inferred from the shape of the template.
- **Change signals are attached to every field automatically** (`:changed()`), rather than requested separately via a `GetChangeSignal` call.
- **Changes propagate upward:** a change to a nested field (e.g. `Inventory.Apples`) also fires the change signal on its parent (`Inventory`).

---

## 2. Setup

Create one module (commonly `Data.luau`, or `PlayerData.luau`) that defines the template and exports the configured module. This can live anywhere in `Shared/` per this project's module conventions — there is no dedicated `Services/DataService` folder needed since there's no singleton to initialize elsewhere.

```lua
-- Shared/Data.luau
local DataServiceTyped = require(Packages.DataServiceTyped)

type WeaponData = {
	Damage: number,
	SwingSpeed: number,
}

type MyTemplate = {
	Currency: number,
	Inventory: {
		Apples: number,
		Oranges: number,
	},
	Settings: {
		MusicOn: boolean,
	},
	Tutorial: {
		Step: number,
		Completed: boolean,
	},
	Words: { string },
	Weapons: { [string]: WeaponData },
}

local template: MyTemplate = {
	Currency = 0,
	Inventory = { Apples = 0, Oranges = 0 },
	Settings = { MusicOn = true },
	Tutorial = { Step = 0, Completed = false },
	Words = {},
	Weapons = {},
}

return DataServiceTyped({
	Template = template,
	-- UseMock, ResetData, ProfileStoreIndex, ViewedUserId, OverriddenUserId, etc.
	-- are the same options base DataService supports.
})
```

**Agent rule:** define the template's type explicitly (not inferred) so IntelliSense and the proxy API's available operations are correct everywhere the module is required.

---

## 3. Client Usage

Require the module's `.Client` (or client-scoped export) and interact with it as a live, typed proxy — never as a plain read-once table.

```lua
local Data = require(Shared.Data).Client

-- Get
local currency = Data.Currency() -- call it like a function to read

-- Subscribe to changes
Data.Currency:changed(function(newValue)
	print("Currency is now", newValue)
end)

-- Nested access works the same way
local apples = Data.Inventory.Apples()
Data.Inventory.Apples:changed(function(newValue)
	print("Apples:", newValue)
end)
```

**Agent rule:** the client is **read/observe only** in this pattern — reading (`Data.Field()`) and subscribing (`Data.Field:changed(fn)`) are the client's role. Writes originate on the server (see §5). Don't call setter-style syntax from the client for authoritative data.

---

## 4. Core Field Operations

| Syntax | Effect |
|---|---|
| `Data.Field()` | Get the current value. |
| `Data.Field(newValue)` | Set the value directly. |
| `Data.Field:update(fn)` | Read-modify-write: `fn` receives the current value, returns the new value. |
| `Data.Field:changed(fn)` | Subscribe to changes on this field (and, by propagation, on any parent field that contains it). |

```lua
-- Server-side update example
Data(player).Inventory.Apples:update(function(current)
	return current + 100
end)
```

**Agent rule:** use `:update()` for any increment/append/decrement — same rule as base DataService — never a manual read-then-set for anything that could race.

---

## 5. Server Usage

The server accesses the same module, but every field is accessed **through a specific player**, since the server manages many players' data at once:

```lua
local Data = require(Shared.Data).Server

local function grantCurrency(player: Player, amount: number)
	Data(player).Currency:update(function(current)
		return current + amount
	end)
end
```

Everything set/updated on the server automatically replicates to that player's client and is automatically saved — no explicit replication or save call is needed.

---

## 6. Arrays

- A field typed as an array (`{ string }`, `{ number }`, etc.) automatically exposes array-specific operations in addition to get/set/update/changed:
  - `Data.Field:insert(value)`
  - `Data.Field:remove(index)` (naming may vary — check the package's current API surface)
  - `Data.Field:onInsert(fn)` / `Data.Field:onRemove(fn)` — callbacks fired on insertion/removal.
- These only appear because the field's **type** declares it as an array. If a field should support array operations, it must be typed as an array in the template — an untyped/loosely-typed field won't expose them.

```lua
Data.Words:insert("taco")
Data.Words:onInsert(function(value)
	print("Inserted:", value)
end)
```

---

## 7. Dictionary-Keyed / Unique-ID Tables

- A common pattern: a field typed as `{ [string]: SomeDataType }` for things like per-item inventory entries keyed by a generated unique ID (e.g. via `HttpService:GenerateGUID()`).
- Since the keys aren't known ahead of time, there's nothing to enumerate on the base field — but once a key exists, accessing it (`Data.Weapons[uniqueId]`) gives the full typed proxy (get/set/update/changed) for that entry, exactly like any other field.

```lua
type WeaponData = { Damage: number, SwingSpeed: number }

-- Weapons: { [string]: WeaponData } in the template

local id = HttpService:GenerateGUID(false)
Data(player).Weapons[id](({ Damage = 10, SwingSpeed = 1.2 } :: WeaponData))

Data(player).Weapons[id].Damage:changed(function(newDamage)
	print("Weapon damage changed:", newDamage)
end)
```

---

## 8. Server-Level Callbacks & Extras

The same service-level extras that exist on base DataService are still available, just accessed through the returned module rather than a separate `DataService` object — e.g. an `OnPlayerInit`-style hook for running logic before/as a player's data loads (session timestamps, join counts, etc.), and messaging/global-update functionality. Confirm the exact current method names against the installed package version before use, since this is a newer/actively-evolving package.

---

## 9. Agent Directives Checklist

When working with player data in a project using DataService Typed:

- [ ] Confirm this project actually uses DataService Typed (check `wally.toml`) before writing to this API — don't mix it with base DataService's path-based calls in the same project.
- [ ] The template's type is explicitly declared, not inferred, so every field exposes correct proxy operations.
- [ ] Reads use `Field()`, writes use `Field(value)` or `Field:update(fn)`, subscriptions use `Field:changed(fn)` — never treat the returned module as a plain static table.
- [ ] Increment/append/decrement operations use `:update()`, never a manual get-then-set.
- [ ] Any field intended to support insert/remove is typed as an array in the template.
- [ ] Server-side field access always goes through a specific player: `Data(player).Field`, never bare `Data.Field` on the server.
- [ ] Client-side code only reads/subscribes — authoritative writes happen on the server.