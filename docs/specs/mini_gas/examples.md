
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
        [ATTR_ATTACK] = { id = ATTR_ATTACK },
        [ATTR_GOLD]   = { id = ATTR_GOLD },
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
                    -- 当 can_activate 为函数形式时，modifier_args 即为该函数返回的 ...
                    attribute = function(context, entity, def, id, value, extra)
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
            -- 授予光环标签，用于业务追踪哪些实体受到了该光环影响；数值加成由 modifier 直接完成
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
            -- can_activate 为空时 Ability 默认激活
        },
        [ABILITY_VIP] = {
            id = ABILITY_VIP,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_VIP },
        },
        [ABILITY_PET] = {
            id = ABILITY_PET,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_PET },
        },
        [ABILITY_BUILDING] = {
            id = ABILITY_BUILDING,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_BUILDING },
            -- 函数形式：返回 true 以及 ModifierAttributeEval 所需的上下文
            can_activate = function(context, entity, def)
                return true, { world_level = 3 }
            end,
        },
        [ABILITY_AURA] = {
            id = ABILITY_AURA,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_AURA },
            -- 对象形式：世界中至少存在 2 名指挥官时激活；include_self 为 true 表示统计时包含自身
            can_activate = {
                allof_tags = { TAG_COMMANDER },
                requires_count = 2,
                include_self = true,
            },
        },
    },
}

-- 2. 定义实体状态与模块
-- 注意：IEntityState 只包含静态标签、属性、静态技能，不直接持有 Effect。
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

-- 迭代器实现：返回 next + state，避免 pairs 陷阱
local function make_entity_module()
    return {
        static_tags = function(entity) return next, entity.static_tags end,
        static_tags_size = function(entity)
            local n = 0
            for _ in pairs(entity.static_tags) do n = n + 1 end
            return n
        end,
        has_static_tag = function(entity, tag) return entity.static_tags[tag] ~= nil end,
        attributes = function(entity) return next, entity.attrs end,
        attributes_size = function(entity)
            local n = 0
            for _ in pairs(entity.attrs) do n = n + 1 end
            return n
        end,
        has_attribute = function(entity, id) return entity.attrs[id] ~= nil end,
        get_attribute = function(entity, id) return entity.attrs[id] or 0 end,
        static_abilities = function(entity) return next, entity.static_abilities end,
        static_abilities_size = function(entity)
            local n = 0
            for _ in pairs(entity.static_abilities) do n = n + 1 end
            return n
        end,
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
    entities = function(context)
        return function(entities, id)
            local next_id, next_state = next(entities, id)
            if next_id == nil then return nil end
            return next_id, next_state, entity_module
        end, context.world.entities
    end,
    entities_size = function(context)
        local n = 0
        for _ in pairs(context.world.entities) do n = n + 1 end
        return n
    end,
    has_entity = function(context, id) return context.world.entities[id] ~= nil end,
    get_entity = function(context, id)
        return context.world.entities[id], entity_module
    end,
}

-- 4. 组装 context 并调用 evaluate 收集结果
local context = {
    world = world_state,
    world_module = world_module,
    defs = defs,
}
local results = {}
local granted_tags = {}

-- 可选的调试接口
local debug = {
    begin_effect = function(context, owner_id, owner_entity, owner_module, ability_id, effect_id)
        print("begin effect", effect_id, "from", owner_id)
    end,
}

-- 最终应用函数：每个实体在全部求值完成后调用一次
-- tags 为 { [tag] = true }，attribute_deltas 为 { [attr_id] = delta }
local function apply(context, entity, tags, attribute_deltas)
    granted_tags[entity] = granted_tags[entity] or {}
    for tag, _ in pairs(tags) do
        local list = granted_tags[entity]
        list[#list + 1] = { tag = tag }
    end

    results[entity] = results[entity] or {}
    for attr_id, value in pairs(attribute_deltas) do
        results[entity][attr_id] = (results[entity][attr_id] or 0) + value
    end
end

-- 如需调试，将 debug 挂到 context.debug
context.debug = debug

-- 这里不需要再传入 world_level，因为建筑 Ability 的 can_activate 已经返回了该上下文
mini_gas.evaluate(context, apply)

-- 5. 查看结果
local function final_attr(entity, attr_id)
    return entity_module.get_attribute(entity, attr_id) + (results[entity] and results[entity][attr_id] or 0)
end

-- hero: attack = 100 + (50 + 40) = 190; gold = 0 + (100*3 * 1.2) = 360
print(final_attr(hero_state, ATTR_ATTACK))     -- 190
print(final_attr(hero_state, ATTR_GOLD))       -- 360

-- commander: 光环激活，给自己和 ally 都授予了 buff.commander_aura；attack = 100 + (100 * 0.2) = 120
print(final_attr(commander_state, ATTR_ATTACK)) -- 120

-- ally: 被 commander 的光环跨实体作用，同样获得 buff.commander_aura；attack = 100 + (100 * 0.2) = 120
print(final_attr(ally_state, ATTR_ATTACK))      -- 120
```

> 以上示例完整演示了：`ApplyFun` 每个实体在全部求值完成后只调用一次，接收 `context`、`entity`、`tags`、`attribute_deltas`，其中 `tags` 为 `{ [tag] = true }` 集合，`attribute_deltas` 为属性 ID 到 add 语义差值（`new_value - old_value`）的映射；业务方通过“旧值 + 差值”得到最终值。Modifier 聚合规则为：Add 累加、Multiply 连乘（无 Multiply 时视为乘以 1）、Override 按遍历顺序取最后一个值；存在 Override 时最终值为 Override 值，否则为 `(base + add_sum) * multiply_product`。来源追踪等调试需求可通过 `IDebug` 钩子完成。`can_activate` 为空时 Ability 默认激活；`AbilityActivateConditionFunc` 通过返回值向 `ModifierAttributeEval` 传递上下文；`AbilityActivateCondition` 对象形式通过 `requires_count = 2` 与 `include_self = true` 实现“世界中至少存在 2 名指挥官”的激活条件；`EffectDef` 的 `allof_tags` 在 `EEffectTarget.All` 下完成了对所有指挥官的跨实体筛选；`IEntityModule` 与 `IWorldModule` 的迭代器均使用 `return next, state` 形式避免 Lua 迭代器陷阱。

---

> [返回 Mini-GAS 设计文档总览](./README.md)
