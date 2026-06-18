--- MiniGas V2 模块入口
--- 快照式、被动-only、标签驱动的轻量 GAS 核心
local enum = require("mini_gas.enum")
local asc = require("mini_gas.asc")

---@type mini_gas.ASC
local M = {
    -- 枚举
    EModifierOp = enum.EModifierOp,
    EAbilityActivationPolicy = enum.EAbilityActivationPolicy,
    EEffectTarget = enum.EEffectTarget,

    -- 求值入口与标签匹配工具
    match_tag = asc.match_tag,
    entity_match_tag = asc.entity_match_tag,
    match_tags = asc.match_tags,
    evaluate = asc.evaluate,
}

return M
