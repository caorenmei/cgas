require("lua_tests.support.env")
local Registry = require("cgas.core.registry")

describe("cgas.core.registry", function()
    it("registers and retrieves ability classes", function()
        local r = Registry.new()
        local cls = { name = "Fireball" }
        r:register_ability("Fireball", cls)
        assert.equal(cls, r:get("ability", "Fireball"))
    end)

    it("registers and retrieves effect classes", function()
        local r = Registry.new()
        local cls = { name = "Burning" }
        r:register_effect("Burning", cls)
        assert.equal(cls, r:get("effect", "Burning"))
    end)

    it("registers and retrieves attribute set classes", function()
        local r = Registry.new()
        local cls = { name = "HealthSet" }
        r:register_attribute_set("HealthSet", cls)
        assert.equal(cls, r:get("attribute_set", "HealthSet"))
    end)

    it("returns nil for unknown classes", function()
        local r = Registry.new()
        assert.is_nil(r:get("ability", "Nothing"))
    end)
end)
