--- 智取威虎山-献图 文本游戏 demo
--- 基于 mini_gas 能力系统驱动
local mini_gas = require("mini_gas")
local ability_mod = require("mini_gas.ability")
local EntityState = mini_gas.EntityState
local MiniASC = mini_gas.MiniASC
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy

local Defs = mini_gas.Defs

local M = {}

---@type mini_gas.Defs
local defs = Defs.new()

---@class mini_gas.demo.weihu_shan.GameState : mini_gas.EntityState
---@field _round number
---@field _game_over boolean
---@field _win boolean

---@enum mini_gas.demo.weihu_shan.EAttribute
M.EAttribute = {
    Credibility = "attr.credibility",
    Suspicion = "attr.suspicion",
    Courage = "attr.courage",
    Eloquence = "attr.eloquence",
}

---@enum mini_gas.demo.weihu_shan.ETag
M.ETag = {
    HasSecretMap = "item.secret_map",
    UnderInterrogation = "status.interrogation",
    Trusted = "status.trusted",
    Suspicious = "status.suspicious",
}

---@enum mini_gas.demo.weihu_shan.EAbilityId
M.EAbilityId = {
    AnswerLingo = "ability.answer_lingo",
    BragBackground = "ability.brag_background",
    PledgeLoyalty = "ability.pledge_loyalty",
    KeepCalm = "ability.keep_calm",
    ShowMap = "ability.show_map",
}

---@enum mini_gas.demo.weihu_shan.EEffectId
M.EEffectId = {
    LingoSuccess = "effect.lingo_success",
    LingoFail = "effect.lingo_fail",
    BackgroundShock = "effect.background_shock",
    LoyaltyPledge = "effect.loyalty_pledge",
    CalmDown = "effect.calm_down",
    MapShock = "effect.map_shock",
}

-- 效果定义（Instant，直接修改属性 Current）
local effect_defs = {
    [M.EEffectId.LingoSuccess] = {
        id = M.EEffectId.LingoSuccess,
        duration_policy = EDurationPolicy.Instant,
        modifiers = {
            { attribute = M.EAttribute.Credibility, op = EModifierOp.Add, value = 20 },
        },
    },
    [M.EEffectId.LingoFail] = {
        id = M.EEffectId.LingoFail,
        duration_policy = EDurationPolicy.Instant,
        modifiers = {
            { attribute = M.EAttribute.Suspicion, op = EModifierOp.Add, value = 20 },
        },
    },
    [M.EEffectId.BackgroundShock] = {
        id = M.EEffectId.BackgroundShock,
        duration_policy = EDurationPolicy.Instant,
        modifiers = {
            { attribute = M.EAttribute.Credibility, op = EModifierOp.Add, value = 30 },
        },
    },
    [M.EEffectId.LoyaltyPledge] = {
        id = M.EEffectId.LoyaltyPledge,
        duration_policy = EDurationPolicy.Instant,
        modifiers = {
            { attribute = M.EAttribute.Credibility, op = EModifierOp.Add, value = 10 },
        },
    },
    [M.EEffectId.CalmDown] = {
        id = M.EEffectId.CalmDown,
        duration_policy = EDurationPolicy.Instant,
        modifiers = {
            { attribute = M.EAttribute.Suspicion, op = EModifierOp.Add, value = -15 },
        },
    },
    [M.EEffectId.MapShock] = {
        id = M.EEffectId.MapShock,
        duration_policy = EDurationPolicy.Instant,
        modifiers = {
            { attribute = M.EAttribute.Credibility, op = EModifierOp.Add, value = 50 },
        },
    },
}

-- 技能定义
local ability_defs = {
    [M.EAbilityId.AnswerLingo] = {
        id = M.EAbilityId.AnswerLingo,
        activation_policy = EAbilityActivationPolicy.Active,
        require_tags = { M.ETag.UnderInterrogation },
        effects = {}, -- 分支效果由 act 根据 choice 手动应用
    },
    [M.EAbilityId.BragBackground] = {
        id = M.EAbilityId.BragBackground,
        activation_policy = EAbilityActivationPolicy.Active,
        require_tags = { M.ETag.UnderInterrogation },
        effects = { effect_defs[M.EEffectId.BackgroundShock] },
    },
    [M.EAbilityId.PledgeLoyalty] = {
        id = M.EAbilityId.PledgeLoyalty,
        activation_policy = EAbilityActivationPolicy.Active,
        require_tags = { M.ETag.UnderInterrogation },
        effects = { effect_defs[M.EEffectId.LoyaltyPledge] },
    },
    [M.EAbilityId.KeepCalm] = {
        id = M.EAbilityId.KeepCalm,
        activation_policy = EAbilityActivationPolicy.Active,
        require_tags = { M.ETag.UnderInterrogation },
        effects = { effect_defs[M.EEffectId.CalmDown] },
    },
    [M.EAbilityId.ShowMap] = {
        id = M.EAbilityId.ShowMap,
        activation_policy = EAbilityActivationPolicy.Active,
        require_tags = { M.ETag.UnderInterrogation, M.ETag.HasSecretMap },
        effects = { effect_defs[M.EEffectId.MapShock] },
    },
}

---创建新游戏状态
---@return mini_gas.demo.weihu_shan.GameState
function M.new_game()
    defs = Defs.new()
    local state = EntityState.new()
    ---@cast state mini_gas.demo.weihu_shan.GameState

    MiniASC.register_attributes(state, defs, {
        { name = M.EAttribute.Credibility, base = 0, min = 0 },
        { name = M.EAttribute.Suspicion, base = 0, min = 0 },
        { name = M.EAttribute.Courage, base = 50, min = 0, max = 100 },
        { name = M.EAttribute.Eloquence, base = 50, min = 0, max = 100 },
    })

    MiniASC.add_tag(state, M.ETag.HasSecretMap)
    MiniASC.add_tag(state, M.ETag.UnderInterrogation)

    for _, def in pairs(ability_defs) do
        MiniASC.give_ability(state, defs, def, 1)
    end

    state._round = 1
    state._game_over = false
    state._win = false

    return state
end

---@class mini_gas.demo.weihu_shan.ActResult
---@field success boolean
---@field message string
---@field credibility_increased boolean
---@field suspicion_increased boolean
---@field game_over boolean
---@field win boolean

---执行一次应对动作
---@param state mini_gas.demo.weihu_shan.GameState
---@param ability_id mini_gas.AbilityId
---@param choice string|nil "success" / "fail"，仅对黑话有效
---@return mini_gas.demo.weihu_shan.ActResult
function M.act(state, ability_id, choice)
    if state._game_over then
        return { success = false, message = "游戏已结束", credibility_increased = false, suspicion_increased = false, game_over = true, win = state._win }
    end

    local old_cred = MiniASC.get_current(state, defs, M.EAttribute.Credibility)
    local old_susp = MiniASC.get_current(state, defs, M.EAttribute.Suspicion)

    local result = {
        success = false,
        message = "",
        credibility_increased = false,
        suspicion_increased = false,
        game_over = false,
        win = false,
    }

    -- 检查 Ability 是否可激活
    local ok = MiniASC.try_activate_ability(state, defs, ability_id)
    if not ok then
        result.message = "此时无法使用该应对。"
        return result
    end

    if ability_id == M.EAbilityId.AnswerLingo then
        if choice == "success" then
            MiniASC.apply_effect(state, defs, effect_defs[M.EEffectId.LingoSuccess], 1)
            result.message = "你对上了黑话，座山雕点了点头。"
            result.success = true
        else
            MiniASC.apply_effect(state, defs, effect_defs[M.EEffectId.LingoFail], 1)
            result.message = "你答错了黑话，座山雕皱起了眉头。"
        end
    elseif ability_id == M.EAbilityId.ShowMap then
        -- 献图：应用震撼效果后判定最终结局
        MiniASC.apply_effect(state, defs, effect_defs[M.EEffectId.MapShock], 1)
        local cred = MiniASC.get_current(state, defs, M.EAttribute.Credibility)
        local susp = MiniASC.get_current(state, defs, M.EAttribute.Suspicion)
        state._game_over = true
        if susp < 50 and cred >= 80 then
            state._win = true
            MiniASC.add_tag(state, M.ETag.Trusted)
            result.message = "你献上先遣图，座山雕大喜，封你为老九！"
        else
            MiniASC.add_tag(state, M.ETag.Suspicious)
            result.message = "座山雕冷笑一声：‘这图有诈，拖出去！’"
        end
        result.success = state._win
    elseif ability_id == M.EAbilityId.BragBackground then
        result.message = "你报出土匪黑话里的三姑六婆，满堂交头接耳。"
        result.success = true
    elseif ability_id == M.EAbilityId.PledgeLoyalty then
        result.message = "你拍着胸脯表忠心，座山雕不置可否。"
        result.success = true
    elseif ability_id == M.EAbilityId.KeepCalm then
        result.message = "你稳住心神，气势不落下风。"
        result.success = true
    else
        result.message = "未知动作。"
    end

    local new_cred = MiniASC.get_current(state, defs, M.EAttribute.Credibility)
    local new_susp = MiniASC.get_current(state, defs, M.EAttribute.Suspicion)
    result.credibility_increased = new_cred > old_cred
    result.suspicion_increased = new_susp > old_susp

    -- 推进回合（献图触发结局，不再推进）
    if not state._game_over then
        state._round = math.min(state._round + 1, 3)
    end

    result.game_over = state._game_over
    result.win = state._win

    return result
end

---获取当前回合
---@param state mini_gas.demo.weihu_shan.GameState
---@return number
function M.get_round(state)
    return state._round
end

---游戏是否结束
---@param state mini_gas.demo.weihu_shan.GameState
---@return boolean
function M.is_game_over(state)
    return state._game_over
end

---是否获胜
---@param state mini_gas.demo.weihu_shan.GameState
---@return boolean
function M.is_win(state)
    return state._win
end

---判断是否拥有某标签
---@param state mini_gas.demo.weihu_shan.GameState
---@param tag mini_gas.TagId
---@return boolean
function M.has_tag(state, tag)
    return MiniASC.has_tag(state, tag)
end

---判断 Ability 当前是否可用
---@param state mini_gas.demo.weihu_shan.GameState
---@param ability_id mini_gas.AbilityId
---@return boolean
function M.can_use_ability(state, ability_id)
    local key = tostring(ability_id)
    local ability = state.abilities[key]
    if not ability then
        return false
    end
    return ability_mod.can_activate(state, ability)
end

---@param state mini_gas.demo.weihu_shan.GameState
---@return number
function M.get_credibility(state)
    return MiniASC.get_current(state, defs, M.EAttribute.Credibility)
end

---@param state mini_gas.demo.weihu_shan.GameState
---@return number
function M.get_suspicion(state)
    return MiniASC.get_current(state, defs, M.EAttribute.Suspicion)
end

---@param state mini_gas.demo.weihu_shan.GameState
---@return number
function M.get_courage(state)
    return MiniASC.get_current(state, defs, M.EAttribute.Courage)
end

---@param state mini_gas.demo.weihu_shan.GameState
---@return number
function M.get_eloquence(state)
    return MiniASC.get_current(state, defs, M.EAttribute.Eloquence)
end

return M
