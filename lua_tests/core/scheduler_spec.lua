require("lua_tests.support.env")
local Scheduler = require("cgas.core.scheduler")

describe("cgas.core.scheduler", function()
    it("registers and ticks callbacks by priority", function()
        local s = Scheduler.new()
        local order = {}
        s:register(1, function(dt) table.insert(order, { "a", dt }) end, 10)
        s:register(2, function(dt) table.insert(order, { "b", dt }) end, 5)
        s:update(0.1)
        assert.equal("b", order[1][1])
        assert.equal("a", order[2][1])
        assert.equal(0.1, order[1][2])
    end)

    it("defers callbacks", function()
        local s = Scheduler.new()
        local called = false
        s:defer(function() called = true end, 0.2)
        s:update(0.1)
        assert.is_false(called)
        s:update(0.2)
        assert.is_true(called)
    end)

    it("runs periodic callbacks", function()
        local s = Scheduler.new()
        local count = 0
        s:every(function() count = count + 1 end, 0.5)
        s:update(0.6)
        assert.equal(1, count)
        s:update(0.6)
        assert.equal(2, count)
    end)

    it("cancels jobs", function()
        local s = Scheduler.new()
        local count = 0
        local id = s:every(function() count = count + 1 end, 0.5)
        s:cancel(id)
        s:update(1.0)
        assert.equal(0, count)
    end)

    it("unregisters tick callbacks", function()
        local s = Scheduler.new()
        local count = 0
        s:register(1, function() count = count + 1 end)
        s:unregister(1)
        s:update(0.1)
        assert.equal(0, count)
    end)
end)
