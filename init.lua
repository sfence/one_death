
one_death = {};


one_death.modpath = minetest.get_modpath(minetest.get_current_modname());
one_death.translator = minetest.get_translator("one_death")
local S = one_death.translator

if minetest.is_singleplayer() then
	one_death.delete_world = minetest.settings:get_bool("one_death_delete_singleplayer_world", true)
else
	one_death.delete_world = minetest.settings:get_bool("one_death_delete_multiplayer_world", false)
end
one_death.fly_after_death = minetest.settings:get_bool("one_death_fly_after_death", true) and not one_death.delete_world
one_death.fast_after_death = minetest.settings:get_bool("one_death_fast_after_death", true) and not one_death.delete_world
one_death.teleport_after_death = minetest.settings:get_bool("one_death_teleport_after_death", true) and not one_death.delete_world

local storage = minetest.get_mod_storage()

if one_death.delete_world then
	minetest.register_on_joinplayer(function(player)
			local name = player:get_player_name()
			local colored_message = minetest.colorize("red", S("!!!This WORLD will be REMOVED if you DIE!!!"))
    	minetest.chat_send_all(colored_message)
	 end)
end

local function erase_file(filename)
	local modpath = one_death.modpath
	local worldpath = minetest.get_worldpath()
	local readFile = io.open (modpath.."/data"..filename, "r")
	local writeFile = io.open (worldpath..filename, "w+")
	local content = readFile:read("*all")
	writeFile:write(content)
	readFile:close()
	writeFile:close()
end

local function new_seed_gen()
	local new_seed = ""
	local add_zeros = false
	local num = math.random(0, 1)
	if num > 0 then
		new_seed = "1"
		add_zeros = true
	end
	for i = 1, 18 do
		num = math.random(0, 9)
		if add_zeros or (num > 0) then
			new_seed = new_seed .. tostring(num)
		end
	end
	if new_seed == "" then
		new_seed = "0"
	end
	return new_seed
end

local function new_seed_map()
	local worldpath = minetest.get_worldpath()
	local lines = {}
	local filename = worldpath.."/map_meta.txt"
	local file = io.open(filename, "r")

	for line in file:lines() do
		if line:match("^seed = %d+$") then
			table.insert(lines, "seed = " .. new_seed_gen())
		else
			table.insert(lines, line)
		end
	end
	file:close()

	file = io.open(filename, "w+")

	for _, line in ipairs(lines) do
		file:write(line, "\n")
	end
	file:close()
end

local function remove_world_files()
	local path = minetest.get_worldpath()
	erase_file("/players.sqlite")
	erase_file("/map.sqlite")
	minetest.delete_area({-32000, -33000, -32000}, {32000, 32000, 32000})
	erase_file("/mod_storage.sqlite")
	new_seed_map()
	os.remove(path.."/force_loaded.txt")
end

minetest.register_on_joinplayer(function(player)
		local name = player:get_player_name()
		if storage:get_int(name) > 0 then
			minetest.change_player_privs(name, {interact = false, shout = false})
			if minetest.check_player_privs(name, {interact = true}) then
				minetest.kick_player(name, S("You are admin and you died. Interact priv cannot be revoked from you."))
			end
		end
	end)


minetest.register_on_dieplayer(function(player)
		local name = player:get_player_name()
		if one_death.delete_world then
			remove_world_files()
			minetest.register_on_shutdown(remove_world_files)
			minetest.request_shutdown(S("Player @1 died.", name), false, 0)
		else
			minetest.change_player_privs(name, {interact = false, shout = false})
			minetest.change_player_privs(name, {peaceful_player = true, })
			if one_death.fly_after_death then
				minetest.change_player_privs(name, {fly = true})
			end
			if one_death.fast_after_death then
				minetest.change_player_privs(name, {fast = true})
			end
			if one_death.teleport_after_death then
				minetest.change_player_privs(name, {teleport = true})
			end
			storage:set_int(name, 1)
			if minetest.check_player_privs(name, {interact = true}) then
				minetest.kick_player(name, S("You are admin and you died. Interact priv cannot be revoked from you."))
			end
		end
	end)

minetest.register_on_priv_grant(function(name, granter, priv)
		print(name..dump(priv))
		if priv == "interact" then
			if (storage:get_int(name) > 0) and minetest.check_player_privs(name, {interact = true}) then
				minetest.change_player_privs(name, {interact = false})
			end
		end
	end)
