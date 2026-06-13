require("lua_tests.support.env")
local task = require("cgas.semantics.task")

describe("cgas.semantics.task", function()
    it("waits for delay", function()
        local fake_ability = { active_tasks = {} }
        local t = task.TaskWaitDelay.new(fake_ability, 1.0)
        local finished = false
        t.on_finished = function() finished = true end
        t:start()
        assert.equal("running", t.state)
        t:update(0.5)
        assert.is_false(finished)
        t:update(0.6)
        assert.is_true(finished)
        assert.equal("finished", t.state)
    end)

    it("cleans up when ability ends", function()
        local fake_ability = { active_tasks = {} }
        local t = task.TaskWaitDelay.new(fake_ability, 1.0)
        t:start()
        assert.is_not_nil(fake_ability.active_tasks[t.handle])
        t:finish(nil)
        assert.is_nil(fake_ability.active_tasks[t.handle])
    end)

    it("emits gameplay event", function()
        local received = nil
        local bus = {
            subscribe = function(_, name, fn) received = { name = name, fn = fn } return 1 end,
            unsubscribe = function() received = nil end,
        }
        local fake_ability = { asc = { event_bus = bus }, active_tasks = {} }
        local t = task.TaskWaitGameplayEvent.new(fake_ability, "my_event")
        t:start()
        assert.equal("my_event", received.name)
        received.fn({ value = 42 })
        assert.equal("finished", t.state)
    end)
end)
