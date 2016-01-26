-- basic vote by rnd

local basic_vote = {};
basic_vote.timeout = 30;
basic_vote.votes = 0; -- vote count
basic_vote.score = 0; -- vote score, if >0 vote succeeds
basic_vote.voters = {}; -- who voted already
basic_vote.state = 0; -- 0 no vote, 1 vote in progress,2 timeout
basic_vote.vote = {time = 0,type = 0, name = "", reason = ""}; -- description of current vote


-- DEFINE VOTE TYPES
basic_vote.types = {[0]="kick", [1]="remove interact of", [2] = "give interact to"};
basic_vote.vote_desc=""; for i,v in pairs(basic_vote.types) do basic_vote.vote_desc = basic_vote.vote_desc .. " type ".. i .. ": ".. v..", " end

-- DEFINE WHAT HAPPENS WHEN VOTE SUCCEEDS
basic_vote.execute = function(type, name, reason) 

	if type==0 then
			minetest.kick_player(name, reason)
		elseif type ==1 then
			local privs = core.get_player_privs(name)
			privs['interact'] = false
			core.set_player_privs(name, privs)
		elseif type ==2 then
			local privs = core.get_player_privs(name)
			privs['interact'] = true
			core.set_player_privs(name, privs)
		end
end



minetest.register_chatcommand("vote", { 
	privs = {
		interact = true
	},
	func = function(name, param)
		
		if basic_vote.state~=0 then minetest.chat_send_player(name,"vote already in progress") return end
		local player = minetest.get_player_by_name(name);
		
		-- split string param into parameters
		local paramt = string.split(param, " ") 
		for i = #paramt+1,3 do paramt[i]="" end
		
		
		if not basic_vote.types[ tonumber(paramt[1]) ] then minetest.chat_send_player(name,"USAGE: vote type name reason, "..basic_vote.vote_desc) return end
		
		basic_vote.vote.time = minetest.get_gametime();
		basic_vote.vote.type = tonumber(paramt[1]);
		basic_vote.vote.name=paramt[2] or "";
		basic_vote.vote.reason = paramt[3]
		
		basic_vote.votes = 0;basic_vote.score = 0;basic_vote.voters = {};
		minetest.chat_send_all("## VOTE (by ".. name ..") to ".. (basic_vote.types[basic_vote.vote.type] or "") .. " " .. (basic_vote.vote.name or "") .. " because " .. (basic_vote.vote.reason or "").. " ##\nsay /y or /n to vote. Timeout in ".. basic_vote.timeout  .. "s.");
		basic_vote.state = 1; minetest.after(basic_vote.timeout, function() 
			if basic_vote.state == 1 then basic_vote.state = 2;basic_vote.update(); end
		end)
	end
	}
)




basic_vote.update = function()
	local players=minetest.get_connected_players();
	local count = #players;

	if basic_vote.state == 2 then -- timeout
		minetest.chat_send_all("##VOTE failed. "..math.ceil(100*basic_vote.votes/count) .."% voted with score "..basic_vote.score .. " (needed 0)");
		basic_vote.state = 0;basic_vote.vote = {time = 0,type = 0, name = "", reason = ""}; return 
	end
	if basic_vote.state~=1 then return end -- no vote in progress
	
	if basic_vote.votes>0.5*count and basic_vote.score>0 then  -- enough voters and score, vote succeeds
		minetest.chat_send_all("##VOTE succeded. "..math.ceil(100*basic_vote.votes/count) .."% voted with score "..basic_vote.score .. " (needed 0)");
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
		if basic_vote.voters[name] then return else basic_vote.voters[name]=true end
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
		if basic_vote.voters[name] then return else basic_vote.voters[name]=true end
		basic_vote.votes = basic_vote.votes+1;basic_vote.score = basic_vote.score-1
		local privs = core.get_player_privs(name);if privs.kick then basic_vote.votes = 100; basic_vote.score = 100; end
		basic_vote.update();minetest.chat_send_player(name,"vote received");
	end
	}
)
