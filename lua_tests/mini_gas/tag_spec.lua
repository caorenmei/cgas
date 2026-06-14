require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local GameplayTag = mini_gas.GameplayTag
local GameplayTagContainer = mini_gas.GameplayTagContainer

describe("mini_gas tag", function()
    it("matches exact and parent tags", function()
        local t1 = GameplayTag.new("state.dead")
        local t2 = GameplayTag.new("state.dead")
        local t3 = GameplayTag.new("state")
        local t4 = GameplayTag.new("state.stunned")

        assert.is_true(t1:matches(t2))
        assert.is_true(t1:matches(t3))
        assert.is_true(t3:matches(t1))
        assert.is_false(t1:matches(t4))
    end)

    it("container supports add/remove/has", function()
        local c = GameplayTagContainer.new()
        c:add("state.dead")
        assert.is_true(c:has("state.dead"))
        assert.is_true(c:has("state"))
        assert.is_false(c:has("state.stunned"))

        c:remove("state.dead")
        assert.is_false(c:has("state.dead"))
        assert.is_false(c:has("state"))
    end)

    it("container supports has_any and has_all", function()
        local c = GameplayTagContainer.new()
        c:add("buff.attack")
        c:add("buff.defense")

        assert.is_true(c:has_any({ "buff.attack", "debuff.slow" }))
        assert.is_false(c:has_any({ "debuff.slow", "debuff.stun" }))
        assert.is_true(c:has_all({ "buff.attack", "buff.defense" }))
        assert.is_false(c:has_all({ "buff.attack", "debuff.slow" }))
    end)

    it("granted tags use reference counting by source", function()
        local c = GameplayTagContainer.new()
        c:add("buff.vip", "ability_a")
        c:add("buff.vip", "ability_b")
        assert.is_true(c:has("buff.vip"))

        c:remove("buff.vip", "ability_a")
        assert.is_true(c:has("buff.vip"))

        c:remove("buff.vip", "ability_b")
        assert.is_false(c:has("buff.vip"))
    end)
end)
