# React Luau — UI System Context

**Purpose:** reference context for any AI agent or contributor building UI in this repo. Describes how UI is built with React Luau — no ScreenGuis hand-placed in Studio, no manually authored instance trees. UI is code. Pairs with `Structure.md`, `SetupContext.md`, and `DataSystem.md`.

**Source reference:** based on the walkthrough in this video: https://www.youtube.com/watch?v=Ezk3vEOvv8o

---

## 1. What React Luau Is

React Luau is Roblox's port of React (the same declarative model used for web apps), applied to Roblox UI. Declarative means: when state changes, the UI updates automatically to match — you describe *what* the UI should look like for a given state, not the imperative steps to mutate instances.

**Agent rule:** in this project, UI is built with React Luau elements, not by manually inserting/parenting `Frame`/`TextLabel`/etc. instances in Studio or scripting direct instance manipulation for UI state. If a UI element needs to exist, it's expressed as a React element/component.

Packages needed: `React` and `ReactRoblox`, installed the same way as other packages — see `roblox-workflow-setup-context.md` §6 (Wally).

---

## 2. Mounting the Tree

Every React UI needs a mount point and a root:

```lua
-- Mount.luau
local ReactRoblox = require(Packages.ReactRoblox)

local function mount(app)
	local container = Instance.new("ScreenGui")
	container.Parent = player:WaitForChild("PlayerGui")

	local root = ReactRoblox.createRoot(container)
	root:render(app)
end

return mount
```

Called once from the client startup script:

```lua
local App = require(Shared.UI.RootUI)
local mount = require(Shared.UI.Mount)

mount(App)
```

**Convention:** the top-level UI module (`RootUI`) holds all top-level screens. This is the entry point passed to `mount`.

---

## 3. `React.createElement`

- Alias `React.createElement` as `e` — this is the project-standard shorthand.
- `e(type, props, children)`:
  - **type** — a string for a plain Roblox instance (`"Frame"`, `"TextLabel"`, ...) or a component function you've defined.
  - **props** — a table of instance properties.
  - **children** — a single element or a table of elements, passed as the third+ argument.
- React elements are **not** Roblox instances — they're a lightweight description of a UI node. Instances are only created when React reconciles the tree.
- Any property not set falls back to the Roblox default for that instance class.

```lua
local e = React.createElement

local function Menu()
	return e("Frame", {
		Size = UDim2.fromScale(0.3, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	}, {
		Corner = e("UICorner", {}),
		Stroke = e("UIStroke", {}),
		Label = e("TextLabel", { Text = "Menu" }),
	})
end
```

---

## 4. Components & Props

- Components are plain functions returning an element tree.
- Accept a `props` table as the first parameter; define a type for it rather than hardcoding values inline.

```lua
export type MenuProps = {
	Position: UDim2,
	Title: string,
}

local function Menu(props: MenuProps)
	return e("Frame", {
		Position = props.Position,
	}, {
		Label = e("TextLabel", { Text = props.Title }),
	})
end
```

Usage:

```lua
e(Menu, { Position = UDim2.fromScale(0.5, 0.5), Title = "Inventory" })
```

- To render a list of elements without a single wrapping instance, wrap them in a **React Fragment** rather than returning a plain table directly — this is the correct pattern even though a plain table often "works" without errors.

---

## 5. Hooks

### `useState`

```lua
local counter, setCounter = React.useState(0)

local function increment()
	setCounter(counter + 1)
end
```

- Returns the current value and a setter. Passing a new value via the setter triggers a re-render.
- Use for UI-local state: is a menu open, which tab is selected, what's highlighted — anything that only affects how the UI looks/behaves locally.

### `useEffect`

```lua
React.useEffect(function()
	local connection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F then
			setShown(not shown)
		end
	end)

	return function()
		connection:Disconnect()
	end
end, { shown })
```

- First parameter: a function that runs after render — for subscribing to events, starting timers, reading external game state, etc.
- That function may return a cleanup function, which runs on unmount or before the effect re-runs.
- Second parameter: the dependency array. Any external state the effect reads must be listed here.
  - Empty table `{}` → effect runs once (no dependencies).
  - **Omitted entirely** → effect re-runs on every render. Avoid this unless that's genuinely intended.

### `useRef`

- For values that don't participate in the render cycle, e.g. holding a direct reference to a created instance.
- `React.useRef(initialValue)` returns a table with a `.current` field.
- Pass the ref via the special `ref` prop to capture the underlying instance (e.g. to call `:CaptureFocus()` on a TextBox).

```lua
local textboxRef = React.useRef(nil)

e("TextBox", { ref = textboxRef, ... })
```

### `useBinding`

- Use instead of `useState` for anything that updates frequently (e.g. per-frame animation) — state updates trigger full re-renders, which is expensive for high-frequency changes; bindings update the underlying property directly without a re-render.
- `React.useBinding(initialValue)` returns `[binding, setBinding]`. Read the current value with `binding:getValue()`.

```lua
local rotation, setRotation = React.useBinding(0)

React.useEffect(function()
	local connection = RunService.RenderStepped:Connect(function(dt)
		setRotation(rotation:getValue() + dt * 90)
	end)
	return function() connection:Disconnect() end
end, {})

e("ImageLabel", { Rotation = rotation })
```

**Agent rule:** any per-frame or high-frequency-updating property (rotation, position tweens, etc.) uses `useBinding`, never `useState`. For tween/spring-driven animation, prefer the project's animation library (Ripple) over hand-rolled `RenderStepped` math where one is available.

---

## 6. Conditional Rendering

Standard pattern for toggle-able UI (e.g. a menu shown/hidden by a keybind): hold a boolean in state, and conditionally return the element via an `if` expression rather than always rendering and toggling `Visible` imperatively.

```lua
local shown, setShown = React.useState(false)

-- ...useEffect toggling `shown` on keypress, with cleanup...

return shown and e(Menu, menuProps) or nil
```

---

## 7. External / Game State vs. UI State

- **React state (`useState`)** — for state that only affects how the UI looks/behaves locally: open/closed, selected tab, hover highlight.
- **External state** — for state that represents real game data: currency, inventory, player settings. This should **not** live inside a React component.
- This project keeps external/game state in an external reactive store (e.g. **Charm**) and has React components subscribe to it, rather than duplicating game state into local component state.
- Player-persisted data specifically flows through **DataService** (see `roblox-data-service-context.md`) — UI components subscribe to DataService's change signals or a Charm store synced from it, not by polling.

**Agent rule:** if a value needs to be saved, is shared across UI components, or represents actual game/player data, it does not belong in a component's `useState` — route it through the external state store / DataService instead.

---

## 8. Storybook / Live Iteration (UI Labs)

- This project uses the **UI Labs** Studio plugin as a component storybook, allowing UI to be built and iterated on live without pressing Play.
- A "story" is a function that performs some mount action and returns a cleanup function. UI Labs passes in the parent instance as the first parameter.

```lua
-- MenuStory.story.luau
return function(target)
	local root = ReactRoblox.createRoot(Instance.new("Folder"))
	root:render(e(Menu, { Position = UDim2.fromScale(0.5, 0.5) }))

	return function()
		root:unmount()
	end
end
```

**Convention:** any non-trivial component should have an accompanying story script for isolated visual iteration.

---

## 9. Agent Directives Checklist

When building or modifying UI in this repo:

- [ ] UI is expressed as React elements/components — never manually inserted/parented instances for interactive UI.
- [ ] `React.createElement` is aliased as `e`.
- [ ] Components accept a typed `props` table rather than hardcoded values.
- [ ] Lists of sibling elements are wrapped in a React Fragment, not returned as a bare table.
- [ ] `useState` is used only for local UI state; anything persistent or shared uses external state (Charm / DataService), never duplicated into component state.
- [ ] Any subscription/connection made in `useEffect` has a matching cleanup function, and the dependency array correctly lists every external value the effect reads.
- [ ] High-frequency-updating properties (animation, per-frame values) use `useBinding`, not `useState`.
- [ ] `useRef` is used (not state) for holding non-rendering values like direct instance references.
- [ ] New non-trivial components get a UI Labs story script for isolated iteration.