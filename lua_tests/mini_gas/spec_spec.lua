require("lua_tests.support.env")
local mini_gas = require("mini_gas")

describe("mini_gas spec", function()
    it("growth curve uses formula", function()
        local linear = function(level, base, params)
            return base + (level - 1) * (params and params.growth or 0)
        end
        local curve = mini_gas.make_growth_curve(100, { growth = 10 }, linear)
        assert.equal(100, curve:value_at(1))
        assert.equal(110, curve:value_at(2))
        assert.equal(130, curve:value_at(4))
    end)

    it("constant curve returns base when no formula", function()
        local curve = mini_gas.make_growth_curve(42, nil, nil)
        assert.equal(42, curve:value_at(1))
        assert.equal(42, curve:value_at(99))
    end)

    it("ability spec stores level and stack", function()
        local def = { id = "ability.test" }
        local spec = mini_gas.AbilitySpec.new(def, 3, 2)
        assert.equal(3, spec.level)
        assert.equal(2, spec.stack)
        assert.equal(def, spec.def)
    end)

    it("effect spec stores level and stack", function()
        local def = { id = "effect.test" }
        local spec = mini_gas.EffectSpec.new(def, 5, 4)
        assert.equal(5, spec.level)
        assert.equal(4, spec.stack)
    end)

    it("attribute spec stores level", function()
        local def = { name = "attr.test", base = 10 }
        local spec = mini_gas.AttributeSpec.new(def, 7)
        assert.equal(7, spec.level)
    end)
end)
