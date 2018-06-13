local UI = {UUIDseed = -1}
package.loaded[...] = UI

local min, max = math.min, math.max

local Typeassert = require "utils/Typeassert"
local AABB = require "UI/AABB"
local Color = require "UI/Color"

UI.__index = UI

UI.theme = {
    Color("#63002dbb"),
    Color("#8b003fbb"),
    Color("#c1404dbb"),
    Color("#ffa535bb"),
    Color("#ffcd32bb"),
    font = love.graphics.newFont(14)
}

function UI.isUI(o)
    return getmetatable(o) == UI
end

function UI.isID(ID)
    return type(ID) == "number"
end

function UI:nextID(...)
    UI.UUIDseed = UI.UUIDseed + 1
    return UI.UUIDseed
end

-- fields:
--- _ID, _index, _widget, _hoveredWidget, _focusedWidget, _clickBegin, _clickEnd
---  origin, size, cursor
function UI.new(x, y, width, height)
    local naturalPred = function(x)
        return type(x) == "number" and x >= 0
    end
    Typeassert({x, y, width, height}, {naturalPred, naturalPred, naturalPred, naturalPred})

    local self =
        setmetatable(
        {
            _ID = UI.nextID(),
            __index = UI,
            _widget = nil,
            _hoveredWidget = nil,
            _focusedWidget = nil,
            _clickBegin = nil,
            _clickEnd = nil,
            origin = {x = x, y = y}, -- on screen real dimensions
            size = {x = width, y = height}, --- ^^^
            cursor = {x = x, y = y} -- relative to window's top-left corner, used for drawing UI elements
        },
        UI
    )
    return self
end

function UI:setWidget(widget)
    self._widget = widget
    widget._parent:removeWidget(widget)
    widget._parent = widget
    widget._UI = self
    self:reload()
end

function UI:update(dt, ...)
    local hovered = self._widget:getHovered()
    if hovered ~= self._hoveredWidget then -- won't trigger while same widget is hovered or no widget is hovered
        if self._hoveredWidget and not self._hoveredWidget.flags.passThru then
            self._hoveredWidget:mouseExited()
        end
        if hovered and not hovered.flags.passThru then
            hovered:mouseEntered()
        end
    end
    self._hoveredWidget = hovered
    self._widget:update(dt, ...)
end

function UI:draw(...)
    love.graphics.push("all")
    local old = {love.graphics.getScissor()}
    love.graphics.setScissor(self.origin.x, self.origin.y, self.size.x, self.size.y)
    local oldSetScissorFun = love.graphics.setScissor

    -- proxy function to always draw inside UI
    love.graphics.setScissor = function(x, y, w, h)
        oldSetScissorFun(self.origin.x, self.origin.y, self.size.x, self.size.y)
        return x and y and w and h and love.graphics.intersectScissor(x, y, w, h)
    end
    self:setRawCursor(self.origin.x, self.origin.y)
    self._widget:draw(...)
    love.graphics.setScissor = oldSetScissorFun
    love.graphics.setScissor(old[1], old[2], old[3], old[4])
    love.graphics.pop()
end

function UI:reload()
    self.cursor.x, self.cursor.y = self.origin.x, self.origin.y
    self:resize(self.origin.x, self.origin.y, self.size.x, self.size.y) -- resize with the same values triggers widget update
    self._hoveredWidget = nil
    self._focusedWidget = nil
    self._clickBegin = nil
    self._clickEnd = nil
    self._widget:reload()
end

function UI:resize(x, y, width, height)
    if type(x) ~= "number" or type(y) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then
        error("UI: invalid values to 'resize()'")
    end
    self.origin.x, self.origin.y = x, y
    self.size.x, self.size.y = max(0, width), max(0, height)
    if self._widget then
        self._widget:setAvailAABB(
            self.origin.x,
            self.origin.y,
            self.origin.x + self.size.x,
            self.origin.y + self.size.y
        )
        self._widget:setVisibleAvailAABB(self._widget._availAABB)
        self._widget:reloadLayout()
    end
end

-- true if gained focus, false otherwise
function UI:requestFocus(widget)
    if self._focusedWidget == nil or self._focusedWidget == widget then
        self._focusedWidget = widget
        return true
    else
        if self._focusedWidget:requestDropFocus() then
            self._focusedWidget = widget
            return true
        else
            return false
        end
    end
end

function UI:getAABB()
    return AABB(self.origin.x, self.origin.y, self.origin.x + self.size.x, self.origin.y + self.size.y)
end

function UI:X()
    return self.origin.x
end

function UI:Y()
    return self.origin.y
end

function UI:width()
    return self.size.x
end

function UI:height()
    return self.size.y
end

-- returns widget over which the mouse was pressed
function UI:getClickBegin()
    return self._clickBegin.widget
end

-- returns widget over which the mouse was released. Available in mouseReleased events
function UI:getClickEnd()
    return self._clickEnd.widget
end

-- returns mouse relative to UI
function UI:getRelativeMouse()
    local mx, my = love.mouse.getX(), love.mouse.getY()
    mx = min(max(self.origin.x, mx), self.origin.x + self.width) - self.origin.x
    my = min(max(self.origin.y, my), self.origin.y + self.height) - self.origin.y
    return mx, my
end

function UI:getRawCursor()
    return self.cursor.x, self.cursor.y
end

function UI:setRawCursor(x, y)
    self.cursor.x, self.cursor.y = x, y
end

-- returns widget at absolute x, y or nil if none. compares realAABB, so for 0 sized it is null
function UI:getWidgetAt(x, y, solid)
    return self._widget and self._widget:getWidgetAt(x, y, solid)
end

-- returns widget by ID with UIWidget tree traversal
function UI:getWidget(ID)
    return self._widget and UI._widget:getWidgetByID(ID)
end

function UI:getHoveredID()
    return self._hoveredWidget and self._hoveredWidget._ID
end

--============EVENTS============--

local function mousePressedEvt(ui, x, y, button)
    local widget = ui:getWidgetAt(x, y, true)
    if widget then
        if widget ~= ui._focusedWidget then
            if ui._focusedWidget then
                ui._focusedWidget:dropFocus()
            end
        end
        widget:mousePressed(x, y, button)
    elseif ui._focusedWidget then -- outside of any widget
        ui._focusedWidget:dropFocus()
    end
    ui._clickBegin = {widget = widget, x = x, y = y}
end

-- if any widget is focused, then release is send back to focused, otherwise to visible element
local function mouseReleasedEvt(ui, x, y, button)
    local targetWidget = ui:getWidgetAt(x, y, true) -- target is a solid widget
    ui._clickEnd = {widget = targetWidget, x = x, y = y}
    if ui._focusedWidget then
        ui._focusedWidget:mouseReleased(x, y, button)
    elseif targetWidget then
        targetWidget:mouseReleased(x, y, button)
    end
    ui._clickEnd = nil
    ui._clickBegin = nil
end

local function wheelMovedEvt(ui, x, y)
    if ui._hoveredWidget then
        ui._hoveredWidget:wheelMoved(x, y)
    end
end

-- can override, currently captures are active for focused element
function UI:keyPressedEvt(key, scancode, isrepeat)
    if self._focusedWidget then
        self._focusedWidget:keyPressed(key, scancode, isrepeat)
    end
end

-- can override, currently captures are active for focused element
function UI:keyReleasedEvt(key, scancode)
    if self._focusedWidget then
        self._focusedWidget:keyReleased(key, scancode)
    end
end

-- captures only for focused widget
local function textInputEvt(ui, text)
    if ui._focusedWidget then
        ui._focusedWidget:textInput(text)
    end
end

-- prioritize the focused widget, otherwise hovered
local function fileDirDroppedEvt(ui, file, isDir)
    local mx, my = love.mouse.getPosition()
    local targetWidget = ui:getWidgetAt(mx, my, true)
    if isDir then
        if ui._focusedWidget then
            ui._focusedWidget:directoryDropped(file)
        elseif targetWidget then
            targetWidget:directoryDropped(file)
        end
    else
        if ui._focusedWidget then
            ui._focusedWidget:fileDropped(file)
        elseif targetWidget then
            targetWidget:fileDropped(file)
        end
    end
end

--------
function UI:getEventHandlers()
    local events = {}
    ----
    events.mousepressed = function(x, y, button)
        mousePressedEvt(self, x, y, button)
    end
    events.mousereleased = function(x, y, button)
        mouseReleasedEvt(self, x, y, button)
    end
    events.wheelmoved = function(x, y)
        wheelMovedEvt(self, x, y)
    end
    events.keypressed = function(key, scancode, isrepeat)
        self:keyPressedEvt(key, scancode, isrepeat)
    end
    events.keyreleased = function(key, scancode)
        self:keyReleasedEvt(key, scancode)
    end
    events.textinput = function(text)
        textInputEvt(self, text)
    end
    events.filedropped = function(file)
        fileDirDroppedEvt(self, file, false)
    end
    events.directorydropped = function(file)
        fileDirDroppedEvt(self, file, true)
    end
    ----
    return events
end
--==============================--

-------------------------------------------------------------------------------------
return setmetatable(
    UI,
    {
        __call = function(_, ...)
            local ok, ret = pcall(UI.new, ...)
            if ok then
                return ret
            else
                error("UI: " .. ret)
            end
        end
    }
)
