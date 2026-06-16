
## 12. 使用示例

### 12.1 装备、VIP、宠物、建筑与光环的综合计算

场景：
- 英雄佩戴传说之剑（被动技能），基础攻击 +50。
- 英雄激活 VIP 特权（被动技能），金币产出 ×1.2，但要求实体拥有 `buff.vip` 标签。
- 英雄携带宠物龙（被动技能），攻击 +40，但要求实体拥有 `pet.active` 标签。
- 英雄拥有金矿建筑（被动技能），金币产出受世界等级影响；这里通过 `AbilityActivateConditionFunc` 返回世界等级上下文。
- 指挥官拥有攻击光环（被动技能），当世界中存在至少 2 名指挥官时激活；该光环会给所有指挥官（包括自身）添加 `buff.commander_aura` 标签，并使攻击 ×1.2；这里使用 `AbilityActivateCondition` 对象形式并设置 `include_self = true`，同时使用 `EEffectTarget.All` 实现跨实体效果。

```lua
local mini_gas = require("mini_gas")
local EModifierOp = mini_gas.EModifierOp
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy
local EEffectTarget = mini_gas.EEffectTarget

-- 业务级 ID 与标签
local ATTR_ATTACK = "attr.attack"
local ATTR_GOLD   = "attr.gold"

local TAG_PET_ACTIVE = "pet.active"
local TAG_VIP        = "buff.vip"
local TAG_COMMANDER  = "role.commander"
local TAG_AURA       = "buff.commander_aura"

local ABILITY_SWORD    = "ability.equipment.sword"
local ABILITY_VIP      = "ability.vip.privilege"
local ABILITY_PET      = "ability.pet.dragon"
local ABILITY_BUILDING = "ability.building.gold_mine"
local ABILITY_AURA     = "ability.attack_aura"

local EFFECT_SWORD    = "effect.equipment.sword"
local EFFECT_VIP      = "effect.vip.privilege"
local EFFECT_PET      = "effect.pet.dragon"
local EFFECT_BUILDING = "effect.building.gold_mine"
local EFFECT_AURA     = "effect.attack_aura"

-- 1. 构建 Defs
local defs = {
    attribute_defs = {
        [ATTR_ATTACK] = { id = ATTR_ATTACK, default = 100 },
        [ATTR_GOLD]   = { id = ATTR_GOLD,   default = 0 },
    },
    effect_defs = {
        [EFFECT_SWORD] = {
            id = EFFECT_SWORD,
            modifiers = {
                { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add },
            },
        },
        [EFFECT_VIP] = {
            id = EFFECT_VIP,
            modifiers = {
                { attribute = { ATTR_GOLD, 1.2 }, op = EModifierOp.Multiply, allof_tags = { TAG_VIP } },
            },
        },
        [EFFECT_PET] = {
            id = EFFECT_PET,
            modifiers = {
                { attribute = { ATTR_ATTACK, 40 }, op = EModifierOp.Add, allof_tags = { TAG_PET_ACTIVE } },
            },
        },
        [EFFECT_BUILDING] = {
            id = EFFECT_BUILDING,
            modifiers = {
                {
                    attribute = function(_, _, _, _, _, _, extra)
                        local world_level = extra and extra.world_level or 1
                        return ATTR_GOLD, 100 * world_level
                    end,
                    op = EModifierOp.Add,
                },
            },
        },
        [EFFECT_AURA] = {
            id = EFFECT_AURA,
            target = EEffectTarget.All,
            allof_tags = { TAG_COMMANDER },
            grant_tags = { TAG_AURA },
            modifiers = {
                { attribute = { ATTR_ATTACK, 1.2 }, op = EModifierOp.Multiply },
            },
        },
    },
    ability_defs = {
        [ABILITY_SWORD] = {
            id = ABILITY_SWORD,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_SWORD },
            can_activate = function() return true end,
        },
        [ABILITY_VIP] = {
            id = ABILITY_VIP,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_VIP },
            can_activate = function() return true end,
        },
        [ABILITY_PET] = {
            id = ABILITY_PET,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_PET },
            can_activate = function() return true end,
        },
        [ABILITY_BUILDING] = {
            id = ABILITY_BUILDING,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_BUILDING },
            can_activate = function()
                return true, { world_level = 3 }
            end,
        },
        [ABILITY_AURA] = {
            id = ABILITY_AURA,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_AURA },
            can_activate = {
                allof_tags = { TAG_COMMANDER },
                requires_count = 2,
                include_self = true,
            },
        },
    },
}

-- 2. 定义实体状态与模块
local hero_state = {
    attrs = { [ATTR_ATTACK] = 100, [ATTR_GOLD] = 0 },
    static_tags = { [TAG_PET_ACTIVE] = true, [TAG_VIP] = true },
    static_abilities = {
        [ABILITY_SWORD] = true,
        [ABILITY_VIP] = true,
        [ABILITY_PET] = true,
        [ABILITY_BUILDING] = true,
    },
}
local commander_state = {
    attrs = { [ATTR_ATTACK] = 100 },
    static_tags = { [TAG_COMMANDER] = true },
    static_abilities = { [ABILITY_AURA] = true },
}
local ally_state = {
    attrs = { [ATTR_ATTACK] = 100 },
    static_tags = { [TAG_COMMANDER] = true },
    static_abilities = {},
}

local function make_entity_module()
    return {
        static_tags = function(entity) return next, entity.static_tags end,
        static_tags_size = function(entity) local n = 0 for _ in pairs(entity.static_tags) do n = n + 1 end return n end,
        has_static_tag = function(entity, tag) return entity.static_tags[tag] ~= nil end,
        attributes = function(entity) return next, entity.attrs end,
        attributes_size = function(entity) local n = 0 for _ in pairs(entity.attrs) do n = n + 1 end return n end,
        has_attribute = function(entity, id) return entity.attrs[id] ~= nil end,
        get_attribute = function(entity, id) return entity.attrs[id] or 0 end,
        static_abilities = function(entity) return next, entity.static_abilities end,
        static_abilities_size = function(entity) local n = 0 for _ in pairs(entity.static_abilities) do n = n + 1 end return n end,
        has_static_ability = function(entity, def_id) return entity.static_abilities[def_id] ~= nil end,
    }
end

local entity_module = make_entity_module()

-- 3. 定义世界状态与模块
local world_state = {
    entities = {
        hero = hero_state,
        commander = commander_state,
        ally = ally_state,
    },
}

local world_module = {
    entities = function(context, world)
        return function(entities, id)
            local next_id, next_state = next(entities, id)
            if next_id == nil then return nil end
            return next_id, next_state, entity_module
        end, world.entities
    end,
    entities_size = function(context, world) local n = 0 for _ in pairs(world.entities) do n = n + 1 end return n end,
    has_entity = function(context, world, id) return world.entities[id] ~= nil end,
    get_entity = function(context, world, id) return world.entities[id], entity_module end,
}

-- 4. 调用 evaluate 并收集结果
local context = {}
local results = {}
local granted_tags = {}

local evaluation = {
    grant_tags = function(_, _, _, entity, src_entity_id, ability_def_id, effect_def_id, tags)
        granted_tags[entity] = granted_tags[entity] or {}
        for _, tag in ipairs(tags) do
            table.insert(granted_tags[entity], { tag = tag, src = src_entity_id, ability = ability_def_id, effect = effect_def_id })
        end
    end,
    apply_attribute = function(_, _, _, entity, _, _, _, attr_id, value)
        results[entity] = results[entity] or {}
        results[entity][attr_id] = (results[entity][attr_id] or 0) + value
    end,
}

mini_gas.evaluate(context, world_state, world_module, defs, evaluation)

-- 5. 查看结果
local function final_attr(entity, attr_id)
    return entity_module.get_attribute(entity, attr_id) + (results[entity] and results[entity][attr_id] or 0)
end

-- hero: attack = 100 + (50 + 40) = 190; gold = 0 + (100*3 * 1.2) = 360
print(final_attr(hero_state, ATTR_ATTACK))     -- 190
print(final_attr(hero_state, ATTR_GOLD))       -- 360

-- commander: 光环激活，给自己和 ally 都授予了 buff.commander_aura; attack = 100 + (100 * 0.2) = 120
print(final_attr(commander_state, ATTR_ATTACK)) -- 120

-- ally: 被 commander 的光环跨实体作用; attack = 120
print(final_attr(ally_state, ATTR_ATTACK))      -- 120
```

---

> [返回 Mini-GAS 设计文档总览](./README.md)
