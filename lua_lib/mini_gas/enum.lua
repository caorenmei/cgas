--- 所有枚举常量定义（运行时值）
--- 类型定义同步标注于本文件

local M = {}

---@enum mini_gas.EModifierOp
M.EModifierOp = {
    Add = 1,      -- 加法，聚合为 sum
    Multiply = 2, -- 乘法，聚合为 product
    Override = 3, -- 覆盖，按优先级取最终值
    Compound = 4, -- 复合公式，由自定义函数计算
}

---@enum mini_gas.EDurationPolicy
M.EDurationPolicy = {
    Instant = 1,     -- 瞬时生效，立即修改 Current 后消失
    Infinite = 2,    -- 永久生效，直到被显式移除
    HasDuration = 3, -- 持续一段时间后自动消失
}

---@enum mini_gas.EStackingPolicy
M.EStackingPolicy = {
    None = 1,    -- 重复应用时替换旧效果
    Add = 2,     -- Stack 数相加
    Replace = 3, -- 新效果替换旧效果
    Refresh = 4, -- 刷新持续时间与 Stack
}

---@enum mini_gas.EAbilityActivationPolicy
M.EAbilityActivationPolicy = {
    Passive = 1,  -- 授予后自动持续生效
    Active = 2,   -- 需要业务方显式调用 TryActivate
    Reactive = 3, -- 响应特定 GameplayEvent 自动尝试激活
}

---@enum mini_gas.EAttribute
M.EAttribute = {
    None = "attr.none", -- 占位；业务 Attribute ID 由策划配置
}

---@enum mini_gas.ETag
M.ETag = {
    None = "tag.none", -- 占位；业务 Tag 由策划配置
}

---@enum mini_gas.EAbilityId
M.EAbilityId = {
    None = "ability.none", -- 占位；业务 Ability ID 由策划配置
}

---@enum mini_gas.EEffectId
M.EEffectId = {
    None = "effect.none", -- 占位；业务 Effect ID 由策划配置
}

---@enum mini_gas.EGameplayEvent
M.EGameplayEvent = {
    AbilityActivated = "event.ability.activated",
    AbilityEnded = "event.ability.ended",
    EffectApplied = "event.effect.applied",
    EffectRemoved = "event.effect.removed",
    AttributeChanged = "event.attribute.changed",
    TagAdded = "event.tag.added",
    TagRemoved = "event.tag.removed",
}

return M
