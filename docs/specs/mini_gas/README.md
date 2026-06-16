# MiniGas V2 设计文档

> 文档版本：v2.0  
> 关联项目：[cgas](../../../) — 基于 Lua 的 GAS 库  
> 本文对应实现目录：[lua_lib/mini_gas](../../../lua_lib/mini_gas/)

---

## 总览

MiniGas V2 是 MiniGas 的第二个版本，是一次完全重构。

**设计目标**：
- 在服务器端以快照方式对世界状态进行全量求值，计算实体之间的相互作用。
- 通过接口化设计（`IEntityModule`、`IWorldModule`、`IEvaluation`）方便与现有系统集成，不强制使用框架内置的状态结构。
- 仅保留 Passive Ability，无主动技能、冷却、消耗、Tick 推进等复杂机制，保持核心最小化。

**适用场景**：
- 英雄、宠物、装备、建筑等成长性数值计算。
- 基于标签的 Buff/Debuff、光环、VIP 特权等条件加成。
- 需要一次性计算世界最终状态，而非逐帧推进的离线或服务端快照场景。

**明确不包含**：
- 主动/响应式技能、冷却、消耗、Stack 堆叠。
- 时间推进（Tick）、周期效果触发、延时任务。
- 网络同步、客户端预测、持久化、渲染表现层。

当项目需要上述能力时，应在 MiniGas V2 之上由业务系统自行扩展，或通过业务层适配桥接到其他 GAS 实现。

---

## 文档索引

| 文档 | 说明 |
|------|------|
| [README.md](./README.md) | 本文：背景、目标、范围、快速开始 |
| [architecture.md](./architecture.md) | 核心架构与接口设计 |
| [core-mechanisms.md](./core-mechanisms.md) | 标签、属性、Modifier、Effect、Ability、evaluate 流程 |
| [types.md](./types.md) | 类型与枚举定义 |
| [api-reference.md](./api-reference.md) | 目录结构与 API 参考 |
| [examples.md](./examples.md) | 综合使用示例 |
| [implementation-notes.md](./implementation-notes.md) | 实现要点与版本历史 |

---

## 快速开始

```lua
local mini_gas = require("mini_gas")
local EModifierOp = mini_gas.EModifierOp
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy

local ATTR_ATTACK = "attr.attack"
local ABILITY_SWORD = "ability.sword"
local EFFECT_SWORD = "effect.sword"

-- 1. 定义配置
local defs = {
    attribute_defs = {
        [ATTR_ATTACK] = { id = ATTR_ATTACK, default = 100 },
    },
    effect_defs = {
        [EFFECT_SWORD] = {
            id = EFFECT_SWORD,
            modifiers = {
                { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add },
            },
        },
    },
    ability_defs = {
        [ABILITY_SWORD] = {
            id = ABILITY_SWORD,
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = { EFFECT_SWORD },
        },
    },
}

-- 2. 实现 IEntityModule 与 IWorldModule（此处为最小示例）
local entity = {
    attrs = { [ATTR_ATTACK] = 100 },
    static_tags = {},
    static_abilities = { [ABILITY_SWORD] = true },
}
local entity_module = {
    static_tags = function(e) return next, e.static_tags end,
    static_tags_size = function(e) local n = 0 for _ in pairs(e.static_tags) do n = n + 1 end return n end,
    has_static_tag = function(e, tag) return e.static_tags[tag] ~= nil end,
    attributes = function(e) return next, e.attrs end,
    attributes_size = function(e) local n = 0 for _ in pairs(e.attrs) do n = n + 1 end return n end,
    has_attribute = function(e, id) return e.attrs[id] ~= nil end,
    get_attribute = function(e, id) return e.attrs[id] or 0 end,
    static_abilities = function(e) return next, e.static_abilities end,
    static_abilities_size = function(e) local n = 0 for _ in pairs(e.static_abilities) do n = n + 1 end return n end,
    has_static_ability = function(e, id) return e.static_abilities[id] ~= nil end,
}
local world = { entities = { hero = entity } }
local world_module = {
    entities = function(_, w)
        return function(entities, id)
            local next_id, next_state = next(entities, id)
            if next_id == nil then return nil end
            return next_id, next_state, entity_module
        end, w.entities
    end,
    entities_size = function(_, w) local n = 0 for _ in pairs(w.entities) do n = n + 1 end return n end,
    has_entity = function(_, w, id) return w.entities[id] ~= nil end,
    get_entity = function(_, w, id) return w.entities[id], entity_module end,
}

-- 3. 实现 IEvaluation
local deltas = {}
local evaluation = {
    apply = function(_, _, _, _, _, _, _, tags, attr_changes)
        for _, entry in ipairs(attr_changes) do
            deltas[entry.attr_id] = (deltas[entry.attr_id] or 0) + entry.value
        end
    end,
}

-- 4. 执行快照求值
mini_gas.evaluate({}, world, world_module, defs, evaluation)

-- 最终 attack = 100 + 50 = 150
print(entity_module.get_attribute(entity, ATTR_ATTACK) + (deltas[ATTR_ATTACK] or 0))
```

---

> [返回 Mini-GAS 设计文档总览](./README.md)
