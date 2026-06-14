require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local Defs = mini_gas.Defs
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
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Attack, base = 100 },
        })

        assert.equal(100, MiniASC.get_base(state, EAttribute.Attack))
        assert.equal(100, MiniASC.get_current(state, defs, EAttribute.Attack))
    end)

    it("clamps current value to min/max", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Hp, base = 100, min = 0, max = 100 },
        })

        MiniASC.set_current(state, defs, EAttribute.Hp, 150)
        assert.equal(100, MiniASC.get_current(state, defs, EAttribute.Hp))

        MiniASC.set_current(state, defs, EAttribute.Hp, -10)
        assert.equal(0, MiniASC.get_current(state, defs, EAttribute.Hp))
    end)

    it("sets current directly", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Hp, base = 100, min = 0 },
        })
        MiniASC.set_current(state, defs, EAttribute.Hp, 80)
        assert.equal(80, MiniASC.get_current(state, defs, EAttribute.Hp))
    end)
end)
