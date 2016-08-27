-- basic vote by rnd

local basic_vote = {};

-- SETTINGS ----------------------------------------------------------------------

-- DEFINE VOTE TYPES
basic_vote.types = { -- [type] = { description , votes_needed , timeout}

[0] = {"kick" , -4 , 30},                -- -4 means at least 4 players need to vote
[1] = {"remove interact of" , 0.5, 120}, -- 0.5 means at least 50% need to vote
[2] = {"give interact to" , 0.5 , 120},
[3] = {"kill" , -4 , 30},
};

-- DEFINE WHAT HAPPENS WHEN VOTE SUCCEEDS
basic_vote.execute = function(type, name, reason) 

	if type == 0 then
	
		minetest.kick_player(name, reason)
			
	elseif type == 1 then
	
		local privs = core.get_player_privs(name);privs.interact = false
		core.set_player_privs(name, privs);	minetest.auth_reload()
		
	elseif type == 2 then
	
		local privs = core.get_player_privs(name);privs.interact = true;
		core.set_player_privs(name, privs);	minetest.auth_reload()
	
	elseif type == 3 then
	
		local player = minetest.get_player_by_name(name); if not player then return end
		player:set_hp(0);
		
	end

end

-- END OF SETTINGS ---------------------------------------------------------------

basic_vote.votes = 0; -- vote count
basic_vote.score = 0; -- vote score, if >0 vote succeeds
basic_vote.voters = {}; -- who voted already
basic_vote.state = 0; -- 0 no vote, 1 vote in progress,2 timeout
basic_vote.vote = {time = 0,type = 0, name = "", reason = "", votes_needed = 0, timeout = 0, description = ""}; -- description of current vote


basic_vote.requirements = {[0]=0}
basic_vote.vote_desc=""; for i,v in pairs(basic_vote.types) do basic_vote.vote_desc = basic_vote.vote_desc .. " type ".. i .. ": ".. v[1]..", " end


minetest.register_chatcommand("vote", { 
	privs = {
		interact = true
	},
	func = function(name, param)
		
		if basic_vote.state~=0 then 
			minetest.chat_send_player(name,"vote already in progress:") 
			minetest.chat_send_player(name,basic_vote.vote.description);
			return 
		end
		local player = minetest.get_player_by_name(name);
		
		-- split string param into parameters
		local paramt = string.split(param, " ") 
		for i = #paramt+1,3 do paramt[i]="" end
		
		
		if not basic_vote.types[ tonumber(paramt[1]) ] then minetest.chat_send_player(name,"USAGE: vote type name reason, "..basic_vote.vote_desc) return end
		
		basic_vote.vote.time = minetest.get_gametime();
		basic_vote.vote.type = tonumber(paramt[1]);
		basic_vote.vote.name=paramt[2] or "";
		basic_vote.vote.reason = paramt[3]
		basic_vote.vote.votes_needed =  basic_vote.types[ basic_vote.vote.type ][2];
		basic_vote.vote.timeout = basic_vote.types[ basic_vote.vote.type ][3];
		
		
		--check if target valid player
		if not minetest.get_player_by_name(basic_vote.vote.name) then return end
		if anticheatNAME and basic_vote.vote.type~=2 then -- #anticheat mod: makes detected cheater more succeptible to voting
			if basic_vote.vote.name==anticheatNAME then -- lookie who we got here, mr. cheater ;)
				basic_vote.vote.votes_needed=0;
				name = "#anticheat"; -- so cheater does not see who voted
			end
		end
		
		basic_vote.votes = 0;basic_vote.score = 0;basic_vote.voters = {};
		
		basic_vote.vote.description = "## VOTE (by ".. name ..") to ".. (basic_vote.types[basic_vote.vote.type][1] or "") .. " " .. (basic_vote.vote.name or "") .. " because " .. (basic_vote.vote.reason or "").. " ##\nsay /y or /n to vote. Timeout in ".. basic_vote.vote.timeout  .. "s.";
		
		minetest.chat_send_all(basic_vote.vote.description);
		basic_vote.state = 1; minetest.after(basic_vote.vote.timeout, function() 
			if basic_vote.state == 1 then basic_vote.state = 2;basic_vote.update(); end
		end)
	end
	}
)


basic_vote.update = function()
	local players=minetest.get_connected_players();
	local count = #players;

	local votes_needed;
	if basic_vote.vote.votes_needed>0 then
		votes_needed = basic_vote.vote.votes_needed*count; -- percent of all players
		if basic_vote.vote.votes_needed>=0.5 then -- more serious vote, to prevent ppl voting serious stuff with few players on server, at least 6 votes needed
			if votes_needed<6 then votes_needed = 6 end
		end
		
	else
		votes_needed = -basic_vote.vote.votes_needed; -- number instead
	end
	
	if basic_vote.state == 2 then -- timeout
		minetest.chat_send_all("##VOTE failed. ".. basic_vote.votes .." voted (needed ".. votes_needed ..") with score "..basic_vote.score .. " (needed 0)");
		basic_vote.state = 0;basic_vote.vote = {time = 0,type = 0, name = "", reason = ""}; return 
	end
	if basic_vote.state~=1 then return end -- no vote in progress
	
	if basic_vote.votes>votes_needed and basic_vote.score>0 then  -- enough voters and score, vote succeeds
		minetest.chat_send_all("##VOTE succeded. "..basic_vote.votes .." voted with score "..basic_vote.score .. " (needed 0)");
		minetest.chat_send_all("##VOTE succeded. "..basic_vote.votes .." dvoted with score "..basic_vote.score .. " (needed 0)");
		minetest.chat_send_all("##VOTE succeded. "..basic_vote.votes .." dvoted with score "..basic_vote.score .. " (needed 0)");
		local type = basic_vote.vote.type;
                basic_vote.execute(basic_vote.vote.type,basic_vote.vote.name, basic_vote.vote.reason)
		basic_vote.state = 0;basic_vote.vote = {time = 0,type = 0, name = "", reason = ""};
		
	end
end

minetest.register_chatcommand("y", { 
	privs = {
		interact = true
	},
	func = function(name, param)
		if basic_vote.state~=1 then return end
		local ip = minetest.get_player_ip(name) or 0;
		if basic_vote.voters[ip] then return else basic_vote.voters[ip]=true end -- mark as already voted
		basic_vote.votes = basic_vote.votes+1;basic_vote.score = basic_vote.score+1;
		local privs = core.get_player_privs(name);if privs.kick then basic_vote.votes = 100; basic_vote.score = 100; end
		basic_vote.update(); minetest.chat_send_player(name,"vote received");
	end
	}
)

minetest.register_chatcommand("n", { 
	privs = {
		interact = true
	},
	func = function(name, param)
		if basic_vote.state~=1 then return end
		local ip = minetest.get_player_ip(name) or 0;
		if basic_vote.voters[ip] then return else basic_vote.voters[ip]=true end -- mark as already voted
		basic_vote.votes = basic_vote.votes+1;basic_vote.score = basic_vote.score-1
		local privs = core.get_player_privs(name);if privs.kick then basic_vote.votes = -100; basic_vote.score = -100; end
		basic_vote.update();minetest.chat_send_player(name,"vote received");
	end
	}
)