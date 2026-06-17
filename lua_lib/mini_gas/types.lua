--- MiniGas V2 LuaCATS 类型定义集中文件
--- 本文件仅用于静态类型声明，不执行运行时逻辑

---@meta

--- 通用 ID，可为整数或字符串
---@alias mini_gas.ID integer | string

--- 标签，采用点分层级结构，如 "state.dead"
---@alias mini_gas.Tag string

--- 返回单个迭代值的 Lua 迭代器
---@alias mini_gas.Iterator<P1> fun(state: any, key?: any): P1

--- 返回两个迭代值的 Lua 迭代器
---@alias mini_gas.Iterator2<P1, P2> fun(state: any, key?: any): P1, P2

--- 返回三个迭代值的 Lua 迭代器
---@alias mini_gas.Iterator3<P1, P2, P3> fun(state: any, key?: any): P1, P2, P3

--- 属性定义
---@class mini_gas.AttributeDef
---@field id mini_gas.ID
---@field min? number 属性最小值约束；若定义，ApplyFun 最终拿到的 attributes[id] 已截断到该边界内
---@field max? number 属性最大值约束；若定义，ApplyFun 最终拿到的 attributes[id] 已截断到该边界内

--- 配置定义表
---@class mini_gas.Defs
---@field attribute_defs table<mini_gas.ID, mini_gas.AttributeDef>
---@field effect_defs table<mini_gas.ID, mini_gas.EffectDef>
---@field ability_defs table<mini_gas.ID, mini_gas.AbilityDef>

--- 系统上下文接口，由库的使用者实现
---@class mini_gas.IContext
---@field world mini_gas.IWorldState 世界状态
---@field world_module mini_gas.IWorldModule 访问 world 的模块接口
---@field defs mini_gas.Defs 属性、效果、能力定义
--- 业务方可按需要扩展其它字段

--- 实体状态接口，由库的使用者实现
---@class mini_gas.IEntityState

--- 实体模块接口，提供访问实体状态的函数
--- 所有迭代器函数均返回“迭代函数 + 状态”二元组，业务方实现时应使用 `return next, collection` 或 `return pairs(collection)`，
--- 切勿直接返回 `pairs, collection`，否则 `for ... in module.xxx(entity)` 会因把 `pairs` 本身当作迭代函数而导致死循环。
---@class mini_gas.IEntityModule
---@field static_tags fun(entity: mini_gas.IEntityState): mini_gas.Iterator<mini_gas.Tag>, any
---@field static_tags_size fun(entity: mini_gas.IEntityState): integer
---@field has_static_tag fun(entity: mini_gas.IEntityState, tag: mini_gas.Tag): boolean
---@field attributes fun(entity: mini_gas.IEntityState): mini_gas.Iterator2<mini_gas.ID, number>, any
---@field attributes_size fun(entity: mini_gas.IEntityState): integer
---@field has_attribute fun(entity: mini_gas.IEntityState, id: mini_gas.ID): boolean
---@field get_attribute fun(entity: mini_gas.IEntityState, id: mini_gas.ID): number
---@field static_abilities fun(entity: mini_gas.IEntityState): mini_gas.Iterator2<mini_gas.ID, boolean>, any
---@field static_abilities_size fun(entity: mini_gas.IEntityState): integer
---@field has_static_ability fun(entity: mini_gas.IEntityState, def_id: mini_gas.ID): boolean

--- 世界状态接口，由库的使用者实现
---@class mini_gas.IWorldState

--- 世界模块接口，提供访问世界状态的函数
--- 迭代器函数同样返回“迭代函数 + 状态”二元组，实现方式与 IEntityModule 的迭代器一致。
---@class mini_gas.IWorldModule
---@field entities fun(context: mini_gas.IContext): mini_gas.Iterator3<mini_gas.ID, mini_gas.IEntityState, mini_gas.IEntityModule>, any
---@field entities_size fun(context: mini_gas.IContext): integer
---@field has_entity fun(context: mini_gas.IContext, id: mini_gas.ID): boolean
---@field get_entity fun(context: mini_gas.IContext, id: mini_gas.ID): mini_gas.IEntityState, mini_gas.IEntityModule

--- 调试/追踪接口，所有方法均为可选。
--- 所有方法尾部的 `...` 均为 `ASC.evaluate` 调用者传入的上下文参数，与 `ModifierAttributeEval` 收到的 `modifier_args` 不同。
---@class mini_gas.IDebug
---@field begin_ability? fun(context: mini_gas.IContext, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, ...: unknown)
---@field end_ability? fun(context: mini_gas.IContext, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, ...: unknown)
---@field begin_effect? fun(context: mini_gas.IContext, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, ...: unknown)
---@field end_effect? fun(context: mini_gas.IContext, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, ...: unknown)
---@field begin_modifier? fun(context: mini_gas.IContext, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, modifier_def: mini_gas.ModifierDef, target_entity: mini_gas.IEntityState, target_module: mini_gas.IEntityModule, ...: unknown)
---@field end_modifier? fun(context: mini_gas.IContext, owner_id: mini_gas.ID, owner_entity: mini_gas.IEntityState, owner_module: mini_gas.IEntityModule, ability_def_id: mini_gas.ID, effect_def_id: mini_gas.ID, modifier_def: mini_gas.ModifierDef, target_entity: mini_gas.IEntityState, target_module: mini_gas.IEntityModule, ...: unknown)
---@field step? fun(context: mini_gas.IContext, phase: string, ...: unknown)

--- 最终应用函数：每个实体在全部求值完成后调用一次。
--- 尾部的 `...` 为 `ASC.evaluate` 调用者传入的上下文参数。
---@alias mini_gas.ApplyFun fun(context: mini_gas.IContext, entity: mini_gas.IEntityState, tags: table<mini_gas.Tag, boolean>, attributes: table<mini_gas.ID, number>, ...: unknown)

--- ModifierDef 中 attribute 字段的函数形式定义。
--- 参数包括系统上下文、实体状态、ModifierDef 本身，以及可选的 id 和 value 参数；若需访问世界状态或定义，可通过 context.world / context.defs 获取。
--- 返回一个属性 ID、一个数值，以及一个可选的下一个求值函数；若第三个返回值非 nil，则递归调用该函数继续求值。每次递归返回的 `(id, value)` 都作为一次独立的属性修改参与后续聚合。
--- 首次调用时，id 与 value 均为 nil；后续递归调用时，id 与 value 分别为上一次调用返回的 id 与 value。
--- 参数尾部的 ... 始终为当前 Ability 产生的 modifier_args，其来源如下：
--- - 当 AbilityDef.can_activate 为 AbilityActivateCondition 对象形式时，modifier_args = { count, ... }，其中 count 为满足该条件标签约束的实体数量，后续 ... 来自 ASC.evaluate 调用者传入的上下文；
--- - 当 AbilityDef.can_activate 为 AbilityActivateConditionFunc 函数形式时，modifier_args 即为该函数返回的 ...；
--- - 当 AbilityDef.can_activate 为空时，Ability 默认激活，modifier_args 即为 ASC.evaluate 调用者传入的上下文。
---@alias mini_gas.ModifierAttributeEval fun(context: mini_gas.IContext, entity: mini_gas.IEntityState, def: mini_gas.ModifierDef, id?: mini_gas.ID, value?: number, ...: unknown): mini_gas.ID, number, mini_gas.ModifierAttributeEval?

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
---@field allof_tags? mini_gas.Tag[] 效果对目标实体生效的标签约束；当 target 为 Other / All 时用于筛选目标实体，为 Self 时用于筛选能力所属实体自身
---@field anyof_tags? mini_gas.Tag[]
---@field noneof_tags? mini_gas.Tag[]
---@field target? mini_gas.EEffectTarget 效果目标范围；省略时默认为 Self

--- 激活条件（对象形式）
--- 当 can_activate 为该对象形式时，库会在世界中查找满足本条件标签约束的实体数量；
--- 该数量会作为 ModifierAttributeEval 函数末尾可变参数的第一个参数传入，其余参数来自 ASC.evaluate 调用者传入的上下文信息。
---@class mini_gas.AbilityActivateCondition
---@field allof_tags? mini_gas.Tag[]
---@field anyof_tags? mini_gas.Tag[]
---@field noneof_tags? mini_gas.Tag[]
---@field requires_count integer 激活所需的最小匹配实体数量；当满足上述标签约束的实体数量大于等于该值时，Ability 激活；省略时默认值为 1；设为 0 时表示无需匹配任何实体即可激活
---@field include_self? boolean 统计匹配实体数量时是否包含当前实体自身；默认为 true

--- 激活条件函数
--- 参数 ... 由 ASC.evaluate 的调用者传入，通常包含一些触发事件的来源等上下文信息；若需访问定义或世界状态，可通过 context.defs / context.world 获取。
--- 返回值的 ... 部分会作为 ModifierAttributeEval 函数末尾可变参数传入。
---@alias mini_gas.AbilityActivateConditionFunc fun(context: mini_gas.IContext, entity: mini_gas.IEntityState, def: mini_gas.AbilityDef, ...: unknown): boolean, ...

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
