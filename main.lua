StateManager = require 'StateManager'
MainMenuState = require 'states/MainMenuState'
GameSetupState = require 'states/GameSetupState'
GameState = require 'states/GameState'

function love.load()
    StateManager.add(MainMenuState)
    StateManager.add(GameSetupState)
    StateManager.add(GameState)
    StateManager.load("MainMenuState")
end

function love.update(dt)
    StateManager.update(dt)
end

function love.draw()
    StateManager.draw()
end