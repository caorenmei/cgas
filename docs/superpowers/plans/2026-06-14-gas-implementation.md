# cgas GAS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the cgas (C-Lua Gameplay Ability System) library as specified in `docs/specs/2026-06-14-gas-design.md`, including core infrastructure, semantic GAS subsystems, adapters, network stubs, and comprehensive tests.

**Architecture:** Build a layered Lua library with `cgas.core.*` providing handle/object identity, event bus, scheduler, timer, and registry; `cgas.semantics.*` implementing UE-GAS-aligned concepts (ASC, Ability, AttributeSet, Effect, Tag, Cue, Task); `cgas.adapters.*` and `cgas.net.*` as manual/Love2D integration and network placeholders. All runtime state is held by injected components, with no global mutable state.

**Tech Stack:** Lua 5.4, LuaRocks, busted, Lua Language Server (LuaCATS annotations)

---

## File Structure

New files to create:

- `lua_lib/cgas/init.lua` — Library entry, re-export public API and factory helpers.
- `lua_lib/cgas/core/object.lua` — Global handle generator and weak instance registry.
- `lua_lib/cgas/core/event.lua` — Queued event bus with safe listener dispatch.
- `lua_lib/cgas/core/scheduler.lua` — Tick registration, deferred/periodic jobs, priority ordering.
- `lua_lib/cgas/core/timer.lua` — Time source with global and per-ASC time dilation.
- `lua_lib/cgas/core/registry.lua` — Class registry for abilities, effects, attribute sets.
- `lua_lib/cgas/semantics/tag.lua` — GameplayTag, GameplayTagContainer, GameplayTagQuery, GameplayTagRegistry.
- `lua_lib/cgas/semantics/attribute.lua` — Attribute, AttributeSet, ModifierOp, Modifier aggregation.
- `lua_lib/cgas/semantics/effect.lua` — GameplayEffect, ActiveGameplayEffect, GameplayEffectSpec, duration/stack/period logic.
- `lua_lib/cgas/semantics/ability.lua` — GameplayAbility lifecycle, instance policies, cost/cooldown, tag constraints.
- `lua_lib/cgas/semantics/asc.lua` — AbilitySystemComponent: composition root for scheduler, event bus, timer, registry, abilities, effects, attribute sets, tags, cues.
- `lua_lib/cgas/semantics/cue.lua` — GameplayCueManager and GameplayCuePayload.
- `lua_lib/cgas/semantics/task.lua` — AbilityTask base and common tasks (WaitDelay, WaitInputRelease, WaitGameplayEvent, WaitAbilityCommit).
- `lua_lib/cgas/adapters/manual.lua` — Manual `update(dt)` adapter for driving an ASC from caller code.
- `lua_lib/cgas/adapters/love2d.lua` — Love2D `love.update(dt)` adapter example.
- `lua_lib/cgas/net/context.lua` — Network authority role placeholder.
- `lua_lib/cgas/net/prediction.lua` — PredictionKey placeholder.
- `lua_lib/cgas/net/event.lua` — Serializable GameplayEvent placeholder.
- `lua_tests/support/env.lua` — Test environment bootstrap: package.path setup and shared helpers.
- `lua_tests/core/object_spec.lua` — Tests for handle generation and weak registry.
- `lua_tests/core/event_spec.lua` — Tests for subscribe/emit/dispatch and error isolation.
- `lua_tests/core/scheduler_spec.lua` — Tests for register/unregister, defer, every, priority.
- `lua_tests/core/timer_spec.lua` — Tests for global and local time dilation.
- `lua_tests/core/registry_spec.lua` — Tests for class registration and lookup.
- `lua_tests/semantics/tag_spec.lua` — Tests for tag hierarchy, container, query.
- `lua_tests/semantics/attribute_spec.lua` — Tests for attribute base/current and modifier aggregation.
- `lua_tests/semantics/effect_spec.lua` — Tests for instant/duration/infinite/periodic effects and stacking.
- `lua_tests/semantics/ability_spec.lua` — Tests for ability lifecycle, tags, cost/cooldown.
- `lua_tests/semantics/asc_spec.lua` — Tests for ASC composition, give/remove ability, apply/remove effect, attribute sets.
- `lua_tests/semantics/cue_spec.lua` — Tests for cue manager and trigger payload.
- `lua_tests/semantics/task_spec.lua` — Tests for WaitDelay and lifecycle binding.
- `lua_tests/integration/fireball_spec.lua` — Fireball combo integration test.

Files to modify:

- `cgas-0.1.0-1.rockspec` — Add `lua_lib/` module entries and test dependencies.
- `.luarc.json` — Ensure `lua_lib/` is on Lua.workspace.library path (verify/adjust).

---

## Phase 1: Core Infrastructure

### Task 1: `cgas.core.object` — Handles and Weak Registry

**Files:**
- Create: `lua_lib/cgas/core/object.lua`
- Test: `lua_tests/core/object_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/core/object_spec.lua
require("lua_tests.support.env")
local object = require("cgas.core.object")

describe("cgas.core.object", function()
    it("generates monotonically increasing handles", function()
        local h1 = object.next_handle()
        local h2 = object.next_handle()
        assert.is_number(h1)
        assert.is_number(h2)
        assert.is_true(h2 > h1)
    end)

    it("registers and retrieves instances by handle", function()
        local handle = object.next_handle()
        local instance = { name = "test" }
        object.register(handle, instance)
        assert.equal(instance, object.get(handle))
    end)

    it("returns nil for unregistered handles", function()
        local h = object.next_handle()
        assert.is_nil(object.get(h))
    end)

    it("allows unregister", function()
        local h = object.next_handle()
        object.register(h, {})
        object.unregister(h)
        assert.is_nil(object.get(h))
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/core/object_spec.lua`
Expected: FAIL with "module 'cgas.core.object' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/core/object.lua
local M = {}

local _next_handle = 1
local _registry = setmetatable({}, { __mode = "v" })

---Generate a new unique handle.
---@return integer handle
function M.next_handle()
    local h = _next_handle
    _next_handle = _next_handle + 1
    return h
end

---Register an instance under a handle.
---@param handle integer
---@param instance table
function M.register(handle, instance)
    _registry[handle] = instance
end

---Unregister an instance.
---@param handle integer
function M.unregister(handle)
    _registry[handle] = nil
end

---Get an instance by handle.
---@param handle integer
---@return table|nil instance
function M.get(handle)
    return _registry[handle]
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/core/object_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/core/object.lua lua_tests/core/object_spec.lua
git commit -m "feat(core): add object handle registry

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: `cgas.core.event` — Queued Event Bus

**Files:**
- Create: `lua_lib/cgas/core/event.lua`
- Test: `lua_tests/core/event_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/core/event_spec.lua
require("lua_tests.support.env")
local EventBus = require("cgas.core.event")

describe("cgas.core.event", function()
    it("dispatches subscribed events", function()
        local bus = EventBus.new()
        local received = nil
        bus:subscribe("test", function(payload)
            received = payload
        end)
        bus:emit("test", { value = 42 })
        bus:dispatch()
        assert.equal(42, received.value)
    end)

    it("does not dispatch immediately", function()
        local bus = EventBus.new()
        local called = false
        bus:subscribe("test", function() called = true end)
        bus:emit("test", {})
        assert.is_false(called)
    end)

    it("queues events emitted during dispatch", function()
        local bus = EventBus.new()
        local count = 0
        bus:subscribe("a", function()
            count = count + 1
            bus:emit("b", {})
        end)
        bus:subscribe("b", function()
            count = count + 1
        end)
        bus:emit("a", {})
        bus:dispatch()
        assert.equal(1, count)
        bus:dispatch()
        assert.equal(2, count)
    end)

    it("isolates listener errors", function()
        local bus = EventBus.new()
        local called = false
        bus:subscribe("test", function() error("boom") end)
        bus:subscribe("test", function() called = true end)
        bus:emit("test", {})
        bus:dispatch()
        assert.is_true(called)
    end)

    it("supports unsubscribe", function()
        local bus = EventBus.new()
        local called = false
        local id = bus:subscribe("test", function() called = true end)
        bus:unsubscribe(id)
        bus:emit("test", {})
        bus:dispatch()
        assert.is_false(called)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/core/event_spec.lua`
Expected: FAIL with "module 'cgas.core.event' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/core/event.lua
local M = {}

---@class cgas.core.EventBus
---@field private _listeners table<string, table<integer, fun(payload: table)>>
---@field private _queue table<integer, {name: string, payload: table}>
---@field private _next_id integer
---@field private _dispatching boolean
local EventBus = {}
EventBus.__index = EventBus

---Create a new EventBus.
---@return cgas.core.EventBus
function M.new()
    return setmetatable({
        _listeners = {},
        _queue = {},
        _next_id = 1,
        _dispatching = false,
    }, EventBus)
end

---Subscribe to an event.
---@param event_name string
---@param listener fun(payload: table)
---@return integer subscription_id
function EventBus:subscribe(event_name, listener)
    local listeners = self._listeners[event_name]
    if not listeners then
        listeners = {}
        self._listeners[event_name] = listeners
    end
    local id = self._next_id
    self._next_id = id + 1
    listeners[id] = listener
    return id
end

---Unsubscribe from an event.
---@param subscription_id integer
function EventBus:unsubscribe(subscription_id)
    for _, listeners in pairs(self._listeners) do
        if listeners[subscription_id] then
            listeners[subscription_id] = nil
            return
        end
    end
end

---Emit an event (queued).
---@param event_name string
---@param payload table
function EventBus:emit(event_name, payload)
    table.insert(self._queue, { name = event_name, payload = payload })
end

---Dispatch all queued events.
function EventBus:dispatch()
    if self._dispatching then return end
    self._dispatching = true
    while #self._queue > 0 do
        local q = self._queue
        self._queue = {}
        for _, e in ipairs(q) do
            local listeners = self._listeners[e.name]
            if listeners then
                for _, listener in pairs(listeners) do
                    local ok, err = pcall(listener, e.payload)
                    if not ok then
                        print("[cgas.event] error in listener: " .. tostring(err))
                    end
                end
            end
        end
    end
    self._dispatching = false
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/core/event_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/core/event.lua lua_tests/core/event_spec.lua
git commit -m "feat(core): add queued event bus

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: `cgas.core.scheduler` — Tick, Defer, Every

**Files:**
- Create: `lua_lib/cgas/core/scheduler.lua`
- Test: `lua_tests/core/scheduler_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/core/scheduler_spec.lua
require("lua_tests.support.env")
local Scheduler = require("cgas.core.scheduler")

describe("cgas.core.scheduler", function()
    it("registers and ticks callbacks by priority", function()
        local s = Scheduler.new()
        local order = {}
        s:register(1, function(dt) table.insert(order, { "a", dt }) end, 10)
        s:register(2, function(dt) table.insert(order, { "b", dt }) end, 5)
        s:update(0.1)
        assert.equal("b", order[1][1])
        assert.equal("a", order[2][1])
        assert.equal(0.1, order[1][2])
    end)

    it("defers callbacks", function()
        local s = Scheduler.new()
        local called = false
        s:defer(function() called = true end, 0.2)
        s:update(0.1)
        assert.is_false(called)
        s:update(0.2)
        assert.is_true(called)
    end)

    it("runs periodic callbacks", function()
        local s = Scheduler.new()
        local count = 0
        s:every(function() count = count + 1 end, 0.5)
        s:update(0.6)
        assert.equal(1, count)
        s:update(0.6)
        assert.equal(2, count)
    end)

    it("cancels jobs", function()
        local s = Scheduler.new()
        local count = 0
        local id = s:every(function() count = count + 1 end, 0.5)
        s:cancel(id)
        s:update(1.0)
        assert.equal(0, count)
    end)

    it("unregisters tick callbacks", function()
        local s = Scheduler.new()
        local count = 0
        s:register(1, function() count = count + 1 end)
        s:unregister(1)
        s:update(0.1)
        assert.equal(0, count)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/core/scheduler_spec.lua`
Expected: FAIL with "module 'cgas.core.scheduler' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/core/scheduler.lua
local M = {}

---@class cgas.core.Scheduler
---@field private _ticks table<integer, {handle: integer, callback: fun(dt: number), priority: integer}>
---@field private _jobs table<integer, {id: integer, fn: fun(), delay: number, interval: number?}>
---@field private _next_job_id integer
local Scheduler = {}
Scheduler.__index = Scheduler

---Create a new Scheduler.
---@return cgas.core.Scheduler
function M.new()
    return setmetatable({
        _ticks = {},
        _jobs = {},
        _next_job_id = 1,
    }, Scheduler)
end

---Register a tick callback.
---@param handle integer
---@param callback fun(dt: number)
---@param priority integer? lower is earlier
function Scheduler:register(handle, callback, priority)
    priority = priority or 0
    self._ticks[handle] = { handle = handle, callback = callback, priority = priority }
end

---Unregister a tick callback.
---@param handle integer
function Scheduler:unregister(handle)
    self._ticks[handle] = nil
end

---Defer a function call.
---@param fn fun()
---@param delay number
---@return integer job_id
function Scheduler:defer(fn, delay)
    local id = self._next_job_id
    self._next_job_id = id + 1
    self._jobs[id] = { id = id, fn = fn, delay = delay, interval = nil }
    return id
end

---Register a periodic function.
---@param fn fun()
---@param interval number
---@param immediate boolean?
---@return integer job_id
function Scheduler:every(fn, interval, immediate)
    local id = self._next_job_id
    self._next_job_id = id + 1
    self._jobs[id] = { id = id, fn = fn, delay = immediate and 0 or interval, interval = interval }
    return id
end

---Cancel a job.
---@param job_id integer
function Scheduler:cancel(job_id)
    self._jobs[job_id] = nil
end

---Drive one frame.
---@param dt number
function Scheduler:update(dt)
    local sorted = {}
    for _, t in pairs(self._ticks) do
        table.insert(sorted, t)
    end
    table.sort(sorted, function(a, b) return a.priority < b.priority end)
    for _, t in ipairs(sorted) do
        local ok, err = pcall(t.callback, dt)
        if not ok then
            print("[cgas.scheduler] tick error: " .. tostring(err))
        end
    end

    local remaining = {}
    for _, job in pairs(self._jobs) do
        job.delay = job.delay - dt
        if job.delay <= 0 then
            local ok, err = pcall(job.fn)
            if not ok then
                print("[cgas.scheduler] job error: " .. tostring(err))
            end
            if job.interval then
                job.delay = job.interval
                table.insert(remaining, job)
            end
        else
            table.insert(remaining, job)
        end
    end

    local new_jobs = {}
    for _, job in ipairs(remaining) do
        new_jobs[job.id] = job
    end
    self._jobs = new_jobs
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/core/scheduler_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/core/scheduler.lua lua_tests/core/scheduler_spec.lua
git commit -m "feat(core): add scheduler with tick, defer, and periodic jobs

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: `cgas.core.timer` — Time Source and Dilation

**Files:**
- Create: `lua_lib/cgas/core/timer.lua`
- Test: `lua_tests/core/timer_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/core/timer_spec.lua
require("lua_tests.support.env")
local Timer = require("cgas.core.timer")

describe("cgas.core.timer", function()
    it("advances time", function()
        local t = Timer.new()
        assert.equal(0, t:now())
        t:advance(1.5)
        assert.equal(1.5, t:now())
    end)

    it("applies global dilation", function()
        local t = Timer.new()
        t:set_global_dilation(0.5)
        assert.equal(0.5, t:scale_dt(1, 1.0))
    end)

    it("applies local dilation", function()
        local t = Timer.new()
        t:set_local_dilation(42, 2.0)
        assert.equal(2.0, t:scale_dt(42, 1.0))
    end)

    it("combines global and local dilation", function()
        local t = Timer.new()
        t:set_global_dilation(0.5)
        t:set_local_dilation(7, 2.0)
        assert.equal(1.0, t:scale_dt(7, 1.0))
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/core/timer_spec.lua`
Expected: FAIL with "module 'cgas.core.timer' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/core/timer.lua
local M = {}

---@class cgas.core.TimeSource
---@field private _time number
---@field private _global_dilation number
---@field private _local_dilations table<integer, number>
local TimeSource = {}
TimeSource.__index = TimeSource

---Create a new TimeSource.
---@return cgas.core.TimeSource
function M.new()
    return setmetatable({
        _time = 0,
        _global_dilation = 1.0,
        _local_dilations = {},
    }, TimeSource)
end

---Advance time.
---@param dt number
function TimeSource:advance(dt)
    self._time = self._time + dt
end

---Get current time.
---@return number time
function TimeSource:now()
    return self._time
end

---Set global time dilation.
---@param dilation number
function TimeSource:set_global_dilation(dilation)
    self._global_dilation = dilation
end

---Set local time dilation for an ASC.
---@param asc_handle integer
---@param dilation number
function TimeSource:set_local_dilation(asc_handle, dilation)
    self._local_dilations[asc_handle] = dilation
end

---Scale raw dt by combined global and local dilation.
---@param asc_handle integer
---@param raw_dt number
---@return number scaled_dt
function TimeSource:scale_dt(asc_handle, raw_dt)
    local local_dilation = self._local_dilations[asc_handle] or 1.0
    return raw_dt * self._global_dilation * local_dilation
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/core/timer_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/core/timer.lua lua_tests/core/timer_spec.lua
git commit -m "feat(core): add time source with global and local dilation

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: `cgas.core.registry` — Class Registry

**Files:**
- Create: `lua_lib/cgas/core/registry.lua`
- Test: `lua_tests/core/registry_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/core/registry_spec.lua
require("lua_tests.support.env")
local Registry = require("cgas.core.registry")

describe("cgas.core.registry", function()
    it("registers and retrieves ability classes", function()
        local r = Registry.new()
        local cls = { name = "Fireball" }
        r:register_ability("Fireball", cls)
        assert.equal(cls, r:get("ability", "Fireball"))
    end)

    it("registers and retrieves effect classes", function()
        local r = Registry.new()
        local cls = { name = "Burning" }
        r:register_effect("Burning", cls)
        assert.equal(cls, r:get("effect", "Burning"))
    end)

    it("registers and retrieves attribute set classes", function()
        local r = Registry.new()
        local cls = { name = "HealthSet" }
        r:register_attribute_set("HealthSet", cls)
        assert.equal(cls, r:get("attribute_set", "HealthSet"))
    end)

    it("returns nil for unknown classes", function()
        local r = Registry.new()
        assert.is_nil(r:get("ability", "Nothing"))
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/core/registry_spec.lua`
Expected: FAIL with "module 'cgas.core.registry' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/core/registry.lua
local M = {}

---@class cgas.core.Registry
---@field private _abilities table<string, table>
---@field private _effects table<string, table>
---@field private _attribute_sets table<string, table>
local Registry = {}
Registry.__index = Registry

---Create a new Registry.
---@return cgas.core.Registry
function M.new()
    return setmetatable({
        _abilities = {},
        _effects = {},
        _attribute_sets = {},
    }, Registry)
end

---Register an ability class.
---@param class_name string
---@param class table
function Registry:register_ability(class_name, class)
    self._abilities[class_name] = class
end

---Register an effect class.
---@param class_name string
---@param class table
function Registry:register_effect(class_name, class)
    self._effects[class_name] = class
end

---Register an attribute set class.
---@param class_name string
---@param class table
function Registry:register_attribute_set(class_name, class)
    self._attribute_sets[class_name] = class
end

---Look up a class by kind and name.
---@param kind "ability"|"effect"|"attribute_set"
---@param class_name string
---@return table|nil class
function Registry:get(kind, class_name)
    if kind == "ability" then
        return self._abilities[class_name]
    elseif kind == "effect" then
        return self._effects[class_name]
    elseif kind == "attribute_set" then
        return self._attribute_sets[class_name]
    end
    return nil
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/core/registry_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/core/registry.lua lua_tests/core/registry_spec.lua
git commit -m "feat(core): add class registry for abilities, effects, and attribute sets

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Phase 2: Semantic Foundation

### Task 6: `cgas.semantics.tag` — GameplayTag System

**Files:**
- Create: `lua_lib/cgas/semantics/tag.lua`
- Test: `lua_tests/semantics/tag_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/semantics/tag_spec.lua
require("lua_tests.support.env")
local tag = require("cgas.semantics.tag")

describe("cgas.semantics.tag", function()
    it("creates tags and checks hierarchy", function()
        local t = tag.GameplayTag.new("state.debuff.stun")
        assert.is_true(t:has("state"))
        assert.is_true(t:has("state.debuff"))
        assert.is_true(t:has("state.debuff.stun"))
        assert.is_false(t:has("state.buff"))
    end)

    it("adds and removes tags from container", function()
        local c = tag.GameplayTagContainer.new()
        local t = tag.GameplayTag.new("state.debuff.stun")
        c:add(t)
        assert.is_true(c:has(tag.GameplayTag.new("state.debuff")))
        c:remove(t)
        assert.is_false(c:has(tag.GameplayTag.new("state.debuff.stun")))
    end)

    it("matches query with all/any/none", function()
        local c = tag.GameplayTagContainer.new()
        c:add(tag.GameplayTag.new("a.b"))
        c:add(tag.GameplayTag.new("c.d"))

        local q1 = tag.GameplayTagQuery.new()
        q1.all_tags:add(tag.GameplayTag.new("a.b"))
        assert.is_true(q1:matches(c))

        local q2 = tag.GameplayTagQuery.new()
        q2.any_tags:add(tag.GameplayTag.new("x.y"))
        q2.any_tags:add(tag.GameplayTag.new("c.d"))
        assert.is_true(q2:matches(c))

        local q3 = tag.GameplayTagQuery.new()
        q3.none_tags:add(tag.GameplayTag.new("a.b"))
        assert.is_false(q3:matches(c))
    end)

    it("matches_any and matches_all between containers", function()
        local a = tag.GameplayTagContainer.new()
        a:add(tag.GameplayTag.new("a.b"))
        a:add(tag.GameplayTag.new("c.d"))

        local b = tag.GameplayTagContainer.new()
        b:add(tag.GameplayTag.new("a.b"))

        assert.is_true(a:matches_any(b))
        assert.is_false(a:matches_all(b))
    end)

    it("supports registry validation", function()
        local registry = tag.GameplayTagRegistry.new()
        registry:register("state.debuff.stun")
        assert.is_true(registry:is_valid("state.debuff.stun"))
        assert.is_false(registry:is_valid("state.buff"))
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/semantics/tag_spec.lua`
Expected: FAIL with "module 'cgas.semantics.tag' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/semantics/tag.lua
local M = {}

---@class cgas.semantics.GameplayTag
---@field value string
local GameplayTag = {}
GameplayTag.__index = GameplayTag

---Create a tag.
---@param value string
---@return cgas.semantics.GameplayTag
function GameplayTag.new(value)
    return setmetatable({ value = value }, GameplayTag)
end

---Check if this tag matches or is a child of another tag.
---@param other cgas.semantics.GameplayTag|string
---@return boolean
function GameplayTag:has(other)
    local other_value = type(other) == "string" and other or other.value
    if self.value == other_value then return true end
    local prefix = other_value .. "."
    return self.value:sub(1, #prefix) == prefix
end

---@class cgas.semantics.GameplayTagContainer
---@field private _tags table<string, cgas.semantics.GameplayTag>
local GameplayTagContainer = {}
GameplayTagContainer.__index = GameplayTagContainer

---Create an empty container.
---@return cgas.semantics.GameplayTagContainer
function GameplayTagContainer.new()
    return setmetatable({ _tags = {} }, GameplayTagContainer)
end

---Add a tag.
---@param t cgas.semantics.GameplayTag
function GameplayTagContainer:add(t)
    self._tags[t.value] = t
end

---Remove a tag.
---@param t cgas.semantics.GameplayTag
function GameplayTagContainer:remove(t)
    self._tags[t.value] = nil
end

---Check exact tag presence.
---@param t cgas.semantics.GameplayTag
---@return boolean
function GameplayTagContainer:has_exact(t)
    return self._tags[t.value] ~= nil
end

---Check tag or parent presence.
---@param t cgas.semantics.GameplayTag
---@return boolean
function GameplayTagContainer:has(t)
    for value, _ in pairs(self._tags) do
        local candidate = GameplayTag.new(value)
        if candidate:has(t) then return true end
    end
    return false
end

---Check if any tag of other is present in self.
---@param other cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagContainer:matches_any(other)
    for value, _ in pairs(other._tags) do
        if self:has(GameplayTag.new(value)) then return true end
    end
    return false
end

---Check if all tags of other are present in self.
---@param other cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagContainer:matches_all(other)
    for value, _ in pairs(other._tags) do
        if not self:has(GameplayTag.new(value)) then return false end
    end
    return #other._tags == 0 or next(other._tags) ~= nil
end

---@class cgas.semantics.GameplayTagQuery
---@field all_tags cgas.semantics.GameplayTagContainer
---@field any_tags cgas.semantics.GameplayTagContainer
---@field none_tags cgas.semantics.GameplayTagContainer
local GameplayTagQuery = {}
GameplayTagQuery.__index = GameplayTagQuery

---Create an empty query.
---@return cgas.semantics.GameplayTagQuery
function GameplayTagQuery.new()
    return setmetatable({
        all_tags = GameplayTagContainer.new(),
        any_tags = GameplayTagContainer.new(),
        none_tags = GameplayTagContainer.new(),
    }, GameplayTagQuery)
end

---Check if a container matches this query.
---@param container cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagQuery:matches(container)
    for value, _ in pairs(self.all_tags._tags) do
        if not container:has(GameplayTag.new(value)) then return false end
    end
    if next(self.any_tags._tags) ~= nil then
        local any = false
        for value, _ in pairs(self.any_tags._tags) do
            if container:has(GameplayTag.new(value)) then
                any = true
                break
            end
        end
        if not any then return false end
    end
    for value, _ in pairs(self.none_tags._tags) do
        if container:has(GameplayTag.new(value)) then return false end
    end
    return true
end

---@class cgas.semantics.GameplayTagRegistry
---@field private _tags table<string, boolean>
local GameplayTagRegistry = {}
GameplayTagRegistry.__index = GameplayTagRegistry

---Create a new registry.
---@return cgas.semantics.GameplayTagRegistry
function GameplayTagRegistry.new()
    return setmetatable({ _tags = {} }, GameplayTagRegistry)
end

---Register a tag path.
---@param tag_string string
function GameplayTagRegistry:register(tag_string)
    self._tags[tag_string] = true
    local parent = tag_string:match("^(.*)%.[^.]+$")
    while parent do
        self._tags[parent] = true
        parent = parent:match("^(.*)%.[^.]+$")
    end
end

---Check if a tag is valid/registered.
---@param tag_string string
---@return boolean
function GameplayTagRegistry:is_valid(tag_string)
    return self._tags[tag_string] == true
end

M.GameplayTag = GameplayTag
M.GameplayTagContainer = GameplayTagContainer
M.GameplayTagQuery = GameplayTagQuery
M.GameplayTagRegistry = GameplayTagRegistry

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/semantics/tag_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/semantics/tag.lua lua_tests/semantics/tag_spec.lua
git commit -m "feat(semantics): add gameplay tag system

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: `cgas.semantics.attribute` — Attributes and Modifiers

**Files:**
- Create: `lua_lib/cgas/semantics/attribute.lua`
- Test: `lua_tests/semantics/attribute_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/semantics/attribute_spec.lua
require("lua_tests.support.env")
local attr = require("cgas.semantics.attribute")

describe("cgas.semantics.attribute", function()
    it("creates attribute with default values", function()
        local a = attr.Attribute.new("Health", 100)
        assert.equal(100, a.base_value)
        assert.equal(100, a.current_value)
    end)

    it("applies add modifiers", function()
        local a = attr.Attribute.new("Health", 100)
        a:recalculate({
            { attribute_name = "Health", op = "add", magnitude = 20 },
        })
        assert.equal(120, a.current_value)
    end)

    it("applies multiply after add", function()
        local a = attr.Attribute.new("Health", 100)
        a:recalculate({
            { attribute_name = "Health", op = "add", magnitude = 50 },
            { attribute_name = "Health", op = "multiply", magnitude = 2 },
        })
        assert.equal(300, a.current_value)
    end)

    it("applies override", function()
        local a = attr.Attribute.new("Health", 100)
        a:recalculate({
            { attribute_name = "Health", op = "add", magnitude = 50 },
            { attribute_name = "Health", op = "override", magnitude = 10 },
        })
        assert.equal(10, a.current_value)
    end)

    it("clamps current value", function()
        local a = attr.Attribute.new("Health", 100, { min_value = 0, max_value = 100 })
        a.base_value = 150
        a:recalculate({})
        assert.equal(100, a.current_value)
        a.base_value = -10
        a:recalculate({})
        assert.equal(0, a.current_value)
    end)

    it("supports attribute sets", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100, { max_value = 100 })
        assert.equal("HealthSet", set.name)
        assert.equal(100, set:get("Health").base_value)
    end)

    it("tracks base and current change", function()
        local a = attr.Attribute.new("Health", 100)
        local events = {}
        a.on_base_changed = function(oldv, newv)
            table.insert(events, { "base", oldv, newv })
        end
        a:set_base(80)
        assert.equal("base", events[1][1])
        assert.equal(80, events[1][3])
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/semantics/attribute_spec.lua`
Expected: FAIL with "module 'cgas.semantics.attribute' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/semantics/attribute.lua
local M = {}

---@alias cgas.semantics.ModifierOp "add"|"multiply"|"divide"|"override"

---@class cgas.semantics.Modifier
---@field attribute_name string
---@field op cgas.semantics.ModifierOp
---@field magnitude number
---@field source_handle integer?

---@class cgas.semantics.Attribute
---@field name string
---@field base_value number
---@field current_value number
---@field min_value number?
---@field max_value number?
---@field is_meta boolean
---@field on_base_changed fun(old_value: number, new_value: number)?
---@field on_current_changed fun(old_value: number, new_value: number)?
local Attribute = {}
Attribute.__index = Attribute

---Create an attribute.
---@param name string
---@param default_value number
---@param opts table?
---@return cgas.semantics.Attribute
function Attribute.new(name, default_value, opts)
    opts = opts or {}
    local a = setmetatable({
        name = name,
        base_value = default_value,
        current_value = default_value,
        min_value = opts.min_value,
        max_value = opts.max_value,
        is_meta = opts.is_meta or false,
        on_base_changed = nil,
        on_current_changed = nil,
    }, Attribute)
    return a
end

---Set base value and trigger callback.
---@param value number
function Attribute:set_base(value)
    local old = self.base_value
    if old ~= value then
        self.base_value = value
        if self.on_base_changed then
            self.on_base_changed(old, value)
        end
    end
end

---Recalculate current value from base and modifiers.
---@param modifiers cgas.semantics.Modifier[]
function Attribute:recalculate(modifiers)
    local old = self.current_value
    local value = self.base_value
    local override = nil

    for _, m in ipairs(modifiers) do
        if m.attribute_name == self.name then
            if m.op == "add" then
                value = value + m.magnitude
            elseif m.op == "multiply" then
                value = value * m.magnitude
            elseif m.op == "divide" then
                value = value / m.magnitude
            elseif m.op == "override" then
                override = m.magnitude
            end
        end
    end

    if override ~= nil then
        value = override
    end

    if self.min_value ~= nil and value < self.min_value then
        value = self.min_value
    end
    if self.max_value ~= nil and value > self.max_value then
        value = self.max_value
    end

    self.current_value = value
    if old ~= value and self.on_current_changed then
        self.on_current_changed(old, value)
    end
end

---@class cgas.semantics.AttributeSet
---@field name string
---@field private _attributes table<string, cgas.semantics.Attribute>
local AttributeSet = {}
AttributeSet.__index = AttributeSet

---Create an attribute set.
---@param name string
---@return cgas.semantics.AttributeSet
function AttributeSet.new(name)
    return setmetatable({ name = name, _attributes = {} }, AttributeSet)
end

---Register an attribute in this set.
---@param attr_name string
---@param default_value number
---@param opts table?
function AttributeSet:register_attribute(attr_name, default_value, opts)
    self._attributes[attr_name] = Attribute.new(attr_name, default_value, opts)
end

---Get an attribute by name.
---@param attr_name string
---@return cgas.semantics.Attribute|nil
function AttributeSet:get(attr_name)
    return self._attributes[attr_name]
end

---Iterate attributes.
---@return fun(): string, cgas.semantics.Attribute
function AttributeSet:iter()
    return pairs(self._attributes)
end

M.Attribute = Attribute
M.AttributeSet = AttributeSet

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/semantics/attribute_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/semantics/attribute.lua lua_tests/semantics/attribute_spec.lua
git commit -m "feat(semantics): add attribute and modifier aggregation

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: `cgas.semantics.effect` — GameplayEffect and ActiveGameplayEffect

**Files:**
- Create: `lua_lib/cgas/semantics/effect.lua`
- Test: `lua_tests/semantics/effect_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/semantics/effect_spec.lua
require("lua_tests.support.env")
local effect = require("cgas.semantics.effect")
local attr = require("cgas.semantics.attribute")

describe("cgas.semantics.effect", function()
    it("creates instant effect spec", function()
        local e = effect.GameplayEffect.new({
            name = "Damage",
            duration_policy = "instant",
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = -10 },
            },
        })
        assert.equal("instant", e.duration_policy)
    end)

    it("applies instant effect to attribute set", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Damage",
            duration_policy = "instant",
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = -10 },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:apply_instant()
        assert.equal(90, set:get("Health").current_value)
    end)

    it("applies duration effect", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Regen",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 2.0 },
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = 5 },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:on_apply()
        assert.equal(105, set:get("Health").current_value)
    end)

    it("updates duration and expires", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Regen",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 1.0 },
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = 5 },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:on_apply()
        active:update(1.1)
        assert.is_true(active:is_expired())
    end)

    it("handles periodic effects", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Poison",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 2.0 },
            period = 0.5,
            periodic_instant = true,
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = -5 },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:on_apply()
        active:update(0.6)
        assert.equal(90, set:get("Health").current_value)
        active:update(0.6)
        assert.equal(80, set:get("Health").current_value)
    end)

    it("stacks effects by target", function()
        local e = effect.GameplayEffect.new({
            name = "Buff",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 5.0 },
            stacking_policy = "aggregate_by_target",
            stack_limit = 3,
            modifiers = {
                { attribute_name = "Strength", op = "add", magnitude = 5 },
            },
        })
        local a1 = effect.ActiveGameplayEffect.new({ effect = e, level = 1 })
        local a2 = effect.ActiveGameplayEffect.new({ effect = e, level = 1 })
        a1:on_apply()
        a2:on_apply()
        assert.equal(2, a1.stack_count)
        a2.stack_count = 3
        assert.is_true(a1:is_stack_at_limit())
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/semantics/effect_spec.lua`
Expected: FAIL with "module 'cgas.semantics.effect' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/semantics/effect.lua
local object = require("cgas.core.object")

local M = {}

---@class cgas.semantics.GameplayEffect
---@field name string
---@field duration_policy "instant"|"duration"|"infinite"
---@field duration cgas.semantics.Magnitude?
---@field period number?
---@field periodic_instant boolean?
---@field modifiers cgas.semantics.Modifier[]
---@field granted_tags cgas.semantics.GameplayTagContainer
---@field removed_tags cgas.semantics.GameplayTagContainer
---@field application_required_tags cgas.semantics.GameplayTagQuery
---@field application_immunity_tags cgas.semantics.GameplayTagQuery
---@field stacking_policy "none"|"aggregate_by_source"|"aggregate_by_target"
---@field stack_limit integer?
---@field stack_refresh "duration"|"magnitude"|"both"
local GameplayEffect = {}
GameplayEffect.__index = GameplayEffect

---@param def table
---@return cgas.semantics.GameplayEffect
function GameplayEffect.new(def)
    local e = setmetatable({
        name = def.name,
        duration_policy = def.duration_policy or "instant",
        duration = def.duration,
        period = def.period,
        periodic_instant = def.periodic_instant or false,
        modifiers = def.modifiers or {},
        granted_tags = def.granted_tags,
        removed_tags = def.removed_tags,
        application_required_tags = def.application_required_tags,
        application_immunity_tags = def.application_immunity_tags,
        stacking_policy = def.stacking_policy or "none",
        stack_limit = def.stack_limit,
        stack_refresh = def.stack_refresh or "duration",
    }, GameplayEffect)
    return e
end

---Resolve magnitude from definition.
---@param magnitude cgas.semantics.Magnitude
---@param level integer
---@param source_set cgas.semantics.AttributeSet?
---@param target_set cgas.semantics.AttributeSet?
---@return number
local function resolve_magnitude(magnitude, level, source_set, target_set)
    if magnitude.type == "scalable_float" then
        return magnitude.value
    elseif magnitude.type == "attribute_based" then
        local attr = nil
        if source_set and source_set:get(magnitude.attribute) then
            attr = source_set:get(magnitude.attribute)
        elseif target_set and target_set:get(magnitude.attribute) then
            attr = target_set:get(magnitude.attribute)
        end
        local base = attr and attr.current_value or 0
        if magnitude.pre_multiply then
            return base * magnitude.coefficient
        else
            return base + magnitude.coefficient
        end
    elseif magnitude.type == "custom" then
        return magnitude.func({ level = level, source_set = source_set, target_set = target_set })
    end
    return 0
end

---@class cgas.semantics.ActiveGameplayEffect
---@field handle integer
---@field effect cgas.semantics.GameplayEffect
---@field target_set cgas.semantics.AttributeSet?
---@field source_set cgas.semantics.AttributeSet?
---@field level integer
---@field start_time number
---@field duration number?
---@field period_timer number
---@field stack_count integer
---@field is_active boolean
local ActiveGameplayEffect = {}
ActiveGameplayEffect.__index = ActiveGameplayEffect

---@param opts table
---@return cgas.semantics.ActiveGameplayEffect
function ActiveGameplayEffect.new(opts)
    local active = setmetatable({
        handle = object.next_handle(),
        effect = opts.effect,
        target_set = opts.target_set,
        source_set = opts.source_set,
        level = opts.level or 1,
        start_time = opts.start_time or 0,
        duration = nil,
        period_timer = 0,
        stack_count = 1,
        is_active = false,
    }, ActiveGameplayEffect)
    if active.effect.duration_policy == "duration" and active.effect.duration then
        active.duration = resolve_magnitude(active.effect.duration, active.level, active.source_set, active.target_set)
    end
    return active
end

---Apply modifiers to the target attribute set.
function ActiveGameplayEffect:_apply_modifiers()
    if not self.target_set then return end
    local all_mods = {}
    for i = 1, self.stack_count do
        for _, m in ipairs(self.effect.modifiers) do
            table.insert(all_mods, m)
        end
    end
    for attr_name, attr in self.target_set:iter() do
        attr:recalculate(all_mods)
    end
end

---Apply an instant effect.
function ActiveGameplayEffect:apply_instant()
    self:_apply_modifiers()
end

---Called when the effect is applied to an ASC.
function ActiveGameplayEffect:on_apply()
    self.is_active = true
    if self.effect.duration_policy ~= "instant" then
        self:_apply_modifiers()
    end
end

---Update the active effect.
---@param dt number
function ActiveGameplayEffect:update(dt)
    if not self.is_active then return end
    if self.effect.duration and self.duration then
        self.duration = self.duration - dt
    end
    if self.effect.period then
        self.period_timer = self.period_timer + dt
        while self.period_timer >= self.effect.period do
            self.period_timer = self.period_timer - self.effect.period
            if self.effect.periodic_instant then
                self:apply_instant()
            end
        end
    end
end

---Check if the effect has expired.
---@return boolean
function ActiveGameplayEffect:is_expired()
    if self.effect.duration_policy == "infinite" then return false end
    if self.effect.duration_policy == "instant" then return true end
    return self.duration ~= nil and self.duration <= 0
end

---Check if stack is at limit.
---@return boolean
function ActiveGameplayEffect:is_stack_at_limit()
    if not self.effect.stack_limit then return false end
    return self.stack_count >= self.effect.stack_limit
end

---Refresh duration on stack increase.
function ActiveGameplayEffect:refresh_duration()
    if self.effect.duration and self.effect.duration_policy == "duration" then
        self.duration = resolve_magnitude(self.effect.duration, self.level, self.source_set, self.target_set)
    end
end

M.GameplayEffect = GameplayEffect
M.ActiveGameplayEffect = ActiveGameplayEffect
M.resolve_magnitude = resolve_magnitude

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/semantics/effect_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/semantics/effect.lua lua_tests/semantics/effect_spec.lua
git commit -m "feat(semantics): add gameplay effect lifecycle and stacking

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Phase 3: Semantic Core

### Task 9: `cgas.semantics.ability` — GameplayAbility Lifecycle

**Files:**
- Create: `lua_lib/cgas/semantics/ability.lua`
- Test: `lua_tests/semantics/ability_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/semantics/ability_spec.lua
require("lua_tests.support.env")
local ability = require("cgas.semantics.ability")
local tag = require("cgas.semantics.tag")

describe("cgas.semantics.ability", function()
    local function make_asc()
        return {
            owned_tags = tag.GameplayTagContainer.new(),
            apply_effect = function() return true end,
            event_bus = { emit = function() end },
            scheduler = {},
            time_source = {},
            remove_active_effect = function() return true end,
        }
    end

    it("starts inactive", function()
        local asc = make_asc()
        local ab = ability.GameplayAbility.new(asc, { name = "Fireball" })
        assert.equal("inactive", ab.state)
    end)

    it("activates and commits", function()
        local asc = make_asc()
        local activated = false
        local ab = ability.GameplayAbility.new(asc, {
            name = "Fireball",
            ActivateAbility = function(self)
                activated = true
            end,
        })
        assert.is_true(ab:can_activate())
        assert.is_true(ab:activate())
        assert.equal("active", ab.state)
        assert.is_true(activated)
        assert.is_true(ab:commit())
    end)

    it("blocks activation by required tags", function()
        local asc = make_asc()
        local ab = ability.GameplayAbility.new(asc, {
            name = "Fireball",
            activation_required_tags = function()
                local q = tag.GameplayTagQuery.new()
                q.all_tags:add(tag.GameplayTag.new("state.ready"))
                return q
            end,
        })
        local ok, err = ab:can_activate()
        assert.is_false(ok)
        assert.is_string(err)
    end)

    it("ends ability and clears tasks", function()
        local asc = make_asc()
        local ab = ability.GameplayAbility.new(asc, { name = "Fireball" })
        ab:activate()
        ab:end_ability()
        assert.equal("inactive", ab.state)
    end)

    it("cancels other abilities with tag", function()
        local asc = make_asc()
        local other = ability.GameplayAbility.new(asc, {
            name = "Channel",
            ability_tags = function()
                local c = tag.GameplayTagContainer.new()
                c:add(tag.GameplayTag.new("ability.channel"))
                return c
            end,
        })
        other:activate()

        local ab = ability.GameplayAbility.new(asc, {
            name = "Stun",
            cancel_abilities_with_tag = function()
                local c = tag.GameplayTagContainer.new()
                c:add(tag.GameplayTag.new("ability.channel"))
                return c
            end,
        })
        ab:cancel_abilities_with_tag()
        assert.equal("inactive", other.state)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/semantics/ability_spec.lua`
Expected: FAIL with "module 'cgas.semantics.ability' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/semantics/ability.lua
local object = require("cgas.core.object")
local tag = require("cgas.semantics.tag")

local M = {}

---@class cgas.semantics.GameplayAbility
---@field handle integer
---@field asc cgas.semantics.ASC
---@field class table
---@field state "inactive"|"committing"|"active"|"ending"
---@field instance_policy "non_instanced"|"instanced_per_actor"|"instanced_per_execution"
---@field level integer
---@field input_id integer|string|nil
---@field ability_tags cgas.semantics.GameplayTagContainer
---@field activation_owned_tags cgas.semantics.GameplayTagContainer
---@field activation_blocked_tags cgas.semantics.GameplayTagContainer
---@field activation_required_tags cgas.semantics.GameplayTagQuery
---@field cancel_abilities_with_tag cgas.semantics.GameplayTagContainer
---@field block_abilities_with_tag cgas.semantics.GameplayTagContainer
---@field cost_effect_class table|nil
---@field cooldown_effect_class table|nil
---@field active_tasks table<integer, cgas.semantics.AbilityTask>
local GameplayAbility = {}
GameplayAbility.__index = GameplayAbility

---Helper to evaluate a class field that may be a value or a function.
---@param cls table
---@param key string
---@return any
local function class_field(cls, key)
    local v = cls[key]
    if type(v) == "function" then
        return v(cls)
    end
    return v
end

---Create an ability instance.
---@param asc cgas.semantics.ASC
---@param class table
---@param level integer?
---@return cgas.semantics.GameplayAbility
function GameplayAbility.new(asc, class, level)
    local ab = setmetatable({
        handle = object.next_handle(),
        asc = asc,
        class = class,
        state = "inactive",
        instance_policy = class.instance_policy or "instanced_per_execution",
        level = level or 1,
        input_id = class.input_id,
        ability_tags = class_field(class, "ability_tags") or tag.GameplayTagContainer.new(),
        activation_owned_tags = class_field(class, "activation_owned_tags") or tag.GameplayTagContainer.new(),
        activation_blocked_tags = class_field(class, "activation_blocked_tags") or tag.GameplayTagContainer.new(),
        activation_required_tags = class_field(class, "activation_required_tags") or tag.GameplayTagQuery.new(),
        cancel_abilities_with_tag = class_field(class, "cancel_abilities_with_tag") or tag.GameplayTagContainer.new(),
        block_abilities_with_tag = class_field(class, "block_abilities_with_tag") or tag.GameplayTagContainer.new(),
        cost_effect_class = class.cost_effect_class,
        cooldown_effect_class = class.cooldown_effect_class,
        active_tasks = {},
    }, GameplayAbility)
    return ab
end

---Check if activation is allowed.
---@return boolean can_activate
---@return string|nil error
function GameplayAbility:can_activate()
    if not self.activation_required_tags:matches(self.asc.owned_tags) then
        return false, "activation blocked: missing required tags"
    end
    if self.activation_blocked_tags:matches_any(self.asc.owned_tags) then
        return false, "activation blocked: owns blocked tags"
    end
    return true, nil
end

---Activate the ability.
---@return boolean ok
function GameplayAbility:activate()
    if self.state ~= "inactive" then return false end
    local ok, err = self:can_activate()
    if not ok then
        print("[cgas.ability] activate failed: " .. tostring(err))
        return false
    end
    self.state = "committing"
    for _, t in pairs(self.activation_owned_tags._tags) do
        self.asc.owned_tags:add(t)
    end
    self.state = "active"
    if self.class.ActivateAbility then
        local ok2, err2 = pcall(self.class.ActivateAbility, self)
        if not ok2 then
            print("[cgas.ability] ActivateAbility error: " .. tostring(err2))
            self:end_ability()
            return false
        end
    end
    return true
end

---Commit the ability (cost and cooldown).
---@return boolean ok
function GameplayAbility:commit()
    if self.state ~= "active" then return false end
    if self.cost_effect_class then
        self.asc:apply_effect({ effect_class = self.cost_effect_class, source = self.asc, level = self.level })
    end
    if self.cooldown_effect_class then
        self.asc:apply_effect({ effect_class = self.cooldown_effect_class, source = self.asc, level = self.level })
    end
    return true
end

---End the ability.
---@return boolean ok
function GameplayAbility:end_ability()
    if self.state ~= "active" then return false end
    self.state = "ending"
    for _, task in pairs(self.active_tasks) do
        task:finish(nil)
    end
    self.active_tasks = {}
    for _, t in pairs(self.activation_owned_tags._tags) do
        self.asc.owned_tags:remove(t)
    end
    self.state = "inactive"
    return true
end

---Cancel the ability.
---@return boolean ok
function GameplayAbility:cancel()
    if self.state ~= "active" then return false end
    return self:end_ability()
end

---Cancel other active abilities matching cancel_abilities_with_tag.
function GameplayAbility:cancel_abilities_with_tag()
    for _, other in pairs(self.asc.granted_abilities or {}) do
        if other ~= self and other.state == "active" then
            if other.ability_tags:matches_any(self.cancel_abilities_with_tag) then
                other:cancel()
            end
        end
    end
end

---Update the ability (and tasks).
---@param dt number
function GameplayAbility:update(dt)
    for _, task in pairs(self.active_tasks) do
        task:update(dt)
    end
end

M.GameplayAbility = GameplayAbility

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/semantics/ability_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/semantics/ability.lua lua_tests/semantics/ability_spec.lua
git commit -m "feat(semantics): add gameplay ability lifecycle

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 10: `cgas.semantics.asc` — AbilitySystemComponent

**Files:**
- Create: `lua_lib/cgas/semantics/asc.lua`
- Test: `lua_tests/semantics/asc_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/semantics/asc_spec.lua
require("lua_tests.support.env")
local asc = require("cgas.semantics.asc")
local attr = require("cgas.semantics.attribute")
local effect = require("cgas.semantics.effect")

describe("cgas.semantics.asc", function()
    it("creates ASC with injected core components", function()
        local a, err = asc.ASC.new({})
        assert.is_nil(err)
        assert.is_not_nil(a.scheduler)
        assert.is_not_nil(a.event_bus)
        assert.is_not_nil(a.time_source)
        assert.is_not_nil(a.registry)
        assert.is_not_nil(a.owned_tags)
    end)

    it("adds attribute sets", function()
        local a = asc.ASC.new({})
        local HealthSet = { name = "HealthSet" }
        function HealthSet:on_init(set)
            set:register_attribute("Health", 100, { max_value = 100 })
        end
        local set = a:add_attribute_set(HealthSet)
        assert.is_not_nil(set)
        assert.equal(100, set:get("Health").current_value)
    end)

    it("gives and removes abilities", function()
        local a = asc.ASC.new({})
        local h, err = a:give_ability({ name = "Fireball" })
        assert.is_nil(err)
        assert.is_number(h)
        assert.is_true(a:remove_ability(h))
    end)

    it("applies and removes effects", function()
        local a = asc.ASC.new({})
        local HealthSet = { name = "HealthSet" }
        function HealthSet:on_init(set)
            set:register_attribute("Health", 100, { max_value = 100 })
        end
        a:add_attribute_set(HealthSet)

        local Damage = effect.GameplayEffect.new({
            name = "Damage",
            duration_policy = "instant",
            modifiers = { { attribute_name = "Health", op = "add", magnitude = -10 } },
        })
        local h, err = a:apply_effect({ effect_class = Damage })
        assert.is_nil(err)
        assert.equal(90, a:get_attribute("HealthSet.Health").current_value)
        assert.is_true(a:remove_active_effect(h))
    end)

    it("updates active effects", function()
        local a = asc.ASC.new({})
        local HealthSet = { name = "HealthSet" }
        function HealthSet:on_init(set)
            set:register_attribute("Health", 100, { max_value = 100 })
        end
        a:add_attribute_set(HealthSet)

        local Regen = effect.GameplayEffect.new({
            name = "Regen",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 5.0 },
            modifiers = { { attribute_name = "Health", op = "add", magnitude = 5 } },
        })
        a:apply_effect({ effect_class = Regen })
        a:update(0.1)
        assert.equal(105, a:get_attribute("HealthSet.Health").current_value)
    end)

    it("destroys cleanly", function()
        local a = asc.ASC.new({})
        local h = a:give_ability({ name = "Fireball" })
        a:destroy()
        assert.is_nil(a.granted_abilities[h])
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/semantics/asc_spec.lua`
Expected: FAIL with "module 'cgas.semantics.asc' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/semantics/asc.lua
local object = require("cgas.core.object")
local Scheduler = require("cgas.core.scheduler")
local EventBus = require("cgas.core.event")
local TimeSource = require("cgas.core.timer")
local Registry = require("cgas.core.registry")
local tag = require("cgas.semantics.tag")
local attr = require("cgas.semantics.attribute")
local effect_mod = require("cgas.semantics.effect")
local ability_mod = require("cgas.semantics.ability")
local cue_mod = require("cgas.semantics.cue")

local M = {}

---@class cgas.semantics.ASC
---@field handle integer
---@field scheduler cgas.core.Scheduler
---@field event_bus cgas.core.EventBus
---@field time_source cgas.core.TimeSource
---@field registry cgas.core.Registry
---@field attribute_sets table<string, cgas.semantics.AttributeSet>
---@field granted_abilities table<integer, cgas.semantics.GameplayAbility>
---@field active_effects table<integer, cgas.semantics.ActiveGameplayEffect>
---@field owned_tags cgas.semantics.GameplayTagContainer
---@field blocked_tags cgas.semantics.GameplayTagContainer
---@field cue_manager cgas.semantics.GameplayCueManager
local ASC = {}
ASC.__index = ASC

---Create an ASC.
---@param opts table
---@return cgas.semantics.ASC|nil asc
---@return string|nil error
function ASC.new(opts)
    opts = opts or {}
    local asc = setmetatable({
        handle = object.next_handle(),
        scheduler = opts.scheduler or Scheduler.new(),
        event_bus = opts.event_bus or EventBus.new(),
        time_source = opts.time_source or TimeSource.new(),
        registry = opts.registry or Registry.new(),
        attribute_sets = {},
        granted_abilities = {},
        active_effects = {},
        owned_tags = tag.GameplayTagContainer.new(),
        blocked_tags = tag.GameplayTagContainer.new(),
        cue_manager = cue_mod.GameplayCueManager.new(),
    }, ASC)
    asc.scheduler:register(asc.handle, function(dt) asc:_tick(dt) end, 10)
    return asc, nil
end

---@param raw_dt number
function ASC:_tick(raw_dt)
    local dt = self.time_source:scale_dt(self.handle, raw_dt)
    self.time_source:advance(dt)
    self:_update_effects(dt)
    self:_update_abilities(dt)
    self.event_bus:dispatch()
    self.event_bus:emit("on_post_update", { asc = self, dt = dt })
    self.event_bus:dispatch()
end

---@param raw_dt number
function ASC:update(raw_dt)
    self.scheduler:update(raw_dt)
end

---@param dt number
function ASC:_update_effects(dt)
    local expired = {}
    for handle, active in pairs(self.active_effects) do
        active:update(dt)
        if active:is_expired() then
            table.insert(expired, handle)
        end
    end
    for _, handle in ipairs(expired) do
        self:remove_active_effect(handle)
    end
end

---@param dt number
function ASC:_update_abilities(dt)
    for _, ab in pairs(self.granted_abilities) do
        ab:update(dt)
    end
end

---Add an AttributeSet.
---@param attr_set_class table
---@return cgas.semantics.AttributeSet|nil attr_set
---@return string|nil error
function ASC:add_attribute_set(attr_set_class)
    local set = attr.AttributeSet.new(attr_set_class.name)
    if attr_set_class.on_init then
        attr_set_class.on_init(set)
    end
    self.attribute_sets[attr_set_class.name] = set
    return set, nil
end

---Get an AttributeSet by name.
---@param set_name string
---@return cgas.semantics.AttributeSet|nil
function ASC:get_attribute_set(set_name)
    return self.attribute_sets[set_name]
end

---Get an attribute by path "SetName.AttributeName".
---@param attr_path string
---@return cgas.semantics.Attribute|nil
function ASC:get_attribute(attr_path)
    local set_name, attr_name = attr_path:match("^([^%.]+)%.([^%.]+)$")
    if not set_name then return nil end
    local set = self.attribute_sets[set_name]
    if not set then return nil end
    return set:get(attr_name)
end

---Grant an ability.
---@param ability_class table
---@param source_level integer?
---@return integer|nil ability_handle
---@return string|nil error
function ASC:give_ability(ability_class, source_level)
    local ab = ability_mod.GameplayAbility.new(self, ability_class, source_level)
    self.granted_abilities[ab.handle] = ab
    return ab.handle, nil
end

---Remove an ability.
---@param ability_handle integer
---@return boolean ok
function ASC:remove_ability(ability_handle)
    local ab = self.granted_abilities[ability_handle]
    if not ab then return false end
    if ab.state == "active" then
        ab:end_ability()
    end
    self.granted_abilities[ability_handle] = nil
    return true
end

---Find ability by tag.
---@param t cgas.semantics.GameplayTag
---@return integer|nil ability_handle
function ASC:find_ability_by_tag(t)
    for handle, ab in pairs(self.granted_abilities) do
        if ab.ability_tags:has(t) then
            return handle
        end
    end
    return nil
end

---Try activate ability by input id.
---@param input_id integer|string
---@return boolean ok
function ASC:try_activate_ability_by_input(input_id)
    for _, ab in pairs(self.granted_abilities) do
        if ab.input_id == input_id then
            return self:try_activate_ability(ab.handle)
        end
    end
    return false
end

---Try activate ability by handle.
---@param ability_handle integer
---@return boolean ok
---@return string|nil error
function ASC:try_activate_ability(ability_handle)
    local ab = self.granted_abilities[ability_handle]
    if not ab then return false, "invalid ability handle" end
    return ab:activate()
end

---Apply an effect spec.
---@param spec cgas.semantics.GameplayEffectSpec
---@return integer|nil active_effect_handle
---@return string|nil error
function ASC:apply_effect(spec)
    local effect = spec.effect_class
    if effect.duration_policy == "instant" then
        local active = effect_mod.ActiveGameplayEffect.new({
            effect = effect,
            target_set = self:_resolve_attribute_set(effect),
            source_set = spec.source and self:_source_attribute_set(spec.source, effect),
            level = spec.level or 1,
        })
        active:apply_instant()
        self.event_bus:emit("on_effect_applied", { effect = effect, target = self, source = spec.source })
        self.cue_manager:trigger_effect_cues(effect, "on_apply", { target = self, source = spec.source })
        return active.handle, nil
    end

    local active = effect_mod.ActiveGameplayEffect.new({
        effect = effect,
        target_set = self:_resolve_attribute_set(effect),
        source_set = spec.source and self:_source_attribute_set(spec.source, effect),
        level = spec.level or 1,
    })
    active:on_apply()
    self.active_effects[active.handle] = active
    self.event_bus:emit("on_effect_applied", { effect = effect, target = self, source = spec.source, handle = active.handle })
    self.cue_manager:trigger_effect_cues(effect, "on_apply", { target = self, source = spec.source })
    return active.handle, nil
end

---@private
function ASC:_resolve_attribute_set(effect)
    for _, m in ipairs(effect.modifiers) do
        local set_name = m.attribute_name:match("^([^%.]+)%.([^%.]+)$") and m.attribute_name:match("^([^%.]+)%.") or nil
        if not set_name then
            for name, set in pairs(self.attribute_sets) do
                if set:get(m.attribute_name) then
                    return set
                end
            end
        else
            return self.attribute_sets[set_name]
        end
    end
    return nil
end

---@private
function ASC:_source_attribute_set(source_asc, effect)
    -- Default to same set structure as target; simplified.
    return self:_resolve_attribute_set(effect)
end

---Remove an active effect.
---@param active_effect_handle integer
---@return boolean ok
function ASC:remove_active_effect(active_effect_handle)
    local active = self.active_effects[active_effect_handle]
    if not active then return false end
    self.active_effects[active_effect_handle] = nil
    self.event_bus:emit("on_effect_removed", { effect = active.effect, target = self, handle = active.handle })
    self.cue_manager:trigger_effect_cues(active.effect, "on_remove", { target = self })
    return true
end

---Add a tag.
---@param t cgas.semantics.GameplayTag
function ASC:add_tag(t)
    self.owned_tags:add(t)
    self.event_bus:emit("on_tag_changed", { tag = t, added = true, asc = self })
end

---Remove a tag.
---@param t cgas.semantics.GameplayTag
function ASC:remove_tag(t)
    self.owned_tags:remove(t)
    self.event_bus:emit("on_tag_changed", { tag = t, added = false, asc = self })
end

---Match a tag query.
---@param query cgas.semantics.GameplayTagQuery
---@return boolean matches
function ASC:matches_tag_query(query)
    return query:matches(self.owned_tags)
end

---Destroy the ASC.
function ASC:destroy()
    for handle, _ in pairs(self.granted_abilities) do
        self:remove_ability(handle)
    end
    for handle, _ in pairs(self.active_effects) do
        self:remove_active_effect(handle)
    end
    self.attribute_sets = {}
    self.owned_tags = tag.GameplayTagContainer.new()
    self.scheduler:unregister(self.handle)
    self.event_bus:emit("on_asc_destroyed", { asc = self })
    self.event_bus:dispatch()
end

M.ASC = ASC

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/semantics/asc_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/semantics/asc.lua lua_tests/semantics/asc_spec.lua
git commit -m "feat(semantics): add ability system component

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 11: `cgas.semantics.cue` — GameplayCue Manager

**Files:**
- Create: `lua_lib/cgas/semantics/cue.lua`
- Test: `lua_tests/semantics/cue_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/semantics/cue_spec.lua
require("lua_tests.support.env")
local cue = require("cgas.semantics.cue")
local tag = require("cgas.semantics.tag")

describe("cgas.semantics.cue", function()
    it("registers and triggers cue handlers", function()
        local mgr = cue.GameplayCueManager.new()
        local received = nil
        mgr:register(tag.GameplayTag.new("cue.fire"), function(payload)
            received = payload
        end)
        mgr:trigger(tag.GameplayTag.new("cue.fire"), { target = "x" })
        assert.equal("x", received.target)
    end)

    it("triggers effect cues by tag", function()
        local mgr = cue.GameplayCueManager.new()
        local count = 0
        mgr:register(tag.GameplayTag.new("cue.fire"), function() count = count + 1 end)
        local Effect = { granted_tags = { value = "cue.fire" } }
        local c = tag.GameplayTagContainer.new()
        c:add(tag.GameplayTag.new("cue.fire"))
        Effect.granted_tags = c
        mgr:trigger_effect_cues(Effect, "on_apply", {})
        assert.equal(1, count)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/semantics/cue_spec.lua`
Expected: FAIL with "module 'cgas.semantics.cue' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/semantics/cue.lua
local M = {}

---@class cgas.semantics.GameplayCuePayload
---@field target cgas.semantics.ASC
---@field source cgas.semantics.ASC?
---@field location table?
---@field normal table?
---@field magnitude number?
---@field context table?

---@class cgas.semantics.GameplayCueManager
---@field private _handlers table<string, fun(payload: cgas.semantics.GameplayCuePayload)[]>
local GameplayCueManager = {}
GameplayCueManager.__index = GameplayCueManager

---Create a new cue manager.
---@return cgas.semantics.GameplayCueManager
function GameplayCueManager.new()
    return setmetatable({ _handlers = {} }, GameplayCueManager)
end

---Register a cue handler.
---@param cue_tag cgas.semantics.GameplayTag
---@param handler fun(payload: cgas.semantics.GameplayCuePayload)
function GameplayCueManager:register(cue_tag, handler)
    local list = self._handlers[cue_tag.value]
    if not list then
        list = {}
        self._handlers[cue_tag.value] = list
    end
    table.insert(list, handler)
end

---Trigger a cue.
---@param cue_tag cgas.semantics.GameplayTag
---@param payload cgas.semantics.GameplayCuePayload
function GameplayCueManager:trigger(cue_tag, payload)
    local list = self._handlers[cue_tag.value]
    if list then
        for _, handler in ipairs(list) do
            local ok, err = pcall(handler, payload)
            if not ok then
                print("[cgas.cue] handler error: " .. tostring(err))
            end
        end
    end
end

---Trigger cues associated with an effect's granted tags.
---@param effect cgas.semantics.GameplayEffect
---@param timing "on_apply"|"on_remove"|"on_periodic"
---@param payload cgas.semantics.GameplayCuePayload
function GameplayCueManager:trigger_effect_cues(effect, timing, payload)
    if not effect.granted_tags then return end
    for value, _ in pairs(effect.granted_tags._tags) do
        self:trigger(require("cgas.semantics.tag").GameplayTag.new(value), payload)
    end
end

M.GameplayCueManager = GameplayCueManager

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/semantics/cue_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/semantics/cue.lua lua_tests/semantics/cue_spec.lua
git commit -m "feat(semantics): add gameplay cue manager

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 12: `cgas.semantics.task` — AbilityTask

**Files:**
- Create: `lua_lib/cgas/semantics/task.lua`
- Test: `lua_tests/semantics/task_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/semantics/task_spec.lua
require("lua_tests.support.env")
local task = require("cgas.semantics.task")

describe("cgas.semantics.task", function()
    it("waits for delay", function()
        local fake_ability = { active_tasks = {} }
        local t = task.TaskWaitDelay.new(fake_ability, 1.0)
        local finished = false
        t.on_finished = function() finished = true end
        t:start()
        assert.equal("running", t.state)
        t:update(0.5)
        assert.is_false(finished)
        t:update(0.6)
        assert.is_true(finished)
        assert.equal("finished", t.state)
    end)

    it("cleans up when ability ends", function()
        local fake_ability = { active_tasks = {} }
        local t = task.TaskWaitDelay.new(fake_ability, 1.0)
        t:start()
        assert.is_not_nil(fake_ability.active_tasks[t.handle])
        t:finish(nil)
        assert.is_nil(fake_ability.active_tasks[t.handle])
    end)

    it("emits gameplay event", function()
        local received = nil
        local bus = {
            subscribe = function(_, name, fn) received = { name = name, fn = fn } end,
            unsubscribe = function() received = nil end,
        }
        local fake_ability = { asc = { event_bus = bus }, active_tasks = {} }
        local t = task.TaskWaitGameplayEvent.new(fake_ability, "my_event")
        t:start()
        assert.equal("my_event", received.name)
        received.fn({ value = 42 })
        assert.equal("finished", t.state)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/semantics/task_spec.lua`
Expected: FAIL with "module 'cgas.semantics.task' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/semantics/task.lua
local object = require("cgas.core.object")

local M = {}

---@class cgas.semantics.AbilityTask
---@field handle integer
---@field ability cgas.semantics.GameplayAbility
---@field state "pending"|"running"|"finished"
---@field on_finished fun(result: table)?
local AbilityTask = {}
AbilityTask.__index = AbilityTask

---Create a task.
---@param ability cgas.semantics.GameplayAbility
---@return cgas.semantics.AbilityTask
function AbilityTask.new(ability)
    return setmetatable({
        handle = object.next_handle(),
        ability = ability,
        state = "pending",
        on_finished = nil,
    }, AbilityTask)
end

---Start the task.
function AbilityTask:start()
    self.state = "running"
    self.ability.active_tasks[self.handle] = self
end

---Finish the task.
---@param result table?
function AbilityTask:finish(result)
    if self.state == "finished" then return end
    self.state = "finished"
    self.ability.active_tasks[self.handle] = nil
    if self.on_finished then
        local ok, err = pcall(self.on_finished, result)
        if not ok then
            print("[cgas.task] on_finished error: " .. tostring(err))
        end
    end
end

---Update the task.
---@param dt number
function AbilityTask:update(dt)
    -- override in subclasses
end

---@class cgas.semantics.TaskWaitDelay : cgas.semantics.AbilityTask
---@field delay number
---@field elapsed number
local TaskWaitDelay = setmetatable({}, { __index = AbilityTask })
TaskWaitDelay.__index = TaskWaitDelay

---@param ability cgas.semantics.GameplayAbility
---@param delay number
---@return cgas.semantics.TaskWaitDelay
function TaskWaitDelay.new(ability, delay)
    local t = setmetatable(AbilityTask.new(ability), TaskWaitDelay)
    t.delay = delay
    t.elapsed = 0
    return t
end

function TaskWaitDelay:start()
    AbilityTask.start(self)
end

---@param dt number
function TaskWaitDelay:update(dt)
    if self.state ~= "running" then return end
    self.elapsed = self.elapsed + dt
    if self.elapsed >= self.delay then
        self:finish({ elapsed = self.elapsed })
    end
end

---@class cgas.semantics.TaskWaitInputRelease : cgas.semantics.AbilityTask
local TaskWaitInputRelease = setmetatable({}, { __index = AbilityTask })
TaskWaitInputRelease.__index = TaskWaitInputRelease

---@param ability cgas.semantics.GameplayAbility
---@return cgas.semantics.TaskWaitInputRelease
function TaskWaitInputRelease.new(ability)
    return setmetatable(AbilityTask.new(ability), TaskWaitInputRelease)
end

function TaskWaitInputRelease:start()
    AbilityTask.start(self)
end

---@class cgas.semantics.TaskWaitGameplayEvent : cgas.semantics.AbilityTask
---@field event_name string
---@field private _sub_id integer?
local TaskWaitGameplayEvent = setmetatable({}, { __index = AbilityTask })
TaskWaitGameplayEvent.__index = TaskWaitGameplayEvent

---@param ability cgas.semantics.GameplayAbility
---@param event_name string
---@return cgas.semantics.TaskWaitGameplayEvent
function TaskWaitGameplayEvent.new(ability, event_name)
    local t = setmetatable(AbilityTask.new(ability), TaskWaitGameplayEvent)
    t.event_name = event_name
    return t
end

function TaskWaitGameplayEvent:start()
    AbilityTask.start(self)
    local self_ref = self
    self._sub_id = self.ability.asc.event_bus:subscribe(self.event_name, function(payload)
        self_ref:finish(payload)
    end)
end

function TaskWaitGameplayEvent:finish(result)
    if self._sub_id and self.ability and self.ability.asc then
        self.ability.asc.event_bus:unsubscribe(self._sub_id)
    end
    AbilityTask.finish(self, result)
end

---@class cgas.semantics.TaskWaitAbilityCommit : cgas.semantics.AbilityTask
local TaskWaitAbilityCommit = setmetatable({}, { __index = AbilityTask })
TaskWaitAbilityCommit.__index = TaskWaitAbilityCommit

---@param ability cgas.semantics.GameplayAbility
---@return cgas.semantics.TaskWaitAbilityCommit
function TaskWaitAbilityCommit.new(ability)
    return setmetatable(AbilityTask.new(ability), TaskWaitAbilityCommit)
end

function TaskWaitAbilityCommit:start()
    AbilityTask.start(self)
end

M.AbilityTask = AbilityTask
M.TaskWaitDelay = TaskWaitDelay
M.TaskWaitInputRelease = TaskWaitInputRelease
M.TaskWaitGameplayEvent = TaskWaitGameplayEvent
M.TaskWaitAbilityCommit = TaskWaitAbilityCommit

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/semantics/task_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/semantics/task.lua lua_tests/semantics/task_spec.lua
git commit -m "feat(semantics): add ability task base and common tasks

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Phase 4: Adapters and Network Stubs

### Task 13: `cgas.adapters.manual` — Manual Update Adapter

**Files:**
- Create: `lua_lib/cgas/adapters/manual.lua`
- Test: `lua_tests/adapters/manual_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/adapters/manual_spec.lua
require("lua_tests.support.env")
local manual = require("cgas.adapters.manual")
local asc = require("cgas.semantics.asc")

describe("cgas.adapters.manual", function()
    it("creates a runner that updates ASC", function()
        local a = asc.ASC.new({})
        local runner = manual.new(a)
        assert.is_function(runner.update)
        runner.update(0.1)
        assert.is_true(a.time_source:now() >= 0)
    end)

    it("destroys cleanly", function()
        local a = asc.ASC.new({})
        local runner = manual.new(a)
        runner.destroy()
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/adapters/manual_spec.lua`
Expected: FAIL with "module 'cgas.adapters.manual' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/adapters/manual.lua
local M = {}

---@class cgas.adapters.ManualRunner
---@field asc cgas.semantics.ASC
local ManualRunner = {}
ManualRunner.__index = ManualRunner

---Create a manual update adapter for an ASC.
---@param asc cgas.semantics.ASC
---@return cgas.adapters.ManualRunner
function M.new(asc)
    return setmetatable({ asc = asc }, ManualRunner)
end

---Drive one frame with raw dt.
---@param dt number
function ManualRunner:update(dt)
    self.asc:update(dt)
end

---Destroy the runner and the ASC.
function ManualRunner:destroy()
    self.asc:destroy()
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/adapters/manual_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_lib/cgas/adapters/manual.lua lua_tests/adapters/manual_spec.lua
git commit -m "feat(adapters): add manual update adapter

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 14: `cgas.adapters.love2d` and `cgas.net.*` — Stubs

**Files:**
- Create: `lua_lib/cgas/adapters/love2d.lua`
- Create: `lua_lib/cgas/net/context.lua`
- Create: `lua_lib/cgas/net/prediction.lua`
- Create: `lua_lib/cgas/net/event.lua`

- [ ] **Step 1: Create stubs**

```lua
-- lua_lib/cgas/adapters/love2d.lua
local M = {}

---@param asc cgas.semantics.ASC
---@return fun(dt: number)
function M.update(asc)
    return function(dt)
        asc:update(dt)
    end
end

return M
```

```lua
-- lua_lib/cgas/net/context.lua
local M = {}

---@class cgas.net.Context
---@field role "authority"|"simulated_proxy"|"autonomous_proxy"
local Context = {}
Context.__index = Context

---Create a default authority context.
---@return cgas.net.Context
function M.new()
    return setmetatable({ role = "authority" }, Context)
end

return M
```

```lua
-- lua_lib/cgas/net/prediction.lua
local M = {}

---@class cgas.net.PredictionKey
---@field id integer
local PredictionKey = {}
PredictionKey.__index = PredictionKey

---Create a prediction key.
---@param id integer
---@return cgas.net.PredictionKey
function M.new(id)
    return setmetatable({ id = id }, PredictionKey)
end

return M
```

```lua
-- lua_lib/cgas/net/event.lua
local M = {}

---@class cgas.net.GameplayEvent
---@field event_name string
---@field payload table
---@field prediction_key cgas.net.PredictionKey?
local GameplayEvent = {}
GameplayEvent.__index = GameplayEvent

---Create a network gameplay event.
---@param event_name string
---@param payload table
---@return cgas.net.GameplayEvent
function M.new(event_name, payload)
    return setmetatable({
        event_name = event_name,
        payload = payload or {},
        prediction_key = nil,
    }, GameplayEvent)
end

return M
```

- [ ] **Step 2: Verify loadable**

Run:
```bash
./lua -e "require('cgas.adapters.love2d'); require('cgas.net.context'); require('cgas.net.prediction'); require('cgas.net.event'); print('ok')"
```
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add lua_lib/cgas/adapters/love2d.lua lua_lib/cgas/net/context.lua lua_lib/cgas/net/prediction.lua lua_lib/cgas/net/event.lua
git commit -m "feat(adapters, net): add love2d adapter and network placeholders

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Phase 5: Library Entry and Integration

### Task 15: `cgas.init` — Library Entry

**Files:**
- Create: `lua_lib/cgas/init.lua`
- Modify: `cgas-0.1.0-1.rockspec`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/cgas_init_spec.lua
require("lua_tests.support.env")
local cgas = require("cgas")

describe("cgas library entry", function()
    it("exports core modules", function()
        assert.is_function(cgas.ASC.new)
        assert.is_function(cgas.GameplayAbility.new)
        assert.is_function(cgas.GameplayEffect.new)
    end)

    it("creates ASC via factory", function()
        local a = cgas.create_asc()
        assert.is_not_nil(a)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/cgas_init_spec.lua`
Expected: FAIL with "module 'cgas' not found"

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua_lib/cgas/init.lua
local M = {}

M.object = require("cgas.core.object")
M.EventBus = require("cgas.core.event")
M.Scheduler = require("cgas.core.scheduler")
M.TimeSource = require("cgas.core.timer")
M.Registry = require("cgas.core.registry")

local asc_mod = require("cgas.semantics.asc")
M.ASC = asc_mod.ASC

local ability_mod = require("cgas.semantics.ability")
M.GameplayAbility = ability_mod.GameplayAbility

local attr_mod = require("cgas.semantics.attribute")
M.Attribute = attr_mod.Attribute
M.AttributeSet = attr_mod.AttributeSet

local effect_mod = require("cgas.semantics.effect")
M.GameplayEffect = effect_mod.GameplayEffect
M.ActiveGameplayEffect = effect_mod.ActiveGameplayEffect

local tag_mod = require("cgas.semantics.tag")
M.GameplayTag = tag_mod.GameplayTag
M.GameplayTagContainer = tag_mod.GameplayTagContainer
M.GameplayTagQuery = tag_mod.GameplayTagQuery
M.GameplayTagRegistry = tag_mod.GameplayTagRegistry

local cue_mod = require("cgas.semantics.cue")
M.GameplayCueManager = cue_mod.GameplayCueManager

local task_mod = require("cgas.semantics.task")
M.AbilityTask = task_mod.AbilityTask
M.TaskWaitDelay = task_mod.TaskWaitDelay
M.TaskWaitInputRelease = task_mod.TaskWaitInputRelease
M.TaskWaitGameplayEvent = task_mod.TaskWaitGameplayEvent
M.TaskWaitAbilityCommit = task_mod.TaskWaitAbilityCommit

M.manual_adapter = require("cgas.adapters.manual")
M.love2d_adapter = require("cgas.adapters.love2d")

M.net_context = require("cgas.net.context")
M.net_prediction = require("cgas.net.prediction")
M.net_event = require("cgas.net.event")

---Factory helper to create an ASC.
---@param opts table?
---@return cgas.semantics.ASC
function M.create_asc(opts)
    return M.ASC.new(opts or {})
end

return M
```

- [ ] **Step 4: Update rockspec**

Add module entries under `build.modules`:

```lua
build = {
    type = "builtin",
    modules = {
        ["cgas"] = "lua_lib/cgas/init.lua",
        ["cgas.core.object"] = "lua_lib/cgas/core/object.lua",
        ["cgas.core.event"] = "lua_lib/cgas/core/event.lua",
        ["cgas.core.scheduler"] = "lua_lib/cgas/core/scheduler.lua",
        ["cgas.core.timer"] = "lua_lib/cgas/core/timer.lua",
        ["cgas.core.registry"] = "lua_lib/cgas/core/registry.lua",
        ["cgas.semantics.asc"] = "lua_lib/cgas/semantics/asc.lua",
        ["cgas.semantics.ability"] = "lua_lib/cgas/semantics/ability.lua",
        ["cgas.semantics.attribute"] = "lua_lib/cgas/semantics/attribute.lua",
        ["cgas.semantics.effect"] = "lua_lib/cgas/semantics/effect.lua",
        ["cgas.semantics.tag"] = "lua_lib/cgas/semantics/tag.lua",
        ["cgas.semantics.cue"] = "lua_lib/cgas/semantics/cue.lua",
        ["cgas.semantics.task"] = "lua_lib/cgas/semantics/task.lua",
        ["cgas.adapters.manual"] = "lua_lib/cgas/adapters/manual.lua",
        ["cgas.adapters.love2d"] = "lua_lib/cgas/adapters/love2d.lua",
        ["cgas.net.context"] = "lua_lib/cgas/net/context.lua",
        ["cgas.net.prediction"] = "lua_lib/cgas/net/prediction.lua",
        ["cgas.net.event"] = "lua_lib/cgas/net/event.lua",
    },
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `./busted lua_tests/cgas_init_spec.lua`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lua_lib/cgas/init.lua lua_tests/cgas_init_spec.lua cgas-0.1.0-1.rockspec
git commit -m "feat(cgas): add library entry and factory helper

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 16: `lua_tests/support/env.lua` — Test Environment

**Files:**
- Create: `lua_lib/cgas/init.lua`
- Create: `lua_tests/support/env.lua`

- [ ] **Step 1: Write env.lua**

```lua
-- lua_tests/support/env.lua
-- Test environment bootstrap: adjust package.path to find lua_lib modules.

local script_path = debug.getinfo(1, "S").source:sub(2)
local test_root = script_path:match("^(.*)/lua_tests/support/") or "."
local lib_root = test_root .. "/lua_lib"

package.path = lib_root .. "/?.lua;" .. lib_root .. "/?/init.lua;" .. package.path
```

- [ ] **Step 2: Verify smoke test passes**

Run: `./busted lua_tests/smoke_spec.lua`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lua_tests/support/env.lua
git commit -m "test: add test environment bootstrap

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 17: Fireball Integration Test

**Files:**
- Create: `lua_tests/integration/fireball_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- lua_tests/integration/fireball_spec.lua
require("lua_tests.support.env")
local cgas = require("cgas")

describe("Fireball combo", function()
    it("casts fireball with mana cost, cooldown, and damage", function()
        -- Player ASC
        local player = cgas.create_asc()

        local HealthSet = { name = "HealthSet" }
        function HealthSet:on_init(set)
            set:register_attribute("Health", 100, { max_value = 100 })
        end
        player:add_attribute_set(HealthSet)

        local ManaSet = { name = "ManaSet" }
        function ManaSet:on_init(set)
            set:register_attribute("Mana", 100, { max_value = 100 })
        end
        player:add_attribute_set(ManaSet)

        local ManaCost = cgas.GameplayEffect.new({
            name = "ManaCost",
            duration_policy = "instant",
            modifiers = { { attribute_name = "ManaSet.Mana", op = "add", magnitude = -20 } },
        })

        local Cooldown = cgas.GameplayEffect.new({
            name = "Cooldown",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 2.0 },
            granted_tags = (function()
                local c = cgas.GameplayTagContainer.new()
                c:add(cgas.GameplayTag.new("ability.cooldown.fireball"))
                return c
            end)(),
        })

        local Fireball = {
            name = "Fireball",
            cost_effect_class = ManaCost,
            cooldown_effect_class = Cooldown,
            activation_blocked_tags = function()
                local q = cgas.GameplayTagQuery.new()
                q.none_tags:add(cgas.GameplayTag.new("ability.cooldown.fireball"))
                return q
            end,
            ActivateAbility = function(self)
                local task = cgas.TaskWaitDelay.new(self, 1.5)
                task.on_finished = function()
                    -- Apply damage to target
                    local Damage = cgas.GameplayEffect.new({
                        name = "FireballDamage",
                        duration_policy = "instant",
                        modifiers = { { attribute_name = "HealthSet.Health", op = "add", magnitude = -30 } },
                    })
                    target:apply_effect({ effect_class = Damage, source = self.asc })
                    self:end_ability()
                end
                task:start()
            end,
        }

        local ability_handle = player:give_ability(Fireball)

        -- Target ASC
        local target = cgas.create_asc()
        target:add_attribute_set(HealthSet)

        -- Cast
        assert.is_true(player:try_activate_ability(ability_handle))
        assert.equal(80, player:get_attribute("ManaSet.Mana").current_value)

        -- Wait for cast
        player:update(1.6)
        assert.equal(70, target:get_attribute("HealthSet.Health").current_value)

        -- Try recast during cooldown
        assert.is_false(player:try_activate_ability(ability_handle))

        -- Wait for cooldown
        player:update(2.0)
        assert.is_true(player:try_activate_ability(ability_handle))
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./busted lua_tests/integration/fireball_spec.lua`
Expected: FAIL (various missing wiring)

- [ ] **Step 3: Fix wiring in ASC and ability until test passes**

Expected adjustments:
- In `ASC:_resolve_attribute_set`, support `"SetName.AttributeName"` modifier attribute names.
- Ensure `Ability:commit` applies cost/cooldown before `ActivateAbility` per spec? Actually spec says `commit` is called after `can_activate` and before/after `ActivateAbility` depending on design. Current design: `activate` calls `can_activate`, goes active, then `ActivateAbility`. `commit` applies cost/cooldown and is called by subclass if desired. For the test, call `self:commit()` at start of `ActivateAbility` or wire `ASC:try_activate_ability` to call `ab:commit()` after activation. Update `try_activate_ability` to:
  ```lua
  function ASC:try_activate_ability(ability_handle)
      local ab = self.granted_abilities[ability_handle]
      if not ab then return false, "invalid ability handle" end
      if not ab:activate() then return false, "activation failed" end
      ab:commit()
      return true
  end
  ```
- Ensure `ActiveGameplayEffect:_apply_modifiers` handles `"SetName.AttributeName"` attribute names.

- [ ] **Step 4: Run test to verify it passes**

Run: `./busted lua_tests/integration/fireball_spec.lua`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua_tests/integration/fireball_spec.lua lua_lib/cgas/semantics/asc.lua lua_lib/cgas/semantics/effect.lua
git commit -m "test(integration): add fireball combo test and fix asc/effect wiring

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Phase 6: Static Diagnostics and Final Verification

### Task 18: Run All Tests

- [ ] **Step 1: Run full test suite**

Run: `./busted lua_tests/`
Expected: ALL PASS

- [ ] **Step 2: Commit any final fixes**

```bash
git add -A
git commit -m "fix: address test suite issues

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 19: Run Lua Language Server Static Check

- [ ] **Step 1: Run diagnostics**

Run: `lua-language-server --check . --configpath .luarc.json`
Expected: No errors/warnings

- [ ] **Step 2: Fix any diagnostic issues**

Common fixes:
- Add missing `@param` or `@return` annotations.
- Replace undefined globals with `local`.
- Add `---@diagnostic disable-next-line` only when justified.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "style: resolve static diagnostic warnings

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review

### Spec coverage

| Spec section | Plan task |
|--------------|-----------|
| 4.1 object | Task 1 |
| 4.2 event | Task 2 |
| 4.3 scheduler | Task 3 |
| 4.4 timer | Task 4 |
| 4.5 registry | Task 5 |
| 5 ASC | Task 10 |
| 6 Ability | Task 9 |
| 7 Attribute | Task 7 |
| 8 Effect | Task 8 |
| 9 Tag | Task 6 |
| 10 Cue | Task 11 |
| 11 Task | Task 12 |
| 12 Lifecycle/Tick | Tasks 3, 10, 12 |
| 13 Replication/Prediction | Task 14 |
| 15 Tests | All tasks |

**Gaps:**
- `set_base` on Attribute is tested but `on_base_changed` is not covered by a dedicated unit test; covered by Task 7.
- `block_abilities_with_tag` enforcement in `ASC:try_activate_ability` is not explicitly tested; add to Task 9 or Task 10 tests if time permits.
- Network placeholders are stubs only; acceptable per spec section 13.

### Placeholder scan

No `TBD`, `TODO`, or vague instructions. Each step includes concrete code or exact commands.

### Type consistency

- `GameplayTagContainer` uses `_tags` consistently.
- `ASC` field names match spec: `granted_abilities`, `active_effects`, `owned_tags`, `blocked_tags`.
- `ActiveGameplayEffect` fields match spec.
- `GameplayAbility` state names match spec: `inactive`, `committing`, `active`, `ending`.

One inconsistency to fix during execution: modifier attribute names in `ActiveGameplayEffect:_apply_modifiers` and `ASC:_resolve_attribute_set` must accept `"SetName.AttributeName"` as well as bare `"AttributeName"`.
