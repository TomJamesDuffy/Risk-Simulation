class Game

require 'rubygems'
require 'sqlite3'

	attr_reader :players, :countries, :DB	

	def initialize()

		File.delete("../database/countries.sqlite") if File.exists? "../database/countries.sqlite"
		File.delete("log.txt") if File.exists? "log.txt"

		@countries_hash = {}
		@region_hash = {}
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

		insert_query_CountryData = "INSERT INTO CountryData(Country, Region) VALUES(?, ?)"
		insert_query_ReinforcementData = "INSERT INTO ReinforcementData(Region, Reinforcements) VALUES(?, ?)"
		insert_query_ConnectorData = "INSERT INTO ConnectorData(Connector, Connectee) VALUES(?, ?)"

		country_array = []
		reinforcements_array = []
		connector_array = []

		File.foreach("../data/data1.txt") do |line|
        		country_array.push(line.split("\t"))
       	 	end

		country_array.length.times do |index|
                	@DB.execute(insert_query_CountryData, country_array[index][0], country_array[index][1].chomp)
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
		country_names = @DB.execute("SELECT Country FROM CountryData")
		country_names.each do |row|
			countryString = row.join()
			q = "SELECT Connectee FROM ConnectorData WHERE Connector = '" + countryString + "';"
			connectionArray = @DB.execute(q)

			@countries_hash[countryString] = Country.new(countryString, connectionArray)
	
		end
			log("Countries have been assigned to country objects.")
		
		#Assign countries to an owner
		count = 0
		@countries_hash.each do |country_name, country|
			if count < @players.length
				@players[count].add(country)
				@players[count].addTroops(country, 1)
				log("#{@players[count].name} has been assigned #{country_name}.")
				count += 1
			else
				count = 0
				@players[count].add(country)
				@players[count].addTroops(country, 1)
				log("#{@players[count].name} has been assigned #{country_name}.")
				count = 1
			end 	

		
		end

		log("Players have been assigned their starting countries.")
	end

	def setup_regions
		#Assign regions to a hash
		regions = @DB.execute("SELECT Region FROM ReinforcementData") 
		regions.each do |region|
			@region_hash[region.join('')] = @DB.execute("SELECT Country FROM Countrydata WHERE Region ='#{region.join('')}';") 
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
			@players.each do |player|
				log("Turn #{turn.to_s} has begun.")
				player.taketurn(@region_hash, self)
				turn += 1
			end
		end
end

class Player

#Need a "load game knowledge" bit where region hash comes in.

	attr_reader :name, :reinforcement_pool, :countries_owned
	attr_writer :reinforcement_pool

	def initialize(name, reinforcement_pool = 0)
		@name = name
		@countries_owned = Array.new
		@reinforcement_pool = reinforcement_pool
	end

	def taketurn(region_hash, game)
		#Assign reinforcements
			#Country reinforcements
			@reinforcement_pool += @countries_owned.length/3.ceil
			game.log("#{self.name} gained #{@countries_owned.length/3.ceil} reinforcements from territories.")
			
			#Create an array for include method below.		
			country_array = []
			@countries_owned.each_with_index do |country, index|
				country_array[index] = country.name
			end

			#Region owned reinforcements
			check = 0
			region_hash.each do |key, value|
				value.each do |country|
					if country_array.include? country.join('')
						check = 0
					else 
						check += 1
					end

				end

				if (check === 0 && key === "Africa")
					@reinforcement_pool += 3
					game.log("#{self.name} gained 3 extra reinforcements for controlling Africa") 
				elsif (check === 0 && key === "Europe")
					@reinforcement_pool += 5
					game.log("#{self.name} gained 5 extra reinforcements for controlling Europe" )
				elsif (check === 0 && key === "Asia")
					@reinforcement_pool += 7
					game.log("#{self.name} gained 7 extra reinforcements for controlling Asia" )
				elsif (check === 0 && key === "North America")
					@reinforcement_pool += 5
					game.log("#{self.name} gained 5 extra reinforcements for controlling North America") 
				elsif (check === 0 && key === "Australia")
					@reinforcement_pool += 2
					game.log("#{self.name} gained 2 extra reinforcements for controlling Australia" )
				elsif (check === 0 && key === "South America")
					@reinforcement_pool += 2
					game.log("#{self.name} gained 2 extra reinforcements for controlling South America") 
				else
					game.log("#{self.name} did not control this region.") 
						
				end
				
			end			

			game.log("#{self.name} gained a total of #{@reinforcement_pool} reinforcements this turn.")

			#Deploy strategy for this turn
			#turn_strategy = Strategy.new
			#turn_strategy.execute
	end
	
	
	def add(country)
		@countries_owned.push(country)
		country.owner = self
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
