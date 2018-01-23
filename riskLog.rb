class Game

        def boardLog
                countries_hash.each do |key, value|
                        insert_query_status = "INSERT INTO riskStatus(Country, Turn, Reinforcements, Owner) VALUES (?, ?, ?, ?)"
                        DB.execute(insert_query_status, turn, value.name, value.troops, value.owner.name)
                end
        end

        def largestArmy
                armies = DB.execute("SELECT Owner, SUM(Reinforcements) FROM riskStatus GROUP BY Owner;")
        end

        def mostCountries
                countries = DB.execute("SELECT Owner,COUNT(Country) FROM riskStatus GROUP BY Owner WHERE Turn = {turn};")
        end
end
