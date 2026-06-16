
## 5. 类型与枚举定义

所有 LuaCATS 类型声明集中维护于 `lua_lib/mini_gas/types.lua`，枚举运行时值与 `@enum` 注解维护于 `lua_lib/mini_gas/enum.lua`。

### 5.1 基础别名

```lua
---@alias mini_gas.ID integer | string
---@alias mini_gas.Tag string
---@alias mini_gas.Iterator fun(state: any, key?: any): any, any
```

### 5.2 枚举

```lua
---@enum mini_gas.EModifierOp
local EModifierOp = {
    Add = 1,      -- 加法：将多个 Add 修改量累加
    Multiply = 2, -- 乘法：将多个 Multiply 修改量连乘
    Override = 3, -- 覆盖：同一属性的多个 Override 按生效顺序取最后一个值
}

---@enum mini_gas.EAbilityActivationPolicy
local EAbilityActivationPolicy = {
    Passive = 1, -- 被动：满足条件时自动激活
}

---@enum mini_gas.EEffectTarget
local EEffectTarget = {
    Self = 1,  -- 仅对能力所属实体自身生效
    Other = 2, -- 对世界中的其他实体生效
    All = 3,   -- 对世界中的所有实体生效，包含能力所属实体自身
}
```

### 5.3 配置定义

```lua
---@class mini_gas.AttributeDef
---@field id mini_gas.ID
---@field min? number
---@field max? number
---@field default? number

---@class mini_gas.Defs
---@field attribute_defs table<mini_gas.ID, mini_gas.AttributeDef>
---@field effect_defs table<mini_gas.ID, mini_gas.EffectDef>
---@field ability_defs table<mini_gas.ID, mini_gas.AbilityDef>
```

### 5.4 回调数据条目

```lua
---@class mini_gas.GrantedTagEntry
---@field entity mini_gas.IEntityState
---@field module mini_gas.IEntityModule
---@field tag mini_gas.Tag

---@class mini_gas.AttrChangeEntry
---@field entity mini_gas.IEntityState
---@field module mini_gas.IEntityModule
---@field attr_id mini_gas.ID
---@field value number
```

### 5.5 IEvaluation

```lua
---@class mini_gas.IEvaluation
---@field begin_ability? fun(context: mini_gas.IContext, world: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, defs: mini_gas.Defs, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, ...: unknown)
---@field end_ability? fun(context: mini_gas.IContext, world: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, defs: mini_gas.Defs, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, ...: unknown)
---@field begin_effect? fun(context: mini_gas.IContext, world: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, defs: mini_gas.Defs, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, ...: unknown)
---@field end_effect? fun(context: mini_gas.IContext, world: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, defs: mini_gas.Defs, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, ...: unknown)
---@field begin_modifier? fun(context: mini_gas.IContext, world: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, defs: mini_gas.Defs, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, modifier_def: mini_gas.ModifierDef, target_entity: mini_gas.IEntityState, target_module: mini_gas.IEntityModule, ...: unknown)
---@field end_modifier? fun(context: mini_gas.IContext, world: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, defs: mini_gas.Defs, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, modifier_def: mini_gas.ModifierDef, target_entity: mini_gas.IEntityState, target_module: mini_gas.IEntityModule, ...: unknown)
---@field apply fun(context: mini_gas.IContext, world: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, defs: mini_gas.Defs, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, granted_tags: mini_gas.GrantedTagEntry[], attr_changes: mini_gas.AttrChangeEntry[], ...: unknown)
```

### 5.6 ModifierDef

```lua
---@alias mini_gas.ModifierAttributeEval fun(context:mini_gas.IContext, world_state: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, entity: mini_gas.IEntityState, entity_module: mini_gas.IEntityModule, def: mini_gas.ModifierDef, id?: mini_gas.ID, value?: number, ...: unknown): mini_gas.ID, number, mini_gas.ModifierAttributeEval?

---@class mini_gas.ModifierDef
---@field attribute [mini_gas.ID, number] | mini_gas.ModifierAttributeEval
---@field op mini_gas.EModifierOp
---@field allof_tags? mini_gas.Tag[]
---@field anyof_tags? mini_gas.Tag[]
---@field noneof_tags? mini_gas.Tag[]
```

### 5.7 EffectDef

```lua
---@class mini_gas.EffectDef
---@field id mini_gas.ID
---@field modifiers mini_gas.ModifierDef[]
---@field grant_tags? mini_gas.Tag[]
---@field allof_tags? mini_gas.Tag[]
---@field anyof_tags? mini_gas.Tag[]
---@field noneof_tags? mini_gas.Tag[]
---@field target? mini_gas.EEffectTarget
```

### 5.8 AbilityDef

```lua
---@class mini_gas.AbilityActivateCondition
---@field allof_tags? mini_gas.Tag[]
---@field anyof_tags? mini_gas.Tag[]
---@field noneof_tags? mini_gas.Tag[]
---@field requires_count integer
---@field include_self? boolean

---@alias mini_gas.AbilityActivateConditionFunc fun(context:mini_gas.IContext, defs: mini_gas.Defs, world_state: mini_gas.IWorldState, world_module: mini_gas.IWorldModule, entity: mini_gas.IEntityState, entity_module: mini_gas.IEntityModule, def: mini_gas.AbilityDef, ...: unknown): boolean, ...

---@class mini_gas.AbilityDef
---@field id mini_gas.ID
---@field activation_policy mini_gas.EAbilityActivationPolicy
---@field effects mini_gas.ID[]
---@field can_activate? mini_gas.AbilityActivateCondition | mini_gas.AbilityActivateConditionFunc
```

---

> [返回 Mini-GAS 设计文档总览](./README.md)
