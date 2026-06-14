require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local MiniASC = mini_gas.MiniASC
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EStackingPolicy = mini_gas.EStackingPolicy

describe("mini_gas effect", function()
    local EAttribute, EEffectId

    before_each(function()
        EAttribute = {
            Hp = "attr.hp",
            Attack = "attr.attack",
            Gold = "attr.gold",
        }
        EEffectId = {
            Heal = "effect.heal",
            BuffAttack = "effect.buff.attack",
            Dot = "effect.dot",
            Stacking = "effect.stacking",
        }
    end)

    it("instant effect modifies current directly", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Hp, base = 100, min = 0, max = 100 },
        })
        MiniASC.apply_effect(state, {
            id = EEffectId.Heal,
            duration_policy = EDurationPolicy.Instant,
            modifiers = {
                { attribute = EAttribute.Hp, op = EModifierOp.Add, value = -20 },
            },
        }, 1, 1)
        assert.equal(80, MiniASC.get_current(state, EAttribute.Hp))
    end)

    it("infinite effect aggregates until removed", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Attack, base = 100 },
        })
        MiniASC.apply_effect(state, {
            id = EEffectId.BuffAttack,
            duration_policy = EDurationPolicy.Infinite,
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 50 },
            },
        }, 1, 1)
        assert.equal(150, MiniASC.get_current(state, EAttribute.Attack))

        MiniASC.remove_effect(state, EEffectId.BuffAttack)
        assert.equal(100, MiniASC.get_current(state, EAttribute.Attack))
    end)

    it("duration effect expires after time", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Attack, base = 100 },
        })
        MiniASC.apply_effect(state, {
            id = EEffectId.BuffAttack,
            duration_policy = EDurationPolicy.HasDuration,
            duration = 2,
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 50 },
            },
        }, 1, 1)
        assert.equal(150, MiniASC.get_current(state, EAttribute.Attack))

        MiniASC.update(state, 1)
        assert.equal(150, MiniASC.get_current(state, EAttribute.Attack))

        MiniASC.update(state, 1)
        assert.equal(100, MiniASC.get_current(state, EAttribute.Attack))
    end)

    it("periodic effect triggers over time", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Gold, base = 0, min = 0 },
        })
        MiniASC.apply_effect(state, {
            id = EEffectId.Dot,
            duration_policy = EDurationPolicy.Infinite,
            period = 1,
            modifiers = {
                { attribute = EAttribute.Gold, op = EModifierOp.Add, value = 10 },
            },
        }, 1, 1)

        MiniASC.update(state, 2.5)
        assert.equal(20, MiniASC.get_current(state, EAttribute.Gold))
    end)

    it("stacking Add increases stack", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Attack, base = 100 },
        })
        local def = {
            id = EEffectId.Stacking,
            duration_policy = EDurationPolicy.Infinite,
            stacking = EStackingPolicy.Add,
            max_stack = 5,
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 10 },
            },
        }
        MiniASC.apply_effect(state, def, 1, 1)
        MiniASC.apply_effect(state, def, 1, 2)
        assert.equal(130, MiniASC.get_current(state, EAttribute.Attack))
    end)

    it("stacking Refresh refreshes duration", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Attack, base = 100 },
        })
        local def = {
            id = EEffectId.BuffAttack,
            duration_policy = EDurationPolicy.HasDuration,
            duration = 2,
            stacking = EStackingPolicy.Refresh,
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 50 },
            },
        }
        MiniASC.apply_effect(state, def, 1, 1)
        MiniASC.update(state, 1)
        MiniASC.apply_effect(state, def, 1, 1)
        MiniASC.update(state, 1.5)
        assert.equal(150, MiniASC.get_current(state, EAttribute.Attack))
    end)
end)
