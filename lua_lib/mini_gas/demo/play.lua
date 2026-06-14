--- 智取威虎山-献图 演示脚本
--- 运行：./lua lua_lib/mini_gas/demo/play.lua
local demo = require("mini_gas.demo.weihu_shan")

local function print_state(state)
    print(string.format("  回合: %d | 可信度: %d | 怀疑值: %d | 胆识: %d | 口才: %d",
        demo.get_round(state),
        demo.get_credibility(state),
        demo.get_suspicion(state),
        demo.get_courage(state),
        demo.get_eloquence(state)))
end

local function step(state, ability_id, choice, description)
    print("\n" .. description)
    local result = demo.act(state, ability_id, choice)
    print("  >> " .. result.message)
    print_state(state)
    return result
end

print("====================================")
print("  智取威虎山 · 献图")
print("====================================")
print("你化名为胡彪，怀揣先遣图，独闯威虎山。")
print("座山雕高坐虎皮椅，八大金刚环伺左右。")

local state = demo.new_game()
print_state(state)

-- 第一回合：对黑话
step(state, demo.EAbilityId.AnswerLingo, "success",
    "【第一回】座山雕冷声问道：‘天王盖地虎！’")

-- 第二回合：搬门子
step(state, demo.EAbilityId.BragBackground, "success",
    "【第二回】座山雕眯起眼：‘说说你的来路。’")

-- 第三回合：表忠心
step(state, demo.EAbilityId.PledgeLoyalty, nil,
    "【第三回】座山雕敲着桌子：‘凭什么让我信你？’")

-- 最终：献图
local final = step(state, demo.EAbilityId.ShowMap, nil,
    "【最终回】你从怀中取出先遣图，双手奉上。")

print("\n====================================")
if final.win then
    print("  结局：座山雕收下地图，封你为威虎山老九！")
else
    print("  结局：座山雕识破了你，你倒在了威虎山上……")
end
print("====================================")
