require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local tag_mod = require("mini_gas.tag")
local EModifierOp = mini_gas.EModifierOp
local Modifier = mini_gas.Modifier
local GameplayTagContainer = require("mini_gas.tag").GameplayTagContainer

local function make_state(effect_id, modifiers)
    local state = mini_gas.EntityState.new()
    state._effect_defs[effect_id] = {
        id = effect_id,
        duration_policy = mini_gas.EDurationPolicy.Infinite,
        modifiers = modifiers,
    }
    return state
end

describe("mini_gas modifier", function()
    it("aggregates Add and Multiply modifiers", function()
        local effect_id = "effect.test"
        local state = make_state(effect_id, {
            { attribute = "attr.attack", op = EModifierOp.Add, value = 50 },
            { attribute = "attr.attack", op = EModifierOp.Multiply, value = 1.2 },
        })
        local mods = {
            Modifier.new(effect_id, 1, 1),
            Modifier.new(effect_id, 2, 1),
        }
        local current = mini_gas.calc_attribute(100, state, mods)
        assert.near(180, current, 0.0001)
    end)

    it("Override takes highest priority", function()
        local effect_id = "effect.test"
        local state = make_state(effect_id, {
            { attribute = "attr.attack", op = EModifierOp.Add, value = 100 },
            { attribute = "attr.attack", op = EModifierOp.Override, value = 300, priority = 1 },
            { attribute = "attr.attack", op = EModifierOp.Override, value = 200, priority = 2 },
        })
        local mods = {
            Modifier.new(effect_id, 1, 1),
            Modifier.new(effect_id, 2, 1),
            Modifier.new(effect_id, 3, 1),
        }
        local current = mini_gas.calc_attribute(100, state, mods)
        assert.equal(200, current)
    end)

    it("Compound applies custom function", function()
        local effect_id = "effect.test"
        local state = make_state(effect_id, {
            { attribute = "attr.attack", op = EModifierOp.Add, value = 50 },
            { attribute = "attr.attack", op = EModifierOp.Compound, value = function(_, v)
                return v * 2
            end, priority = 1 },
        })
        local mods = {
            Modifier.new(effect_id, 1, 1),
            Modifier.new(effect_id, 2, 1),
        }
        local current = mini_gas.calc_attribute(100, state, mods)
        assert.equal(300, current)
    end)

    it("respects require_tags and blocked_tags", function()
        local container = GameplayTagContainer.new()
        tag_mod.add(container, "buff.attack")

        local effect_id = "effect.test"
        local state = make_state(effect_id, {
            { attribute = "attr.attack", op = EModifierOp.Add, value = 50, require_tags = { "buff.attack" } },
            { attribute = "attr.attack", op = EModifierOp.Add, value = 30, require_tags = { "buff.missing" } },
            { attribute = "attr.attack", op = EModifierOp.Add, value = 20, blocked_tags = { "buff.attack" } },
        })
        state.tags = container
        local mods = {
            Modifier.new(effect_id, 1, 1),
            Modifier.new(effect_id, 2, 1),
            Modifier.new(effect_id, 3, 1),
        }
        local current = mini_gas.calc_attribute(100, state, mods)
        assert.equal(150, current)
    end)
end)
