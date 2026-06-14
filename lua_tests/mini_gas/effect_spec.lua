require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local Defs = mini_gas.Defs
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
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Hp, base = 100, min = 0, max = 100 },
        })
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.Heal,
            duration_policy = EDurationPolicy.Instant,
            modifiers = {
                { attribute = EAttribute.Hp, op = EModifierOp.Add, value = -20 },
            },
        }, 1)
        assert.equal(80, MiniASC.get_current(state, defs, EAttribute.Hp))
    end)

    it("infinite effect aggregates until removed", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Attack, base = 100 },
        })
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.BuffAttack,
            duration_policy = EDurationPolicy.Infinite,
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 50 },
            },
        }, 1)
        assert.equal(150, MiniASC.get_current(state, defs, EAttribute.Attack))

        MiniASC.remove_effect(state, EEffectId.BuffAttack)
        assert.equal(100, MiniASC.get_current(state, defs, EAttribute.Attack))
    end)

    it("duration effect expires after time", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Attack, base = 100 },
        })
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.BuffAttack,
            duration_policy = EDurationPolicy.HasDuration,
            duration = 2,
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 50 },
            },
        }, 1)
        assert.equal(150, MiniASC.get_current(state, defs, EAttribute.Attack))

        MiniASC.update(state, defs, 1)
        assert.equal(150, MiniASC.get_current(state, defs, EAttribute.Attack))

        MiniASC.update(state, defs, 1)
        assert.equal(100, MiniASC.get_current(state, defs, EAttribute.Attack))
    end)

    it("periodic effect triggers over time", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Gold, base = 0, min = 0 },
        })
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.Dot,
            duration_policy = EDurationPolicy.Infinite,
            period = 1,
            modifiers = {
                { attribute = EAttribute.Gold, op = EModifierOp.Add, value = 10 },
            },
        }, 1)

        MiniASC.update(state, defs, 2.5)
        assert.equal(20, MiniASC.get_current(state, defs, EAttribute.Gold))
    end)

    it("stacking Add increases stack", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
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
        MiniASC.apply_effect(state, defs, def, 1)
        MiniASC.apply_effect(state, defs, def, 2)
        assert.equal(130, MiniASC.get_current(state, defs, EAttribute.Attack))
    end)

    it("instant effect supports compound modifier", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Hp, base = 100, min = 0 },
        })
        MiniASC.apply_effect(state, defs, {
            id = EEffectId.Heal,
            duration_policy = EDurationPolicy.Instant,
            modifiers = {
                { attribute = EAttribute.Hp, op = EModifierOp.Compound, value = function(_, v) return v * 2 end },
            },
        }, 1)
        assert.equal(200, MiniASC.get_current(state, defs, EAttribute.Hp))
    end)

    it("stacking Refresh refreshes duration", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
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
        MiniASC.apply_effect(state, defs, def, 1)
        MiniASC.update(state, defs, 1)
        MiniASC.apply_effect(state, defs, def, 1)
        MiniASC.update(state, defs, 1.5)
        assert.equal(150, MiniASC.get_current(state, defs, EAttribute.Attack))
    end)

    it("effect subclass with level scales modifier via compound", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Attack, base = 100 },
        })
        local leveled_buff_def = {
            id = "effect.buff.leveled",
            duration_policy = EDurationPolicy.Infinite,
            level = 4,
            modifiers = {
                { attribute = EAttribute.Attack, op = EModifierOp.Compound, value = function(mod, v) return v + mod.level * 10 end },
            },
        }
        MiniASC.apply_effect(state, defs, leveled_buff_def)
        assert.equal(140, MiniASC.get_current(state, defs, EAttribute.Attack))
    end)
end)
