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
