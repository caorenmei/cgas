
## 12. 使用示例

### 12.1 英雄基础属性 + 装备 + VIP

> 以下示例中的项目级枚举代表由策划配置、通过 `ConfigAdapter` 映射后的业务 ID；`mini-gas` 框架层不预定义这些业务常量。

```lua
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local Defs = mini_gas.Defs
local MiniASC = mini_gas.MiniASC
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy

-- 项目级枚举（来自策划配置的 alias）
---@enum project.EAttribute
local EAttribute = {
    MaxHp = "attr.max_hp",
    Attack = "attr.attack",
    Defense = "attr.defense",
    GoldGainRate = "attr.gold_gain_rate",
}

---@enum project.EEffectId
local EEffectId = {
    EquipmentSword = "effect.equipment.sword",
    VipLevel3 = "effect.vip.level_3",
}

-- 1. 创建状态对象（由业务方持有，可序列化）
local hero_state = EntityState.new()
local defs = Defs.new()

-- 2. 注册英雄基础属性
MiniASC.register_attributes(hero_state, defs, {
    { name = EAttribute.MaxHp,    base = 1000, min = 0 },
    { name = EAttribute.Attack,   base = 100,  min = 0 },
    { name = EAttribute.Defense,  base = 50,   min = 0 },
    { name = EAttribute.GoldGainRate, base = 1.0, min = 0 },
})

-- 3. 装备效果（永久）
MiniASC.apply_effect(hero_state, defs, {
    id = EEffectId.EquipmentSword,
    duration_policy = EDurationPolicy.Infinite,
    modifiers = {
        { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 50 },
    },
}, 1)

-- 4. VIP 效果（永久）
MiniASC.apply_effect(hero_state, defs, {
    id = EEffectId.VipLevel3,
    duration_policy = EDurationPolicy.Infinite,
    modifiers = {
        { attribute = EAttribute.GoldGainRate, op = EModifierOp.Multiply, value = 1.15 },
    },
}, 1)

-- 5. 计算结果
print(MiniASC.get_current(hero_state, defs, EAttribute.Attack))        -- 150
print(MiniASC.get_current(hero_state, defs, EAttribute.GoldGainRate))  -- 1.15

-- 6. 状态可序列化后保存或网络同步
local serialized = json.encode(hero_state)
```

### 12.2 成长性技能：火球术

```lua
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy

-- 项目级枚举（来自策划配置的 alias）
---@enum project.EAbilityId
local EAbilityId = {
    Fireball = "ability.fireball",
}

---@enum project.EEffectId
local EEffectId = {
    FireballDamage = "effect.fireball.damage",
}

---@enum project.EAttribute
local EAttribute = {
    Hp = "attr.hp",
    Mp = "attr.mp",
}

-- 业务 helper：按等级生成固定数值
local function calc_by_level(base, growth, level)
    return base + (level - 1) * growth
end

local fireball_level = 3
local fireball_def = {
    id = EAbilityId.Fireball,
    activation_policy = EAbilityActivationPolicy.Active,
    level = fireball_level,
    -- cooldown 是公式函数：self 为 GameplayAbility 实例，通过 defs 读取业务字段
    cooldown = function(self) return calc_by_level(5, -0.2, defs.ability_defs[self.id].level) end,
    cost = {
        [EAttribute.Mp] = function(self) return calc_by_level(20, 2, defs.ability_defs[self.id].level) end,
    },
    effects = {
        {
            id = EEffectId.FireballDamage,
            duration_policy = EDurationPolicy.Instant,
            modifiers = {
                {
                    attribute = EAttribute.Hp,
                    op = EModifierOp.Add,
                    value = calc_by_level(-100, -15, fireball_level), -- 3 级时 -130
                },
            },
        },
    },
}

MiniASC.give_ability(hero_state, defs, fireball_def, 1)
local ok = MiniASC.try_activate_ability(hero_state, defs, EAbilityId.Fireball)
```

### 12.3 被动技能：攻击光环

```lua
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy

-- 项目级枚举（来自策划配置的 alias）
---@enum project.EAbilityId
local EAbilityId = {
    AttackAura = "ability.attack_aura",
}

---@enum project.EEffectId
local EEffectId = {
    AttackAura = "effect.attack_aura",
}

---@enum project.EAttribute
local EAttribute = {
    Attack = "attr.attack",
}

---@enum project.ETag
local ETag = {
    Buff_AttackAura = "buff.attack_aura",
}

local attack_aura_def = {
    id = EAbilityId.AttackAura,
    activation_policy = EAbilityActivationPolicy.Passive,
    grant_tags = { ETag.Buff_AttackAura },
    effects = {
        {
            id = EEffectId.AttackAura,
            duration_policy = EDurationPolicy.Infinite,
            granted_tags = { ETag.Buff_AttackAura },
            modifiers = {
                {
                    attribute = EAttribute.Attack,
                    op = EModifierOp.Multiply,
                    value = 1.2,
                },
            },
        },
    },
}

MiniASC.give_ability(hero_state, defs, attack_aura_def, 1)
-- 被动技能自动生效
```

### 12.4 响应式技能：受击反击

```lua
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy

-- 项目级枚举（来自策划配置的 alias）
---@enum project.EAbilityId
local EAbilityId = {
    CounterAttack = "ability.counter_attack",
}

---@enum project.EEffectId
local EEffectId = {
    CounterDamage = "effect.counter.damage",
}

---@enum project.EAttribute
local EAttribute = {
    Hp = "attr.hp",
}

---@enum project.ETag
local ETag = {
    State_Combat = "state.combat",
    State_Stunned = "state.stunned",
}

---@enum project.EGameplayEvent
local EGameplayEvent = {
    DamageTaken = "event.damage.taken",
}

local counter_attack_def = {
    id = EAbilityId.CounterAttack,
    activation_policy = EAbilityActivationPolicy.Reactive,
    activation_event = EGameplayEvent.DamageTaken,
    require_tags = { ETag.State_Combat },
    blocked_tags = { ETag.State_Stunned },
    cooldown = 3,
    effects = {
        {
            id = EEffectId.CounterDamage,
            duration_policy = EDurationPolicy.Instant,
            modifiers = {
                { attribute = EAttribute.Hp, op = EModifierOp.Add, value = -50 },
            },
        },
    },
}

MiniASC.give_ability(hero_state, defs, counter_attack_def, 1)
-- 当 DamageTaken 事件触发且满足标签条件时，自动尝试激活
```

### 12.5 周期性效果：主城建筑产出

```lua
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy

-- 项目级枚举（来自策划配置的 alias）
---@enum project.EAttribute
local EAttribute = {
    IronOutput = "attr.iron_output",
}

---@enum project.EEffectId
local EEffectId = {
    BuildingIronMine = "effect.building.iron_mine",
}

local city_state = EntityState.new()
local city_defs = Defs.new()
MiniASC.register_attributes(city_state, city_defs, {
    { name = EAttribute.IronOutput, base = 0, min = 0 },
})

MiniASC.apply_effect(city_state, city_defs, {
    id = EEffectId.BuildingIronMine,
    duration_policy = EDurationPolicy.Infinite,
    period = 60,
    modifiers = {
        { attribute = EAttribute.IronOutput, op = EModifierOp.Add, value = 100 },
    },
}, 1)

-- 在游戏主循环中调用
MiniASC.update(city_state, city_defs, dt)

local total_iron = MiniASC.get_current(city_state, city_defs, EAttribute.IronOutput)
```

### 12.6 综合示例：英雄、装备、宠物、主城与特权相互影响

以下示例展示英雄、装备、宠物、主城与特权如何通过 **同一个 `EntityState`** 与 **Tag 机制** 实现相互影响，并通过 `WorldState`（`table<EntityId, EntityState>`）统一批量更新：

- **装备**：永久加成攻击与防御。
- **宠物**：按等级公式永久加成攻击，并 **Granted** `pet.active` 标签。
- **英雄技能**：通过 `require_tags = {pet.active}` 只有携带宠物时才能激活；通过 `blocked_tags = {state.silenced}` 被沉默时无法使用。
- **VIP 特权**：**Granted** `buff.vip` 标签，并提升金币/经验倍率；建筑产出的额外倍率 Modifier 通过 `require_tags = {buff.vip}` 启用。
- **主城建筑**：周期性产出金币与铁矿，产出倍率受 VIP 标签驱动。
- **WorldState**：将共享的 `EntityState` 注册为 `"player"`，通过 `MiniASC.update_world` 统一推进所有实体。

```lua
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local WorldState = mini_gas.WorldState
local Defs = mini_gas.Defs
local MiniASC = mini_gas.MiniASC
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy

-- 项目级枚举（来自策划配置的 alias）
---@enum project.EAttribute
local EAttribute = {
    MaxHp = "attr.max_hp",
    Hp = "attr.hp",
    Mp = "attr.mp",
    Attack = "attr.attack",
    Defense = "attr.defense",
    Gold = "attr.gold",
    Iron = "attr.iron",
    GoldGainRate = "attr.gold_gain_rate",
    ExpGainRate = "attr.exp_gain_rate",
}

---@enum project.ETag
local ETag = {
    State_Combat = "state.combat",
    Pet_Active = "pet.active",
    Buff_Vip = "buff.vip",
    State_Silenced = "state.silenced", -- Block Tag 示例
}

---@enum project.EAbilityId
local EAbilityId = {
    HeroAttack = "ability.hero_attack",
}

---@enum project.EEffectId
local EEffectId = {
    EquipSword = "effect.equip.sword",
    PetDragon = "effect.pet.dragon",
    VipPrivilege = "effect.vip.privilege",
    HeroAttackDamage = "effect.hero.attack_damage",
    BuildingGoldMine = "effect.building.gold_mine",
    BuildingIronMine = "effect.building.iron_mine",
}

-- 业务 helper：按等级生成固定数值
local function calc_by_level(base, growth, level)
    return base + (level - 1) * growth
end

-- 所有子系统共享同一个 EntityState 与 Defs
local state = EntityState.new()
local defs = Defs.new()

MiniASC.register_attributes(state, defs, {
    { name = EAttribute.MaxHp,        base = 1000, min = 0 },
    { name = EAttribute.Hp,           base = 1000, min = 0, max = 1000 },
    { name = EAttribute.Mp,           base = 200,  min = 0, max = 200 },
    { name = EAttribute.Attack,       base = 100,  min = 0 },
    { name = EAttribute.Defense,      base = 50,   min = 0 },
    { name = EAttribute.Gold,         base = 0,    min = 0 },
    { name = EAttribute.Iron,         base = 0,    min = 0 },
    { name = EAttribute.GoldGainRate, base = 1.0,  min = 0 },
    { name = EAttribute.ExpGainRate,  base = 1.0,  min = 0 },
})

-- 装备：传说之剑（永久 + 攻击、+ 防御）
MiniASC.apply_effect(state, defs, {
    id = EEffectId.EquipSword,
    duration_policy = EDurationPolicy.Infinite,
    modifiers = {
        { attribute = EAttribute.Attack,  op = EModifierOp.Add, value = 80 },
        { attribute = EAttribute.Defense, op = EModifierOp.Add, value = 30 },
    },
}, 1)

-- 宠物：小龙（5 级），Granted pet.active 标签
MiniASC.apply_effect(state, defs, {
    id = EEffectId.PetDragon,
    duration_policy = EDurationPolicy.Infinite,
    granted_tags = { ETag.Pet_Active },
    modifiers = {
        { attribute = EAttribute.Attack, op = EModifierOp.Add, value = calc_by_level(20, 5, 5) }, -- 5 级时 40
    },
}, 1)

-- VIP 特权：Granted buff.vip 标签，并提升金币/经验倍率
MiniASC.apply_effect(state, defs, {
    id = EEffectId.VipPrivilege,
    duration_policy = EDurationPolicy.Infinite,
    granted_tags = { ETag.Buff_Vip },
    modifiers = {
        { attribute = EAttribute.GoldGainRate, op = EModifierOp.Multiply, value = 1.2 },
        { attribute = EAttribute.ExpGainRate,  op = EModifierOp.Multiply, value = 1.1 },
    },
}, 1)

-- 主动技能：普通攻击
-- Require Tags：必须携带宠物；Blocked Tags：沉默时无法使用
local hero_attack_def = {
    id = EAbilityId.HeroAttack,
    activation_policy = EAbilityActivationPolicy.Active,
    require_tags = { ETag.Pet_Active },
    blocked_tags = { ETag.State_Silenced },
    cooldown = 1.5,
    cost = { [EAttribute.Mp] = 10 },
    effects = {
        {
            id = EEffectId.HeroAttackDamage,
            duration_policy = EDurationPolicy.Instant,
            modifiers = {
                { attribute = EAttribute.Hp, op = EModifierOp.Add, value = -100 },
            },
        },
    },
}
MiniASC.give_ability(state, defs, hero_attack_def, 1)

-- 金矿：每 60 秒产出 100 金币；VIP 额外 ×1.2
MiniASC.apply_effect(state, defs, {
    id = EEffectId.BuildingGoldMine,
    duration_policy = EDurationPolicy.Infinite,
    period = 60,
    modifiers = {
        -- 基础产出
        { attribute = EAttribute.Gold, op = EModifierOp.Add, value = 100 },
        -- VIP 加成：需要 buff.vip 标签才生效
        { attribute = EAttribute.Gold, op = EModifierOp.Multiply, value = 1.2, require_tags = { ETag.Buff_Vip } },
    },
}, 1)

-- 铁矿厂：每 60 秒产出 50 铁矿；VIP 额外 ×1.2
MiniASC.apply_effect(state, defs, {
    id = EEffectId.BuildingIronMine,
    duration_policy = EDurationPolicy.Infinite,
    period = 60,
    modifiers = {
        { attribute = EAttribute.Iron, op = EModifierOp.Add, value = 50 },
        { attribute = EAttribute.Iron, op = EModifierOp.Multiply, value = 1.2, require_tags = { ETag.Buff_Vip } },
    },
}, 1)

-- 使用 WorldState 管理实体（本质是 table<EntityId, EntityState>）
local world = WorldState.new()
mini_gas.register_entity(world, "player", state)

-- 模拟 120 秒的游戏时间：统一更新整个世界
MiniASC.update_world(world, defs, 120)

-- 模拟英雄战斗：携带宠物且未被沉默，技能可以激活
local ok1 = MiniASC.try_activate_ability(state, defs, EAbilityId.HeroAttack) -- true

-- 若英雄被沉默（添加 Block Tag），技能无法激活
MiniASC.add_tag(state, ETag.State_Silenced)
local ok2 = MiniASC.try_activate_ability(state, defs, EAbilityId.HeroAttack) -- false
MiniASC.remove_tag(state, ETag.State_Silenced)

-- 读取最终数值
print(MiniASC.get_current(state, defs, EAttribute.Attack))       -- 100 + 80 + 40 = 220
print(MiniASC.get_current(state, defs, EAttribute.Defense))      -- 50 + 30 = 80
print(MiniASC.get_current(state, defs, EAttribute.GoldGainRate)) -- 1.0 * 1.2 = 1.2
print(MiniASC.get_current(state, defs, EAttribute.Gold))         -- 100 * 2 周期 * 1.2 = 240
print(MiniASC.get_current(state, defs, EAttribute.Iron))         -- 50 * 2 周期 * 1.2 = 120

-- 整个世界状态可序列化
local saved = json.encode(world)
```

---

---

> [返回 Mini-GAS 设计文档总览](./README.md)
