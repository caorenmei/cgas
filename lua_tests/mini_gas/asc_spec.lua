require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local state_mod = require("mini_gas.state")
local EntityState = mini_gas.EntityState
local WorldState = mini_gas.WorldState
local MiniASC = mini_gas.MiniASC
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy

describe("mini_gas asc", function()
    local EAttribute, EEffectId, ETag

    before_each(function()
        EAttribute = {
            Attack = "attr.attack",
            Defense = "attr.defense",
            Gold = "attr.gold",
            Iron = "attr.iron",
            Mp = "attr.mp",
            GoldGainRate = "attr.gold_gain_rate",
            ExpGainRate = "attr.exp_gain_rate",
        }
        EEffectId = {
            Sword = "effect.equip.sword",
            Vip = "effect.vip",
            GoldMine = "effect.building.gold_mine",
            IronMine = "effect.building.iron_mine",
        }
        ETag = {
            Vip = "buff.vip",
            Silenced = "state.silenced",
            PetActive = "pet.active",
        }
    end)

    it("full example: equipment + vip + building production", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Attack, base = 100, min = 0 },
            { name = EAttribute.Defense, base = 50, min = 0 },
            { name = EAttribute.Gold, base = 0, min = 0 },
            { name = EAttribute.Iron, base = 0, min = 0 },
            { name = EAttribute.GoldGainRate, base = 1.0, min = 0 },
            { name = EAttribute.ExpGainRate, base = 1.0, min = 0 },
        })

        MiniASC.apply_effect(state, {
            id = EEffectId.Sword,
            duration_policy = EDurationPolicy.Infinite,
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 80 },
                { attribute = EAttribute.Defense, op = EModifierOp.Add, value = 30 },
            },
        }, 1, 1)

        MiniASC.apply_effect(state, {
            id = EEffectId.Vip,
            duration_policy = EDurationPolicy.Infinite,
            granted_tags = { ETag.Vip },
            modifiers = {
                { attribute = EAttribute.GoldGainRate, op = EModifierOp.Multiply, value = 1.2 },
                { attribute = EAttribute.ExpGainRate, op = EModifierOp.Multiply, value = 1.1 },
            },
        }, 1, 1)

        MiniASC.apply_effect(state, {
            id = EEffectId.GoldMine,
            duration_policy = EDurationPolicy.Infinite,
            period = 60,
            modifiers = {
                { attribute = EAttribute.Gold, op = EModifierOp.Add, value = 100 },
                { attribute = EAttribute.Gold, op = EModifierOp.Multiply, value = 1.2, require_tags = { ETag.Vip } },
            },
        }, 1, 1)

        MiniASC.apply_effect(state, {
            id = EEffectId.IronMine,
            duration_policy = EDurationPolicy.Infinite,
            period = 60,
            modifiers = {
                { attribute = EAttribute.Iron, op = EModifierOp.Add, value = 50 },
                { attribute = EAttribute.Iron, op = EModifierOp.Multiply, value = 1.2, require_tags = { ETag.Vip } },
            },
        }, 1, 1)

        MiniASC.update(state, 120)

        assert.equal(180, MiniASC.get_current(state, EAttribute.Attack))
        assert.equal(80, MiniASC.get_current(state, EAttribute.Defense))
        assert.near(1.2, MiniASC.get_current(state, EAttribute.GoldGainRate), 0.0001)
        assert.near(240, MiniASC.get_current(state, EAttribute.Gold), 0.0001)
        assert.near(120, MiniASC.get_current(state, EAttribute.Iron), 0.0001)
    end)

    it("update_world updates all entities", function()
        local world = WorldState.new()
        local state1 = EntityState.new()
        local state2 = EntityState.new()
        MiniASC.register_attributes(state1, { { name = EAttribute.Gold, base = 0, min = 0 } })
        MiniASC.register_attributes(state2, { { name = EAttribute.Gold, base = 0, min = 0 } })
        MiniASC.apply_effect(state1, {
            id = EEffectId.GoldMine,
            duration_policy = EDurationPolicy.Infinite,
            period = 1,
            modifiers = { { attribute = EAttribute.Gold, op = EModifierOp.Add, value = 1 } },
        }, 1, 1)
        MiniASC.apply_effect(state2, {
            id = EEffectId.GoldMine,
            duration_policy = EDurationPolicy.Infinite,
            period = 1,
            modifiers = { { attribute = EAttribute.Gold, op = EModifierOp.Add, value = 2 } },
        }, 1, 1)
        state_mod.register_entity(world, "s1", state1)
        state_mod.register_entity(world, "s2", state2)

        MiniASC.update_world(world, 3)
        assert.equal(3, MiniASC.get_current(state1, EAttribute.Gold))
        assert.equal(6, MiniASC.get_current(state2, EAttribute.Gold))
    end)

    it("listen_event receives dispatched events", function()
        local state = EntityState.new()
        local received = nil
        MiniASC.listen_event(state, mini_gas.EGameplayEvent.TagAdded, function(payload)
            received = payload
        end)
        MiniASC.add_tag(state, ETag.Silenced)
        assert.is_not_nil(received)
        local tag = received and received.tag
        assert.equal(ETag.Silenced, tag)
    end)
end)
