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
				country.owner = @players[count]
				log("#{@players[count].name} has been assigned #{country.name}.")
				count += 1
			else
				count = 0
				@players[count].add(country)
				country.owner = @players[count]
				log("#{@players[count].name} has been assigned #{country.name}.")
				count = 1
			end 	

			setup_country_connections
		end

		log("Players have been assigned their starting countries.")
	end

	def setup_country_connections
		@country_array.each do |country|
			country.connections.each do |connecting_country|
				@country_array.each do |country_2|
					if connecting_country.join("").strip == country_2.name
						country.connectionsObjects.push(country_2)
					end
				end
			end
		end
	end

	def setup_regions
		#Creates region object
		regions = @DB.execute("SELECT Region, Reinforcements FROM ReinforcementData") 
		regions.each do |region_data|
			region_object = Region.new(region_data[0], region_data[1])
			@country_array.each do |country| 
				if country.region === region_data[0]
					region_object.countries.push(country)
					country.regionObject = region_object
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
				log("#{player.name} owns #{country.name} which has #{country.troops} troops.")
			end
		end

		log("Players have been assigned their starting reinforcements.") 
		log("---------------------------------------------------------") 
		log("GAME START")
		log("---------------------------------------------------------") 
	end
	
	def run_game
		#Players take turns until game is over
		turn = 0 
		game_over = false
		while !game_over 
			@players.each do |player|
				turn += 1
				log("Turn #{turn.to_s} has begun.")
				player.taketurn(@region_array, @country_array, self)

				if player.countries_owned.length == 42
					end_game(player)
				end
			end
		end
	end		
	
	def player_check
		@players.each do |player|
			if player.countries_owned.length == 0
				@players.delete(player)
			end
		end
	end

	def end_game(player)
		puts "#{player.name} has won by conquering all of the countries!"
		log("#{player.name} has won by conquering all of the countries!")
		game_over = true
		exit
	end
end

class Strategy
	
	def initialize(region_array, country_array, player, game)
		@region_array = region_array
		@country_array = country_array
		@player = player
		@target_region = ""
		@game = game
		@fresh_expansion = false
		@reinforcement_focus = ""
		@attack_focus = ""
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
			troop_density[region] = (cou_den_player.to_f/cou_den_all.to_f).round(4)
			country_density[region] = (cou_count_player.to_f/cou_count.to_f).round(4)

			cou_den_all = 0
			cou_den_player = 0
			cou_count = 0
			cou_count_player = 0
		end
		metrics["Metrics"] = [troop_density, country_density]
	end	

	def identify_focus
		metrics = create_metrics		

		owned = []
		no_presence = []
		some_presence = []
		
		#Sort regions into presence
		metrics[0].each do |key, value| 
			if value == 1
				owned.push([key, value])
			elsif value == 0
				no_presence.push([key, value])
			else
				some_presence.push([key, value])
				some_presence.sort! {|a,b| a[1] <=> b[1]}
			end
		end

		#Identify target region based on sorting
		if some_presence != []
			@target_region = some_presence[-1][0] #target region with greatest presence
			return @target_region
		elsif no_presence != []
			foothold = []
			@player.countries_owned.each do |country|
				country.connectionsObjects.each do |country_connection|
					if !@player.regions_owned.include? country_connection.regionObject
						foothold.push([country, country_connection])
					end
				end
			end
			return foothold
		else	
			@game.end_game(@player)
		end			
	end

	def allocate_reinforcements(focus)
		if focus.class == Region #if we get a region from identify_focus...
			strategy = (@player.reinforcement_pool * 0.7).round(0)
			random_rf = @player.reinforcement_pool - strategy
		

			@game.log("#{@player.name} identified #{focus.name} as being a priority, therefore the majority of reinforcements have been allocated to this region.")		
			while strategy > 0 
				@player.countries_owned.each do |country|
					if country.region == @target_region.name
						@player.addTroops(country, 1)
						strategy -= 1
					end
				end
			end
		
			while random_rf > 0
				random = Random.rand*(@player.countries_owned.length).ceil
				@player.addTroops(@player.countries_owned[random], 1)
				random_rf -= 1
			end

		elsif focus.class == Array #If we get an array from identify_focus...
			@game.log("#{@player.name} identified #{focus[0][1].name} as being a priority, therefore reinforcements have been allocated to #{focus[0][0].name} for an imminent attack.")		
			while @player.reinforcement_pool > 0
				@player.addTroops(focus[0][0], 1)
			end
		end
	end
	

	def identify_targets
		attackFrom = ""
		attackTo = ""
		focus = identify_focus
		if focus.class == Region
			@player.countries_owned.each do |country|
				if country.regionObject == focus && country.troops > 3 
					country.connectionsObjects.each do |country_2|
						focus.countries.each do |focus_region_c|
							if (focus_region_c.name === country_2.name) && ((country.troops - focus_region_c.troops) > 2) && (country_2.owner != @player)
								attackFrom = country
								attackTo = country_2
							end
						end
					end
				end
			end
	
		elsif focus.class == Array
			attackFrom = focus[0][0]
			attackTo = focus[0][1]	
		end
		return attackFrom, attackTo
	end
	
	def attack_targets
		attacksCompleted = false
		until attacksCompleted == true 
			attackCountry, defendCountry = identify_targets
			if attackCountry.class == Country && defendCountry.class == Country && (defendCountry.owner != @player) && ((attackCountry.troops - defendCountry.troops) > 2)
				@player.attack(attackCountry, defendCountry, defendCountry.owner, attackCountry.troops - 1, defendCountry.troops, @game)
			else
				attacksCompleted = true
			end
		end
	end

	#Execute strategy		
	def execute
		allocate_reinforcements(identify_focus)
		attack_targets
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
		if ((@countries_owned.length)/3) < 3
			extra = 3
		else
			extra = @countries_owned.length/3
		end

		@reinforcement_pool += extra 
		game.log("#{self.name} gained #{extra} reinforcements from territories. Reinforcement pool: #{@reinforcement_pool}")

		#Reinforcements related to regions held.
		region_array.each do |region|
			if region.countries - countries_owned === []
				regions_owned.push(region)
				@reinforcement_pool += region.reinforcements
				game.log("#{self.name} gained #{region.reinforcements} reinforcements from controlling #{region.name}. Reinforcement pool: #{@reinforcement_pool}")
			else
				regions_owned.delete(region)
			end
		end			

			game.log("#{self.name} gained a total of #{@reinforcement_pool} reinforcements this turn.")

			#Deploy strategy for this turn
			turn_strategy = Strategy.new(region_array, country_array, self, game)
			turn_strategy.execute
			
			
			game.log("At the end of the turn the map looks as follows")

			game.players.each do |player|
				player.countries_owned.each do |country|
					game.log("#{player.name} owns #{country.name} which has #{country.troops} troops.")
				end
			end
	end
	
	
	def add(country)
		@countries_owned.push(country)
		country.owner = self
	end
	
	def roll_dice
		roll = (Random.rand*6).ceil
		return roll
	end
	
	def roll_attack_dice(attackerDice, defenderDice)
		attackerTroopsDestroyed = 0
		defenderTroopsDestroyed = 0

		defender_array = []
		attacker_array = []
		outcome = []

		#Roll dice and push result to array for attacker and defender
		defenderDice.times do
			defender_array.push(roll_dice)
		end

		attackerDice.times do
			attacker_array.push(roll_dice)
		end
		
		#Order array from smallest to largest
		defender_array.sort!
		attacker_array.sort!

		#If the defender has more dice remove the lowest so it is equal to the attacker
		#If the attacker has more dice do the inverse.
		if defender_array.length > attacker_array.length
			excess = defender_array.length - attacker_array.length
			excess.times do
				defender_array.shift
			end
		elsif attacker_array.length > defender_array.length
			excess = attacker_array.length - defender_array.length
			excess.times do
				attacker_array.shift
			end
		end

		#Compare the attacking and defending dice and push to an array
		attacker_array.length.times do |index|
			outcome.push(attacker_array[index] - defender_array[index])
		end	

		#Based on the number of comparisons destroy either an attacking or defending troop.
		outcome.each do |item|
			if item <= 0
				attackerTroopsDestroyed += 1
			elsif item > 0
				defenderTroopsDestroyed += 1
			end	
		end		
		#return the number of attacking/defending troops that have been destroyed.
		return attackerTroopsDestroyed, defenderTroopsDestroyed 
	end

	def addTroops(country, number)
		if @reinforcement_pool > 0
			country.troops += number.to_i
			@reinforcement_pool -= 1
		end
	end

	def subTroops(country, number)
		country.troops -= number.to_i
	end
	
	def attack(attackingCountry, defendingCountry, defendingPlayer, troopsAttacker, troopsDefender, game)
		
		game.log("#{self.name} attacked #{defendingCountry.name} owned by #{defendingPlayer.name} from #{attackingCountry.name} with #{troopsAttacker} (Total: #{attackingCountry.troops}) troops.")
		game.log("#{defendingPlayer.name} defended with #{troopsDefender} troops.")	
 
		game.log("ATTACKING - #{troopsAttacker}, DEFENDING - #{troopsDefender}")

		until troopsAttacker == 0 || troopsDefender == 0
			
			if troopsAttacker >= 3 && troopsDefender >= 2
				a, d = roll_attack_dice(3, 2)
			elsif troopsAttacker >= 3 && troopsDefender == 1
				a, d = roll_attack_dice(3, 1)
			elsif troopsAttacker == 2 && troopsDefender >= 2 
				a, d = roll_attack_dice(2, 2)
			elsif troopsAttacker == 2 && troopsDefender == 1
				a, d = roll_attack_dice(2, 1)
			elsif troopsAttacker == 1 && troopsDefender == 1
				a, d = roll_attack_dice(1, 1)
			elsif troopsAttacker == 1 && troopsDefender >= 2
				a, d = roll_attack_dice(1, 2)
			end
			
			troopsAttacker -= a
			troopsDefender -= d

			game.log("ATTACKING - #{troopsAttacker}, DEFENDING - #{troopsDefender}")

		end

		if troopsDefender === 0 
			defendingCountry.owner = self
			defendingCountry.troops = troopsAttacker

			attackingCountry.troops = 1

			self.countries_owned.push(defendingCountry)
			defendingPlayer.countries_owned.delete(defendingCountry)
			
			game.log("#{self.name} successfully captured #{defendingCountry.name}.")
			game.log("#{defendingCountry.name} now has #{defendingCountry.troops} troops holding it.")

		elsif troopsAttacker === 0
			attackingCountry.troops = 1
			defendingCountry.troops = troopsDefender

			game.log("#{self.name} failed to capture #{defendingCountry.name}.")
			game.log("#{defendingCountry.name} now has #{defendingCountry.troops} troops holding it.")
		end
		
		#Player check
		game.player_check	
	end
	
end


class Country

	attr_reader :connections, :name, :owner, :troops, :region, :regionObject, :connectionsObjects
	attr_writer :owner, :troops, :regionObject, :connectionsObjects

	def initialize(name, connections, region, troops = 1)
		@connections = connections
		@name = name
		@region = region
		@troops = troops
		@connectionsObjects = Array.new
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






