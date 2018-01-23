require './databaseCreate.rb'

class Player

#Need a "load game knowledge" bit where region hash comes in.

	attr_reader :name, :reinforcement_pool, :countries_owned
	attr_writer :reinforcement_pool

	def initialize(name, reinforcement_pool = 0)
		@name = name
		@countries_owned = Array.new
		@reinforcement_pool = reinforcement_pool
	end

	def taketurn(region_hash)
		#Assign reinforcements
			#Country reinforcements
			reinforcement_pool += countries_owned.length/3.ceil
			
			#Region owned reinforcements
			region_hash.each do |region|
				if player.countries_owned.include? region_hash["Africa"]
					reinforcement_pool += 5	
			end			

		#Choose attack
		#Movement
	end
	
	
	def add(country)
		@countries_owned.push(country)
		country.owner = @self
	end
	
	def roll_dice
		roll = (Random.rand*6).ceil
	end

	def addTroops(country, number)
		country.troops += number.to_i
		@reinforcement_pool -= 1
	end

	def subTroops(country, number)
		country.troops -= number.to_i
	end
	
end


class Country

	attr_reader :connections, :name, :owner, :troops
	attr_writer :owner, :troops

	def initialize(name, connections, troops = 0)
		@connections = connections
		@name = name
		@troops = troops
	end

end

puts "Enter computer names"
player_names = gets.chomp

players = player_names.split(' ')

#Create and assign player objects to hash
players.length.times do |index| 
	players[index] = Player.new(players[index])
	end

#Assign seats
players.shuffle! 

#Assign countries to country objects
countries_hash= {}
country_names = DB.execute("SELECT Country FROM CountryData")

country_names.each do |row|
	countryString = row.join()

	q = "SELECT Connectee FROM ConnectorData WHERE Connector = '" + countryString + "';"
	connectionArray = DB.execute(q)

	countries_hash[countryString] = Country.new(countryString, connectionArray)
	
end

#Assign countries to an owner
count = 0
countries_hash.each do |country_name, country|
	if count < players.length
		players[count].add(country)
		players[count].addTroops(country, 1)
		count += 1
	else
		count = 0
		players[count].add(country)
		players[count].addTroops(country, 1)
		count = 1
	end 	
end

#Allocate reinforcements in relation to the number of players
starting_reinforcements = (50 - (players.length*5))
	
players.each do |player|
	player.reinforcement_pool = starting_reinforcements	
end

#Distribute reinforcements randomly among owned countries
players.each do |player|
	while player.reinforcement_pool > 0
		random = Random.rand*(player.countries_owned.length).ceil
		player.addTroops(player.countries_owned[random], 1)
	end
end

#This should be, 'prepare region hash' when simulation starts.
region_hash = Hash.new
regions = DB.execute("SELECT Region FROM ReinforcementData") 
	regions.each do |region|
		region_hash[region] = DB.execute("SELECT Country FROM Countrydata WHERE Region ='#{region.join('')}';") 
	end



#Players take turns until game is over
=begin
turn = 0
while !game_over 
	players.each do |player|
		player.taketurn(region_hash)
		turn += 1
	end
end
=end

#Testing
=begin
players.each do |player|
	puts player.name
	player.countries_owned.each do |country|
		puts country.name + ", troops: " + country.troops.to_s
	end
end
=end
