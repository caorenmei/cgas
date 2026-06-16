--- MiniGas V2 LuaCATS 类型定义集中文件
--- 本文件仅用于静态类型声明，不执行运行时逻辑

---@meta

--- 通用 ID，可为整数或字符串
---@alias mini_gas.ID integer | string

--- 标签，采用点分层级结构，如 "state.dead"
---@alias mini_gas.Tag string

--- Lua 迭代器：返回 next + state 的二元组
---@alias mini_gas.Iterator fun(state: any, key?: any): any, any

--- 属性定义
---@class mini_gas.AttributeDef
---@field id mini_gas.ID
---@field min? number 属性最小值约束；未定义时不限制
---@field max? number 属性最大值约束；未定义时不限制
---@field default? number 属性初始值；省略时默认为 0

--- 配置定义表
---@class mini_gas.Defs
---@field attribute_defs table<mini_gas.ID, mini_gas.AttributeDef>
---@field effect_defs table<mini_gas.ID, mini_gas.EffectDef>
---@field ability_defs table<mini_gas.ID, mini_gas.AbilityDef>

--- 系统上下文接口，由业务方实现
---@class mini_gas.IContext

--- 实体状态接口，由业务方实现
---@class mini_gas.IEntityState

--- 实体模块接口，提供访问实体状态的函数
--- 所有迭代器函数均返回“迭代函数 + 状态”二元组
---@class mini_gas.IEntityModule
---@field static_tags fun(entity: mini_gas.IEntityState): mini_gas.Iterator, any
---@field static_tags_size fun(entity: mini_gas.IEntityState): integer
---@field has_static_tag fun(entity: mini_gas.IEntityState, tag: mini_gas.Tag): boolean
---@field attributes fun(entity: mini_gas.IEntityState): mini_gas.Iterator, any
---@field attributes_size fun(entity: mini_gas.IEntityState): integer
---@field has_attribute fun(entity: mini_gas.IEntityState, id: mini_gas.ID): boolean
---@field get_attribute fun(entity: mini_gas.IEntityState, id: mini_gas.ID): number
---@field static_abilities fun(entity: mini_gas.IEntityState): mini_gas.Iterator, any
---@field static_abilities_size fun(entity: mini_gas.IEntityState): integer
---@field has_static_ability fun(entity: mini_gas.IEntityState, def_id: mini_gas.ID): boolean

--- 世界状态接口，由业务方实现
---@class mini_gas.IWorldState

--- 世界模块接口，提供访问世界状态的函数
---@class mini_gas.IWorldModule
---@field entities fun(context: mini_gas.IContext, world: mini_gas.IWorldState): mini_gas.Iterator, any
---@field entities_size fun(context: mini_gas.IContext, world: mini_gas.IWorldState): integer
---@field has_entity fun(context: mini_gas.IContext, world: mini_gas.IWorldState, id: mini_gas.ID): boolean
---@field get_entity fun(context: mini_gas.IContext, world: mini_gas.IWorldState, id: mini_gas.ID): mini_gas.IEntityState, mini_gas.IEntityModule

--- 求值回调接口，由业务方实现
---@class mini_gas.IEvaluation
---@field grant_tags fun(context: mini_gas.IContext, world: mini_gas.IWorldState, defs: mini_gas.Defs, entity: mini_gas.IEntityState, src_entity_id: mini_gas.ID, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, tags: mini_gas.Tag[], ...: unknown)
---@field apply_attribute fun(context: mini_gas.IContext, world: mini_gas.IWorldState, defs: mini_gas.Defs, entity: mini_gas.IEntityState, src_entity_id: mini_gas.ID, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, id: mini_gas.ID, value: number, ...: unknown)

--- ModifierDef.attribute 函数形式
--- 返回属性 ID、数值，以及可选的下一个求值函数
---@alias mini_gas.ModifierAttributeEval fun(context: mini_gas.IContext, world_state: mini_gas.IWorldState, entity: mini_gas.IEntityState, def: mini_gas.ModifierDef, id?: mini_gas.ID, value?: number, ...: unknown): mini_gas.ID, number, mini_gas.ModifierAttributeEval?

--- 修饰器定义
---@class mini_gas.ModifierDef
---@field attribute [mini_gas.ID, number] | mini_gas.ModifierAttributeEval
---@field op mini_gas.EModifierOp
---@field allof_tags? mini_gas.Tag[]
---@field anyof_tags? mini_gas.Tag[]
---@field noneof_tags? mini_gas.Tag[]

--- 效果定义
---@class mini_gas.EffectDef
---@field id mini_gas.ID
---@field modifiers mini_gas.ModifierDef[]
---@field grant_tags? mini_gas.Tag[] 对目标实体应用的标签
---@field allof_tags? mini_gas.Tag[] 效果对目标实体生效的标签约束
---@field anyof_tags? mini_gas.Tag[]
---@field noneof_tags? mini_gas.Tag[]
---@field target? mini_gas.EEffectTarget 效果目标范围；省略时默认为 Self

--- 激活条件（对象形式）
---@class mini_gas.AbilityActivateCondition
---@field allof_tags? mini_gas.Tag[]
---@field anyof_tags? mini_gas.Tag[]
---@field noneof_tags? mini_gas.Tag[]
---@field requires_count integer 激活所需的最小匹配实体数量；省略时默认值为 1
---@field include_self? boolean 统计匹配实体数量时是否包含当前实体自身；默认为 true

--- 激活条件函数
---@alias mini_gas.AbilityActivateConditionFunc fun(context: mini_gas.IContext, defs: mini_gas.Defs, world_state: mini_gas.IWorldState, entity: mini_gas.IEntityState, def: mini_gas.AbilityDef, ...: unknown): boolean, ...

--- 能力定义
---@class mini_gas.AbilityDef
---@field id mini_gas.ID
---@field activation_policy mini_gas.EAbilityActivationPolicy
---@field effects mini_gas.ID[]
---@field can_activate? mini_gas.AbilityActivateCondition | mini_gas.AbilityActivateConditionFunc

--- 能力系统组件入口
---@class mini_gas.ASC
local ASC = {}

return ASC
