--- MiniGas V2 模块入口
--- 快照式、被动-only、标签驱动的轻量 GAS 核心
local enum = require("mini_gas.enum")
local asc = require("mini_gas.asc")

local M = {}

-- 枚举
M.EModifierOp = enum.EModifierOp
M.EAbilityActivationPolicy = enum.EAbilityActivationPolicy
M.EEffectTarget = enum.EEffectTarget

-- 求值入口与标签匹配工具
M.match_tag = asc.match_tag
M.entity_match_tag = asc.entity_match_tag
M.match_tags = asc.match_tags
M.evaluate = asc.evaluate

return M
