require("lua_tests.support.env")
local effect = require("cgas.semantics.effect")
local attr = require("cgas.semantics.attribute")

describe("cgas.semantics.effect", function()
    it("creates instant effect spec", function()
        local e = effect.GameplayEffect.new({
            name = "Damage",
            duration_policy = "instant",
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = -10 },
            },
        })
        assert.equal("instant", e.duration_policy)
    end)

    it("applies instant effect to attribute set", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Damage",
            duration_policy = "instant",
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = -10 },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:apply_instant()
        assert.equal(90, set:get("Health").current_value)
    end)

    it("applies duration effect", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Regen",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 2.0 },
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = 5 },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:on_apply()
        assert.equal(105, set:get("Health").current_value)
    end)

    it("updates duration and expires", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Regen",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 1.0 },
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = 5 },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:on_apply()
        active:update(1.1)
        assert.is_true(active:is_expired())
    end)

    it("handles periodic effects", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Poison",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 2.0 },
            period = 0.5,
            periodic_instant = true,
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = -5 },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:on_apply()
        active:update(0.6)
        assert.equal(90, set:get("Health").current_value)
        active:update(0.6)
        assert.equal(80, set:get("Health").current_value)
    end)

    it("stacks effects by target", function()
        local e = effect.GameplayEffect.new({
            name = "Buff",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 5.0 },
            stacking_policy = "aggregate_by_target",
            stack_limit = 3,
            modifiers = {
                { attribute_name = "Strength", op = "add", magnitude = 5 },
            },
        })
        local a1 = effect.ActiveGameplayEffect.new({ effect = e, level = 1 })
        local a2 = effect.ActiveGameplayEffect.new({ effect = e, level = 1 })
        a1:on_apply()
        a2:on_apply()
        assert.equal(2, a1.stack_count)
        a2.stack_count = 3
        assert.is_true(a1:is_stack_at_limit())
    end)
end)
