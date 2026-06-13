require("lua_tests.support.env")
local ability = require("cgas.semantics.ability")
local tag = require("cgas.semantics.tag")

describe("cgas.semantics.ability", function()
    local function make_asc()
        return {
            owned_tags = tag.GameplayTagContainer.new(),
            granted_abilities = {},
            apply_effect = function() return true end,
            event_bus = { emit = function() end },
            scheduler = {},
            time_source = {},
            remove_active_effect = function() return true end,
        }
    end

    it("starts inactive", function()
        local asc = make_asc()
        local ab = ability.GameplayAbility.new(asc, { name = "Fireball" })
        assert.equal("inactive", ab.state)
    end)

    it("activates and commits", function()
        local asc = make_asc()
        local activated = false
        local ab = ability.GameplayAbility.new(asc, {
            name = "Fireball",
            ActivateAbility = function(_self)
                activated = true
            end,
        })
        assert.is_true(ab:can_activate())
        assert.is_true(ab:activate())
        assert.equal("active", ab.state)
        assert.is_true(activated)
        assert.is_true(ab:commit())
    end)

    it("blocks activation by required tags", function()
        local asc = make_asc()
        local ab = ability.GameplayAbility.new(asc, {
            name = "Fireball",
            activation_required_tags = function()
                local q = tag.GameplayTagQuery.new()
                q.all_tags:add(tag.GameplayTag.new("state.ready"))
                return q
            end,
        })
        local ok, err = ab:can_activate()
        assert.is_false(ok)
        assert.is_string(err)
    end)

    it("ends ability and clears tasks", function()
        local asc = make_asc()
        local ab = ability.GameplayAbility.new(asc, { name = "Fireball" })
        ab:activate()
        ab:end_ability()
        assert.equal("inactive", ab.state)
    end)

    it("cancels other abilities with tag", function()
        local asc = make_asc()
        local other = ability.GameplayAbility.new(asc, {
            name = "Channel",
            ability_tags = function()
                local c = tag.GameplayTagContainer.new()
                c:add(tag.GameplayTag.new("ability.channel"))
                return c
            end,
        })
        asc.granted_abilities[other.handle] = other
        other:activate()

        local ab = ability.GameplayAbility.new(asc, {
            name = "Stun",
            cancel_abilities_with_tag = function()
                local c = tag.GameplayTagContainer.new()
                c:add(tag.GameplayTag.new("ability.channel"))
                return c
            end,
        })
        asc.granted_abilities[ab.handle] = ab
        ab:cancel_matching_abilities()
        assert.equal("inactive", other.state)
    end)
end)
