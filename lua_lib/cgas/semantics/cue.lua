local tag = require("cgas.semantics.tag")

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
    local list = self._handlers[cue_tag.tag]
    if not list then
        list = {}
        self._handlers[cue_tag.tag] = list
    end
    table.insert(list, handler)
end

---Trigger a cue.
---@param cue_tag cgas.semantics.GameplayTag
---@param payload cgas.semantics.GameplayCuePayload
function GameplayCueManager:trigger(cue_tag, payload)
    local list = self._handlers[cue_tag.tag]
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
---@param _timing "on_apply"|"on_remove"|"on_periodic"
---@param payload cgas.semantics.GameplayCuePayload
---@diagnostic disable-next-line: unused-local
function GameplayCueManager:trigger_effect_cues(effect, _timing, payload)
    if not effect.granted_tags then return end
    for tag_str, _ in pairs(effect.granted_tags.tags) do
        self:trigger(tag.GameplayTag.new(tag_str), payload)
    end
end

M.GameplayCueManager = GameplayCueManager

return M
