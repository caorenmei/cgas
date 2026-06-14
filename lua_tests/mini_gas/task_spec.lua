require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local MiniASC = mini_gas.MiniASC
local GameplayTask = mini_gas.GameplayTask
local EGameplayEvent = mini_gas.EGameplayEvent

describe("mini_gas task", function()
    it("delay task fires after duration", function()
        local state = EntityState.new()
        local fired = false
        GameplayTask.register_task(state, GameplayTask.delay(1, function()
            fired = true
        end))
        MiniASC.update(state, 0.5)
        assert.is_false(fired)
        MiniASC.update(state, 0.6)
        assert.is_true(fired)
    end)

    it("periodic task fires repeatedly", function()
        local state = EntityState.new()
        local count = 0
        GameplayTask.register_task(state, GameplayTask.periodic(1, function()
            count = count + 1
        end, 3))
        MiniASC.update(state, 2.5)
        assert.equal(2, count)
        MiniASC.update(state, 1)
        assert.equal(3, count)
    end)

    it("wait_event task fires on event", function()
        local state = EntityState.new()
        local fired = false
        GameplayTask.register_task(state, GameplayTask.wait_event(EGameplayEvent.TagAdded, function(_)
            fired = true
        end))
        MiniASC.update(state, 0.1)
        assert.is_false(fired)
        MiniASC.add_tag(state, "state.combat")
        assert.is_true(fired)
    end)
end)
