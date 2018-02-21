-- environment
PLAYERS_PROPORTION = 3
INITIAL_MONEY      = 200
--TURNS              = 3500

-- players
--STRATEGIES = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0}
STRATEGIES = {"Nash", "Random", "Defect"} --0.1, 0.5, 1.0}

-- threshold for changing cell
THRESHOLD = -20

-- how much each player gains after each game?
GAIN = 0.0

SHOOT     = 1
NOT_SHOOT = 0

count__           = 0
qtty_strategies__ = #STRATEGIES

changed = false

function Game(p1, p2)
	if p1 == SHOOT     and p2 == SHOOT     then return {-10,-10} end
	if p1 == SHOOT     and p2 == NOT_SHOOT then return {  1, -1} end
	if p1 == NOT_SHOOT and p2 == SHOOT     then return { -1,  1} end
	if p1 == NOT_SHOOT and p2 == NOT_SHOOT then return {  0,  0} end
end

-- these functions work with a vector of numbers, indicating positions of a vector of players

function RemoveOneIfOdd(players)	
	if (#players % 2) == 1 then
		table.remove(players, math.random(1, #players))
	end

	return players
end

strategiesProb = {
	Nash = 0.1,
	Random = 0.5,
	Defect = 1.0
}

function GamesTable(cell)
	local vplayers   = {}
	local vconfronts = {}

	local players = cell:getAgents()
	local tp = #players

	for i = 1, tp, 1 do
		vplayers[i] = i
	end	

	local p = tp
	for i = 1, tp, 1 do
		local pos = math.random(1, p)
		vconfronts[i] = vplayers[pos]
		table.remove(vplayers, pos)
		p = p - 1
	end
	
	return RemoveOneIfOdd(vconfronts)	
end

-- return the strategy for a player. it cycles all STRATEGIES.
function InitialStrategy()
	count__ = (count__ + 1) % qtty_strategies__
	return STRATEGIES[count__ + 1]
end

agent = Agent{
	money    = INITIAL_MONEY,
	balance  = 0,
	strategy = Choice{"Nash", "Random", "Defect"},
	init = function(self)
		self.strategy = InitialStrategy()
	end,
	play = function(player)
		if math.random() <= strategiesProb[player.strategy] then
			return SHOOT
		else
			return NOT_SHOOT
		end
	end,
	changeMoney = function(player, value)
		player.money   = player.money   + value
		player.balance = player.balance + value
	end,
	execute = function(player)
		if player.money <= 0 then
			player:die()
		elseif player.balance < THRESHOLD then
			player.balance = 0
			player:walk()
		end
	end
}

cell = Cell{
	runTurn = function(cell)
		local np = #cell:getAgents()

		if np < 2 then return true end

		forEachAgent(cell, function(agent)
			if strategiesProb[agent.strategy] > 0.01 then
				changed = true
			end
		end)

		local tab     = GamesTable(cell)
		local players = cell:getAgents()

		for i = 1, #tab - 1, 2 do
			local player  = players[tab[i]  ]
			local oponent = players[tab[i+1]]

			local confront = Game(player:play(), oponent:play())

			player:changeMoney(confront[1] + GAIN)
			oponent:changeMoney(confront[2] + GAIN)
		end	
	end,
	-- if the cell does not have any agent, it will return nil
	owner = function(cell)
		local players = cell:getAgents()
		local owner = players[1]

		forEachAgent(cell, function(player)
			if player.money > owner.money then
				owner = player
			end
		end)

		return owner
	end,
	ownerStrategy = function(cell)
		local owner = cell:owner()
		if owner then
			return cell:owner().strategy
		else
			return 0
		end
	end,
	lonelyOwnerStrategy = function(cell)
		local players = cell:getAgents()
		local owner = players[1]

		if #players == 1 then
			return owner.strategy
		elseif #players == 0 then
			return 0
		else
			forEachAgent(cell, function(player)
				if player.strategy ~= owner.strategy then
					owner = player
				end
			end)

			if owner == players[1] then
				return owner.strategy
			else
				return 0
			end
		end
	end,
	strategy = function(cell)
		local owner = cell:owner()
		if not owner then return "empty" end
		return owner.strategy
	end,
	quantity = function(cell)
		local quant = #cell:getAgents()
		if quant > 3 then quant = 3 end
		return quant
	end
}

cs = CellularSpace{
	xdim = 20,
	instance = cell
}

cs:createNeighborhood{}

soc = Society{
	instance = agent,
	quantity = PLAYERS_PROPORTION * #STRATEGIES * #cs
}

env = Environment{soc, cs}
env:createPlacement{strategy = "uniform"}

map1 = Map{
	target = cs,
	grid = true,
	select = "strategy",
	value = {"empty", "Nash", "Random", "Defect"},
	color = {"white", "green", "blue", "red"}
}

map2 = Map{
	target = cs,
	grid = true,
	select = "quantity",
	value = {0, 1, 2, 3},
	color = {"white", "yellow", "purple", "black"},
	label = {"0", "1", "2", "3 or more"}
}

chart1 = Chart{
	target = soc,
	select = "strategy",
	title = "Players",
	value = {"Nash", "Random", "Defect"},
	color = {"green", "blue", "red"}
}

chart2 = Chart{
	target = cs,
	select = "ownerStrategy",
	value = {"Nash", "Random", "Defect"},
	title = "Owners",
	color = {"green", "blue", "red"}
}

chart2 = Chart{
	target = cs,
	select = "lonelyOwnerStrategy",
	value = {"Nash", "Random", "Defect"},
	title = "Lonely Owners",
	color = {"green", "blue", "red"}
}

timer = Timer{
	Event{action = chart1},
	Event{action = chart2},
	Event{action = map1},
	Event{action = map2},
	Event{action = function()
		changed = false
		cs:runTurn()
		soc:execute()
		return changed
	end}
}

timer:run(2500)

