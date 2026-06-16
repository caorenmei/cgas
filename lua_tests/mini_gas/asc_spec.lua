require("lua_tests.support.env")
local mini_gas = require("mini_gas")

local EModifierOp = mini_gas.EModifierOp
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy
local EEffectTarget = mini_gas.EEffectTarget

--- 构造一个简单的实体模块
---@param entity table
---@return mini_gas.IEntityModule
local function make_entity_module(entity)
    return {
        static_tags = function() return next, entity.static_tags end,
        static_tags_size = function()
            local n = 0
            for _ in pairs(entity.static_tags) do n = n + 1 end
            return n
        end,
        has_static_tag = function(_, tag) return entity.static_tags[tag] ~= nil end,
        attributes = function() return next, entity.attrs end,
        attributes_size = function()
            local n = 0
            for _ in pairs(entity.attrs) do n = n + 1 end
            return n
        end,
        has_attribute = function(_, id) return entity.attrs[id] ~= nil end,
        get_attribute = function(_, id) return entity.attrs[id] or 0 end,
        static_abilities = function() return next, entity.static_abilities end,
        static_abilities_size = function()
            local n = 0
            for _ in pairs(entity.static_abilities) do n = n + 1 end
            return n
        end,
        has_static_ability = function(_, def_id) return entity.static_abilities[def_id] ~= nil end,
    }
end

--- 构造一个世界模块
---@param world table
---@param modules table<any, mini_gas.IEntityModule>
---@return mini_gas.IWorldModule
local function make_world_module(world, modules)
    return {
        entities = function(_, _)
            return function(entities, id)
                local next_id, next_state = next(entities, id)
                if next_id == nil then return nil end
                return next_id, next_state, modules[next_id]
            end, world.entities
        end,
        entities_size = function()
            local n = 0
            for _ in pairs(world.entities) do n = n + 1 end
            return n
        end,
        has_entity = function(_, _, id) return world.entities[id] ~= nil end,
        get_entity = function(_, _, id) return world.entities[id], modules[id] end,
    }
end

--- 从 evaluation.apply 调用中累加属性变化
---@param deltas table<any, number>
---@return mini_gas.IEvaluation
local function make_evaluation(deltas)
    return {
        apply = function(_, _, _, _, _, _, _, _, attr_changes)
            for _, entry in ipairs(attr_changes) do
                deltas[entry.attr_id] = (deltas[entry.attr_id] or 0) + entry.value
            end
        end,
    }
end

describe("mini_gas v2 asc", function()
    local ATTR_ATTACK = "attr.attack"
    local ATTR_GOLD = "attr.gold"
    local TAG_VIP = "buff.vip"
    local TAG_PET_ACTIVE = "pet.active"
    local TAG_COMMANDER = "role.commander"
    local TAG_AURA = "buff.commander_aura"
    local ABILITY_SWORD = "ability.sword"
    local ABILITY_VIP = "ability.vip"
    local ABILITY_PET = "ability.pet"
    local ABILITY_AURA = "ability.aura"
    local EFFECT_SWORD = "effect.sword"
    local EFFECT_VIP = "effect.vip"
    local EFFECT_PET = "effect.pet"
    local EFFECT_AURA = "effect.aura"

    it("match_tag supports exact and hierarchical matching", function()
        assert.is_true(mini_gas.match_tag("state.dead", "state.dead"))
        assert.is_true(mini_gas.match_tag("state.dead", "state"))
        assert.is_false(mini_gas.match_tag("state.dead", "state.stunned"))
        assert.is_false(mini_gas.match_tag("state.dead", "state.deadly"))
        assert.is_false(mini_gas.match_tag("state.dead", ""))
    end)

    it("match_tags checks allof / anyof / noneof constraints", function()
        local entity = { static_tags = { ["state.dead"] = true, ["buff.vip"] = true } }
        local module = make_entity_module(entity)
        assert.is_true(mini_gas.match_tags(entity, module, { "state" }))
        assert.is_true(mini_gas.match_tags(entity, module, { "state.dead" }))
        assert.is_true(mini_gas.match_tags(entity, module, nil, { "state.stunned", "buff.vip" }))
        assert.is_true(mini_gas.match_tags(entity, module, nil, nil, { "state.stunned" }))
        assert.is_false(mini_gas.match_tags(entity, module, nil, nil, { "state" }))
        assert.is_false(mini_gas.match_tags(entity, module, { "state.stunned" }))
    end)

    it("evaluate applies self-target additive modifiers", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = {},
            static_abilities = { [ABILITY_SWORD] = true },
        }
        local modules = { hero = make_entity_module(entity) }
        local world = { entities = { hero = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = { [ATTR_ATTACK] = { id = ATTR_ATTACK, default = 100 } },
            effect_defs = {
                [EFFECT_SWORD] = {
                    id = EFFECT_SWORD,
                    modifiers = { { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add } },
                },
            },
            ability_defs = {
                [ABILITY_SWORD] = {
                    id = ABILITY_SWORD,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_SWORD },
                },
            },
        }

        local deltas = {}
        mini_gas.evaluate({}, world, world_module, defs, make_evaluation(deltas))
        assert.equal(50, deltas[ATTR_ATTACK])
    end)

    it("evaluate filters modifiers by target tags", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_PET_ACTIVE] = true },
            static_abilities = { [ABILITY_PET] = true },
        }
        local modules = { hero = make_entity_module(entity) }
        local world = { entities = { hero = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_PET] = {
                    id = EFFECT_PET,
                    modifiers = {
                        { attribute = { ATTR_ATTACK, 40 }, op = EModifierOp.Add, allof_tags = { TAG_PET_ACTIVE } },
                        { attribute = { ATTR_ATTACK, 999 }, op = EModifierOp.Add, allof_tags = { "missing.tag" } },
                    },
                },
            },
            ability_defs = {
                [ABILITY_PET] = {
                    id = ABILITY_PET,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_PET },
                },
            },
        }

        local deltas = {}
        mini_gas.evaluate({}, world, world_module, defs, make_evaluation(deltas))
        assert.equal(40, deltas[ATTR_ATTACK])
    end)

    it("evaluate aggregates add and multiply modifiers from same effect", function()
        local entity = {
            attrs = { [ATTR_GOLD] = 0 },
            static_tags = { [TAG_VIP] = true },
            static_abilities = { [ABILITY_VIP] = true, [ABILITY_SWORD] = true },
        }
        local modules = { hero = make_entity_module(entity) }
        local world = { entities = { hero = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_SWORD] = {
                    id = EFFECT_SWORD,
                    modifiers = { { attribute = { ATTR_GOLD, 100 }, op = EModifierOp.Add } },
                },
                [EFFECT_VIP] = {
                    id = EFFECT_VIP,
                    modifiers = { { attribute = { ATTR_GOLD, 1.2 }, op = EModifierOp.Multiply, allof_tags = { TAG_VIP } } },
                },
            },
            ability_defs = {
                [ABILITY_SWORD] = {
                    id = ABILITY_SWORD,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_SWORD },
                },
                [ABILITY_VIP] = {
                    id = ABILITY_VIP,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_VIP },
                },
            },
        }

        local deltas = {}
        mini_gas.evaluate({}, world, world_module, defs, make_evaluation(deltas))
        assert.near(120, deltas[ATTR_GOLD], 0.0001)
    end)

    it("evaluate applies all-target cross-entity effects", function()
        local commander = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = { [ABILITY_AURA] = true },
        }
        local ally = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = {},
        }
        local modules = { commander = make_entity_module(commander), ally = make_entity_module(ally) }
        local world = { entities = { commander = commander, ally = ally } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_AURA] = {
                    id = EFFECT_AURA,
                    target = EEffectTarget.All,
                    allof_tags = { TAG_COMMANDER },
                    grant_tags = { TAG_AURA },
                    modifiers = { { attribute = { ATTR_ATTACK, 1.2 }, op = EModifierOp.Multiply } },
                },
            },
            ability_defs = {
                [ABILITY_AURA] = {
                    id = ABILITY_AURA,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_AURA },
                    can_activate = {
                        allof_tags = { TAG_COMMANDER },
                        requires_count = 2,
                        include_self = true,
                    },
                },
            },
        }

        local granted = {}
        local deltas = {}
        local evaluation = {
            apply = function(_, _, _, _, _, _, _, granted_tags, attr_changes)
                for _, entry in ipairs(granted_tags) do
                    granted[entry.entity] = granted[entry.entity] or {}
                    table.insert(granted[entry.entity], entry.tag)
                end
                for _, entry in ipairs(attr_changes) do
                    deltas[entry.entity] = deltas[entry.entity] or {}
                    deltas[entry.entity][entry.attr_id] = { value = entry.value }
                end
            end,
        }

        mini_gas.evaluate({}, world, world_module, defs, evaluation)
        assert.is_not_nil(granted[commander])
        assert.is_not_nil(granted[ally])
        assert.near(20, deltas[commander][ATTR_ATTACK].value, 0.0001)
        assert.near(20, deltas[ally][ATTR_ATTACK].value, 0.0001)
    end)

    it("evaluate handles ability condition object with requires_count and include_self", function()
        local a = {
            attrs = {},
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = { [ABILITY_AURA] = true },
        }
        local b = {
            attrs = {},
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = {},
        }
        local modules = { a = make_entity_module(a), b = make_entity_module(b) }
        local world = { entities = { a = a, b = b } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_AURA] = {
                    id = EFFECT_AURA,
                    target = EEffectTarget.All,
                    grant_tags = { TAG_AURA },
                    modifiers = {},
                },
            },
            ability_defs = {
                [ABILITY_AURA] = {
                    id = ABILITY_AURA,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_AURA },
                    can_activate = {
                        allof_tags = { TAG_COMMANDER },
                        requires_count = 2,
                        include_self = true,
                    },
                },
            },
        }

        local granted_count = 0
        local evaluation = {
            apply = function(_, _, _, _, _, _, _, granted_tags)
                granted_count = granted_count + #granted_tags
            end,
        }

        mini_gas.evaluate({}, world, world_module, defs, evaluation)
        assert.equal(2, granted_count) -- a has the ability and activates; grants tags to a and b
    end)

    it("evaluate passes condition function extras to modifier functions", function()
        local entity = {
            attrs = { [ATTR_GOLD] = 0 },
            static_tags = {},
            static_abilities = { [ABILITY_SWORD] = true },
        }
        local modules = { hero = make_entity_module(entity) }
        local world = { entities = { hero = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_SWORD] = {
                    id = EFFECT_SWORD,
                    modifiers = {
                        {
                            attribute = function(_, _, _, _, _, _, _, _, extra)
                                local level = extra and extra.level or 1
                                return ATTR_GOLD, 100 * level
                            end,
                            op = EModifierOp.Add,
                        },
                    },
                },
            },
            ability_defs = {
                [ABILITY_SWORD] = {
                    id = ABILITY_SWORD,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_SWORD },
                    can_activate = function(_, _, _, _, _, _, _, _, _)
                        return true, { level = 3 }
                    end,
                },
            },
        }

        local deltas = {}
        mini_gas.evaluate({}, world, world_module, defs, make_evaluation(deltas))
        assert.equal(300, deltas[ATTR_GOLD])
    end)

    it("evaluate passes condition object count as first vararg to modifier functions", function()
        local a = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = { [ABILITY_AURA] = true },
        }
        local b = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = {},
        }
        local modules = { a = make_entity_module(a), b = make_entity_module(b) }
        local world = { entities = { a = a, b = b } }
        local world_module = make_world_module(world, modules)

        local received_count
        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_AURA] = {
                    id = EFFECT_AURA,
                    target = EEffectTarget.All,
                    modifiers = {
                        {
                            attribute = function(_, _, _, _, _, _, _, _, count)
                                received_count = count
                                return ATTR_ATTACK, 1.1
                            end,
                            op = EModifierOp.Multiply,
                        },
                    },
                },
            },
            ability_defs = {
                [ABILITY_AURA] = {
                    id = ABILITY_AURA,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_AURA },
                    can_activate = {
                        allof_tags = { TAG_COMMANDER },
                        requires_count = 2,
                        include_self = true,
                    },
                },
            },
        }

        mini_gas.evaluate({}, world, world_module, defs, make_evaluation({}))
        assert.equal(2, received_count)
    end)

    it("evaluate clamps final value to attribute min/max", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = {},
            static_abilities = { [ABILITY_SWORD] = true },
        }
        local modules = { hero = make_entity_module(entity) }
        local world = { entities = { hero = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = { [ATTR_ATTACK] = { id = ATTR_ATTACK, min = 0, max = 120 } },
            effect_defs = {
                [EFFECT_SWORD] = {
                    id = EFFECT_SWORD,
                    modifiers = { { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add } },
                },
            },
            ability_defs = {
                [ABILITY_SWORD] = {
                    id = ABILITY_SWORD,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_SWORD },
                },
            },
        }

        local deltas = {}
        mini_gas.evaluate({}, world, world_module, defs, make_evaluation(deltas))
        assert.equal(20, deltas[ATTR_ATTACK]) -- 100 + 50 clamped to 120, delta = 20
    end)

    it("evaluate supports recursive modifier attribute functions", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100, [ATTR_GOLD] = 0 },
            static_tags = {},
            static_abilities = { [ABILITY_SWORD] = true },
        }
        local modules = { hero = make_entity_module(entity) }
        local world = { entities = { hero = entity } }
        local world_module = make_world_module(world, modules)

        local step = 0
        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_SWORD] = {
                    id = EFFECT_SWORD,
                    modifiers = {
                        {
                            attribute = function(_, _, _, _, _, _, _, _, _)
                                step = step + 1
                                if step == 1 then
                                    return ATTR_ATTACK, 10, function(_, _, _, _, _, _, _, _, _)
                                        step = step + 1
                                        return ATTR_GOLD, 5, nil
                                    end
                                end
                                return nil, nil, nil
                            end,
                            op = EModifierOp.Add,
                        },
                    },
                },
            },
            ability_defs = {
                [ABILITY_SWORD] = {
                    id = ABILITY_SWORD,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_SWORD },
                },
            },
        }

        local deltas = {}
        mini_gas.evaluate({}, world, world_module, defs, make_evaluation(deltas))
        assert.equal(10, deltas[ATTR_ATTACK])
        assert.equal(5, deltas[ATTR_GOLD])
    end)

    it("evaluate supports override operation", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = {},
            static_abilities = { [ABILITY_SWORD] = true },
        }
        local modules = { hero = make_entity_module(entity) }
        local world = { entities = { hero = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_SWORD] = {
                    id = EFFECT_SWORD,
                    modifiers = {
                        { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add },
                        { attribute = { ATTR_ATTACK, 300 }, op = EModifierOp.Override },
                    },
                },
            },
            ability_defs = {
                [ABILITY_SWORD] = {
                    id = ABILITY_SWORD,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_SWORD },
                },
            },
        }

        local deltas = {}
        mini_gas.evaluate({}, world, world_module, defs, make_evaluation(deltas))
        assert.equal(200, deltas[ATTR_ATTACK]) -- override 300 - base 100 = 200
    end)
end)
