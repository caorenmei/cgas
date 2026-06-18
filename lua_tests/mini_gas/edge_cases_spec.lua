require("lua_tests.support.env")
local mini_gas = require("mini_gas")

local EModifierOp = mini_gas.EModifierOp
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy
local EEffectTarget = mini_gas.EEffectTarget

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

---@param world table
---@param modules table<any, mini_gas.IEntityModule>
---@return mini_gas.IWorldModule
local function make_world_module(world, modules)
    return {
        entities = function(_)
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
        has_entity = function(_, id) return world.entities[id] ~= nil end,
        get_entity = function(_, id) return world.entities[id], modules[id] end,
    }
end

---@param world table
---@param world_module mini_gas.IWorldModule
---@param defs table
---@return mini_gas.IContext
local function make_context(world, world_module, defs)
    return {
        world = world,
        world_module = world_module,
        defs = defs,
    }
end

---@param deltas table
---@return mini_gas.ApplyFun
local function make_apply(deltas)
    return function(_, entity, _, attributes)
        deltas[entity] = deltas[entity] or {}
        for attr_id, value in pairs(attributes) do
            deltas[entity][attr_id] = (deltas[entity][attr_id] or 0) + value
        end
    end
end

describe("mini_gas v2 edge cases", function()
    local ATTR_ATTACK = "attr.attack"
    local ATTR_GOLD = "attr.gold"
    local TAG_AURA = "buff.aura"
    local TAG_COMMANDER = "role.commander"
    local TAG_VIP = "buff.vip"
    local TAG_DEAD = "state.dead"
    local ABILITY_AURA = "ability.aura"
    local ABILITY_LEGAL = "ability.legal"
    local ABILITY_MISSING_EFFECT = "ability.missing_effect"
    local ABILITY_MISSING_ID = "ability.missing_id"
    local ABILITY_BAD_CAN_ACTIVATE = "ability.bad_can_activate"
    local ABILITY_BAD_MODIFIER = "ability.bad_modifier"
    local ABILITY_NON_PASSIVE = "ability.non_passive"
    local EFFECT_AURA_OTHER = "effect.aura_other"
    local EFFECT_LEGAL = "effect.legal"
    local EFFECT_MISSING = "effect.missing"
    local EFFECT_BAD_MODIFIER = "effect.bad_modifier"

    it("Other target does not affect owner but affects matching entities", function()
        local owner = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = { [ABILITY_AURA] = true },
        }
        local other = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = {},
        }
        local unrelated = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = {},
            static_abilities = {},
        }
        local modules = { owner = make_entity_module(owner), other = make_entity_module(other), unrelated = make_entity_module(unrelated) }
        local world = { entities = { owner = owner, other = other, unrelated = unrelated } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_AURA_OTHER] = {
                    id = EFFECT_AURA_OTHER,
                    target = EEffectTarget.Other,
                    allof_tags = { TAG_COMMANDER },
                    grant_tags = { TAG_AURA },
                    modifiers = { { attribute = { ATTR_ATTACK, 10 }, op = EModifierOp.Add } },
                },
            },
            ability_defs = {
                [ABILITY_AURA] = {
                    id = ABILITY_AURA,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_AURA_OTHER },
                },
            },
        }

        local entity_tags = {}
        local deltas = {}
        local function apply(_, entity, tags, attributes)
            entity_tags[entity] = {}
            for tag in pairs(tags) do
                entity_tags[entity][tag] = true
            end
            deltas[entity] = deltas[entity] or {}
            for attr_id, value in pairs(attributes) do
                deltas[entity][attr_id] = (deltas[entity][attr_id] or 0) + value
            end
        end

        local context = make_context(world, world_module, defs)
        mini_gas.evaluate(context, apply)

        assert.is_nil(entity_tags[owner][TAG_AURA])
        assert.is_true(entity_tags[other][TAG_AURA])
        assert.is_nil(entity_tags[unrelated][TAG_AURA])
        assert.is_nil(deltas[owner][ATTR_ATTACK])
        assert.equal(10, deltas[other][ATTR_ATTACK])
        assert.is_nil(deltas[unrelated][ATTR_ATTACK])
    end)

    it("silently skips invalid configurations and still applies legal effects", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = {},
            static_abilities = {
                [ABILITY_LEGAL] = true,
                [ABILITY_MISSING_EFFECT] = true,
                [ABILITY_MISSING_ID] = true,
                [ABILITY_BAD_CAN_ACTIVATE] = true,
                [ABILITY_BAD_MODIFIER] = true,
            },
        }
        local modules = { e = make_entity_module(entity) }
        local world = { entities = { e = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_LEGAL] = {
                    id = EFFECT_LEGAL,
                    modifiers = { { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add } },
                },
                [EFFECT_BAD_MODIFIER] = {
                    id = EFFECT_BAD_MODIFIER,
                    modifiers = { { attribute = "not_a_table", op = EModifierOp.Add } },
                },
            },
            ability_defs = {
                [ABILITY_LEGAL] = {
                    id = ABILITY_LEGAL,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_LEGAL },
                },
                [ABILITY_MISSING_EFFECT] = {
                    id = ABILITY_MISSING_EFFECT,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_MISSING },
                },
                [ABILITY_BAD_CAN_ACTIVATE] = {
                    id = ABILITY_BAD_CAN_ACTIVATE,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_LEGAL },
                    can_activate = "invalid",
                },
                [ABILITY_BAD_MODIFIER] = {
                    id = ABILITY_BAD_MODIFIER,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_BAD_MODIFIER },
                },
            },
        }

        local steps = {}
        local debug = {
            step = function(_, phase, ...)
                table.insert(steps, { phase = phase, args = { ... } })
            end,
        }

        local deltas = {}
        local context = make_context(world, world_module, defs)
        context.debug = debug
        mini_gas.evaluate(context, make_apply(deltas))

        assert.equal(50, deltas[entity][ATTR_ATTACK])

        local missing_effect_step = false
        local invalid_modifier_step = false
        for _, s in ipairs(steps) do
            if s.phase == "missing_effect" then
                missing_effect_step = true
            elseif s.phase == "invalid_modifier_attribute" then
                invalid_modifier_step = true
            end
        end
        assert.is_true(missing_effect_step)
        assert.is_true(invalid_modifier_step)
    end)

    it("does not modify original entity attrs or static_tags between evaluations", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_VIP] = true },
            static_abilities = { [ABILITY_LEGAL] = true },
        }
        local modules = { e = make_entity_module(entity) }
        local world = { entities = { e = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_LEGAL] = {
                    id = EFFECT_LEGAL,
                    modifiers = { { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add } },
                },
            },
            ability_defs = {
                [ABILITY_LEGAL] = {
                    id = ABILITY_LEGAL,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_LEGAL },
                },
            },
        }

        local first_deltas = {}
        local second_deltas = {}
        local context = make_context(world, world_module, defs)
        mini_gas.evaluate(context, make_apply(first_deltas))
        mini_gas.evaluate(context, make_apply(second_deltas))

        assert.equal(first_deltas[entity][ATTR_ATTACK], second_deltas[entity][ATTR_ATTACK])
        assert.equal(100, entity.attrs[ATTR_ATTACK])
        assert.is_true(entity.static_tags[TAG_VIP])
    end)

    it("calls apply once per entity with empty tables when no abilities or conditions apply", function()
        local a = {
            attrs = {},
            static_tags = {},
            static_abilities = {},
        }
        local b = {
            attrs = {},
            static_tags = { [TAG_VIP] = true },
            static_abilities = { [ABILITY_LEGAL] = true },
        }
        local modules = { a = make_entity_module(a), b = make_entity_module(b) }
        local world = { entities = { a = a, b = b } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_LEGAL] = {
                    id = EFFECT_LEGAL,
                    modifiers = { { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add, allof_tags = { "missing.tag" } } },
                },
            },
            ability_defs = {
                [ABILITY_LEGAL] = {
                    id = ABILITY_LEGAL,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_LEGAL },
                    can_activate = function() return false end,
                },
            },
        }

        local calls = {}
        local function apply(_, entity, tags, attribute_deltas)
            table.insert(calls, entity)
            assert.are.same({}, tags)
            assert.are.same({}, attribute_deltas)
        end

        local context = make_context(world, world_module, defs)
        mini_gas.evaluate(context, apply)
        assert.equal(2, #calls)
    end)

    it("supports anyof_tags and noneof_tags on effects and modifiers", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100, [ATTR_GOLD] = 0 },
            static_tags = { [TAG_VIP] = true, [TAG_DEAD] = true },
            static_abilities = { [ABILITY_LEGAL] = true },
        }
        local modules = { e = make_entity_module(entity) }
        local world = { entities = { e = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_LEGAL] = {
                    id = EFFECT_LEGAL,
                    anyof_tags = { TAG_VIP, TAG_COMMANDER },
                    noneof_tags = { "state.stunned" },
                    modifiers = {
                        { attribute = { ATTR_ATTACK, 10 }, op = EModifierOp.Add },
                        { attribute = { ATTR_GOLD, 5 }, op = EModifierOp.Add, noneof_tags = { TAG_VIP } },
                    },
                },
            },
            ability_defs = {
                [ABILITY_LEGAL] = {
                    id = ABILITY_LEGAL,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_LEGAL },
                },
            },
        }

        local deltas = {}
        local context = make_context(world, world_module, defs)
        mini_gas.evaluate(context, make_apply(deltas))

        assert.equal(10, deltas[entity][ATTR_ATTACK])
        assert.is_nil(deltas[entity][ATTR_GOLD])
    end)

    it("matches hierarchical parent tags in allof_tags and excludes children in noneof_tags", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_DEAD] = true },
            static_abilities = { [ABILITY_LEGAL] = true },
        }
        local modules = { e = make_entity_module(entity) }
        local world = { entities = { e = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_LEGAL] = {
                    id = EFFECT_LEGAL,
                    allof_tags = { "state" },
                    noneof_tags = { "state" },
                    modifiers = { { attribute = { ATTR_ATTACK, 10 }, op = EModifierOp.Add } },
                },
            },
            ability_defs = {
                [ABILITY_LEGAL] = {
                    id = ABILITY_LEGAL,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_LEGAL },
                },
            },
        }

        local deltas = {}
        local context = make_context(world, world_module, defs)
        mini_gas.evaluate(context, make_apply(deltas))

        -- allof_tags "state" matches "state.dead", but noneof_tags "state" also excludes it.
        assert.is_nil(deltas[entity][ATTR_ATTACK])
    end)

    it("skips abilities whose activation_policy is not Passive", function()
        local entity = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = {},
            static_abilities = { [ABILITY_NON_PASSIVE] = true, [ABILITY_LEGAL] = true },
        }
        local modules = { e = make_entity_module(entity) }
        local world = { entities = { e = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_LEGAL] = {
                    id = EFFECT_LEGAL,
                    modifiers = { { attribute = { ATTR_ATTACK, 50 }, op = EModifierOp.Add } },
                },
            },
            ability_defs = {
                [ABILITY_NON_PASSIVE] = {
                    id = ABILITY_NON_PASSIVE,
                    activation_policy = 999,
                    effects = { EFFECT_LEGAL },
                },
                [ABILITY_LEGAL] = {
                    id = ABILITY_LEGAL,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_LEGAL },
                },
            },
        }

        local deltas = {}
        local context = make_context(world, world_module, defs)
        mini_gas.evaluate(context, make_apply(deltas))

        assert.equal(50, deltas[entity][ATTR_ATTACK])
    end)

    it("notifies IDebug for missing effect and invalid modifier attribute", function()
        local entity = {
            attrs = {},
            static_tags = {},
            static_abilities = { [ABILITY_MISSING_EFFECT] = true, [ABILITY_BAD_MODIFIER] = true },
        }
        local modules = { e = make_entity_module(entity) }
        local world = { entities = { e = entity } }
        local world_module = make_world_module(world, modules)

        local defs = {
            attribute_defs = {},
            effect_defs = {
                [EFFECT_BAD_MODIFIER] = {
                    id = EFFECT_BAD_MODIFIER,
                    modifiers = { { attribute = 12345, op = EModifierOp.Add } },
                },
            },
            ability_defs = {
                [ABILITY_MISSING_EFFECT] = {
                    id = ABILITY_MISSING_EFFECT,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_MISSING },
                },
                [ABILITY_BAD_MODIFIER] = {
                    id = ABILITY_BAD_MODIFIER,
                    activation_policy = EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_BAD_MODIFIER },
                },
            },
        }

        local steps = {}
        local debug = {
            step = function(_, phase, ...)
                table.insert(steps, { phase = phase, args = { ... } })
            end,
        }

        local context = make_context(world, world_module, defs)
        context.debug = debug
        mini_gas.evaluate(context, function() end)

        local found_missing = false
        local found_invalid = false
        for _, s in ipairs(steps) do
            if s.phase == "missing_effect" then
                found_missing = true
            elseif s.phase == "invalid_modifier_attribute" then
                found_invalid = true
            end
        end
        assert.is_true(found_missing)
        assert.is_true(found_invalid)
    end)
end)
