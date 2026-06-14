--- GameplayAbility 与 AbilitySpec
local M = {}

---@class mini_gas.GameplayAbilityDef
---@field id mini_gas.AbilityId
---@field alias string|integer|nil 策划配置原始 ID；nil 时使用 id 的枚举值
---@field activation_policy mini_gas.EAbilityActivationPolicy
---@field cooldown number|mini_gas.GrowthCurve|nil
---@field cost table<mini_gas.AttributeId, number|mini_gas.GrowthCurve>|nil
---@field require_tags mini_gas.TagId[]|nil
---@field forbid_tags mini_gas.TagId[]|nil
---@field grant_tags mini_gas.TagId[]|nil
---@field activation_event mini_gas.GameplayEventId|nil  Reactive 时使用
---@field effects mini_gas.EffectDef[]|nil 激活时自动应用的效果
---@field source any
---@field can_activate? fun(state: mini_gas.EntityState, payload: table|nil): boolean|nil 业务自定义回调

---@class mini_gas.GameplayAbility
---@field spec mini_gas.GameplayAbilityDef
---@field level number
---@field stack number
---@field is_active boolean
---@field cooldown_remaining number
local GameplayAbility = {}
GameplayAbility.__index = GameplayAbility

---@param spec mini_gas.GameplayAbilityDef
---@param level number
---@param stack number|nil
---@return mini_gas.GameplayAbility
function GameplayAbility.new(spec, level, stack)
    return setmetatable({
        spec = spec,
        level = level or 1,
        stack = stack or 1,
        is_active = false,
        cooldown_remaining = 0,
    }, GameplayAbility)
end

---解析数值（可能是常量或成长曲线）
---@param value number|mini_gas.GrowthCurve
---@param level number
---@return number
local function resolve_value(value, level)
    if type(value) == "number" then
        return value
    end
    if type(value) == "table" and value.value_at then
        return value:value_at(level)
    end
    return 0
end

---检查当前是否可以激活
---@param state mini_gas.EntityState
---@return boolean
function GameplayAbility:can_activate(state)
    if self.is_active then
        return false
    end
    if self.cooldown_remaining > 0 then
        return false
    end

    local container = state.tags
    local req = self.spec.require_tags or {}
    local forbid = self.spec.forbid_tags or {}
    if not container:has_all(req) or container:has_any(forbid) then
        return false
    end

    -- 消耗检查
    if self.spec.cost then
        for attr_id, cost_value in pairs(self.spec.cost) do
            local attr = state.attributes[attr_id]
            if not attr then
                return false
            end
            local need = resolve_value(cost_value, self.level)
            if attr:get_current() < need then
                return false
            end
        end
    end

    if self.spec.can_activate then
        local ok = self.spec.can_activate(state, nil)
        if ok == false then
            return false
        end
    end

    return true
end

---激活技能
---@param _state mini_gas.EntityState
---@param _payload table|nil
function GameplayAbility:activate(_state, _payload)
    _ = _state
    _ = _payload
    self.is_active = true
end

---结束技能
---@param _state mini_gas.EntityState
function GameplayAbility:end_ability(_state)
    _ = _state
    self.is_active = false
    self.cooldown_remaining = resolve_value(self.spec.cooldown, self.level)
end

M.GameplayAbility = GameplayAbility
M.resolve_value = resolve_value

return M
