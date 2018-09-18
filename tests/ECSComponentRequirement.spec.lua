
return function()
    local root = game:GetService("ReplicatedStorage"):FindFirstChild("ECSFramework")
    local ECSComponentRequirement = require(root.ECSComponentRequirement)
    local ECSEntity = require(root.ECSEntity)
    local Table = require(root.Table)

    describe("new()", function()
        it("should work", function()
            local componentRequirement

            expect(function()
                componentRequirement = ECSComponentRequirement.new()
            end).never.to.throw()
            expect(componentRequirement).to.be.ok()
        end)
    end)

    describe("Setting requirements", function()
        it("should work", function()
            local componentRequirement = ECSComponentRequirement.new()

            expect(function()
                componentRequirement:All("AllComponent1", "AllComponent2")
                    :One("OneComponent1", "OneComponent2")
                    :Exclude("ExcludeComponent1", "ExcludeComponent2")
            end).never.to.throw()
        end)

        it("should prevent collisions", function()
            local componentRequirement = ECSComponentRequirement.new()

            componentRequirement:Exclude("ExcludeComponent")
            componentRequirement:All("AllComponent", "ExcludeComponent")
            componentRequirement:One("OneComponent", "ExcludeComponent", "AllComponent")
            componentRequirement:All("OneComponent")
            componentRequirement:Exclude("AllComponent", "OneComponent")

            expect(Table.Contains(componentRequirement.ExcludeList, "ExcludeComponent")).to.equal(true)
            expect(Table.Contains(componentRequirement.AllList, "ExcludeComponent")).to.equal(false)
            expect(Table.Contains(componentRequirement.OneList, "ExcludeComponent")).to.equal(false)

            expect(Table.Contains(componentRequirement.ExcludeList, "AllComponent")).to.equal(false)
            expect(Table.Contains(componentRequirement.AllList, "AllComponent")).to.equal(true)
            expect(Table.Contains(componentRequirement.OneList, "AllComponent")).to.equal(true)

            expect(Table.Contains(componentRequirement.ExcludeList, "OneComponent")).to.equal(false)
            expect(Table.Contains(componentRequirement.AllList, "OneComponent")).to.equal(true)
            expect(Table.Contains(componentRequirement.OneList, "OneComponent")).to.equal(true)
        end)
    end)

    describe("EntityBelongs()", function()
        it("All should work", function()
            local componentRequirement = ECSComponentRequirement.new()
            componentRequirement:All("AllComponent1", "AllComponent2")

            local entity = ECSEntity.new()

            entity:AddComponentToEntity("AllComponent1", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(false)
            entity:AddComponentToEntity("AllComponent2", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(true)
        end)

        it("One should work", function()
            local componentRequirement = ECSComponentRequirement.new()
            componentRequirement:One("OneComponent1", "OneComponent2")

            local entity = ECSEntity.new()

            entity:AddComponentToEntity("EmptyComponent", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(false)
            entity:AddComponentToEntity("OneComponent1", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(true)
            entity:AddComponentToEntity("OneComponent2", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(true)
            entity:RemoveComponentFromEntity("OneComponent1")
            expect(componentRequirement:EntityBelongs(entity)).to.equal(true)
            entity:RemoveComponentFromEntity("OneComponent2")
            expect(componentRequirement:EntityBelongs(entity)).to.equal(false)
        end)

        it("One and All should work", function()
            local componentRequirement = ECSComponentRequirement.new()
            componentRequirement:All("AllComponent1", "AllComponent2")
            componentRequirement:One("OneComponent")

            local entity = ECSEntity.new()

            entity:AddComponentToEntity("EmptyComponent", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(false)
            entity:AddComponentToEntity("OneComponent", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(false)
            entity:AddComponentToEntity("AllComponent1", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(false)
            entity:AddComponentToEntity("AllComponent2", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(true)
        end)

        it("Exclude should work", function()
            local componentRequirement = ECSComponentRequirement.new()
            componentRequirement:One("OneComponent")
            componentRequirement:Exclude("ExcludeComponent")

            local entity = ECSEntity.new()

            entity:AddComponentToEntity("OneComponent", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(true)
            entity:AddComponentToEntity("ExcludeComponent", {})
            expect(componentRequirement:EntityBelongs(entity)).to.equal(false)
        end)


    end)
end