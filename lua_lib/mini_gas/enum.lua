--- MiniGas V2 枚举定义
--- 仅保留快照求值所需的最小枚举集合

local M = {}

--- 修饰器操作类型
---@enum mini_gas.EModifierOp
M.EModifierOp = {
    Add = 1,      -- 加法：将多个 Add 修改量累加
    Multiply = 2, -- 乘法：将多个 Multiply 修改量连乘
    Override = 3, -- 覆盖：同一属性的多个 Override 按生效顺序取最后一个值
}

--- 能力激活策略，V2 仅支持被动
---@enum mini_gas.EAbilityActivationPolicy
M.EAbilityActivationPolicy = {
    Passive = 1, -- 被动：满足条件时自动激活
}

--- 效果目标范围
---@enum mini_gas.EEffectTarget
M.EEffectTarget = {
    Self = 1,  -- 仅对能力所属实体自身生效
    Other = 2, -- 对世界中的其他实体生效
    All = 3,   -- 对世界中的所有实体生效，包含能力所属实体自身
}

return M
