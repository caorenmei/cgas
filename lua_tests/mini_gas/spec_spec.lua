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

    it("register_attributes accepts AttributeSpec", function()
        local state = EntityState.new()
        local defs = Defs.new()
        defs.attribute_defs["attr.hp"] = { name = "attr.hp", base = 100, min = 0 }
        MiniASC.register_attributes(state, defs, {
            mini_gas.AttributeSpec.new("attr.hp", 1),
        })
        assert.equal(100, MiniASC.get_base(state, "attr.hp"))
    end)

    it("give_ability accepts AbilitySpec", function()
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
        MiniASC.give_ability(state, defs, mini_gas.AbilitySpec.new("ability.buff", 2, 1))
        assert.equal(110, MiniASC.get_current(state, defs, "attr.attack"))
    end)

    it("apply_effect accepts EffectSpec", function()
        local state = EntityState.new()
        local defs = Defs.new()
        defs.effect_defs["effect.heal"] = {
            id = "effect.heal",
            duration_policy = EDurationPolicy.Instant,
            modifiers = {
                { attribute = "attr.hp", op = EModifierOp.Add, value = 50 },
            },
        }
        MiniASC.register_attributes(state, defs, {
            { name = "attr.hp", base = 100, min = 0 },
        })
        MiniASC.apply_effect(state, defs, mini_gas.EffectSpec.new("effect.heal", 1, 1))
        assert.equal(150, MiniASC.get_current(state, defs, "attr.hp"))
    end)

    it("remove_ability only removes spawned effects", function()
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
        defs.effect_defs["effect.independent"] = {
            id = "effect.independent",
            duration_policy = EDurationPolicy.Infinite,
            source = "ability.buff",
            modifiers = {
                { attribute = "attr.attack", op = EModifierOp.Add, value = 20 },
            },
        }
        MiniASC.give_ability(state, defs, mini_gas.AbilitySpec.new("ability.buff", 1, 1))
        MiniASC.apply_effect(state, defs, defs.effect_defs["effect.independent"], 1, 1)
        -- 移除技能时不应误删业务方独立应用的效果
        MiniASC.remove_ability(state, "ability.buff")
        assert.equal(120, MiniASC.get_current(state, defs, "attr.attack"))
    end)
end)
