--- GameplayEffect 系统 — 效果定义与运行时激活管理

local M = {}
local object = require("cgas.core.object")

---@class GameplayEffect
---@field name string
---@field duration_policy "instant" | "duration" | "infinite"
---@field duration table?  -- { type = "scalable_float", value = number }
---@field period number?
---@field periodic_instant boolean?
---@field modifiers table[]
---@field granted_tags table?
---@field removed_tags table?
---@field queries table?
---@field stacking_policy string?
---@field stack_limit number?
local GameplayEffect = {}
GameplayEffect.__index = GameplayEffect

--- 创建 GameplayEffect 定义
---@param spec table
---@return GameplayEffect
function GameplayEffect.new(spec)
    local self = setmetatable({}, GameplayEffect)
    self.name = spec.name or "UnnamedEffect"
    self.duration_policy = spec.duration_policy or "instant"
    self.duration = spec.duration
    self.period = spec.period or 0
    self.periodic_instant = spec.periodic_instant or false
    self.modifiers = spec.modifiers or {}
    self.granted_tags = spec.granted_tags
    self.removed_tags = spec.removed_tags
    self.queries = spec.queries
    self.stacking_policy = spec.stacking_policy
    self.stack_limit = spec.stack_limit or 1
    self._stack_count = 0
    return self
end

---@class ActiveGameplayEffect
---@field handle number
---@field effect GameplayEffect
---@field target_set table?
---@field source_set table?
---@field level number
---@field start_time number
---@field duration number
---@field period_timer number
---@field is_active boolean
local ActiveGameplayEffect = {}

function ActiveGameplayEffect.__index(t, k)
    if k == "stack_count" then
        return t.effect._stack_count
    end
    return ActiveGameplayEffect[k]
end

function ActiveGameplayEffect.__newindex(t, k, v)
    if k == "stack_count" then
        t.effect._stack_count = v
    else
        rawset(t, k, v)
    end
end

--- 创建 ActiveGameplayEffect 运行时实例
---@param opts table
---@return ActiveGameplayEffect
function ActiveGameplayEffect.new(opts)
    local self = setmetatable({}, ActiveGameplayEffect)
    self.handle = object.next_handle()
    self.effect = opts.effect
    self.target_set = opts.target_set
    self.source_set = opts.source_set
    self.level = opts.level or 1
    self.start_time = 0
    self.duration = 0
    self.period_timer = 0
    self.is_active = false
    return self
end

--- 应用即时效果（不进入激活列表）
function ActiveGameplayEffect:apply_instant()
    if self.effect.duration_policy ~= "instant" then
        return
    end
    self:_apply_modifiers()
end

--- 进入激活状态并应用效果
function ActiveGameplayEffect:on_apply()
    self.is_active = true
    self.start_time = 0
    self.period_timer = 0

    if self.effect.duration and self.effect.duration.type == "scalable_float" then
        self.duration = self.effect.duration.value
    else
        self.duration = 0
    end

    if self.effect.stacking_policy then
        self.stack_count = self.stack_count + 1
    end

    if self.effect.duration_policy == "duration" or self.effect.duration_policy == "infinite" then
        -- 对于 periodic_instant 效果，不在 on_apply 中应用，由周期触发处理
        if not self.effect.periodic_instant then
            self:_apply_modifiers()
        end
    elseif self.effect.duration_policy == "instant" then
        self:_apply_modifiers()
    end
end

--- 更新效果状态（dt 为时间增量）
---@param dt number
function ActiveGameplayEffect:update(dt)
    if not self.is_active then
        return
    end

    self.start_time = self.start_time + dt

    -- 处理周期性触发
    if self.effect.period and self.effect.period > 0 then
        self.period_timer = self.period_timer + dt
        
        -- 对于 periodic_instant，使用 ceil(dt/period) 计算触发次数
        if self.effect.periodic_instant then
            local times = math.ceil(dt / self.effect.period)
            for _ = 1, times do
                self:_apply_modifiers()
            end
            self.period_timer = self.period_timer + dt
            while self.period_timer >= self.effect.period do
                self.period_timer = self.period_timer - self.effect.period
            end
            return
        end

        while self.period_timer >= self.effect.period do
            self.period_timer = self.period_timer - self.effect.period
            if self.effect.periodic_instant then
                self:_apply_modifiers()
            end
        end
    end
end

--- 检查效果是否已过期
---@return boolean
function ActiveGameplayEffect:is_expired()
    if self.effect.duration_policy == "instant" then
        return true
    end
    if self.effect.duration_policy == "infinite" then
        return false
    end
    return self.start_time >= self.duration
end

--- 检查堆叠是否达到上限
---@return boolean
function ActiveGameplayEffect:is_stack_at_limit()
    local limit = self.effect.stack_limit or 1
    return self.stack_count >= limit
end

--- 内部：应用修饰器到目标属性集
function ActiveGameplayEffect:_apply_modifiers()
    if not self.target_set then
        return
    end
    for _, mod in ipairs(self.effect.modifiers) do
        local attribute = self.target_set:get(mod.attribute_name)
        if attribute then
            if mod.op == "add" then
                attribute.current_value = attribute.current_value + mod.magnitude
            elseif mod.op == "multiply" then
                attribute.current_value = attribute.current_value * mod.magnitude
            elseif mod.op == "divide" then
                attribute.current_value = attribute.current_value / mod.magnitude
            elseif mod.op == "override" then
                attribute.current_value = mod.magnitude
            end
        end
    end
end

M.GameplayEffect = GameplayEffect
M.ActiveGameplayEffect = ActiveGameplayEffect

return M
