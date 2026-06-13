require("lua_tests.support.env")
local asc = require("cgas.semantics.asc")
local effect = require("cgas.semantics.effect")

describe("cgas.semantics.asc", function()
    local function new_asc()
        local a = asc.ASC.new({})
        assert.is_not_nil(a)
        ---@cast a cgas.semantics.ASC
        return a
    end

    it("creates ASC with injected core components", function()
        local a = new_asc()
        assert.is_not_nil(a.scheduler)
        assert.is_not_nil(a.event_bus)
        assert.is_not_nil(a.time_source)
        assert.is_not_nil(a.registry)
        assert.is_not_nil(a.owned_tags)
    end)

    it("adds attribute sets", function()
        local a = new_asc()
        local HealthSet = { name = "HealthSet" }
        function HealthSet:on_init(set)
            set:register_attribute("Health", 100, { max_value = 100 })
        end
        local set = a:add_attribute_set(HealthSet)
        assert.is_not_nil(set)
        ---@cast set cgas.semantics.AttributeSet
        assert.equal(100, set:get("Health").current_value)
    end)

    it("gives and removes abilities", function()
        local a = new_asc()
        local h, err = a:give_ability({ name = "Fireball" })
        assert.is_nil(err)
        assert.is_number(h)
        ---@cast h integer
        assert.is_true(a:remove_ability(h))
    end)

    it("applies and removes effects", function()
        local a = new_asc()
        local HealthSet = { name = "HealthSet" }
        function HealthSet:on_init(set)
            set:register_attribute("Health", 100, { max_value = 100 })
        end
        a:add_attribute_set(HealthSet)

        local Regen = effect.GameplayEffect.new({
            name = "Regen",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 5.0 },
            modifiers = { { attribute_name = "Health", op = "add", magnitude = 5 } },
        })
        local h, err = a:apply_effect({ effect_class = Regen })
        assert.is_nil(err)
        ---@cast h integer
        local attr = a:get_attribute("HealthSet.Health")
        assert.is_not_nil(attr)
        ---@cast attr cgas.semantics.Attribute
        assert.equal(105, attr.current_value)
        assert.is_true(a:remove_active_effect(h))
    end)

    it("updates active effects", function()
        local a = new_asc()
        local HealthSet = { name = "HealthSet" }
        function HealthSet:on_init(set)
            set:register_attribute("Health", 100, { max_value = 100 })
        end
        a:add_attribute_set(HealthSet)

        local Regen = effect.GameplayEffect.new({
            name = "Regen",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 5.0 },
            modifiers = { { attribute_name = "Health", op = "add", magnitude = 5 } },
        })
        a:apply_effect({ effect_class = Regen })
        a:update(0.1)
        local attr = a:get_attribute("HealthSet.Health")
        assert.is_not_nil(attr)
        ---@cast attr cgas.semantics.Attribute
        assert.equal(105, attr.current_value)
    end)

    it("destroys cleanly", function()
        local a = new_asc()
        local h = a:give_ability({ name = "Fireball" })
        a:destroy()
        assert.is_nil(a.granted_abilities[h])
    end)
end)
