require("lua_tests.support.env")
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local Defs = mini_gas.Defs
local MiniASC = mini_gas.MiniASC
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy
local EGameplayEvent = mini_gas.EGameplayEvent

describe("mini_gas ability", function()
    local EAttribute, EAbilityId, EEffectId, ETag

    before_each(function()
        EAttribute = {
            Hp = "attr.hp",
            Mp = "attr.mp",
            Attack = "attr.attack",
        }
        EAbilityId = {
            Fireball = "ability.fireball",
            Aura = "ability.aura",
            Counter = "ability.counter",
        }
        EEffectId = {
            FireballDamage = "effect.fireball.damage",
            AuraBuff = "effect.aura.buff",
            CounterDamage = "effect.counter.damage",
        }
        ETag = {
            Combat = "state.combat",
            Stunned = "state.stunned",
            AuraBuff = "buff.attack_aura",
        }
    end)

    it("passive ability auto activates", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Attack, base = 100 },
        })
        MiniASC.give_ability(state, defs, {
            id = EAbilityId.Aura,
            activation_policy = EAbilityActivationPolicy.Passive,
            grant_tags = { ETag.AuraBuff },
            effects = {
                {
                    id = EEffectId.AuraBuff,
                    duration_policy = EDurationPolicy.Infinite,
                    modifiers = {
                        { attribute = EAttribute.Attack, op = EModifierOp.Add, value = 20 },
                    },
                },
            },
        }, 1)

        assert.is_true(MiniASC.has_tag(state, ETag.AuraBuff))
        assert.equal(120, MiniASC.get_current(state, defs, EAttribute.Attack))
    end)

    it("active ability checks cost, cooldown and tags", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Hp, base = 1000, min = 0 },
            { name = EAttribute.Mp, base = 200, min = 0, max = 200 },
        })
        MiniASC.give_ability(state, defs, {
            id = EAbilityId.Fireball,
            activation_policy = EAbilityActivationPolicy.Active,
            cooldown = 5,
            cost = { [EAttribute.Mp] = 20 },
            require_tags = {},
            blocked_tags = {},
            effects = {
                {
                    id = EEffectId.FireballDamage,
                    duration_policy = EDurationPolicy.Instant,
                    modifiers = {
                        { attribute = EAttribute.Hp, op = EModifierOp.Add, value = -100 },
                    },
                },
            },
        }, 1)

        local ok = MiniASC.try_activate_ability(state, defs, EAbilityId.Fireball)
        assert.is_true(ok)
        assert.equal(180, MiniASC.get_current(state, defs, EAttribute.Mp))
        assert.equal(900, MiniASC.get_current(state, defs, EAttribute.Hp))

        -- 冷却中无法再次激活
        ok = MiniASC.try_activate_ability(state, defs, EAbilityId.Fireball)
        assert.is_false(ok)

        -- 推进冷却后成功
        MiniASC.update(state, defs, 5)
        ok = MiniASC.try_activate_ability(state, defs, EAbilityId.Fireball)
        assert.is_true(ok)
    end)

    it("active ability respects tags", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Mp, base = 100, min = 0 },
        })
        MiniASC.give_ability(state, defs, {
            id = EAbilityId.Fireball,
            activation_policy = EAbilityActivationPolicy.Active,
            cooldown = 0,
            cost = { [EAttribute.Mp] = 10 },
            require_tags = { ETag.Combat },
            blocked_tags = { ETag.Stunned },
            effects = {},
        }, 1)

        assert.is_false(MiniASC.try_activate_ability(state, defs, EAbilityId.Fireball))
        MiniASC.add_tag(state, ETag.Combat)
        assert.is_true(MiniASC.try_activate_ability(state, defs, EAbilityId.Fireball))

        MiniASC.add_tag(state, ETag.Stunned)
        assert.is_false(MiniASC.try_activate_ability(state, defs, EAbilityId.Fireball))
    end)

    it("passes payload to can_activate callback", function()
        local state = EntityState.new()
        local defs = Defs.new()
        local received_payload
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Hp, base = 100, min = 0 },
        })
        MiniASC.give_ability(state, defs, {
            id = EAbilityId.Fireball,
            activation_policy = EAbilityActivationPolicy.Active,
            cooldown = 0,
            cost = {},
            can_activate = function(_, payload)
                received_payload = payload
                return true
            end,
            effects = {},
        }, 1)
        local payload = { reason = "test" }
        MiniASC.try_activate_ability(state, defs, EAbilityId.Fireball, payload)
        assert.equal("test", received_payload.reason)
    end)

    it("reactive ability triggers on event", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Hp, base = 100, min = 0 },
        })
        MiniASC.give_ability(state, defs, {
            id = EAbilityId.Counter,
            activation_policy = EAbilityActivationPolicy.Reactive,
            activation_event = EGameplayEvent.AttributeChanged,
            cooldown = 0,
            effects = {
                {
                    id = EEffectId.CounterDamage,
                    duration_policy = EDurationPolicy.Instant,
                    modifiers = {
                        { attribute = EAttribute.Hp, op = EModifierOp.Add, value = -10 },
                    },
                },
            },
        }, 1)

        MiniASC.set_current(state, defs, EAttribute.Hp, 90)
        assert.equal(80, MiniASC.get_current(state, defs, EAttribute.Hp))
    end)

    it("ability subclass with level scales cooldown and cost", function()
        local state = EntityState.new()
        local defs = Defs.new()
        MiniASC.register_attributes(state, defs, {
            { name = EAttribute.Mp, base = 200, min = 0, max = 200 },
        })
        local leveled_fireball_def = {
            id = "ability.fireball.leveled",
            activation_policy = EAbilityActivationPolicy.Active,
            level = 3,
            cooldown = function(self) return defs.ability_defs[self.id].level * 2 end,
            cost = { [EAttribute.Mp] = function(self) return defs.ability_defs[self.id].level * 10 end },
            effects = {},
        }
        MiniASC.give_ability(state, defs, leveled_fireball_def)
        MiniASC.try_activate_ability(state, defs, "ability.fireball.leveled")
        assert.equal(170, MiniASC.get_current(state, defs, EAttribute.Mp))
        assert.equal(6, state.abilities["ability.fireball.leveled"].cooldown_remaining)
    end)
end)
