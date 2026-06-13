require("lua_tests.support.env")
local cgas = require("cgas")

describe("Fireball combo", function()
    it("casts fireball with mana cost, cooldown, and damage", function()
        -- Player ASC
        local player = cgas.create_asc()

        local HealthSet = { name = "HealthSet" }
        function HealthSet:on_init(set)
            set:register_attribute("Health", 100, { max_value = 100 })
        end
        player:add_attribute_set(HealthSet)

        local ManaSet = { name = "ManaSet" }
        function ManaSet:on_init(set)
            set:register_attribute("Mana", 100, { max_value = 100 })
        end
        player:add_attribute_set(ManaSet)

        local ManaCost = cgas.GameplayEffect.new({
            name = "ManaCost",
            duration_policy = "instant",
            modifiers = { { attribute_name = "ManaSet.Mana", op = "add", magnitude = -20 } },
        })

        local Cooldown = cgas.GameplayEffect.new({
            name = "Cooldown",
            duration_policy = "duration",
            duration = { type = "scalable_float", value = 2.0 },
            granted_tags = (function()
                local c = cgas.GameplayTagContainer.new()
                c:add(cgas.GameplayTag.new("ability.cooldown.fireball"))
                return c
            end)(),
        })

        -- Target ASC
        local target = cgas.create_asc()
        target:add_attribute_set(HealthSet)

        local Fireball = {
            name = "Fireball",
            cost_effect_class = ManaCost,
            cooldown_effect_class = Cooldown,
            activation_blocked_tags = function()
                local c = cgas.GameplayTagContainer.new()
                c:add(cgas.GameplayTag.new("ability.cooldown.fireball"))
                return c
            end,
            ActivateAbility = function(self)
                local task = cgas.TaskWaitDelay.new(self, 1.5)
                task.on_finished = function()
                    -- Apply damage to target
                    local Damage = cgas.GameplayEffect.new({
                        name = "FireballDamage",
                        duration_policy = "instant",
                        modifiers = { { attribute_name = "HealthSet.Health", op = "add", magnitude = -30 } },
                    })
                    target:apply_effect({ effect_class = Damage, source = self.asc })
                    self:end_ability()
                end
                task:start()
            end,
        }

        local ability_handle = player:give_ability(Fireball)
        assert.is_number(ability_handle)
        ---@cast ability_handle integer

        -- Cast
        assert.is_true(player:try_activate_ability(ability_handle))
        local mana = player:get_attribute("ManaSet.Mana")
        assert.is_not_nil(mana)
        ---@cast mana cgas.semantics.Attribute
        assert.equal(80, mana.current_value)

        -- Wait for cast
        player:update(1.6)
        local health = target:get_attribute("HealthSet.Health")
        assert.is_not_nil(health)
        ---@cast health cgas.semantics.Attribute
        assert.equal(70, health.current_value)

        -- Try recast during cooldown
        assert.is_false(player:try_activate_ability(ability_handle))

        -- Wait for cooldown
        player:update(2.0)
        assert.is_true(player:try_activate_ability(ability_handle))
    end)
end)
