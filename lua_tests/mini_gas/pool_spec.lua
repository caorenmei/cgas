require("lua_tests.support.env")
local pool = require("mini_gas.pool")

describe("mini_gas v2 pool", function()
    it("reuses tables from table_pool after release", function()
        local t = pool.acquire_table()
        t.foo = "bar"
        pool.release_table(t)

        local reused = pool.acquire_table()
        assert.equal(t, reused)
        assert.is_nil(reused.foo)
    end)

    it("does not duplicate table in pool on double release", function()
        local t = pool.acquire_table()
        t.key = 1
        pool.release_table(t)
        pool.release_table(t)

        local a = pool.acquire_table()
        local b = pool.acquire_table()
        assert.equal(t, a)
        assert.is_not.equal(t, b)
    end)

    it("reuses short arrays and resets .n after release", function()
        local t = pool.acquire_short_array()
        t[1] = 42
        t.n = 5
        pool.release_short_array(t)

        local reused = pool.acquire_short_array()
        assert.equal(t, reused)
        assert.equal(0, reused.n)
        assert.is_false(reused[1])
    end)

    it("does not duplicate short array in pool on double release", function()
        local t = pool.acquire_short_array()
        t[1] = 1
        t.n = 1
        pool.release_short_array(t)
        pool.release_short_array(t)

        local a = pool.acquire_short_array()
        local b = pool.acquire_short_array()
        assert.equal(t, a)
        assert.is_not.equal(t, b)
    end)

    it("reuses long arrays and resets .n after release", function()
        local t = pool.acquire_long_array()
        t[1] = "x"
        t.n = 3
        pool.release_long_array(t)

        local reused = pool.acquire_long_array()
        assert.equal(t, reused)
        assert.equal(0, reused.n)
        assert.is_false(reused[1])
    end)

    it("does not duplicate long array in pool on double release", function()
        local t = pool.acquire_long_array()
        t[1] = 1
        t.n = 1
        pool.release_long_array(t)
        pool.release_long_array(t)

        local a = pool.acquire_long_array()
        local b = pool.acquire_long_array()
        assert.equal(t, a)
        assert.is_not.equal(t, b)
    end)
end)
