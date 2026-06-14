require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local EModifierOp = mini_gas.EModifierOp
local Modifier = mini_gas.Modifier
local GameplayTagContainer = mini_gas.GameplayTagContainer

describe("mini_gas modifier", function()
    it("aggregates Add and Multiply modifiers", function()
        local mods = {
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Add, value = 50 }, 1),
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Multiply, value = 1.2 }, 1),
        }
        local current = mini_gas.calc_attribute(100, mods)
        assert.near(180, current, 0.0001)
    end)

    it("Override takes highest priority", function()
        local mods = {
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Add, value = 100 }, 1),
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Override, value = 300, priority = 1 }, 1),
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Override, value = 200, priority = 2 }, 1),
        }
        local current = mini_gas.calc_attribute(100, mods)
        assert.equal(200, current)
    end)

    it("Compound applies custom function", function()
        local mods = {
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Add, value = 50 }, 1),
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Compound, value = function(v)
                return v * 2
            end, priority = 1 }, 1),
        }
        local current = mini_gas.calc_attribute(100, mods)
        assert.equal(300, current)
    end)

    it("respects require_tags and forbid_tags", function()
        local container = GameplayTagContainer.new()
        container:add("buff.attack")

        local mods = {
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Add, value = 50, require_tags = { "buff.attack" } }, 1),
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Add, value = 30, require_tags = { "buff.missing" } }, 1),
            Modifier.new({ attribute = "attr.attack", op = EModifierOp.Add, value = 20, forbid_tags = { "buff.attack" } }, 1),
        }
        local current = mini_gas.calc_attribute(100, mods, container)
        assert.equal(150, current)
    end)
end)
