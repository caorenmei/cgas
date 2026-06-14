require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local MiniASC = mini_gas.MiniASC

describe("mini_gas attribute", function()
    local EAttribute

    before_each(function()
        EAttribute = {
            Hp = "attr.hp",
            MaxHp = "attr.max_hp",
            Attack = "attr.attack",
        }
    end)

    it("registers attributes and reads base/current", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Attack, base = 100 },
        })

        assert.equal(100, MiniASC.get_base(state, EAttribute.Attack))
        assert.equal(100, MiniASC.get_current(state, EAttribute.Attack))
    end)

    it("supports growth curve for base value", function()
        local state = EntityState.new()
        local linear = function(level, base, params)
            return base + (level - 1) * (params and params.growth or 0)
        end
        MiniASC.register_attributes(state, {
            { name = EAttribute.Attack, base = 100, growth = mini_gas.make_growth_curve(function(level)
                return linear(level, 100, { growth = 10 })
            end) },
        })

        assert.equal(100, MiniASC.get_base(state, EAttribute.Attack))
    end)

    it("clamps current value to min/max", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Hp, base = 100, min = 0, max = 100 },
        })

        MiniASC.set_current(state, EAttribute.Hp, 150)
        assert.equal(100, MiniASC.get_current(state, EAttribute.Hp))

        MiniASC.set_current(state, EAttribute.Hp, -10)
        assert.equal(0, MiniASC.get_current(state, EAttribute.Hp))
    end)

    it("sets current directly", function()
        local state = EntityState.new()
        MiniASC.register_attributes(state, {
            { name = EAttribute.Hp, base = 100, min = 0 },
        })
        MiniASC.set_current(state, EAttribute.Hp, 80)
        assert.equal(80, MiniASC.get_current(state, EAttribute.Hp))
    end)
end)
