require("lua_tests.support.env")
local demo = require("mini_gas.demo.weihu_shan")

describe("智取威虎山-献图 demo", function()
    it("初始化游戏状态：杨子荣持有先遣图、具备初始属性与应对技能", function()
        local state = demo.new_game()

        assert.is_true(demo.has_tag(state, demo.ETag.HasSecretMap))
        assert.is_true(demo.has_tag(state, demo.ETag.UnderInterrogation))
        assert.equal(0, demo.get_credibility(state))
        assert.equal(0, demo.get_suspicion(state))
        assert.equal(50, demo.get_courage(state))
        assert.equal(50, demo.get_eloquence(state))

        -- 具备所有应对技能
        assert.is_true(demo.can_use_ability(state, demo.EAbilityId.AnswerLingo))
        assert.is_true(demo.can_use_ability(state, demo.EAbilityId.BragBackground))
        assert.is_true(demo.can_use_ability(state, demo.EAbilityId.PledgeLoyalty))
        assert.is_true(demo.can_use_ability(state, demo.EAbilityId.KeepCalm))
        assert.is_true(demo.can_use_ability(state, demo.EAbilityId.ShowMap))
    end)

    it("对黑话成功：增加可信度", function()
        local state = demo.new_game()
        local result = demo.act(state, demo.EAbilityId.AnswerLingo, "success")

        assert.is_true(result.success)
        assert.is_true(result.credibility_increased)
        assert.is_false(demo.is_game_over(state))
    end)

    it("对黑话失败：增加怀疑值", function()
        local state = demo.new_game()
        local result = demo.act(state, demo.EAbilityId.AnswerLingo, "fail")

        assert.is_false(result.success)
        assert.is_true(result.suspicion_increased)
    end)

    it("搬门子成功：增加可信度", function()
        local state = demo.new_game()
        local old = demo.get_credibility(state)
        local result = demo.act(state, demo.EAbilityId.BragBackground, "success")

        assert.is_true(result.success)
        assert.is_true(demo.get_credibility(state) > old)
    end)

    it("表忠心：增加少量可信度", function()
        local state = demo.new_game()
        local old = demo.get_credibility(state)
        local result = demo.act(state, demo.EAbilityId.PledgeLoyalty)

        assert.is_true(result.success)
        assert.is_true(demo.get_credibility(state) > old)
    end)

    it("镇定自若：降低怀疑值", function()
        local state = demo.new_game()
        -- 先让怀疑值上升
        demo.act(state, demo.EAbilityId.AnswerLingo, "fail")
        local after_fail = demo.get_suspicion(state)
        assert.is_true(after_fail > 0)

        demo.act(state, demo.EAbilityId.KeepCalm)
        assert.is_true(demo.get_suspicion(state) < after_fail)
    end)

    it("献图成功：可信度足够、怀疑值不高且持有先遣图", function()
        local state = demo.new_game()
        -- 积累可信度，控制怀疑值
        demo.act(state, demo.EAbilityId.BragBackground, "success")
        demo.act(state, demo.EAbilityId.AnswerLingo, "success")
        demo.act(state, demo.EAbilityId.PledgeLoyalty)

        local result = demo.act(state, demo.EAbilityId.ShowMap)

        assert.is_true(result.success)
        assert.is_true(demo.is_game_over(state))
        assert.is_true(demo.is_win(state))
        assert.is_true(demo.has_tag(state, demo.ETag.Trusted))
    end)

    it("献图失败：怀疑值过高被识破", function()
        local state = demo.new_game()
        -- 连续失败导致怀疑值飙升
        demo.act(state, demo.EAbilityId.AnswerLingo, "fail")
        demo.act(state, demo.EAbilityId.AnswerLingo, "fail")
        demo.act(state, demo.EAbilityId.AnswerLingo, "fail")

        local result = demo.act(state, demo.EAbilityId.ShowMap)

        assert.is_false(result.success)
        assert.is_true(demo.is_game_over(state))
        assert.is_false(demo.is_win(state))
        assert.is_true(demo.has_tag(state, demo.ETag.Suspicious))
    end)

    it("游戏流程：多回合推进", function()
        local state = demo.new_game()
        assert.equal(1, demo.get_round(state))

        demo.act(state, demo.EAbilityId.AnswerLingo, "success")
        assert.equal(2, demo.get_round(state))

        demo.act(state, demo.EAbilityId.BragBackground, "success")
        assert.equal(3, demo.get_round(state))
    end)
end)
