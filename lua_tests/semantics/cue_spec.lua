require("lua_tests.support.env")
local cue = require("cgas.semantics.cue")
local tag = require("cgas.semantics.tag")

describe("cgas.semantics.cue", function()
    it("registers and triggers cue handlers", function()
        local mgr = cue.GameplayCueManager.new()
        local received = nil
        mgr:register(tag.GameplayTag.new("cue.fire"), function(payload)
            received = payload
        end)
        local target = { handle = 1 }
        mgr:trigger(tag.GameplayTag.new("cue.fire"), { target = target })
        assert.is_not_nil(received)
        ---@cast received cgas.semantics.GameplayCuePayload
        assert.equal(target, received.target)
    end)

    it("triggers effect cues by tag", function()
        local mgr = cue.GameplayCueManager.new()
        local count = 0
        mgr:register(tag.GameplayTag.new("cue.fire"), function() count = count + 1 end)
        local Effect = {}
        local c = tag.GameplayTagContainer.new()
        c:add(tag.GameplayTag.new("cue.fire"))
        Effect.granted_tags = c
        mgr:trigger_effect_cues(Effect, "on_apply", { target = ({ handle = 1 }) --[[@as cgas.semantics.ASC]] })
        assert.equal(1, count)
    end)
end)
