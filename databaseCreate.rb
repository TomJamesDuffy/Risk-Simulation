require 'rubygems'
require 'sqlite3'


DBNAME = "countries.sqlite"
File.delete(DBNAME) if File.exists?DBNAME

DB = SQLite3::Database.new( DBNAME )
DB.execute("

	CREATE TABLE CountryData (
		Country TINYTEXT, 
		Region TINYTEXT, 
		PRIMARY KEY (Country),
		FOREIGN KEY (Region) REFERENCES ReinforcementData(Region)
		FOREIGN KEY (Country) REFERENCES ConnectorData(Connector)
		)
")

DB.execute("

	CREATE TABLE ConnectorData (
		Connection INTEGER PRIMARY KEY, 
		Connector TINYTEXT,
		Connectee TINYTEXT,
		FOREIGN KEY (Connectee) REFERENCES CountryData(Country)
		)
")

DB.execute("

	CREATE TABLE ReinforcementData (
		Region TINYTEXT,
		Reinforcements TINYINT NOT NULL,
		PRIMARY KEY (Region)
		FOREIGN KEY (Region) REFERENCES CountryData(Region)
		)
")

DB.execute("

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

File.foreach("data1.txt") do |line|
	country_array.push(line.split("\t"))
	end

country_array.length.times do |index|
		DB.execute(insert_query_CountryData, country_array[index][0], country_array[index][1].chomp)  
	end

File.foreach("data2.txt") do |line|
	reinforcements_array.push(line.split("\t"))
	end

reinforcements_array.length.times do |index|
		DB.execute(insert_query_ReinforcementData, reinforcements_array[index][0].chomp, reinforcements_array[index][1].to_i)  
	end

File.foreach("data3.txt") do |line|
	connector_array.push(line.split("\t"))
	end

connector_array.length.times do |index|
		DB.execute(insert_query_ConnectorData, connector_array[index][0], connector_array[index][1])  
	end
