class Game

require 'rubygems'
require 'sqlite3'

	attr_reader :players, :country_array	

	def initialize()

		File.delete("../database/countries.sqlite") if File.exists? "../database/countries.sqlite"
		File.delete("log.txt") if File.exists? "log.txt"

		@country_array = []
		@region_array = []
		@players = Array.new
		@DB = SQLite3::Database.new("../database/countries.sqlite")
	end


	def log(string)
		File.open('log.txt', 'a') { |f| f.write(string +"\n") }
	end

	def setup_players
		#Get number of players from the user
		puts "How many computer players?"
		player_num = gets.chomp.to_i

		#Create that many player objects
		player_num.times do |index| 
			@players[index] = Player.new("Computer #{index}")
		end

		#Assign seats
		@players.shuffle! 
		log("#{player_num} players have been set up.")
	end

	def create_database
		@DB.execute("

        CREATE TABLE CountryData (
                Country TINYTEXT,
                Region TINYTEXT,
		Owner TINYTEXT,
		Reinforcements TINYTEXT,
                PRIMARY KEY (Country),
                FOREIGN KEY (Region) REFERENCES ReinforcementData(Region)
                FOREIGN KEY (Country) REFERENCES ConnectorData(Connector)
                )
		")

		@DB.execute("

        CREATE TABLE ConnectorData (
                Connection INTEGER PRIMARY KEY,
                Connector TINYTEXT,
                Connectee TINYTEXT,
                FOREIGN KEY (Connectee) REFERENCES CountryData(Country)
                )
		")

		@DB.execute("

        CREATE TABLE ReinforcementData (
                Region TINYTEXT,
                Reinforcements TINYINT NOT NULL,
                PRIMARY KEY (Region)
                FOREIGN KEY (Region) REFERENCES CountryData(Region)
                )
		")

		@DB.execute("

        CREATE TABLE riskStatus(
                Country TINYTEXT,
                Turn TINYINT NOT NULL,
                Reinforcements TINYINT NOT NULL,
                Owner TINYTEXT,
                PRIMARY KEY (Country)
                FOREIGN KEY (Country) REFERENCES CountryData(Country)
		)
		")

		insert_query_CountryData = "INSERT INTO CountryData(Country, Region, Owner, Reinforcements) VALUES(?, ?, ?, ?)"
		insert_query_ReinforcementData = "INSERT INTO ReinforcementData(Region, Reinforcements) VALUES(?, ?)"
		insert_query_ConnectorData = "INSERT INTO ConnectorData(Connector, Connectee) VALUES(?, ?)"

		country_array = []
		reinforcements_array = []
		connector_array = []

		File.foreach("../data/data1.txt") do |line|
        		country_array.push(line.split("\t"))
       	 	end

		country_array.length.times do |index|
                	@DB.execute(insert_query_CountryData, country_array[index][0], country_array[index][1].chomp, "not yet allocated", "not yet allocated")
        	end

		File.foreach("../data/data2.txt") do |line|
        		reinforcements_array.push(line.split("\t"))
        	end

		reinforcements_array.length.times do |index|
                	@DB.execute(insert_query_ReinforcementData, reinforcements_array[index][0].chomp, reinforcements_array[index][1].to_i)
        	end

		File.foreach("../data/data3.txt") do |line|
        		connector_array.push(line.split("\t"))
        	end

		connector_array.length.times do |index|
                	@DB.execute(insert_query_ConnectorData, connector_array[index][0], connector_array[index][1])
        	end
		log("World database has been created")
	end

	def setup_countries
		#Assign countries to country objects
		country_names = @DB.execute("SELECT Country, Region FROM CountryData")
		country_names.each do |row|
			countryString = row[0]
			regionString = row[1]
			q = "SELECT Connectee FROM ConnectorData WHERE Connector = '" + countryString + "';"
			connectionArray = @DB.execute(q)

			countryObject = Country.new(countryString, connectionArray, regionString)
			@country_array.push(countryObject)
	
		end
			log("Countries have been assigned to country objects.")
		
		#Assign countries to an owner
		count = 0
		@country_array.each do |country|
			if count < @players.length
				@players[count].add(country)
				@players[count].addTroops(country, 1)
				country.owner = @players[count]
				log("#{@players[count].name} has been assigned #{country.name}.")
				count += 1
			else
				count = 0
				@players[count].add(country)
				@players[count].addTroops(country, 1)
				country.owner = @players[count]
				log("#{@players[count].name} has been assigned #{country.name}.")
				count = 1
			end 	

		
		end

		log("Players have been assigned their starting countries.")
	end

	def setup_regions
		#Creates region object
		regions = @DB.execute("SELECT Region, Reinforcements FROM ReinforcementData") 
		regions.each do |region_data|
			region_object = Region.new(region_data[0], region_data[1])
			@country_array.each do |country| 
				if country.region === region_data[0]
					region_object.countries.push(country)
				end
			end

			@region_array.push(region_object)
		end	
	end

	def setup_starting_reinforcements
		#Allocate reinforcements in relation to the number of players
		starting_reinforcements = (50 - (@players.length*5))
	
		@players.each do |player|
			player.reinforcement_pool = starting_reinforcements	
		end

		#Distribute reinforcements randomly among owned countries
		@players.each do |player|
			while player.reinforcement_pool > 0
				random = Random.rand*(player.countries_owned.length).ceil
				player.addTroops(player.countries_owned[random], 1)
			end
		end
		@players.each do |player|
			player.countries_owned.each do |country|
				log("#{player.name} owns #{country.name} which has #{country.troops} reinforcements.")
			end
		end

		log("Players have been assigned their starting reinforcements.") 
	end
	
	def run_game
		#Players take turns until game is over
		turn = 0
		#while !game_over 
			#@players.each do |player|
				#log("Turn #{turn.to_s} has begun.")
				@players[0].taketurn(@region_array, @country_array, self)
				#turn += 1
			#end
		#end
	end		
end

class Strategy
	
	def initialize(region_array, country_array, player)
		@region_array = region_array
		@country_array = country_array
		@player = player
	end
	
	#Create metrics for computer to evaluate map.
	
	def create_metrics
		#Proportion of troops owned per region & Proportion of countries owned per region
		troop_density = {}
		country_density = {}
		metrics = {}

		cou_den_all = 0
		cou_den_player = 0

		cou_count = 0
		cou_count_player = 0

		@region_array.each do |region|
			region.countries.each do |country|
				cou_den_all += country.troops
				cou_count += 1
				if country.owner === @player
					cou_den_player += country.troops
					cou_count_player += 1
				end
			end
			troop_density["#{region.name}"] = (cou_den_player.to_f/cou_den_all.to_f).round(2)
			country_density["#{region.name}"] = (cou_count_player.to_f/cou_count.to_f).round(2)

			cou_den_all = 0
			cou_den_player = 0
			cou_count = 0
			cou_count_player = 0
		end
		metrics["Metrics"] = [troop_density, country_density]
	end	


	#identify appropriate strategy
	def allocate_reinforcements(metrics)
	#Assign reinformcements to strategy and random
		strategy = (@player.reinforcement_pool * 0.7).round(0)
		random_rf = @player.reinforcement_pool - strategy
		hold = ""
		tracker = 0.0

		#Identify region with greatest potential
		metrics[0].each do |key, value| 
			if (tracker < value) && (value != 1)
				tracker = value
				hold = key
			end
			
		end

		#Allocate 70% of reinforcement pool to region with greatest potential		
		while strategy > 0 
			@player.countries_owned.each do |country|
				if country.region === hold
					@player.addTroops(country, 1)
					strategy -= 1
				end
			end
		end
		
		#Allocate remainder of reinforcement pool randomly among the players owned countries
		while random_rf > 0
			random = Random.rand*(@player.countries_owned.length).ceil
			@player.addTroops(@player.countries_owned[random], 1)
			random_rf -= 1
		end
		
	end

	def identify_and_attack_targets(metrics)
		
	end

	#Execute strategy		
	def execute
		allocate_reinforcements(create_metrics)
		identify_and_attack_targets(create_metrics)
	end

end

class Player

	attr_reader :name, :reinforcement_pool, :countries_owned, :regions_owned
	attr_writer :reinforcement_pool

	def initialize(name, reinforcement_pool = 0)
		@name = name
		@countries_owned = Array.new
		@reinforcement_pool = reinforcement_pool
		@regions_owned = Array.new
	end

	def taketurn(region_array, country_array, game)
		# Count reinforcements earned.
		# Reinforcements related to countries held.
		@reinforcement_pool += @countries_owned.length/3.ceil
		game.log("#{self.name} gained #{@countries_owned.length/3.ceil} reinforcements from territories.")

		#Reinforcements related to regions held.
		region_array.each do |region|
			if region.countries - countries_owned === []
				regions_owned.push(region)
				@reinforcement_pool += region.reinforcements
				game.log("#{self.name} gained #{region.reinforcements} from controlling #{region.name}.")
			else
				regions_owned.delete(region)
			end
		end			

			game.log("#{self.name} gained a total of #{@reinforcement_pool} reinforcements this turn.")

			#Deploy strategy for this turn
			turn_strategy = Strategy.new(region_array, country_array, self)
			turn_strategy.execute
	end
	
	
	def add(country)
		@countries_owned.push(country)
		country.owner = self
	end
	
	def roll_dice
		roll = (Random.rand*6).ceil
	end
	
	def roll_attack_dice(defenderDice, attackerDice)
		attackerTroopsDestroyed = 0
		defenderTroopsDestroyed = 0


		defender_array = []
		attacker_array = []
		
		#Roll dice and push result to array for attacker and defender
		defenderDice.times do
			roll
			defender_array.push(roll)
		end

		attackerDice.times do
			roll
			attacker_array.push(roll)
		end
		
		#Order array from smallest to largest
		defender_array.sort!
		attacker_array.sort!

		#If the defender has more dice remove the lowest so it is equal to the attacker
		#If the attacker has more dice do the inverse.
		if defender_array.length > attacker_array.length
			excess = defender_array.length - attacker_array.length
			excess.times do
				defender_array.shift!
			end
		elsif attacker_array.length > defender_array.length
			excess = attacker_array.length - defender_array.length
			excess.times do
				attacker_array.shift!
			end
		end

		outcome = []
		#Compare the attacking and defending dice and push to an array
		attacker_array.length.each_with_index do |item, index|
			outcome.push(attacker_array[index] - defender_array[index])
			
		end	
		#Based on the number of comparisons destroy either an attacking or defending troop.
		outcome.each do |item|
			if outcome <= 0
				attackerTroopsDestroyed += 1
			elsif outcome > 0
				defenderTroopsDestroyed =+ 1
			end	
		end		

		#return the number of attacking/defending troops that have been destroyed.
	
		return attackerTroopsDestroyed, defenderTroopsDestroyed 
	end

	def addTroops(country, number)
		country.troops += number.to_i
		@reinforcement_pool -= 1
	end

	def subTroops(country, number)
		country.troops -= number.to_i
	end
	
	def attack(attackingCountry, defendingCountry, defendingPlayer, troopsAttacker, troopsDefender)

		atd = 0
		dtd = 0

		while troopsAttacker > 0 || troopsDefender > 0
			if troopsAttacker >= 3 && troopsDefender >= 2
				a, d = roll_attack_dice(3, 2)
			elsif troopsAttacker >= 3 && troopsDefender = 1
				a, d = roll_attack_dice(3, 1)
			elsif troopsAttacker = 2 && troopsDefender = 1
				a, d = roll_attack_dice(2, 2)
			elsif troopsAttacker = 2 && troopsDefender = 1
				a, d = roll_attack_dice(2, 1)
			elsif troopsAttacker = 1 && troopsDefender = 1
				a, d = roll_attack_dice(1, 1)
			elsif troopsAttacker = 1 && troopsDefender = 2
				a, d = roll_attack_dice(1, 2)
			end

			troopsAttacker -= a
			troopsDefender -= d
		
			atd += a
			dtd += d
		end
			@player.subTroops(attackingCountry, atd)
			@player.subTroops(defendingCountry, dtd)
		
		if troopsDefender === 0 
			defendingCountry.owner = @player
			@player.countries_owned.push(defendingCountry)
			defendingPlayer.countries_owned.delete(defendingCountry)
			defendingCountry.troops = (troopsAttacker - atd)
			
		end
			
	end
	
end


class Country

	attr_reader :connections, :name, :owner, :troops, :region
	attr_writer :owner, :troops

	def initialize(name, connections, region, troops = 0)
		@connections = connections
		@name = name
		@region = region
		@troops = troops
	end

end

class Region
	
	attr_reader :reinforcements, :countries, :name 
	attr_writer :countries
	
	def initialize(name, reinforcements)

	@name = name
	@countries = Array.new
	@reinforcements = reinforcements

	end
end






