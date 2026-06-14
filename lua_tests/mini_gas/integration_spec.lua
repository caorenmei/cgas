require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local state_mod = require("mini_gas.state")
local EntityState = mini_gas.EntityState
local WorldState = mini_gas.WorldState
local Defs = mini_gas.Defs
local MiniASC = mini_gas.MiniASC
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy

describe("mini_gas integration", function()
    it("heroes, equipment, pets, city and privileges interact via tags", function()
        -- 项目级枚举（来自策划配置的 alias）
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

        local ETag = {
            State_Combat = "state.combat",
            Pet_Active = "pet.active",
            Buff_Vip = "buff.vip",
            State_Silenced = "state.silenced",
        }

        local EAbilityId = {
            HeroAttack = "ability.hero_attack",
        }

        local EEffectId = {
            EquipSword = "effect.equip.sword",
            PetDragon = "effect.pet.dragon",
            VipPrivilege = "effect.vip.privilege",
            HeroAttackDamage = "effect.hero.attack_damage",
            BuildingGoldMine = "effect.building.gold_mine",
            BuildingIronMine = "effect.building.iron_mine",
        }

        local function make_linear(base, growth)
            return function(_, level)
                return base + (level - 1) * growth
            end
        end

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

        -- 装备：传说之剑
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.EquipSword,
            duration_policy = EDurationPolicy.Infinite,
            modifiers = {
                { attribute = EAttribute.Attack,  op = EModifierOp.Add, value = 80 },
                { attribute = EAttribute.Defense, op = EModifierOp.Add, value = 30 },
            },
        }, 1)

        -- 宠物：小龙（5 级）
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.PetDragon,
            duration_policy = EDurationPolicy.Infinite,
            granted_tags = { ETag.Pet_Active },
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Add, value = make_linear(20, 5)(nil, 5) },
            },
        }, 1)

        -- VIP 特权
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

        -- 金矿
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.BuildingGoldMine,
            duration_policy = EDurationPolicy.Infinite,
            period = 60,
            modifiers = {
                { attribute = EAttribute.Gold, op = EModifierOp.Add, value = 100 },
                { attribute = EAttribute.Gold, op = EModifierOp.Multiply, value = 1.2, require_tags = { ETag.Buff_Vip } },
            },
        }, 1)

        -- 铁矿厂
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.BuildingIronMine,
            duration_policy = EDurationPolicy.Infinite,
            period = 60,
            modifiers = {
                { attribute = EAttribute.Iron, op = EModifierOp.Add, value = 50 },
                { attribute = EAttribute.Iron, op = EModifierOp.Multiply, value = 1.2, require_tags = { ETag.Buff_Vip } },
            },
        }, 1)

        -- WorldState 管理
        local world = WorldState.new()
        state_mod.register_entity(world, "player", state)

        MiniASC.update_world(world, defs, 120)

        -- 携带宠物且未被沉默，技能可以激活
        local ok1 = MiniASC.try_activate_ability(state, defs, EAbilityId.HeroAttack)
        assert.is_true(ok1)

        -- 被沉默时无法激活
        MiniASC.add_tag(state, ETag.State_Silenced)
        local ok2 = MiniASC.try_activate_ability(state, defs, EAbilityId.HeroAttack)
        assert.is_false(ok2)
        MiniASC.remove_tag(state, ETag.State_Silenced)

        -- 验证最终数值
        assert.equal(220, MiniASC.get_current(state, defs, EAttribute.Attack))
        assert.equal(80, MiniASC.get_current(state, defs, EAttribute.Defense))
        assert.near(1.2, MiniASC.get_current(state, defs, EAttribute.GoldGainRate), 0.0001)
        assert.near(240, MiniASC.get_current(state, defs, EAttribute.Gold), 0.0001)
        assert.near(120, MiniASC.get_current(state, defs, EAttribute.Iron), 0.0001)

        -- 技能消耗了 Mp
        assert.equal(190, MiniASC.get_current(state, defs, EAttribute.Mp))

        -- 整个世界状态可序列化为纯 Lua 表
        assert.is_table(world.entities)
        assert.is_table(world.entities.player)
    end)
end)
