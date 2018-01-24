require "./risk.rb"

game = Game.new


game.create_database
game.setup_players
game.setup_countries
game.setup_regions
game.setup_starting_reinforcements
game.run_game
