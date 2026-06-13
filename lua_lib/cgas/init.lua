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
