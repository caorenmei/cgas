require("lua_tests.support.env")
local EventBus = require("cgas.core.event")

describe("cgas.core.event", function()
    it("dispatches subscribed events", function()
        local bus = EventBus.new()
        local received = nil
        bus:subscribe("test", function(payload)
            received = payload
        end)
        bus:emit("test", { value = 42 })
        bus:dispatch()
        assert.is_not_nil(received)
        ---@cast received table
        assert.equal(42, received.value)
    end)

    it("does not dispatch immediately", function()
        local bus = EventBus.new()
        local called = false
        bus:subscribe("test", function() called = true end)
        bus:emit("test", {})
        assert.is_false(called)
    end)

    it("queues events emitted during dispatch", function()
        local bus = EventBus.new()
        local count = 0
        bus:subscribe("a", function()
            count = count + 1
            bus:emit("b", {})
        end)
        bus:subscribe("b", function()
            count = count + 1
        end)
        bus:emit("a", {})
        bus:dispatch()
        assert.equal(1, count)
        bus:dispatch()
        assert.equal(2, count)
    end)

    it("isolates listener errors", function()
        local bus = EventBus.new()
        local called = false
        bus:subscribe("test", function() error("boom") end)
        bus:subscribe("test", function() called = true end)
        bus:emit("test", {})
        bus:dispatch()
        assert.is_true(called)
    end)

    it("supports unsubscribe", function()
        local bus = EventBus.new()
        local called = false
        local id = bus:subscribe("test", function() called = true end)
        bus:unsubscribe(id)
        bus:emit("test", {})
        bus:dispatch()
        assert.is_false(called)
    end)
end)
