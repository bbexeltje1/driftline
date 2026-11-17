--!strict
-- Original M1 equipment catalogue. Boards are sidegrades (turn vs speed);
-- the decal is cosmetic only. No paid statistical advantage.
local BoardCatalog = {}

BoardCatalog.Boards = {
	Trailboard = {
		id = "Trailboard",
		name = "Trailboard",
		cost = 0,
		turnRate = 2.4,
		maxSpeed = 62,
		grip = 0.75,
		accel = 10,
		color = { 232, 236, 240 },
	},
	Arcboard = {
		id = "Arcboard",
		name = "Arcboard",
		cost = 150,
		turnRate = 2.9, -- sharper carve
		maxSpeed = 56, -- small top-speed tradeoff
		grip = 0.85,
		accel = 10,
		color = { 255, 122, 89 },
	},
}

BoardCatalog.Cosmetics = {
	DuskStripe = {
		id = "DuskStripe",
		name = "Dusk Stripe",
		cost = 100,
		color = { 94, 200, 255 },
	},
}

function BoardCatalog.getBoard(id: string?): { [string]: any }?
	if type(id) ~= "string" then
		return nil
	end
	return BoardCatalog.Boards[id]
end

function BoardCatalog.getItem(id: string?): { [string]: any }?
	if type(id) ~= "string" then
		return nil
	end
	return BoardCatalog.Boards[id] or BoardCatalog.Cosmetics[id]
end

function BoardCatalog.isBoard(id: string?): boolean
	return BoardCatalog.getBoard(id) ~= nil
end

function BoardCatalog.isCosmetic(id: string?): boolean
	return type(id) == "string" and BoardCatalog.Cosmetics[id] ~= nil
end

function BoardCatalog.costOf(id: string?): number?
	local item = BoardCatalog.getItem(id)
	if not item then
		return nil
	end
	return item.cost
end

return BoardCatalog
