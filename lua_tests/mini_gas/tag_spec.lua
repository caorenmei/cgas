require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local tag_mod = require("mini_gas.tag")
local GameplayTag = mini_gas.GameplayTag
local GameplayTagContainer = mini_gas.GameplayTagContainer

describe("mini_gas tag", function()
    it("matches exact and parent tags", function()
        local t1 = GameplayTag.new("state.dead")
        local t2 = GameplayTag.new("state.dead")
        local t3 = GameplayTag.new("state")
        local t4 = GameplayTag.new("state.stunned")

        assert.is_true(tag_mod.matches(t1, t2))
        assert.is_true(tag_mod.matches(t1, t3))
        assert.is_true(tag_mod.matches(t3, t1))
        assert.is_false(tag_mod.matches(t1, t4))
    end)

    it("container supports add/remove/has", function()
        local c = GameplayTagContainer.new()
        tag_mod.add(c, "state.dead")
        assert.is_true(tag_mod.has(c, "state.dead"))
        assert.is_true(tag_mod.has(c, "state"))
        assert.is_false(tag_mod.has(c, "state.stunned"))

        tag_mod.remove(c, "state.dead")
        assert.is_false(tag_mod.has(c, "state.dead"))
        assert.is_false(tag_mod.has(c, "state"))
    end)

    it("container supports has_any and has_all", function()
        local c = GameplayTagContainer.new()
        tag_mod.add(c, "buff.attack")
        tag_mod.add(c, "buff.defense")

        assert.is_true(tag_mod.has_any(c, { "buff.attack", "debuff.slow" }))
        assert.is_false(tag_mod.has_any(c, { "debuff.slow", "debuff.stun" }))
        assert.is_true(tag_mod.has_all(c, { "buff.attack", "buff.defense" }))
        assert.is_false(tag_mod.has_all(c, { "buff.attack", "debuff.slow" }))
    end)

    it("granted tags use reference counting by source", function()
        local c = GameplayTagContainer.new()
        tag_mod.add(c, "buff.vip", "ability_a")
        tag_mod.add(c, "buff.vip", "ability_b")
        assert.is_true(tag_mod.has(c, "buff.vip"))

        tag_mod.remove(c, "buff.vip", "ability_a")
        assert.is_true(tag_mod.has(c, "buff.vip"))

        tag_mod.remove(c, "buff.vip", "ability_b")
        assert.is_false(tag_mod.has(c, "buff.vip"))
    end)
end)
