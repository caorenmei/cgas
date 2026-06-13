require("lua_tests.support.env")
local attr = require("cgas.semantics.attribute")

describe("cgas.semantics.attribute", function()
    it("creates attribute with default values", function()
        local a = attr.Attribute.new("Health", 100)
        assert.equal(100, a.base_value)
        assert.equal(100, a.current_value)
    end)

    it("applies add modifiers", function()
        local a = attr.Attribute.new("Health", 100)
        a:recalculate({
            { attribute_name = "Health", op = "add", magnitude = 20 },
        })
        assert.equal(120, a.current_value)
    end)

    it("applies multiply after add", function()
        local a = attr.Attribute.new("Health", 100)
        a:recalculate({
            { attribute_name = "Health", op = "add", magnitude = 50 },
            { attribute_name = "Health", op = "multiply", magnitude = 2 },
        })
        assert.equal(300, a.current_value)
    end)

    it("applies override", function()
        local a = attr.Attribute.new("Health", 100)
        a:recalculate({
            { attribute_name = "Health", op = "add", magnitude = 50 },
            { attribute_name = "Health", op = "override", magnitude = 10 },
        })
        assert.equal(10, a.current_value)
    end)

    it("clamps current value", function()
        local a = attr.Attribute.new("Health", 100, { min_value = 0, max_value = 100 })
        a.base_value = 150
        a:recalculate({})
        assert.equal(100, a.current_value)
        a.base_value = -10
        a:recalculate({})
        assert.equal(0, a.current_value)
    end)

    it("supports attribute sets", function()
        local set = attr.AttributeSet.new("HealthSet")
        set:register_attribute("Health", 100, { max_value = 100 })
        assert.equal("HealthSet", set.name)
        assert.equal(100, set:get("Health").base_value)
    end)

    it("tracks base and current change", function()
        local a = attr.Attribute.new("Health", 100)
        local events = {}
        a.on_base_changed = function(oldv, newv)
            table.insert(events, { "base", oldv, newv })
        end
        a:set_base(80)
        assert.equal("base", events[1][1])
        assert.equal(80, events[1][3])
    end)
end)
