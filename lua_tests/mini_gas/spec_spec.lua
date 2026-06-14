require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local Defs = mini_gas.Defs
local MiniASC = mini_gas.MiniASC
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy

describe("mini_gas spec", function()
    it("ability spec stores def_id level and stack", function()
        local spec = mini_gas.AbilitySpec.new("ability.test", 3, 2)
        assert.equal("ability.test", spec.def_id)
        assert.equal(3, spec.level)
        assert.equal(2, spec.stack)
    end)

    it("effect spec stores def_id level and stack", function()
        local spec = mini_gas.EffectSpec.new("effect.test", 5, 4)
        assert.equal("effect.test", spec.def_id)
        assert.equal(5, spec.level)
        assert.equal(4, spec.stack)
    end)

    it("attribute spec stores def_id and level", function()
        local spec = mini_gas.AttributeSpec.new("attr.test", 7)
        assert.equal("attr.test", spec.def_id)
        assert.equal(7, spec.level)
    end)

    it("business code uses AbilitySpec to lookup def and call give_ability", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = "attr.attack", base = 100 },
        })
        defs.ability_defs["ability.buff"] = {
            id = "ability.buff",
            activation_policy = EAbilityActivationPolicy.Passive,
            effects = {
                {
                    id = "effect.buff",
                    duration_policy = EDurationPolicy.Infinite,
                    modifiers = {
                        { attribute = "attr.attack", op = EModifierOp.Add, value = 10 },
                    },
                },
            },
        }
        local spec = mini_gas.AbilitySpec.new("ability.buff", 2, 1)
        local ability_def = defs.ability_defs[spec.def_id]
        MiniASC.give_ability(state, defs, ability_def, spec.level, spec.stack)
        assert.equal(110, MiniASC.get_current(state, defs, "attr.attack"))
    end)

    it("business code uses EffectSpec to lookup def and call apply_effect", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = "attr.hp", base = 100, min = 0 },
        })
        defs.effect_defs["effect.heal"] = {
            id = "effect.heal",
            duration_policy = EDurationPolicy.Instant,
            modifiers = {
                { attribute = "attr.hp", op = EModifierOp.Add, value = 50 },
            },
        }
        local spec = mini_gas.EffectSpec.new("effect.heal", 1, 1)
        local effect_def = defs.effect_defs[spec.def_id]
        MiniASC.apply_effect(state, defs, effect_def, spec.level, spec.stack)
        assert.equal(150, MiniASC.get_current(state, defs, "attr.hp"))
    end)
end)
