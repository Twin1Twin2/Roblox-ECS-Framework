
return function()
    local root = game:GetService("ReplicatedStorage"):FindFirstChild("ECSFramework")
    local ECSSystem = require(root.ECSSystem)

    describe("new()", function()

        it("should work", function()
            local system

            expect(function()
                system = ECSSystem.new("Test System")
            end).never.to.throw()
            expect(system).to.be.ok()
        end)
    end)

    describe("", function()
        --
    end)

    -- how would you test getting entities?
    -- hmm. do it in system test?
end