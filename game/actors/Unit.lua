local Actor = require "game/actors/Actor"
local map = require "game/GameMap"

local Unit = Actor:new({type = "Unit", health = 100, movePenalty = 0, attack = 10, defense = 0, range = 1, 
                        equipment = {}, equipedWeapon = nil, equipedArmor = nil, equipedArtifact = nil})

local function itemPos(equipment, itemName)
    for i = 1, #equipment  do 
        if equipment[i].name == itemName then
            return equipment[i]
        end
    end
    return nil
end

function Unit:addItem(item)
    table.insert( self.equipment, item)
end

function Unit:removeItem(itemName)
    local pos = itemPos(self.equipment, itemName)
    if pos == nil then return end
    local lastPos = #self.equipment
    self.equipment[pos] = self.equipment[lastPos]
    self.equipment[lastPos] = nil
end

function Unit:hasItem(itemName)
    return itemPos(self.equipment, itemName) ~= nil
end

function Unit:getItem(itemName)
    return self.equipment[itemPos(self.equipment, itemName)]
end

local equipableItemTypes = 
{
    weapon = "equipedWeapon",
    armor = "equipedArmor",
    artifact = "equipedArtifact"
}

function Unit:useItem(itemName)
    local item = self:getItem(itemName)
    self:removeItem(itemName)
    
    local equipableField = equipableItemTypes[item.itemType]
    if equipableField ~= nil then
        local equipedItem = self[equipableField]
        if equipedItem then
            equipedItem:onUse(self, {unequip = true})
            self:addItem(equipedItem)
        end
        self[equipableField] = item
    end

    item:onUse(self)
end

function Unit:die()
    for _, item in ipairs(self.equipment) do
        item:setPos(self.x, self.y)
        map.addActor(item)
    end

    for _, field in pairs(equipableItemTypes) do
        if self[field] ~= nil then
            local item = self[field]
            item:setPos(self.x, self.y)
            map.addActor(item)
        end
    end

    map.removeActor(self)
end

function Unit:draw()
    Actor.draw(self)
    love.graphics.print(self.health, self.x*32, self.y*32)
end

function Unit:debugInfo()
    Actor.debugInfo(self) 
end

return Unit