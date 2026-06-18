require("lua_tests.support.env")
local mini_gas = require("mini_gas")

-- 业务级 ID 与标签
local ATTR_ATTACK = "attr.attack"
local ATTR_GOLD = "attr.gold"

local TAG_PET_ACTIVE = "pet.active"
local TAG_VIP = "buff.vip"
local TAG_COMMANDER = "role.commander"
local TAG_AURA = "buff.commander_aura"

local ABILITY_SWORD = "ability.equipment.sword"
local ABILITY_VIP = "ability.vip.privilege"
local ABILITY_PET = "ability.pet.dragon"
local ABILITY_BUILDING = "ability.building.gold_mine"
local ABILITY_AURA = "ability.attack_aura"

local EFFECT_SWORD = "effect.equipment.sword"
local EFFECT_VIP = "effect.vip.privilege"
local EFFECT_PET = "effect.pet.dragon"
local EFFECT_BUILDING = "effect.building.gold_mine"
local EFFECT_AURA = "effect.attack_aura"

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

describe("mini_gas v2 integration", function()
    it("full example from v2 spec", function()
        local defs = {
            attribute_defs = {
                [ATTR_ATTACK] = { id = ATTR_ATTACK },
                [ATTR_GOLD] = { id = ATTR_GOLD },
            },
            effect_defs = {
                [EFFECT_SWORD] = {
                    id = EFFECT_SWORD,
                    modifiers = { { attribute = { ATTR_ATTACK, 50 }, op = mini_gas.EModifierOp.Add } },
                },
                [EFFECT_VIP] = {
                    id = EFFECT_VIP,
                    modifiers = { { attribute = { ATTR_GOLD, 1.2 }, op = mini_gas.EModifierOp.Multiply, allof_tags = { TAG_VIP } } },
                },
                [EFFECT_PET] = {
                    id = EFFECT_PET,
                    modifiers = { { attribute = { ATTR_ATTACK, 40 }, op = mini_gas.EModifierOp.Add, allof_tags = { TAG_PET_ACTIVE } } },
                },
                [EFFECT_BUILDING] = {
                    id = EFFECT_BUILDING,
                    modifiers = {
                        {
                            attribute = function(_, _, _, _, _, _, extra)
                                local world_level = extra and extra.world_level or 1
                                return ATTR_GOLD, 100 * world_level
                            end,
                            op = mini_gas.EModifierOp.Add,
                        },
                    },
                },
                [EFFECT_AURA] = {
                    id = EFFECT_AURA,
                    target = mini_gas.EEffectTarget.All,
                    allof_tags = { TAG_COMMANDER },
                    grant_tags = { TAG_AURA },
                    modifiers = { { attribute = { ATTR_ATTACK, 1.2 }, op = mini_gas.EModifierOp.Multiply } },
                },
            },
            ability_defs = {
                [ABILITY_SWORD] = {
                    id = ABILITY_SWORD,
                    activation_policy = mini_gas.EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_SWORD },
                },
                [ABILITY_VIP] = {
                    id = ABILITY_VIP,
                    activation_policy = mini_gas.EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_VIP },
                },
                [ABILITY_PET] = {
                    id = ABILITY_PET,
                    activation_policy = mini_gas.EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_PET },
                },
                [ABILITY_BUILDING] = {
                    id = ABILITY_BUILDING,
                    activation_policy = mini_gas.EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_BUILDING },
                    can_activate = function(_, _, _)
                        return true, 1, { world_level = 3 }
                    end,
                },
                [ABILITY_AURA] = {
                    id = ABILITY_AURA,
                    activation_policy = mini_gas.EAbilityActivationPolicy.Passive,
                    effects = { EFFECT_AURA },
                    can_activate = {
                        allof_tags = { TAG_COMMANDER },
                        requires_count = 2,
                        include_self = true,
                    },
                },
            },
        }

        local hero_state = {
            attrs = { [ATTR_ATTACK] = 100, [ATTR_GOLD] = 0 },
            static_tags = { [TAG_PET_ACTIVE] = true, [TAG_VIP] = true },
            static_abilities = {
                [ABILITY_SWORD] = true,
                [ABILITY_VIP] = true,
                [ABILITY_PET] = true,
                [ABILITY_BUILDING] = true,
            },
        }
        local commander_state = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = { [ABILITY_AURA] = true },
        }
        local ally_state = {
            attrs = { [ATTR_ATTACK] = 100 },
            static_tags = { [TAG_COMMANDER] = true },
            static_abilities = {},
        }

        local modules = {
            hero = make_entity_module(hero_state),
            commander = make_entity_module(commander_state),
            ally = make_entity_module(ally_state),
        }
        local world_state = { entities = { hero = hero_state, commander = commander_state, ally = ally_state } }
        local world_module = make_world_module(world_state, modules)

        local results = {}
        local entity_tags = {}
        local function apply(_, entity, tags, attributes)
            entity_tags[entity] = {}
            for tag in pairs(tags) do
                entity_tags[entity][tag] = true
            end
            results[entity] = results[entity] or {}
            for attr_id, value in pairs(attributes) do
                results[entity][attr_id] = (results[entity][attr_id] or 0) + value
            end
        end

        local context = {
            world = world_state,
            world_module = world_module,
            defs = defs,
        }
        mini_gas.evaluate(context, apply)

        local function final_attr(entity, attr_id)
            return modules[entity].get_attribute(world_state.entities[entity], attr_id) + (results[world_state.entities[entity]] and results[world_state.entities[entity]][attr_id] or 0)
        end

        assert.near(190, final_attr("hero", ATTR_ATTACK), 0.0001)
        assert.near(360, final_attr("hero", ATTR_GOLD), 0.0001)
        assert.near(120, final_attr("commander", ATTR_ATTACK), 0.0001)
        assert.near(120, final_attr("ally", ATTR_ATTACK), 0.0001)

        assert.is_true(entity_tags[commander_state][TAG_AURA])
        assert.is_true(entity_tags[ally_state][TAG_AURA])
    end)
end)
