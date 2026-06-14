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

    it("tracks stack count per active effect instance", function()
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
        -- Each active instance maintains its own stack count.
        assert.equal(1, a1.stack_count)
        assert.equal(1, a2.stack_count)
        a1.stack_count = 3
        assert.is_true(a1:is_stack_at_limit())
        assert.is_false(a2:is_stack_at_limit())
    end)

    it("resolves scalable_float magnitude", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100)

        local e = effect.GameplayEffect.new({
            name = "Heal",
            duration_policy = "instant",
            modifiers = {
                { attribute_name = "Health", op = "add", magnitude = { type = "scalable_float", value = 15 } },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, level = 1 })
        active:apply_instant()
        assert.equal(115, set:get("Health").current_value)
    end)

    it("resolves attribute_based magnitude", function()
        local set = attr.AttributeSet.new("CombatSet")
        set:register_attribute("Strength", 10)
        set:register_attribute("Damage", 0)

        local e = effect.GameplayEffect.new({
            name = "StrengthDamage",
            duration_policy = "instant",
            modifiers = {
                { attribute_name = "Damage", op = "override", magnitude = { type = "attribute_based", attribute = "Strength", coefficient = 5, pre_multiply = true } },
            },
        })
        local active = effect.ActiveGameplayEffect.new({ effect = e, target_set = set, source_set = set, level = 1 })
        active:apply_instant()
        assert.equal(50, set:get("Damage").current_value)
    end)
end)
