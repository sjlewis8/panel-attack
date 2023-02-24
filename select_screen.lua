local select_screen = {}

select_screen.fallback_when_missing = { nil, nil }
select_screen.character_select_mode = "1p_vs_yourself"

local wait = coroutine.yield
local current_page = 1

-- fills the provided map based on the provided template and return the amount of pages. __Empty values will be replaced by character_ids

local function fill_map(template_map,map)
  local X,Y = 5,9
  local pages_amount = 0
  local character_id_index = 1
  while true do
    -- new page handling
    pages_amount = pages_amount+1
    map[pages_amount] = deepcpy(template_map)

    -- go through the page and replace __Empty with characters_ids_for_current_theme
    for i=1,X do
      for j=1,Y do
        if map[pages_amount][i][j] == "__Empty" then
          map[pages_amount][i][j] = characters_ids_for_current_theme[character_id_index]
          character_id_index = character_id_index+1
          -- end case: no more characters_ids_for_current_theme to add
          if character_id_index == #characters_ids_for_current_theme+1 then
            print("filled "..#characters_ids_for_current_theme.." characters across "..pages_amount.." page(s)")
            return pages_amount
          end
        end
      end
    end
  end
end

local function patch_is_random(refreshed) -- retrocompatibility
  if refreshed ~= nil then
    if refreshed.stage_is_random == true then
      refreshed.stage_is_random = random_stage_special_value
    elseif refreshed.stage_is_random == false then
      refreshed.stage_is_random = nil
    elseif refreshed.stage_is_random ~= nil and refreshed.stage_is_random ~= random_stage_special_value and stages[refreshed.stage_is_random] == nil then
      refreshed.stage_is_random = random_stage_special_value
    end
    if refreshed.character_is_random == true then
      refreshed.character_is_random = random_character_special_value
    elseif refreshed.character_is_random == false then
      refreshed.character_is_random = nil
    elseif refreshed.character_is_random ~= nil and refreshed.character_is_random ~= random_character_special_value and characters[refreshed.character_is_random] == nil then
      refreshed.character_is_random = random_character_special_value
    end
  end
end

function refresh_based_on_own_mods(refreshed,ask_change_fallback)
  patch_is_random(refreshed)
  ask_change_fallback = ask_change_fallback or false
  if refreshed ~= nil then
    -- panels
    if refreshed.panels_dir == nil or panels[refreshed.panels_dir] == nil then
      refreshed.panels_dir = config.panels
    end

    -- stage
    if refreshed.stage == nil or ( refreshed.stage ~= random_stage_special_value and stages[refreshed.stage] == nil ) then
      if not select_screen.fallback_when_missing[1] or ask_change_fallback then
        select_screen.fallback_when_missing[1] = uniformly(stages_ids_for_current_theme)
        if stages[select_screen.fallback_when_missing[1]]:is_bundle() then -- may pick a bundle!
          select_screen.fallback_when_missing[1] = uniformly(stages[select_screen.fallback_when_missing[1]].sub_stages)
        end
      end
      refreshed.stage = select_screen.fallback_when_missing[1]
    end

    -- character
    if refreshed.character == nil or ( refreshed.character ~= random_character_special_value and characters[refreshed.character] == nil ) then
      if refreshed.character_display_name and characters_ids_by_display_names[refreshed.character_display_name]
        and not characters[characters_ids_by_display_names[refreshed.character_display_name][1]]:is_bundle() then
        refreshed.character = characters_ids_by_display_names[refreshed.character_display_name][1]
      else
        if not select_screen.fallback_when_missing[2] or ask_change_fallback then
          select_screen.fallback_when_missing[2] = uniformly(characters_ids_for_current_theme)
          if characters[select_screen.fallback_when_missing[2]]:is_bundle() then -- may pick a bundle
            select_screen.fallback_when_missing[2] = uniformly(characters[select_screen.fallback_when_missing[2]].sub_characters)
          end
        end
        refreshed.character = select_screen.fallback_when_missing[2]
      end
    end
  end
end

local function resolve_character_random(state)
  if state.character_is_random ~= nil then

    if state.character_is_random == random_character_special_value then
      state.character = uniformly(characters_ids_for_current_theme)
      if characters[state.character]:is_bundle() then -- may pick a bundle
        state.character = uniformly(characters[state.character].sub_characters)
      end
    else
      state.character = uniformly(characters[state.character_is_random].sub_characters)
    end
    return true
  end
  return false
end

local function resolve_stage_random(state)
  if state.stage_is_random ~= nil then
    if state.stage_is_random == random_stage_special_value then
      state.stage = uniformly(stages_ids_for_current_theme)
      if stages[state.stage]:is_bundle() then
        state.stage = uniformly(stages[state.stage].sub_stages)
      end
    else
      state.stage = uniformly(stages[state.stage_is_random].sub_stages)
    end
  end
end

function select_screen.main()
  if themes[config.theme].musics.select_screen then
    stop_the_music()
    find_and_add_music(themes[config.theme].musics, "select_screen")
  elseif themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end

  background = themes[config.theme].images.bg_select_screen
  reset_filters()

  select_screen.fallback_when_missing = { nil, nil }

  local function add_client_data(state)
    state.loaded = characters[state.character] and characters[state.character].fully_loaded and stages[state.stage] and stages[state.stage].fully_loaded
    state.wants_ready = state.ready
  end


  local function refresh_loaded_and_ready(state_t)
		local all_players_loaded = true
		
		for p = 1, global_max_players do
			if state_t[p] and state_t[p].state then 
				local state_p = state_t[p].state
				
				if (not state_p.loaded) then 
					all_players_loaded = false 
				end
				
				state_p.loaded = characters[state_p.character] and characters[state_p.character].fully_loaded and stages[state_p.stage] and stages[state_p.stage].fully_loaded
			end
		end

		if select_screen.character_select_mode == "2p_net_vs" then
			state_t[1].state.ready = state_t[1].state.wants_ready and state_t[1].state.loaded and state_t[2].state.loaded
			
		elseif select_screen.character_select_mode == "round_robin" or select_screen.character_select_mode == "rr_netplay" then
		
			for player = 1, global_rr.num_players do
				state_t[player].state.ready = state_t[player].state.wants_ready and state_t[player].state.loaded and all_players_loaded
			end
			
		else
			state_t[1].state.ready = state_t[1].state.wants_ready and state_t[1].state.loaded 
			
			if state_t[2].state then
				state_t[2].state.ready = state_t[2].state.wants_ready and state_t[2].state.loaded
			end
		end
  end

  -- map is composed of special values prefixed by __ and character ids
  local template_map = {{"__Panels", "__Panels", "__Stage", "__Stage", "__Stage", "__Level", "__Level", "__Level", "__Ready"},
             {"__Random", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Leave"}}
  local map = {}
  local inNetplay = select_screen.character_select_mode == "rr_netplay" or false 
  

  if select_screen.character_select_mode == "2p_net_vs" then
    local opponent_connected = false
    local retries, retry_limit = 0, 250
	
    while not global_initialize_room_msg and retries < retry_limit do
      local msg = server_queue:pop_next_with("create_room", "character_select", "spectate_request_granted")
      if msg then
        global_initialize_room_msg = msg
      end
      gprint(loc("ss_init"), unpack(main_menu_screen_pos))
      wait()
      if not do_messages() then
        return main_dumb_transition, {main_select_mode, loc("ss_disconnect").."\n\n"..loc("ss_return"), 60, 300}
      end
      retries = retries + 1
    end
	
    if not global_initialize_room_msg then
      return main_dumb_transition, {main_select_mode, loc("ss_init_fail").."\n\n"..loc("ss_return"), 60, 300}
    end
    msg = global_initialize_room_msg
    if msg.ratings then
        global_current_room_ratings = msg.ratings
    end

    if msg.your_player_number then
      my_player_number = msg.your_player_number
    elseif currently_spectating then
      my_player_number = 1
    elseif my_player_number and my_player_number ~= 0 then
      print("We assumed our player number is still "..my_player_number)
    else
      error(loc("nt_player_err"))
      print("Error: The server never told us our player number.  Assuming it is 1")
      my_player_number = 1
    end

    if msg.op_player_number then
      op_player_number = msg.op_player_number or op_player_number
    elseif currently_spectating then
      op_player_number = 2
    elseif op_player_number and op_player_number ~= 0 then
      print("We assumed op player number is still "..op_player_number)
    else
      error("We never heard from the server as to what player number we are")
      print("Error: The server never told us our player number.  Assuming it is 2")
      op_player_number = 2
    end

    if my_player_number == 2 and msg.a_menu_state ~= nil and msg.b_menu_state ~= nil then
      print("inverting the states to match player number!")
      msg.a_menu_state, msg.b_menu_state = msg.b_menu_state, msg.a_menu_state
    end

    global_my_state = msg.a_menu_state
    refresh_based_on_own_mods(global_my_state)
    global_op_state = msg.b_menu_state
    refresh_based_on_own_mods(global_op_state)

    if msg.win_counts then
      update_win_counts(msg.win_counts)
    end
	
    if msg.replay_of_match_so_far then
      replay_of_match_so_far = msg.replay_of_match_so_far
    end
	
    if msg.ranked then
      match_type = "Ranked"
      match_type_message = ""
    else
      match_type = "Casual"
    end
	
    if currently_spectating then
      P1 = {panel_buffer="", gpanel_buffer=""}
      print("we reset P1 buffers at start of main_character_select()")
    end
    P2 = {panel_buffer="", gpanel_buffer=""}
    print("we reset P2 buffers at start of main_character_select()")
    print("current_server_supports_ranking: "..tostring(current_server_supports_ranking))

    if current_server_supports_ranking then
      template_map = {{"__Panels", "__Panels", "__Mode", "__Mode", "__Stage", "__Stage", "__Level", "__Level", "__Ready"},
             {"__Random", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Leave"}}
    end
  end

  local pages_amount = fill_map(template_map, map)
  if current_page > pages_amount then
    current_page = 1
  end

  op_win_count = op_win_count or 0

  if select_screen.character_select_mode == "2p_net_vs" then
    global_current_room_ratings = global_current_room_ratings or {{new=0,old=0,difference=0},{new=0,old=0,difference=0}}
    my_expected_win_ratio = nil
    op_expected_win_ratio = nil
    print("my_player_number = "..my_player_number)
    print("op_player_number = "..op_player_number)
    if global_current_room_ratings[my_player_number].new
    and global_current_room_ratings[my_player_number].new ~= 0
    and global_current_room_ratings[op_player_number]
    and global_current_room_ratings[op_player_number].new ~= 0 then
      my_expected_win_ratio = (100*round(1/(1+10^
            ((global_current_room_ratings[op_player_number].new
                -global_current_room_ratings[my_player_number].new)
              /RATING_SPREAD_MODIFIER))
            ,2))
      op_expected_win_ratio = (100*round(1/(1+10^
            ((global_current_room_ratings[my_player_number].new
                -global_current_room_ratings[op_player_number].new)
              /RATING_SPREAD_MODIFIER))
            ,2))
    end
    match_type = match_type or "Casual"
    if match_type == "" then match_type = "Casual" end
  end

  match_type_message = match_type_message or ""

  local function do_leave()
    stop_the_music()
    my_win_count = 0
    op_win_count = 0
    return json_send({leave_room=true})
  end

  -- be wary: name_to_xy_per_page is kinda buggy for larger blocks as they span multiple positions (we retain the last one), and is completely broken with __Empty
  local name_to_xy_per_page = {}
  local X,Y = 5,9
  for p=1,pages_amount do
    name_to_xy_per_page[p] = {}
    for i=1,X do
      for j=1,Y do
        if map[p][i][j] then
          name_to_xy_per_page[p][map[p][i][j] ] = {i,j}
        end
      end
    end
  end

  my_win_count = my_win_count or 0

  --sets cursors to the "ready square" etc.
  local cursor_data = {{position=shallowcpy(name_to_xy_per_page[current_page]["__Ready"]),can_super_select=false,selected=false}, {position=shallowcpy(name_to_xy_per_page[current_page]["__Ready"]),can_super_select=false,selected=false}}
  
  if global_rr.num_players then 
    for player = 3, global_rr.num_players do
      cursor_data[player] = {position=shallowcpy(name_to_xy_per_page[current_page]["__Ready"]),can_super_select=false,selected=false}
    end
  end
  
  -- our data (first player in local)
  if global_my_state ~= nil then
    cursor_data[1].state = shallowcpy(global_my_state)
    global_my_state = nil
  else
    cursor_data[1].state = {stage=config.stage, 
														stage_is_random=( (config.stage==random_stage_special_value or stages[config.stage]:is_bundle()) and config.stage or nil ), 
														character=config.character, 
														character_is_random=( ( config.character==random_character_special_value or characters[config.character]:is_bundle()) and config.character or nil ), 
														level=config.level, panels_dir=config.panels, cursor="__Ready", ready=false, ranked=config.ranked}
  end

  -- setup for round-robin mode 
  if select_screen.character_select_mode == "round_robin" then
		rrIsSetup = false
		global_rr.matchup = "Winner" 
		global_rr.win_mode = "Best of Three"
	
		for player = 1, global_rr.num_players do
			global_rr.win_count[player] = 0	
				
			--this doesn't work yet, loads each player's previously played character
			if global_rr.states[player] ~= nil then 
				cursor_data[player].state = deepcpy(global_rr.states[player])
				global_rr.states[player] = nil
				
			else
				cursor_data[player].state = {stage = config.stage, 
																			stage_is_random=( (config.stage==random_stage_special_value or stages[config.stage]:is_bundle()) and config.stage or nil ), 
																			character=config.character, character_is_random=( ( config.character==random_character_special_value or characters[config.character]:is_bundle()) and config.character or nil ), 
																			level=config.level, 
																			panels_dir=config.panels, 
																			cursor="__Ready", 
																			ready=false, 
																			ranked=config.ranked}
			end
		end
  end

print(config.stage)
  if resolve_character_random(cursor_data[1].state) then
    character_loader_load(cursor_data[1].state.character)
  end

  cursor_data[1].state.character_display_name = characters[cursor_data[1].state.character].display_name

  resolve_stage_random(cursor_data[1].state)
  stage_loader_load(cursor_data[1].state.stage)
  add_client_data(cursor_data[1].state)

  for player = 2, global_rr.num_players do 
	  if select_screen.character_select_mode ~= "1p_vs_yourself"  or select_screen.character_select_mode ~= "rr_netplay" then
			if global_op_state ~= nil then
				cursor_data[player].state = shallowcpy(global_op_state)
				
				if (select_screen.character_select_mode ~= "2p_local_vs" or select_screen.character_select_mode ~= "round_robin") then
					global_op_state = nil -- retains state of the second player,
					
				else
					resolve_character_random(cursor_data[player].state)
					cursor_data[player].state.character_display_name = characters[cursor_data[player].state.character].display_name
					resolve_stage_random(cursor_data[player].state)
				end
				
			else
				cursor_data[player].state = {stage=config.stage, stage_is_random=( (config.stage==random_stage_special_value or stages[config.stage]:is_bundle()) and config.stage or nil ),
				 character=config.character, character_is_random=( ( config.character==random_character_special_value or characters[config.character]:is_bundle()) and config.character or nil ), level=config.level, panels_dir=config.panels, cursor="__Ready", ready=false, ranked=false}
				 
				resolve_character_random(cursor_data[player].state)
				cursor_data[player].state.character_display_name = characters[cursor_data[player].state.character].display_name
				resolve_stage_random(cursor_data[player].state)
			end
			
			if cursor_data[player].state.character ~= random_character_special_value and not characters[cursor_data[player].state.character]:is_bundle() then
				character_loader_load(cursor_data[player].state.character)
			end
			
			if cursor_data[player].state.stage ~= random_stage_special_value and not stages[cursor_data[player].state.stage]:is_bundle() then 
				stage_loader_load(cursor_data[player].state.stage)
			end
			
			add_client_data(cursor_data[player].state)
	  end
  end
  
  refresh_loaded_and_ready(cursor_data)

  local prev_state = shallowcpy(cursor_data[1].state)

  local super_select_pixelcode = [[
      uniform float percent;
      vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
      {
          vec4 c = Texel(tex, texture_coords) * color;
          if( texture_coords.x < percent )
          {
            return c;
          }
          float ret = (c.x+c.y+c.z)/3.0;
          return vec4(ret, ret, ret, c.a);
      }
  ]]
 
  -- one per player, should we put them into cursor_data even though it's meaningless?
  local super_select_shaders = { love.graphics.newShader(super_select_pixelcode), love.graphics.newShader(super_select_pixelcode) }

  local function draw_button(x,y,w,h,str,halign,valign,no_rect, getXY) 
    local menu_width = Y*100
    local menu_height = X*80
    local spacing = 8
    local text_height = 13
    local x_padding = math.floor((canvas_width-menu_width)/2)
    local y_padding = math.floor((canvas_height-menu_height)/2)
		
		no_rect = no_rect or str == "__Empty" or str == "__Reserved"
    halign = halign or "center"
    valign = valign or "top"
	
    set_color(unpack(colors.white))
	
		-- grays out inactive players in round robin 
		if(str:match('^[P]%d$')) then -- begins with P and ends with a digit
			if cursor_data[tonumber(string.sub(str,2,2))].active == false then
				set_color(unpack(colors.gray))
			end
		end
	
    render_x = x_padding+(y-1)*100+spacing
    render_y = y_padding+(x-1)*100+spacing
    button_width = w*100-2*spacing
    button_height = h*100-2*spacing
	
    if no_rect == false then
      grectangle("line", render_x, render_y, button_width, button_height)
    end
	

    local character = characters[str]
	
		if (select_screen.character_select_mode ~= "round_robin" and select_screen.character_select_mode ~= "rr_netplay") then  
			global_rr.num_players = 2 
		end
		
		for player = 1, global_rr.num_players do 
			if str == "P"..player then
				if cursor_data[player].state.character_is_random then
					if cursor_data[player].state.character_is_random == random_character_special_value then
						character = random_character_special_value
					else
						character = characters[cursor_data[player].state.character_is_random]
					end
					
				else
					character = characters[cursor_data[player].state.character]
					
				end
			end 
		end
	
    local width_for_alignment = button_width
    local x_add,y_add = 0,0
    if valign == "center" then
      y_add = math.floor(0.5*button_height-0.5*text_height)-3
    elseif valign == "bottom" then
      y_add = math.floor(button_height-text_height)
    end

    local function draw_character(character)
      -- draw character icon with its super selection or bundle character icon 
      if character == random_character_special_value or not character:is_bundle() or character.images.icon then
        local icon_to_use = character == random_character_special_value and themes[config.theme].images.IMG_random_character or character.images.icon
        local orig_w, orig_h = icon_to_use:getDimensions()
        local scale = button_width/math.max(orig_w,orig_h) -- keep image ratio
        menu_drawf(icon_to_use, render_x+0.5*button_width, render_y+0.5*button_height,"center","center", 0, scale, scale )
        if str ~= "P1" and str ~= "P2" then
          if character.stage then
            local orig_w, orig_h = stages[character.stage].images.thumbnail:getDimensions()
            menu_drawf(stages[character.stage].images.thumbnail, render_x+10, render_y+button_height-7,"center","center", 0, 16/orig_w, 9/orig_h )
          end
          if character.panels then
            local orig_w, orig_h = panels[character.panels].images.classic[1][1]:getDimensions()
            menu_drawf(panels[character.panels].images.classic[1][1], render_x+7, character.stage and render_y+button_height-19 or render_y+button_height-6,"center","center", 0, 12/orig_w, 12/orig_h )
          end
        end
      elseif character and character:is_bundle() then -- draw bundle character generated thumbnails
        local sub_characters = character.sub_characters
        local sub_characters_count = math.min(4, #sub_characters) -- between 2 and 4 (inclusive), by design

        local thumbnail_1 = characters[sub_characters[1]].images.icon
        local thumb_y_padding = 0.25*button_height
        local thumb_1_and_2_y_padding = sub_characters_count >= 3 and -thumb_y_padding or 0
        local scale_1 = button_width*0.5/math.max(thumbnail_1:getWidth(), thumbnail_1:getHeight())
        menu_drawf(thumbnail_1, render_x+0.25*button_width, render_y+0.5*button_height+thumb_1_and_2_y_padding, "center", "center", 0, scale_1, scale_1 )
        
        local thumbnail_2 = characters[sub_characters[2]].images.icon
        local scale_2 = button_width*0.5/math.max(thumbnail_2:getWidth(), thumbnail_2:getHeight())
        menu_drawf(thumbnail_2, render_x+0.75*button_width, render_y+0.5*button_height+thumb_1_and_2_y_padding, "center", "center", 0, scale_2, scale_2 )

        if sub_characters_count >= 3 then
          local thumbnail_3 = characters[sub_characters[3]].images.icon
          local scale_3 = button_width*0.5/math.max(thumbnail_3:getWidth(), thumbnail_3:getHeight())
          local thumb_3_x_padding = sub_characters_count == 3 and 0.25*button_width or 0
          menu_drawf(thumbnail_3, render_x+0.25*button_width+thumb_3_x_padding, render_y+0.75*button_height, "center", "center", 0, scale_3, scale_3 )
        end
        if sub_characters_count == 4 then
          local thumbnail_4 = characters[sub_characters[4]].images.icon
          local scale_4 = button_width*0.5/math.max(thumbnail_4:getWidth(), thumbnail_4:getHeight())
          menu_drawf(thumbnail_4, render_x+0.75*button_width, render_y+0.75*button_height, "center", "center", 0, scale_4, scale_4 )
        end
      end

      -- draw flag in the bottom-right corner
      if character and character ~= random_character_special_value and character.flag then
        local flag_icon = themes[config.theme].images.flags[character.flag]
        if flag_icon then
          local orig_w, orig_h = flag_icon:getDimensions()
          local scale = 0.2*button_width/orig_w -- keep image ratio
          menu_drawf(flag_icon, render_x+button_width-1, render_y+button_height-1,"right","bottom", 0, scale, scale )
        end
      end
    end

    local function draw_super_select(player_num)
      local ratio = menu_pressing_enter(K[player_num])
      if ratio > super_selection_enable_ratio then
        super_select_shaders[player_num]:send("percent", linear_smooth(ratio,super_selection_enable_ratio,1.0))
        set_shader(super_select_shaders[player_num])
        menu_drawf(themes[config.theme].images.IMG_super, render_x+button_width*0.5, render_y+button_height*0.5, "center", "center" )
        set_shader()
      end
    end

    local function draw_cursor(button_height, spacing, player_num, ready)
      local cur_blink_frequency = 4
      local cur_pos_change_frequency = 8
      local draw_cur_this_frame = false
      local cursor_frame = 1
			local ready_freq = 2
	  
			if select_screen.character_select_mode == "round_robin" and not inLobby then
				ready_freq = global_rr.num_players 
			end
				
			if ready then
				if (math.floor(menu_clock/cur_blink_frequency))%ready_freq+1 == player_num%2+1 then
          draw_cur_this_frame = true
        end
				
      else
        draw_cur_this_frame = true
        cursor_frame = (math.floor(menu_clock/cur_pos_change_frequency)+player_num)%2+1
				
      end
	  
      if draw_cur_this_frame then
        local cur_img = themes[config.theme].images.IMG_char_sel_cursors[player_num][cursor_frame]
        local cur_img_left = themes[config.theme].images.IMG_char_sel_cursor_halves.left[player_num][cursor_frame]
        local cur_img_right = themes[config.theme].images.IMG_char_sel_cursor_halves.right[player_num][cursor_frame]
        local cur_img_w, cur_img_h = cur_img:getDimensions()
        local cursor_scale = (button_height+(spacing*2))/cur_img_h
        menu_drawq(cur_img, cur_img_left, render_x-spacing, render_y-spacing, 0, cursor_scale , cursor_scale)
        menu_drawq(cur_img, cur_img_right, render_x+button_width+spacing-cur_img_w*cursor_scale/2, render_y-spacing, 0, cursor_scale, cursor_scale)
      end
    end

    local function draw_player_state(cursor_data,player_number)

      if characters[cursor_data.state.character] and not characters[cursor_data.state.character].fully_loaded then
        menu_drawf(themes[config.theme].images.IMG_loading, render_x+button_width*0.5, render_y+button_height*0.5, "center", "center" )
      elseif cursor_data.state.wants_ready then
        menu_drawf(themes[config.theme].images.IMG_ready, render_x+button_width*0.5, render_y+button_height*0.5, "center", "center" )
      end
	  
      local scale = 0.25*button_width/math.max(themes[config.theme].images.IMG_players[player_number]:getWidth(),themes[config.theme].images.IMG_players[player_number]:getHeight()) -- keep image ratio
      menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x+1, render_y+button_height-1, "left", "bottom", 0, scale, scale )
 
			scale = 0.25 * button_width / math.max(themes[config.theme].images.IMG_levels[cursor_data.state.level]:getWidth(),themes[config.theme].images.IMG_levels[cursor_data.state.level]:getHeight()) -- keep image ratio
			
      menu_drawf(themes[config.theme].images.IMG_levels[cursor_data.state.level], render_x+button_width-1, render_y+button_height-1, "right", "bottom", 0, scale, scale )
    end

    local function draw_panels(cursor_data,player_number,y_padding)
      local panels_max_width = 0.25*button_height
      local panels_width = math.min(panels_max_width,panels[cursor_data.state.panels_dir].images.classic[1][1]:getWidth())
      local padding_x = 0.5*button_width-3*panels_width -- center them, not 3.5 mysteriously?
      if cursor_data.state.level >= 9 then
        padding_x = padding_x-0.5*panels_width
      end
      local is_selected = cursor_data.selected and cursor_data.state.cursor == "__Panels"
      if is_selected then
        padding_x = padding_x-panels_width
      end
      local panels_scale = panels_width/panels[cursor_data.state.panels_dir].images.classic[1][1]:getWidth()
      menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x+padding_x, render_y+y_padding, "center", "center" )
      padding_x = padding_x + panels_width
      if is_selected then
        gprintf("<", render_x+padding_x-0.5*panels_width, render_y+y_padding-0.5*text_height,panels_width,"center")
        padding_x = padding_x + panels_width
      end
      for i=1,8 do
        if i ~= 7 and (i ~= 6 or cursor_data.state.level >= 9) then
          menu_drawf(panels[cursor_data.state.panels_dir].images.classic[i][1], render_x+padding_x, render_y+y_padding, "center", "center", 0, panels_scale, panels_scale )
          padding_x = padding_x + panels_width
        end
      end
      if is_selected then
        gprintf(">", render_x+padding_x-0.5*panels_width, render_y+y_padding-0.5*text_height,panels_width,"center")
      end
    end

    local function draw_levels(cursor_data,player_number,y_padding)
      local level_max_width = 0.2*button_height
      local level_width = math.min(level_max_width,themes[config.theme].images.IMG_levels[1]:getWidth())
      local padding_x = math.floor(0.5*button_width-5.5*level_width)
      local is_selected = cursor_data.selected and cursor_data.state.cursor == "__Level"
      if is_selected then
        padding_x = padding_x-level_width
      end
      local level_scale = level_width/themes[config.theme].images.IMG_levels[1]:getWidth()
      menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x+padding_x, render_y+y_padding, "center", "center" )
      local ex_scaling = level_width/themes[config.theme].images.IMG_levels[11]:getWidth()
      menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x+padding_x, render_y+y_padding, "center", "center" )
      padding_x = padding_x + level_width
      if is_selected then
        gprintf("<", render_x+padding_x-0.5*level_width, render_y+y_padding-0.5*text_height,level_width,"center")
        padding_x = padding_x + level_width
      end
      for i=1,#level_to_starting_speed do --which should equal the number of levels in the game
        local additional_padding = math.floor(0.5*(themes[config.theme].images.IMG_levels[i]:getWidth()-level_width))
        padding_x = padding_x + additional_padding
        local use_unfocus = cursor_data.state.level < i
        if use_unfocus then
          menu_drawf(themes[config.theme].images.IMG_levels_unfocus[i], render_x+padding_x, render_y+y_padding, "center", "center", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale) )
        else
          menu_drawf(themes[config.theme].images.IMG_levels[i], render_x+padding_x, render_y+y_padding, "center", "center", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale) )
        end
        if i == cursor_data.state.level then
          menu_drawf(themes[config.theme].images.IMG_level_cursor, render_x+padding_x, render_y+y_padding+themes[config.theme].images.IMG_levels[i]:getHeight()*0.5, "center", "top", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale) )
        end
        padding_x = padding_x + level_width + additional_padding
      end
      if is_selected then
        gprintf(">", render_x+padding_x-0.5*level_width, render_y+y_padding-0.5*text_height,level_width,"center")
      end
    end

    local function draw_match_type(cursor_data,player_number,y_padding)
      local padding_x = math.floor(0.5*button_width - themes[config.theme].images.IMG_players[player_number]:getWidth()*0.5 - 46)  -- ty GIMP; no way to know the size of the text?
      menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x+padding_x, render_y+y_padding, "center", "center" )
      padding_x = padding_x+themes[config.theme].images.IMG_players[player_number]:getWidth()
      local to_print
      if cursor_data.state.ranked then
        to_print = loc("ss_casual").." ["..loc("ss_ranked").."]"
      else
        to_print = "["..loc("ss_casual").."] "..loc("ss_ranked")
      end
      gprint(to_print, render_x+padding_x, render_y+y_padding-0.5*text_height-1)
    end

    local function draw_stage(cursor_data,player_number,x_padding)
      local stage_dimensions = { 80, 45 }
      local y_padding = math.floor(0.5*button_height)
      local padding_x = math.floor(x_padding-0.5*stage_dimensions[1])
      local is_selected = cursor_data.selected and cursor_data.state.cursor == "__Stage"
      if is_selected then
        local arrow_pos = select_screen.character_select_mode == "2p_net_vs"
          and { math.floor(render_x+x_padding-20), math.floor(render_y+y_padding-stage_dimensions[2]*0.5-15) }
          or { math.floor(render_x+padding_x-13), math.floor(render_y+y_padding+0.25*text_height) }
        gprintf("<", arrow_pos[1], arrow_pos[2],10,"center")
      end
      -- background for thumbnail
      grectangle("line", render_x+padding_x, math.floor(render_y+y_padding-stage_dimensions[2]*0.5), stage_dimensions[1], stage_dimensions[2])
      -- thumbnail or composed thumbnail (for bundles without thumbnails)
      if cursor_data.state.stage_is_random == random_stage_special_value 
        or ( cursor_data.state.stage_is_random and not stages[cursor_data.state.stage_is_random] ) 
        or ( cursor_data.state.stage_is_random and stages[cursor_data.state.stage_is_random] and stages[cursor_data.state.stage_is_random].images.thumbnail ) 
        or ( not cursor_data.state.stage_is_random and stages[cursor_data.state.stage].images.thumbnail ) then
				local thumbnail = themes[config.theme].images.IMG_random_stage
        if cursor_data.state.stage_is_random and stages[cursor_data.state.stage_is_random] and stages[cursor_data.state.stage_is_random].images.thumbnail then
          thumbnail = stages[cursor_data.state.stage_is_random].images.thumbnail
        elseif not cursor_data.state.stage_is_random and stages[cursor_data.state.stage].images.thumbnail then
          thumbnail = stages[cursor_data.state.stage].images.thumbnail
        end
        menu_drawf(thumbnail, render_x+padding_x, render_y+y_padding-1, "left", "center", 0, stage_dimensions[1]/thumbnail:getWidth(), stage_dimensions[2]/thumbnail:getHeight() )
      elseif cursor_data.state.stage_is_random and stages[cursor_data.state.stage_is_random]:is_bundle() then
        local half_stage_dimensions = { math.floor(stage_dimensions[1]*0.5), math.floor(stage_dimensions[2]*0.5) }
        local sub_stages = stages[cursor_data.state.stage_is_random].sub_stages
        local sub_stages_count = math.min(4, #sub_stages) -- between 2 and 4 (inclusive), by design

        local thumbnail_1 = stages[sub_stages[1]].images.thumbnail
        local thumb_y_padding = math.floor(half_stage_dimensions[2]*0.5)
        local thumb_1_and_2_y_padding = sub_stages_count >= 3 and -thumb_y_padding or 0
        menu_drawf(thumbnail_1, render_x+padding_x, render_y+y_padding-1+thumb_1_and_2_y_padding, "left", "center", 0, half_stage_dimensions[1]/thumbnail_1:getWidth(), half_stage_dimensions[2]/thumbnail_1:getHeight() )
        
        local thumbnail_2 = stages[sub_stages[2]].images.thumbnail
        menu_drawf(thumbnail_2, render_x+padding_x+half_stage_dimensions[1], render_y+y_padding-1+thumb_1_and_2_y_padding, "left", "center", 0, half_stage_dimensions[1]/thumbnail_2:getWidth(), half_stage_dimensions[2]/thumbnail_2:getHeight() )

        if sub_stages_count >= 3 then
          local thumbnail_3 = stages[sub_stages[3]].images.thumbnail
          local thumb_3_x_padding = sub_stages_count == 3 and math.floor(half_stage_dimensions[1]*0.5) or 0
          menu_drawf(thumbnail_3, render_x+padding_x+thumb_3_x_padding, render_y+y_padding-1+thumb_y_padding, "left", "center", 0, half_stage_dimensions[1]/thumbnail_3:getWidth(), half_stage_dimensions[2]/thumbnail_3:getHeight() )
        end
        if sub_stages_count == 4 then
          local thumbnail_4 = stages[sub_stages[4]].images.thumbnail
          menu_drawf(thumbnail_4, render_x+padding_x+half_stage_dimensions[1], render_y+y_padding-1+thumb_y_padding, "left", "center", 0, half_stage_dimensions[1]/thumbnail_4:getWidth(), half_stage_dimensions[2]/thumbnail_4:getHeight() )
        end
      end

      -- player image
      local player_icon_pos = select_screen.character_select_mode == "2p_net_vs"
        and { math.floor(render_x+padding_x+stage_dimensions[1]*0.5), math.floor(render_y+y_padding-stage_dimensions[2]*0.5-7) }
        or { math.floor(render_x+padding_x-10), math.floor(render_y+y_padding-stage_dimensions[2]*0.25) }
      menu_drawf(themes[config.theme].images.IMG_players[player_number], player_icon_pos[1], player_icon_pos[2], "center", "center" )
      -- display name
      local display_name = nil
      if cursor_data.state.stage_is_random == random_stage_special_value 
        or ( cursor_data.state.stage_is_random and not stages[cursor_data.state.stage_is_random] ) then
        display_name = loc("random")
      elseif cursor_data.state.stage_is_random then
        display_name = stages[cursor_data.state.stage_is_random].display_name
      else
        display_name = stages[cursor_data.state.stage].display_name
      end
      gprintf(display_name, render_x+padding_x, math.floor(render_y+y_padding+stage_dimensions[2]*0.5),stage_dimensions[1],"center",nil,1,small_font)

      padding_x = padding_x+stage_dimensions[1]

      if is_selected then
        local arrow_pos = select_screen.character_select_mode == "2p_net_vs"
          and { math.floor(render_x+x_padding+11), math.floor(render_y+y_padding-stage_dimensions[2]*0.5-15) }
          or { math.floor(render_x+padding_x+3), math.floor(render_y+y_padding+0.25*text_height) }
        gprintf(">", arrow_pos[1], arrow_pos[2], 10,"center")
      end
    end

    if character then
      x_add = 0.025*button_width
      width_for_alignment = 0.95*button_width
      draw_character(character)
    end

	--removes underscores from str (to print out the name verbatim)
    local pstr
    if string.sub(str, 1, 2) == "__" then
      pstr = string.sub(str, 3)
    end

	--decides what kind of drawing to do
    if str == "__Mode" then
      if (select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs") then
        draw_match_type(cursor_data[1],1,0.4*button_height)
        draw_match_type(cursor_data[2],2,0.7*button_height)
      else
        draw_match_type(cursor_data[1],1,0.5*button_height)
      end
    elseif str == "__Panels" then
      if (select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs") then
        draw_panels(cursor_data[1],1,0.4*button_height)
        draw_panels(cursor_data[2],2,0.7*button_height)
      else
        draw_panels(cursor_data[1],1,0.5*button_height)
      end
    elseif str == "__Stage" then
      if (select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs") then
        draw_stage(cursor_data[1],1,0.25*button_width)
        draw_stage(cursor_data[2],2,0.75*button_width)
      else
        draw_stage(cursor_data[1],1,0.5*button_width)
      end
    elseif str == "__Level" then
      if (select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs") then
        draw_levels(cursor_data[1],1,0.4*button_height)
        draw_levels(cursor_data[2],2,0.7*button_height)
      else
        draw_levels(cursor_data[1],1,0.5*button_height)
      end
    elseif str == "P1" then
      draw_player_state(cursor_data[1],1)
      pstr = my_name
    elseif str == "P2" then
      draw_player_state(cursor_data[2],2)
      pstr = op_name or ("Player 2")
			
		-- if players 3-8
		elseif str:match('^[P][345678]$') then
			local p_num = tonumber(str:sub(2,2,1))
			
			draw_player_state(cursor_data[p_num],p_num)
			pstr = "Player "..tostring(p_num)
			
			elseif character and character ~= random_character_special_value then
				pstr = character.display_name
				
			-- catch random_character_special_value case
			elseif string.sub(str, 1, 2) ~= "__" then 
				pstr = str:gsub("^%l", string.upper)
				
			end

		-- draw cursor in netplay mode
		local p_num = tonumber(str:sub(2,2,1))	
		if select_screen.character_select_mode == "rr_netplay" and str:match('^[P][12345678]$') then
			if cursor_data[p_num] and cursor_data[p_num].name then
				pstr = cursor_data[p_num].name
			end
		end
	

	--drawing cursor(s)
    if x ~= 0 then
			-- Player 1
      if cursor_data[1].state and cursor_data[1].state.cursor == str and select_screen.character_select_mode ~= "rr_netplay"
        and ( (str ~= "__Empty" and str ~= "__Reserved") or ( cursor_data[1].position[1] == x and cursor_data[1].position[2] == y ) ) then
        draw_cursor(button_height, spacing, 1, cursor_data[1].state.ready)
        if cursor_data[1].can_super_select then
          draw_super_select(1)
        end
      end 
			
			-- Player 2
			if (select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs" or select_screen.character_select_mode == "round_robin")
        and cursor_data[2].state and cursor_data[2].state.cursor == str
        and ( (str ~= "__Empty" and str ~= "__Reserved") or ( cursor_data[2].position[1] == x and cursor_data[2].position[2] == y ) ) then
        draw_cursor(button_height, spacing, 2, cursor_data[2].state.ready)
        if cursor_data[2].can_super_select then
          draw_super_select(2)
        end
      end
			
			-- Player 3-8 for offline round robin mode
			for player = 3, global_rr.num_players do
				if (select_screen.character_select_mode == "round_robin") and cursor_data[player].state and cursor_data[player].state.cursor == str and ( (str ~= "__Empty" and str ~= "__Reserved") or ( cursor_data[player].position[1] == x and cursor_data[player].position[2] == y ) ) then
				
					draw_cursor(button_height, spacing, player, cursor_data[player].state.ready)
					if cursor_data[player].can_super_select then
						draw_super_select(player)
					end
					
				end
			end
    end
	
		-- all round robin netplay cursors
		if select_screen.character_select_mode == "rr_netplay" then 
			for player = 1, 8 do
				if cursor_data[player] and cursor_data[player].visible and cursor_data[player].state and cursor_data[player].state.cursor == str and (( str ~= "__Empty" and str ~= "__Reserved") or (cursor_data[player].position[1] == x and cursor_data[player].position[2] == y)) then
					
					draw_cursor(button_height, spacing, player, cursor_data[player].state.ready)
					if cursor_data[player].can_super_select then
						draw_super_select(player)
					end	  
					
				end
			end
		end
	
    if str ~= "__Empty" and str ~= "__Reserved" then
      local loc_str = {Level= loc("level"), Mode=loc("mode"), Stage=loc("stage"), Panels=loc("panels"), Ready=loc("ready"), Random=loc("random"), Leave=loc("leave")}
      local to_p = loc_str[pstr]
      gprintf( not to_p and pstr or to_p, render_x+x_add, render_y+y_add,width_for_alignment,halign)
    end
	
		if getXY then 
			return render_x, render_y 
		end
		
  end

  print("got to LOC before net_vs_room character select loop")
  menu_clock = 0

  local v_align_center = { __Ready=true, __Random=true, __Leave=true }
  local is_special_value = { __Leave=true, __Level=true, __Panels=true, __Ready=true, __Stage=true, __Mode=true, __Random=true }

  while true do

    -- draw the buttons, handle horizontal spans
    for i=1,X do
      for j=1,Y do
        local value = map[current_page][i][j]
        local span_width = 1
        if is_special_value[value] then
          if j == 1 or map[current_page][i][j-1] ~= value then
            -- detect how many blocks the special value spans
            if j ~= Y then
              for u=j+1,Y do
                if map[current_page][i][u] == value then
                  span_width = span_width + 1
                else
                  break
                end
              end
            end
          else
            -- has already been drawn 
            span_width = 0
          end
        end

        if span_width ~= 0 then
          draw_button(i,j,span_width,1,value,"center", v_align_center[value] and "center" or "top" )
        end
      end
    end

    if select_screen.character_select_mode == "2p_net_vs" then
      local messages = server_queue:pop_all_with("win_counts", "menu_state", "ranked_match_approved", "leave_room", "match_start", "ranked_match_denied")
      if global_initialize_room_msg then
        messages[#messages+1] = global_initialize_room_msg
        global_initialize_room_msg = nil
      end
      for _,msg in ipairs(messages) do
        if msg.win_counts then
          update_win_counts(msg.win_counts)
        end
        if msg.menu_state then
          if currently_spectating then
            if msg.player_number == 1 or msg.player_number == 2 then
              cursor_data[msg.player_number].state = msg.menu_state
              refresh_based_on_own_mods(cursor_data[msg.player_number].state)
              character_loader_load(cursor_data[msg.player_number].state.character)
              stage_loader_load(cursor_data[msg.player_number].state.stage)
            end
          else
            cursor_data[2].state = msg.menu_state
            refresh_based_on_own_mods(cursor_data[2].state)
            character_loader_load(cursor_data[2].state.character)
            stage_loader_load(cursor_data[2].state.stage)
          end

					refresh_loaded_and_ready(cursor_data)
        end
        if msg.ranked_match_approved then
          match_type = "Ranked"
          match_type_message = ""
          if msg.caveats then
            match_type_message = match_type_message..(msg.caveats[1] or "")
          end
        elseif msg.ranked_match_denied then
          match_type = "Casual"
          match_type_message = (loc("ss_not_ranked") or "").."  "
          if msg.reasons then
            match_type_message = match_type_message..(msg.reasons[1] or loc("ss_err_no_reason"))
          end
        end
        if msg.leave_room then
          my_win_count = 0
          op_win_count = 0
          return main_dumb_transition, {main_net_vs_lobby, "", 0, 0}
        end
        if msg.match_start or replay_of_match_so_far then
          print("currently_spectating: "..tostring(currently_spectating))
          local fake_P1 = P1
          local fake_P2 = P2
          refresh_based_on_own_mods(msg.opponent_settings)
          refresh_based_on_own_mods(msg.player_settings, true)
          refresh_based_on_own_mods(msg) -- for stage only, other data are meaningless to us
          -- mainly for spectator mode, those characters have already been loaded otherwise
          character_loader_load(msg.player_settings.character)
          character_loader_load(msg.opponent_settings.character)
          current_stage = msg.stage
          stage_loader_load(msg.stage)
          character_loader_wait()
          stage_loader_wait()
          P1 = Stack(1, "vs", msg.player_settings.panels_dir, msg.player_settings.level, msg.player_settings.character, msg.player_settings.player_number)
          P1.cur_wait_time = default_input_repeat_delay  -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
          P1.enable_analytics = not currently_spectating and not replay_of_match_so_far
          P2 = Stack(2, "vs", msg.opponent_settings.panels_dir, msg.opponent_settings.level, msg.opponent_settings.character, msg.opponent_settings.player_number)
          P2.cur_wait_time = default_input_repeat_delay  -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
          if currently_spectating then
            P1.panel_buffer = fake_P1.panel_buffer
            P1.gpanel_buffer = fake_P1.gpanel_buffer
          end
          P2.panel_buffer = fake_P2.panel_buffer
          P2.gpanel_buffer = fake_P2.gpanel_buffer
          P1.garbage_target = P2
          P2.garbage_target = P1
          move_stack(P2,2)
          replay.vs = {P="",O="",I="",Q="",R="",in_buf="",
                      P1_level=P1.level,P2_level=P2.level,
                      P1_name=my_name, P2_name=op_name,
                      P1_char=P1.character,P2_char=P2.character,
                      P1_cur_wait_time=P1.cur_wait_time, P2_cur_wait_time=P2.cur_wait_time,
                      ranked=msg.ranked, do_countdown=true}
          if currently_spectating and replay_of_match_so_far then --we joined a match in progress
            replay.vs = replay_of_match_so_far.vs
            P1.input_buffer = replay_of_match_so_far.vs.in_buf
            P1.panel_buffer = replay_of_match_so_far.vs.P
            P1.gpanel_buffer = replay_of_match_so_far.vs.Q
            P2.input_buffer = replay_of_match_so_far.vs.I
            P2.panel_buffer = replay_of_match_so_far.vs.O
            P2.gpanel_buffer = replay_of_match_so_far.vs.R
            if replay.vs.ranked then
              match_type = "Ranked"
              match_type_message = ""
            else
              match_type = "Casual"
            end
            replay_of_match_so_far = nil
            P1.play_to_end = true  --this makes foreign_run run until caught up
            P2.play_to_end = true
          end
          if not currently_spectating then
              ask_for_gpanels("000000")
              ask_for_panels("000000")
          end
          to_print = loc("pl_game_start").."\n"..loc("level")..": "..P1.level.."\n"..loc("opponent_level")..": "..P2.level
          if P1.play_to_end or P2.play_to_end then
            to_print = loc("pl_spectate_join")
          end
          for i=1,30 do
            gprint(to_print,unpack(main_menu_screen_pos))
            if not do_messages() then
              return main_dumb_transition, {main_select_mode, loc("ss_disconnect").."\n\n"..loc("ss_return"), 60, 300}
            end
            wait()
          end
          local game_start_timeout = 0
          while P1.panel_buffer == "" or P2.panel_buffer == ""
            or P1.gpanel_buffer == "" or P2.gpanel_buffer == "" do
            --testing getting stuck here at "Game is starting"
            game_start_timeout = game_start_timeout + 1
            print("game_start_timeout = "..game_start_timeout)
            print("P1.panel_buffer = "..P1.panel_buffer)
            print("P2.panel_buffer = "..P2.panel_buffer)
            print("P1.gpanel_buffer = "..P1.gpanel_buffer)
            print("P2.gpanel_buffer = "..P2.gpanel_buffer)
            gprint(to_print,unpack(main_menu_screen_pos))
            if not do_messages() then
              return main_dumb_transition, {main_select_mode, loc("ss_disconnect").."\n\n"..loc("ss_return"), 60, 300}
            end
            wait()
            if game_start_timeout > 250 then
              return main_dumb_transition, {main_select_mode,
                              loc("pl_time_out").."\n"
                              .."\n".."msg.match_start = "..(tostring(msg.match_start) or "nil")
                              .."\n".."replay_of_match_so_far = "..(tostring(replay_of_match_so_far) or "nil")
                              .."\n".."P1.panel_buffer = "..P1.panel_buffer
                              .."\n".."P2.panel_buffer = "..P2.panel_buffer
                              .."\n".."P1.gpanel_buffer = "..P1.gpanel_buffer
                              .."\n".."P2.gpanel_buffer = "..P2.gpanel_buffer,
                              180}
            end
          love.timer.sleep(0.017)
          end
          P1:starting_state()
          P2:starting_state()
          return main_dumb_transition, {main_net_vs, "", 0, 0}
        end
      end
    end

    local my_rating_difference = ""
    local op_rating_difference = ""
    if current_server_supports_ranking and not global_current_room_ratings[my_player_number].placement_match_progress then
      if global_current_room_ratings[my_player_number].difference then
        if global_current_room_ratings[my_player_number].difference>= 0 then
          my_rating_difference = "(+"..global_current_room_ratings[my_player_number].difference..") "
        else
          my_rating_difference = "("..global_current_room_ratings[my_player_number].difference..") "
        end
      end
      if global_current_room_ratings[op_player_number].difference then
        if global_current_room_ratings[op_player_number].difference >= 0 then
          op_rating_difference = "(+"..global_current_room_ratings[op_player_number].difference..") "
        else
          op_rating_difference = "("..global_current_room_ratings[op_player_number].difference..") "
        end
      end
    end
   
    local function get_player_state_str(player_number, rating_difference, win_count, op_win_count, expected_win_ratio)
      local state = ""
      if current_server_supports_ranking then
        state = state..loc("ss_rating").." "..(global_current_room_ratings[player_number].league or "")
        if not global_current_room_ratings[player_number].placement_match_progress then
          state = state.."\n"..rating_difference..global_current_room_ratings[player_number].new
        elseif global_current_room_ratings[player_number].placement_match_progress
        and global_current_room_ratings[player_number].new
        and global_current_room_ratings[player_number].new == 0 then
          state = state.."\n"..global_current_room_ratings[player_number].placement_match_progress
        end
      end
      if select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs" then
        if current_server_supports_ranking then
          state = state.."\n"
        end
        state = state..loc("ss_wins").." "..win_count
        if (current_server_supports_ranking and expected_win_ratio) or win_count + op_win_count > 0 then
          state = state.."\n"..loc("ss_winrate").."\n"
          local need_line_return = false
          if win_count + op_win_count > 0 then
            state = state.."    "..loc("ss_current_rating").." "..(100*round(win_count/(op_win_count+win_count),2)).."%"
            need_line_return = true
          end
          if current_server_supports_ranking and expected_win_ratio then
            if need_line_return then
              state = state.."\n"
            end
            state = state.."    "..loc("ss_expected_rating").." "..expected_win_ratio.."%"
          end
        end
      end
      return state
    end
	
    draw_button(0,1,1,1,"P1")
    draw_button(0,2,2,1,get_player_state_str(my_player_number,my_rating_difference,my_win_count,op_win_count,my_expected_win_ratio),"left","top",true)
	
	--draws P2 and stats
    if select_screen.character_select_mode ~= "round_robin" then 
			
			-- draw player win statistics
			if cursor_data[1].state and op_name then 
				draw_button(0, 3, 1, 1, "P2")
				draw_button(0, 4, 2, 1, get_player_state_str(op_player_number, op_rating_difference, op_win_count,my_win_count, op_expected_win_ratio), "left", "top", true)
			end
			
		else 
			local spacing = 8 / global_rr.num_players
			
			for player = 2, global_rr.num_players do
				draw_button(0, player * spacing, 1, 1, "P"..player)
			end
		end

	--prints if net play game is ranked or casual
    if select_screen.character_select_mode == "2p_net_vs" then
      if not cursor_data[1].state.ranked and not cursor_data[2].state.ranked then
        match_type_message = ""
      end
      local match_type_str = ""
      if match_type == "Casual" then
        match_type_str = loc("ss_casual")
      elseif match_type == "Ranked" then
        match_type_str = loc("ss_ranked")
      end
      gprintf(match_type_str, 0, 15, canvas_width, "center")
      gprintf(match_type_message, 0, 30, canvas_width, "center")
    end
   
    --prints which page of buttons is being shown
		if pages_amount ~= 1 then
      gprintf(loc("page").." "..current_page.."/"..pages_amount, 0, 660, canvas_width, "center")
    end
	
    wait()
    local ret = nil

    local function move_cursor(cursor,direction)
      local cursor_pos = cursor.position
      local dx,dy = unpack(direction)
      local can_x,can_y = wrap(1, cursor_pos[1]+dx, X), wrap(1, cursor_pos[2]+dy, Y)
      while can_x ~= cursor_pos[1] or can_y ~= cursor_pos[2] do
        if map[current_page][can_x][can_y] and ( map[current_page][can_x][can_y] ~= map[current_page][cursor_pos[1]][cursor_pos[2]] or 
          map[current_page][can_x][can_y] == "__Empty" or map[current_page][can_x][can_y] == "__Reserved" ) then
          break
        end
        can_x,can_y = wrap(1, can_x+dx, X), wrap(1, can_y+dy, Y)
      end
      cursor_pos[1],cursor_pos[2] = can_x,can_y
      local character = characters[map[current_page][can_x][can_y]]
      cursor.can_super_select = character and ( character.stage or character.panels )
    end

    local function change_panels_dir(panels_dir,increment)
      local current = 0
      for k,v in ipairs(panels_ids) do
        if v == panels_dir then
          current = k
          break
        end
      end
      local dir_count = #panels_ids
      local new_theme_idx = ((current - 1 + increment) % dir_count) + 1
      for k,v in ipairs(panels_ids) do
        if k == new_theme_idx then
            return v
        end
      end
      return panels_dir
    end

    local function change_stage(state,increment)
      -- random_stage_special_value is placed at the end of the list and is 'replaced' by a random pick and stage_is_random=true
      local current = nil
      for k,v in ipairs(stages_ids_for_current_theme) do
        if ( not state.stage_is_random and v == state.stage ) 
        or ( state.stage_is_random and v == state.stage_is_random ) then
          current = k
          break
        end
      end
      if state.stage == nil or state.stage_is_random == random_stage_special_value then
        current = #stages_ids_for_current_theme+1
      end
      if current == nil then -- stage belonged to another set of stages, it's no more in the list
        current = 0
      end
      local dir_count = #stages_ids_for_current_theme + 1
      local new_stage_idx = ((current - 1 + increment) % dir_count) + 1
      if new_stage_idx <= #stages_ids_for_current_theme then
        local new_stage = stages_ids_for_current_theme[new_stage_idx]
        if stages[new_stage]:is_bundle() then
          state.stage_is_random = new_stage
          state.stage = uniformly(stages[new_stage].sub_stages) 
        else
          state.stage_is_random = nil
          state.stage = new_stage
        end
      else
        state.stage_is_random = random_stage_special_value
        state.stage = uniformly(stages_ids_for_current_theme)
        if stages[state.stage]:is_bundle() then -- may pick a bundle!
          state.stage = uniformly(stages[state.stage].sub_stages)
        end
      end
      print("stage and stage_is_random: "..state.stage.." / "..(state.stage_is_random or "nil"))
    end

    local function on_quit()
      if themes[config.theme].musics.select_screen then
        stop_the_music()
      end
      if select_screen.character_select_mode == "2p_net_vs" then
        if not do_leave() then
          ret = {main_dumb_transition, {main_select_mode, loc("ss_error_leave"), 60, 300}}
        end
      else
        ret = {main_select_mode}
      end
    end 

    local function on_select(cursor,super)
      local noisy = false
      local selectable = {__Stage=true, __Panels=true, __Level=true, __Ready=true}
      if selectable[cursor.state.cursor] then
        if cursor.selected and cursor.state.cursor == "__Stage" then
          -- load stage even if hidden!
          stage_loader_load(cursor.state.stage)
        end
        cursor.selected = not cursor.selected
		
      elseif cursor.state.cursor == "__Leave" then
        on_quit()
		
      elseif cursor.state.cursor == "__Random" then
        cursor.state.character_is_random = inNetplay and nil or random_character_special_value
        cursor.state.character = uniformly(characters_ids_for_current_theme)
        if characters[cursor.state.character]:is_bundle() then -- may pick a bundle
          cursor.state.character = uniformly(characters[cursor.state.character].sub_characters)
        end
        cursor.state.character_display_name = characters[cursor.state.character].display_name
        character_loader_load(cursor.state.character)
        cursor.state.cursor = "__Ready"
        cursor.position = shallowcpy(name_to_xy_per_page[current_page]["__Ready"])
        cursor.can_super_select = false
		
      elseif cursor.state.cursor == "__Mode" then
        cursor.state.ranked = not cursor.state.ranked
		
      elseif ( cursor.state.cursor ~= "__Empty" and cursor.state.cursor ~= "__Reserved" ) then
        cursor.state.character_is_random = nil
        cursor.state.character = cursor.state.cursor
		

        if characters[cursor.state.character]:is_bundle() then -- may pick a bundle
          cursor.state.character_is_random = cursor.state.character
          cursor.state.character = uniformly(characters[cursor.state.character_is_random].sub_characters)
        end
		
        cursor.state.character_display_name = characters[cursor.state.character].display_name
        local character = characters[cursor.state.character]
		
        if not cursor.state.character_is_random then
          noisy = character:play_selection_sfx()
        elseif characters[cursor.state.character_is_random] then
          noisy = characters[cursor.state.character_is_random]:play_selection_sfx()
        end

        character_loader_load(cursor.state.character)
		
        if super then
          if character.stage then
            cursor.state.stage = character.stage
            stage_loader_load(cursor.state.stage)
            cursor.state.stage_is_random = false
          end
          if character.panels then
            cursor.state.panels_dir = character.panels
          end
        end
		
        --When we select a character, move cursor to "__Ready"
        cursor.state.cursor = "__Ready"
        cursor.position = shallowcpy(name_to_xy_per_page[current_page]["__Ready"])
        cursor.can_super_select = false
      end
	  
      return noisy
    end

    variable_step(function()
      menu_clock = menu_clock + 1

      character_loader_update()
      stage_loader_update()

			refresh_loaded_and_ready(cursor_data)

      local up,down,left,right = {-1,0}, {1,0}, {0,-1}, {0,1}

      if not currently_spectating then
        local KMax = 1
				
				-- increases maximum players to the round robin maximum
        if select_screen.character_select_mode == "2p_local_vs" or select_screen.character_select_mode == "round_robin" then
          KMax = global_rr.num_players
        end
		
        for i=1,KMax do
          local k=K[i]
          local cursor = cursor_data[i]

          if menu_prev_page(k) then
            if not cursor.selected then current_page = bound(1, current_page-1, pages_amount) end
        
					elseif menu_next_page(k) then
            if not cursor.selected then current_page = bound(1, current_page+1, pages_amount) end
          
					elseif menu_up(k) then
            if not cursor.selected then move_cursor(cursor,up) end
          
					elseif menu_down(k) then
            if not cursor.selected then move_cursor(cursor,down) end
          
					elseif menu_left(k) then
            if cursor.selected then
              if cursor.state.cursor == "__Level" then
                cursor.state.level = bound(1, cursor.state.level-1, #level_to_starting_speed) --which should equal the number of levels in the game
              elseif cursor.state.cursor == "__Panels" then
                cursor.state.panels_dir = change_panels_dir(cursor.state.panels_dir,-1)
              elseif cursor.state.cursor == "__Stage" then
                change_stage(cursor.state,-1)
              end
            end
            if not cursor.selected then move_cursor(cursor,left) end
          
					elseif menu_right(k) then
            if cursor.selected then
              if cursor.state.cursor == "__Level" then
                cursor.state.level = bound(1, cursor.state.level+1, #level_to_starting_speed) --which should equal the number of levels in the game
              elseif cursor.state.cursor == "__Panels" then
                cursor.state.panels_dir = change_panels_dir(cursor.state.panels_dir,1)
              elseif cursor.state.cursor == "__Stage" then
                change_stage(cursor.state,1)
              end
            end
            if not cursor.selected then move_cursor(cursor,right) end
          
					else
            -- code below is bit hard to read: basically we are storing the default sfx callbacks until it's needed (or not!) based on the on_select method
            local long_enter, long_enter_callback = menu_long_enter(k, true)
            local normal_enter, normal_enter_callback = menu_enter(k, true)
            if long_enter then
              if not on_select(cursor, true) then
                long_enter_callback()
              end
            elseif normal_enter and (not cursor.can_super_select or menu_pressing_enter(k) < super_selection_enable_ratio) then
              if not on_select(cursor, false) then
                normal_enter_callback()
              end
            elseif menu_escape(k) then
              if cursor.state.cursor == "__Leave" then
                on_quit()
              end
              cursor.selected = false
              cursor.position = shallowcpy(name_to_xy_per_page[current_page]["__Leave"])
              cursor.can_super_select = false
            end
          end
          if cursor.state ~= nil then
            cursor.state.cursor = map[current_page][cursor.position[1]][cursor.position[2]]
            cursor.state.wants_ready = cursor.selected and cursor.state.cursor=="__Ready"
          end
        end

        -- update config, does not redefine it
        config.character = cursor_data[1].state.character_is_random and cursor_data[1].state.character_is_random or cursor_data[1].state.character
        config.stage = cursor_data[1].state.stage_is_random and cursor_data[1].state.stage_is_random or cursor_data[1].state.stage
        config.level = cursor_data[1].state.level
        config.ranked = cursor_data[1].state.ranked
        config.panels = cursor_data[1].state.panels_dir
		
				-- random character don't work well with round robin mode because it doesn't go back to character select before playing a match so this
				-- just assigns a random character immediately after the character select screen. It doesn't save "__RandomCharacter" as the player's default choice for next time"..
				rr_override_character = cursor_data[1].state.character
				
				-- check if random character needs to handled
				if cursor_data[1].state.character_is_random and (select_screen.character_select_mode == "rr_netplay_char_select" or select_screen.character_select_mode == "round_robin") then 
					cursor_data[1].state.character_is_random = nil 
				end

				-- set up character select for local vs mode
        if select_screen.character_select_mode == "2p_local_vs" then
          global_op_state = shallowcpy(cursor_data[2].state)
          global_op_state.character = global_op_state.character_is_random and global_op_state.character_is_random or global_op_state.character
          global_op_state.stage = global_op_state.stage_is_random and global_op_state.stage_is_random or global_op_state.stage
          global_op_state.wants_ready = false
        end

				-- send current menu state to server when playing online
        if select_screen.character_select_mode == "2p_net_vs" and not content_equal(cursor_data[1].state, prev_state) and not currently_spectating then
          json_send({menu_state=cursor_data[1].state})
        end
				
        prev_state = shallowcpy(cursor_data[1].state)

			-- in spectating mode
			else
				if menu_escape(K[1]) then
					if select_screen.character_select_mode == "rr_netplay_char_select" then
						ret = main_select_mode
					else 
						do_leave()
						ret = {main_net_vs_lobby}
					end
        end
      end
    end)

    if ret then
      return unpack(ret)
    end
	
		-- main lobby when playing round robin mode
		function round_robin_lobby()
			local ret = nil
			local l_player, r_player = nil, nil	
			local lobby_state_changed = false
			local netPlayerNum = init_cursor_number
			local inNetplay = select_screen.character_select_mode == "rr_netplay" or false 
			
			-- initialize each player
			local function init_players()
				for player = 1, global_rr.num_players do
					cursor_data[player].state.ready = nil
					cursor_data[player].ready = false
					cursor_data[player].selected = false
					cursor_data[player].active = true --false if sitting out
					global_rr.win_count[player] = 0
				end				
			end	

			-- discard all of a player's state data
			local function clear_player(player)
				if cursor_data[player] then 
					cursor_data[player].ready = nil
					cursor_data[player].state.wants_ready = nil
					cursor_data[player].selected = nil
					cursor_data[player].active = nil
					cursor_data[player].state.level = nil
					cursor_data[player].state.character = nil
					cursor_data[player].state.character_display_name = nil
					cursor_data[player].state.cursor = nil
					cursor_data[player].name = nil
					cursor_data[player].visible = false
					global_rr.win_count[player] = 0	
				end
			end
			
			-- adds all players to the list that draws the next player to play
			local function fill_player_queue()
				local chosen_players = {}
				
				for i = 1, global_rr.num_players do
					local player
					
					-- find a player that has not been chosen
					repeat
						player = math.random(global_rr.num_players)
					until chosen_players[player] == nil 
					
					-- if that player is still playing, add them to the queue
					if cursor_data[player].active then
						global_rr.player_order:push(player)
					end
					
					chosen_players[player] = true				
				end
				
			end
			
			-- determine both players who will play next
			local function pick_now_playing()	
			
				--chooses left player
				if (not l_player or l_player == nobody) then	
					if global_rr.win_count.last_winner and global_rr.matchup == "Winner" and r_player ~= global_rr.win_count.last_winner and cursor_data[global_rr.win_count.last_winner].active then
						l_player = global_rr.win_count.last_winner
					else
						
						-- refill queue if it is empty
						if global_rr.player_order:len() == 0 then
							fill_player_queue()
						end
						
						if global_rr.player_order:len() > 0 then
						
							-- grab the next available player and add them if they are still active
							repeat
								l_player = global_rr.player_order:pop()
								
								 -- nobody if no player is free to play (ie all players are sitting out) 
								if cursor_data[l_player].active == false or l_player == r_player then 
									l_player = nobody
								end
								
							until l_player or global_rr.player_order:len() < 1	
							
						end 
					end
				end

				--chooses right player
				if (not r_player or r_player == nobody) then
					if global_rr.win_count.last_winner and global_rr.matchup == "Winner" and l_player ~= global_rr.win_count.last_winner and cursor_data[global_rr.win_count.last_winner].active then
						r_player = global_rr.win_count.last_winner
					else
					
						-- refill queue if it is empty
						if global_rr.player_order:len() == 0 then
							fill_player_queue()
						end
						
						if global_rr.player_order:len() > 0 then			

							-- grab the next available player and add them if they are still active
							repeat
								r_player = global_rr.player_order:pop()
								
								-- nobody if no player is free to play (ie all players are sitting out) 
								if cursor_data[r_player].active == false or r_player == l_player then 
									r_player = nobody 
								end
								
							until r_player or global_rr.player_order:len() < 1
						end
					end
				end		
			end

			-- send current state of the lobby to the server
			local function send_lobby_state()
				cursor = cursor_data[netPlayerNum]
				
				sent_json = {rr_state = {cursor_state = cursor.state.cursor, 
																cursor_active = cursor.active, 
																cursor_selected = cursor.selected, 
																cursor_ready = (cursor.ready and cursor.state.ready),
																}}
				json_send(sent_json)
			end

			-- receive lobby information from server
			local function net_update_lobby()
				local got_msg = false
			
				repeat
					local msg = server_queue:pop_next_with("rr_lobby_state")
					
					if msg then 
						got_msg = true
				
						-- clear each player's state
						for i = 1, 8 do
							if i ~= netPlayerNum then
								clear_player(i)
							end
						end											
						
						-- load message data
						for _, v in pairs(msg.rr_lobby_state) do
							local player = v.player_number
					
							-- update any player information that isn't the local player
							if player ~= netPlayerNum then 
								cursor_data[player].ready = v.cursor_ready
								cursor_data[player].selected = v.cursor_selected
								cursor_data[player].active = v.cursor_active
								cursor_data[player].state.level = v.level
								cursor_data[player].state.character = v.character
								cursor_data[player].state.stage = v.stage
								cursor_data[player].state.character_display_name = v.character_display_name
								cursor_data[player].state.cursor = v.cursor_state
								cursor_data[player].name = v.player_name
								cursor_data[player].visible = true
								global_rr.win_count[player] = v.wins
								
								-- wait for character portrait to load if not done already
								if not characters[cursor_data[player].state.character].fully_loaded then 
										character_loader_load(cursor_data[player].state.character)
										character_loader_wait()
								end
								
								-- wait for stage to load
								if cursor_data[player].state.stage ~= "__RandomStage" and not stages[cursor_data[player].state.stage].fully_loaded then
									stage_loader_load(cursor_data[player].state.stage)
								end
								
							-- update local player's information
							else

								-- update cursor state
								cursor_data[player].state.cursor = v.cursor_state
								rr_net_return = false

								-- update player's name if the server renamed them
								cursor_data[player].name = v.player_name
								global_rr.win_count[player] = v.wins
							end
						end 

						l_player = msg.rr_mode.l_player
						r_player = msg.rr_mode.r_player

						global_rr.win_mode = msg.rr_mode.rr_win_mode or ""
						global_rr.matchup = msg.rr_mode.rr_play_mode or ""	

					end
				until not msg	
				
				refresh_loaded_and_ready(cursor_data)			

				return got_msg
			end

			--set up the scrolling background
			local bg_x, bg_y = 0, 0
			
			scrolling_bg = themes[config.theme].images.rr_lobby
			scrolling_bg:setWrap("repeat", "repeat")
			bg_quad = love.graphics.newQuad(0, 0, canvas_width, canvas_height, scrolling_bg:getWidth(), scrolling_bg:getHeight())

			--only should be done the first time netplay is run
			if not global_rr.isSetup then
				init_players()
				fill_player_queue()
			end
			
			-- setup netplay variables
			if inNetplay and not global_rr.isSetup then 
				cursor_data[netPlayerNum] = deepcpy(cursor_data[1])
				send_lobby_state()		
				my_name = config.name or my_name or ""
			
				global_rr.num_players = global_max_players
				for i = 1, global_max_players do
					cursor_data[i].visible = false
				end
				
			end

			-- wait for initial lobby information from server
			if inNetplay then
				local got_lobby = false
				local i = 0
				repeat 
					got_lobby = net_update_lobby()
					i = i + 1
				until got_lobby or i > 50
				
				P1 = {panel_buffer="", gpanel_buffer=""}
				P2 = {panel_buffer="", gpanel_buffer=""}
			end	
			
			--init more netplay variables
			if inNetplay and not global_rr.isSetup then
			
				cursor_data[netPlayerNum].state.ready = nil
				cursor_data[netPlayerNum].ready = false
				cursor_data[netPlayerNum].state.wants_ready = false
				cursor_data[netPlayerNum].selected = false
				cursor_data[netPlayerNum].active = true
				cursor_data[netPlayerNum].visible = true
				cursor_data[netPlayerNum].name = my_name
				cursor_data[netPlayerNum].state.cursor = "Sit Out"
				
				send_lobby_state()
			end

			-- local setup if not playing online
			if not inNetplay then
				pick_now_playing()
				
				--starting positions of the cursors
				for p = 1, global_rr.num_players do
					if p == l_player then 
						cursor_data[p].state.cursor = "Ready Left Player"
					elseif p == r_player then
						cursor_data[p].state.cursor = "Ready Right Player"
					else
						cursor_data[p].state.cursor = "Sit Out"
					end			
				end			
			end
			
			global_rr.isSetup = true
				
			--main loop
			while (not ret) do 
			
				local function scroll_background()
					bg_x = bg_x-0.4
					bg_y = bg_y-0.6
					bg_quad:setViewport(bg_x, bg_y, canvas_width, canvas_height)
					menu_drawq(scrolling_bg, bg_quad, 0, 0, 0, 1, 1)
				end	
				
				local function draw_interface()
					--draw player information
					for p = 1, global_rr.num_players do
					
						if inNetplay and not cursor_data[p].visible then
							pstr = "__Empty"
						else
							pstr = "P"..p
						end
		
						-- draw portraits in columns
						if p <= 4 then
							draw_button((p - 0.5) * 1.25, 0, 1, 1, pstr)
							if pstr ~= "__Empty" then 
								draw_button((p - 0.5) * 1.25, 1, 1, 1, "Wins: "..tostring(global_rr.win_count[p] or 0), "center", "center", true);
							end
							
						else 
							draw_button((p - 4 - 0.5) * 1.25, 3, 1, 1, pstr)
							if pstr ~= "__Empty" then 
								draw_button((p - 4 - 0.5) * 1.25, 4, 1, 1, "Wins: "..tostring(global_rr.win_count[p] or 0), "center", "center", true);
							end
						end
					end
					
					-- draw ready buttons and ready image if selected
					
					-- left player
					local pl_x, pl_y = draw_button(0.5, 5, 2, 2, "Ready Left Player", false, false, false, true)
					
					if l_player and l_player ~= nobody then
						local pstr = "PLAYER "..tostring(l_player)
						if inNetplay then pstr = cursor_data[l_player].name end

						draw_button(0.5, 5, 2, 2, pstr, "center", "center")
						
						if(cursor_data[l_player].ready == true) then
							menu_drawf(themes[config.theme].images.IMG_ready, pl_x + 125, pl_y + 50, "center", "center", math.pi/4, 2, 2)
						end
					else
						draw_button(0.5, 5, 2, 2, "No free player", "center", "center")
					end
					
					-- right player
					local pr_x, pr_y = draw_button(0.5, 8, 2, 2, "Ready Right Player", false, false, false, true)
					if r_player and r_player ~= nobody then 
						local pstr = "PLAYER "..tostring(r_player)
						if inNetplay then pstr = cursor_data[r_player].name end				
					
						draw_button(0.5, 8, 2, 2, pstr, "center", "center") 
						
						if(cursor_data[r_player].ready == true) then
							menu_drawf(themes[config.theme].images.IMG_ready, pr_x + 125, pr_y + 50, "center", "center", math.pi/4, 2, 2)
						end					
					else
						draw_button(0.5, 8, 2, 2, "No free player", "center", "center")
					end
					 
					--draw option buttons
					draw_button(3.5*1.25, 8, 1, 1, "Sit Out")
					draw_button(3.5*1.25, 9, 1, 1, "Leave")

					local padding = (global_rr.matchup == "Even") and "  " or ""
					draw_button(3.5*1.25, 7, 1, 1, "Next Player")
					gprintf(padding.."<-"..string.upper(global_rr.matchup).."->", 801, 550)
					
					draw_button(3.5*1.25, 5, 2, 1, "Game Type")
					gprint("<-"..string.upper(global_rr.win_mode).."->", 630, 550)
				end		

				if inNetplay then 
					net_update_lobby()
				end	
				
				scroll_background()
				draw_interface()	

				if not inNetplay then 
					pick_now_playing()		
				end
				
				-- quit if error in network
				if inNetplay and not do_messages() then
					ret = main_select_mode
				end	
							
				variable_step(function () 
					menu_clock = menu_clock + 1

					-- moves cursor to the appropriate button
					local function move_lobby_cursor(cursor, dir, player)
						local item = cursor.state.cursor
						local prev = cursor.state.cursor

						lobby_state_changed = true

						if dir == "left" then 
							if cursor.state.cursor == "Ready Left Player" 		then cursor.state.cursor = "Ready Right Player"
							elseif cursor.state.cursor == "Ready Right Player"  then cursor.state.cursor = "Ready Left Player"
							elseif cursor.state.cursor == "Sit Out" 			then cursor.state.cursor = "Next Player" 
							elseif cursor.state.cursor == "Next Player" 		then cursor.state.cursor = "Game Type"
							elseif cursor.state.cursor == "Game Type" 			then cursor.state.cursor = "Leave"
							elseif cursor.state.cursor == "Leave" 				then cursor.state.cursor = "Sit Out" 
							end
						end

						if dir == "right" then 
							if cursor.state.cursor == "Ready Left Player" 		then cursor.state.cursor = "Ready Right Player" 
							elseif cursor.state.cursor == "Ready Right Player" 	then cursor.state.cursor = "Ready Left Player"
							elseif cursor.state.cursor == "Sit Out" 			then cursor.state.cursor = "Leave"
							elseif cursor.state.cursor == "Leave"	 			then cursor.state.cursor = "Game Type"
							elseif cursor.state.cursor == "Game Type" 			then cursor.state.cursor = "Next Player"
							elseif cursor.state.cursor == "Next Player" 		then cursor.state.cursor = "Sit Out"
							elseif cursor.state.cursor == "Leave" 				then cursor.state.cursor = "Next Player"
							end
						end
						
						if dir == "up" or dir == "down" then
							if cursor.state.cursor == "Ready Left Player" or cursor.state.cursor == "Ready Right Player" then 
								cursor.state.cursor = "Sit Out" 
							elseif cursor.state.cursor == "Sit Out" or cursor.state.cursor == "Leave" or cursor.state.cursor == "Next Player" or cursor.state.cursor == "Game Type" then
								if player == l_player then cursor.state.cursor = "Ready Left Player" end
								if player == r_player then cursor.state.cursor = "Ready Right Player" end
							end
						end
						
						--if the player isn't playing... don't let them try to choose a ready button
						if cursor.state.cursor == "Ready Left Player" and (not (player == l_player)) then 
							cursor.state.cursor = prev 
						end
						
						if cursor.state.cursor == "Ready Right Player" and (not (player == r_player)) then 
							cursor.state.cursor = prev 
						end
					end

					-- handles each player's keyboard input
					for i = 1, global_rr.num_players do
						local k = K[i]
						local cursor = cursor_data[i]				 		  
						
						if inNetplay then
							k = K[1]
							cursor = cursor_data[netPlayerNum]
							i = netPlayerNum
						end
						
						if menu_right(k) and (not cursor.selected) then move_lobby_cursor(cursor, "right", i) end
						if menu_left(k)  and (not cursor.selected) then move_lobby_cursor(cursor, "left", i) end 
						if menu_up(k) and (not cursor.selected) then move_lobby_cursor(cursor, "up", i) end
						if menu_down(k) and (not cursor.selected) then move_lobby_cursor(cursor, "down", i) end

						--if changing the next player option button
						if (menu_right(k) or menu_left(k)) and cursor.selected and cursor.state.cursor == "Next Player" then
							global_rr.player_order:clear()
							
							if global_rr.matchup == "Winner" then 
								global_rr.matchup = "Even" 
							elseif global_rr.matchup == "Even" then 
								global_rr.matchup = "Winner" 
							end
						end
					
						-- changing the game type button
						if (menu_right(k) or menu_left(k)) and cursor.selected and cursor.state.cursor == "Game Type" then
							if global_rr.win_mode == "Best of Three" then 
								global_rr.win_mode = "Single Match" 
							elseif global_rr.win_mode == "Single Match" then 
								global_rr.win_mode = "Best of Three" 
							end
						end
						
						-- "Enter" key pressed
						if menu_enter(k, false) then
							lobby_state_changed = true
							
							if not cursor.selected then 
							
								-- send immediate changes to server
								if inNetplay and cursor.state.cursor == "Game Type" then
									json_send({change_win_mode = true})
									
								elseif inNetplay and cursor.state.cursor == "Next Player" then
									json_send({change_play_mode = true})
									
								-- changes that require further processing
								else
								
									cursor.selected = true
									
									-- select ready to play
									if ((cursor.state.cursor == "Ready Left Player" and i == l_player) or (cursor.state.cursor == "Ready Right Player" and i == r_player)) then						
										cursor.state.ready = true
										cursor.ready = true
										
									-- leave game
									elseif cursor.state.cursor == "Leave" then 
										if inNetplay then
											json_send({logout=true})
										else
											global_rr.player_order:clear()
										end	
										
										ret = main_select_mode
									
									-- change from "active" state
									elseif cursor.state.cursor == "Sit Out" then
										
										-- no longer on deck to play
										if i == l_player then
											l_player = nil
										elseif i == r_player then
											r_player = nil
										end
										
										--remove this player from the queue if sitting out
										for j = 1, global_rr.player_order:len() do
											if(global_rr.player_order:peek() == i) then
												global_rr.player_order:pop()
												j = j + 1
											else
												global_rr.player_order:push(global_rr.player_order:pop())
											end
										end
										
										cursor.active = false
									end	
								end
								
							-- undo select 
							elseif cursor.selected then 
								cursor.selected = false
								cursor.ready = false
								cursor.state.ready = false
								cursor.active = true
							end				
						end 

						if inNetplay then 
							break 
						end -- only takes input for the local play in netplay

					end 
				end)
			
				-- time to play! for offline...
				if not inNetplay and l_player and l_player ~= nobody and r_player and r_player ~= nobody then
					if cursor_data[l_player].ready and cursor_data[r_player].ready then
						
						 -- P1 has to pretend to be player #1 so that the countdown sfx players (it is limited to P1 so both players don't make it play simultaneously I guess)
						local P1_for_a_day = false
						if r_player ~= 1 then 
							P1_for_a_day = true 
						end
						
						--copied from down below
						P1 = Stack(l_player, "vs", cursor_data[l_player].state.panels_dir, cursor_data[l_player].state.level, cursor_data[l_player].state.character, nil, P1_for_a_day)
						P1.enable_analytics = true
						P2 = Stack(r_player, "vs", cursor_data[r_player].state.panels_dir, cursor_data[r_player].state.level, cursor_data[r_player].state.character)
						P1.garbage_target = P2
						P2.garbage_target = P1
						current_stage = cursor_data[math.random(l_player,r_player)].state.stage
						stage_loader_load(current_stage)
						stage_loader_wait()
						move_stack(P2,2) 
						make_local_panels(P1, "000000")
						make_local_gpanels(P1, "000000")
						make_local_panels(P2, "000000")
						make_local_gpanels(P2, "000000")
						P1:starting_state()
						P2:starting_state()
											
						for p = 1, global_rr.num_players do
							if cursor_data[p].active ~= false then
								cursor_data[p].ready = false
								cursor_data[p].state.ready = false
								cursor_data[p].selected = false
							end
						end
						
						l_player = nil
						r_player = nil
						
						ret = rr_local_vs				  
					end
					
				-- start match if playing online
				elseif inNetplay then
				
						-- grab all relevant initialization messages
						local messages = server_queue:pop_all_with("match_start", "replay_of_match_so_far")
						for _,msg in ipairs(messages) do

							currently_spectating = false
							
							if msg.match_start or msg.replay_of_match_so_far then
								local replay_of_match_so_far = msg.replay_of_match_so_far

								-- make spectator
								if netPlayerNum ~= msg.player_settings.cursor_number and netPlayerNum ~= msg.opponent_settings.cursor_number or msg.spectate_request_granted then
									currently_spectating = true
								end
								
								-- print all spectators
								print("currently_spectating: "..tostring(currently_spectating))
								
								-- joining a fresh game
								if not msg.replay_of_match_so_far then
									cursor_data[msg.player_settings.cursor_number].ready = false
									cursor_data[msg.opponent_settings.cursor_number].ready = false
									
									cursor_data[msg.player_settings.cursor_number].selected = false
									cursor_data[msg.opponent_settings.cursor_number].ready = false
														
									my_name = msg.player_settings.name
									op_name = msg.opponent_settings.name
									
									my_win_count = global_rr.win_count[msg.player_settings.cursor_number] or 0
									op_win_count = global_rr.win_count[msg.opponent_settings.cursor_number] or 0
									
								-- joining game in progress
								else
									my_name = replay_of_match_so_far.vs.P1_name
									op_name = replay_of_match_so_far.vs.P2_name
									
									my_win_count = msg.win_counts[1]
									op_win_count = msg.win_counts[2]
								end
								
								local fake_P1 = P1
								local fake_P2 = P2
								
								-- override settings based on local mods
								refresh_based_on_own_mods(msg.opponent_settings)
								refresh_based_on_own_mods(msg.player_settings, true)
								refresh_based_on_own_mods(msg)
								
								--load character and stages if not already done
								character_loader_load(msg.player_settings.character)
								character_loader_load(msg.opponent_settings.character)
								current_stage = msg.stage
								stage_loader_load(msg.stage)
								character_loader_wait()
								stage_loader_wait()

								-- copied from original code
								P1 = Stack(1, "vs", msg.player_settings.panels_dir, msg.player_settings.level, msg.player_settings.character, msg.player_settings.player_number)
								P1.cur_wait_time = default_input_repeat_delay  -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
								P1.enable_analytics = not currently_spectating and not replay_of_match_so_far
								P2 = Stack(2, "vs", msg.opponent_settings.panels_dir, msg.opponent_settings.level, msg.opponent_settings.character, msg.opponent_settings.player_number)
								P2.cur_wait_time = default_input_repeat_delay  -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.

								if currently_spectating then
									P1.panel_buffer = fake_P1.panel_buffer
									P1.gpanel_buffer = fake_P1.gpanel_buffer
								end
								
								P2.panel_buffer = fake_P2.panel_buffer
								P2.gpanel_buffer = fake_P2.gpanel_buffer
								P1.garbage_target = P2
								P2.garbage_target = P1
								
								move_stack(P2,2)
								
								replay.vs = {P="",O="",I="",Q="",R="",in_buf="",
											P1_level=P1.level,P2_level=P2.level,
											P1_name=my_name, P2_name=op_name,
											P1_char=P1.character,P2_char=P2.character,
											P1_cur_wait_time=P1.cur_wait_time, P2_cur_wait_time=P2.cur_wait_time,
											ranked=msg.ranked, do_countdown=true}

								if currently_spectating and replay_of_match_so_far then --we joined a match in progress
									replay.vs = replay_of_match_so_far.vs
									P1.input_buffer = replay_of_match_so_far.vs.in_buf
									P1.panel_buffer = replay_of_match_so_far.vs.P
									P1.gpanel_buffer = replay_of_match_so_far.vs.Q
									P2.input_buffer = replay_of_match_so_far.vs.I
									P2.panel_buffer = replay_of_match_so_far.vs.O
									P2.gpanel_buffer = replay_of_match_so_far.vs.R
									
									if replay.vs.ranked then
										match_type = "Ranked"
										match_type_message = ""
									else
										match_type = "Casual"
									end
									
									replay_of_match_so_far = nil
									P1.play_to_end = true  --this makes foreign_run run until caught up
									P2.play_to_end = true
								end
								
								if not currently_spectating then
									ask_for_gpanels("000000")
									ask_for_panels("000000")
								end
								
								to_print = loc("pl_game_start").."\n"..loc("level")..": "..P1.level.."\n"..loc("opponent_level")..": "..P2.level
								if P1.play_to_end or P2.play_to_end then
									to_print = loc("pl_spectate_join")
								end
										
								for i=1,30 do
									gprint(to_print,unpack(main_menu_screen_pos))
									if not do_messages() then
										return main_dumb_transition, {main_select_mode, loc("ss_disconnect").."\n\n"..loc("ss_return"), 60, 300}
									end
									wait()
								end
						
								local game_start_timeout = 0
								
								while P1.panel_buffer == "" or P2.panel_buffer == ""
								or P1.gpanel_buffer == "" or P2.gpanel_buffer == "" do

									game_start_timeout = game_start_timeout + 1
									print("game_start_timeout = "..game_start_timeout)
									print("P1.panel_buffer = "..P1.panel_buffer)
									print("P2.panel_buffer = "..P2.panel_buffer)
									print("P1.gpanel_buffer = "..P1.gpanel_buffer)
									print("P2.gpanel_buffer = "..P2.gpanel_buffer)
									if not do_messages() then
										return main_dumb_transition, {main_select_mode, loc("ss_disconnect").."\n\n"..loc("ss_return"), 60, 300}
									end
									wait()
									if game_start_timeout > 250 then
										return main_dumb_transition, {main_select_mode,
														loc("pl_time_out").."\n"
														.."\n".."msg.match_start = "..(tostring(msg.match_start) or "nil")
														.."\n".."replay_of_match_so_far = "..(tostring(replay_of_match_so_far) or "nil")
														.."\n".."P1.panel_buffer = "..P1.panel_buffer
														.."\n".."P2.panel_buffer = "..P2.panel_buffer
														.."\n".."P1.gpanel_buffer = "..P1.gpanel_buffer
														.."\n".."P2.gpanel_buffer = "..P2.gpanel_buffer,
														180}
									end
									
									love.timer.sleep(0.017)
								end
								
								P1:starting_state()
								P2:starting_state()

								server_queue:pop_all_with("rr_lobby_state") -- all lobby states are stale now
								ret = main_net_vs
							end
						end
					end

				if inNetplay and lobby_state_changed == true then
					send_lobby_state()
					lobby_state_changed = false
				end
			
				wait() 
			end --end main loop		
		
			if global_rr.isSetup then
				if ret == main_select_mode then
					global_rr.isSetup = false
				end

				return main_dumb_transition(ret, "", 0, 0)
			else
				if ret == rr_local_vs then
					global_rr.isSetup = true
				end
				
				return {ret, "", 0, 0}
			end
		end --end round_robin_lobby
		
		-- sigle player local 
		if cursor_data[1].state.ready and select_screen.character_select_mode == "1p_vs_yourself" then
				P1 = Stack(1, "vs", cursor_data[1].state.panels_dir, cursor_data[1].state.level, cursor_data[1].state.character)
				P1.enable_analytics = true
				P1.garbage_target = P1
				make_local_panels(P1, "000000")
				make_local_gpanels(P1, "000000")
				current_stage = cursor_data[1].state.stage
				stage_loader_load(current_stage)
				stage_loader_wait()
				P1:starting_state()
				return main_dumb_transition, {main_local_vs_yourself, "", 0, 0}
			 
			elseif cursor_data[1].state.ready and select_screen.character_select_mode == "2p_local_vs" and cursor_data[2].state.ready then
				P1 = Stack(1, "vs", cursor_data[1].state.panels_dir, cursor_data[1].state.level, cursor_data[1].state.character)
				P1.enable_analytics = true
				P2 = Stack(2, "vs", cursor_data[2].state.panels_dir, cursor_data[2].state.level, cursor_data[2].state.character)
				P1.garbage_target = P2
				P2.garbage_target = P1
				current_stage = cursor_data[math.random(1,2)].state.stage
				stage_loader_load(current_stage)
				stage_loader_wait()
				move_stack(P2,2)
				-- TODO: this does not correctly implement starting configurations.
				-- Starting configurations should be identical for visible blocks, and
				-- they should not be completely flat.
				--
				-- In general the block-generation logic should be the same as the server's, so
				-- maybe there should be only one implementation.
				make_local_panels(P1, "000000")
				make_local_gpanels(P1, "000000")
				make_local_panels(P2, "000000")
				make_local_gpanels(P2, "000000")
				P1:starting_state()
				P2:starting_state()
				return main_dumb_transition, {main_local_vs, "", 0, 0}
			
		-- round robin local mode
		elseif select_screen.character_select_mode == "round_robin" then
			local all_players_ready = true
			
			-- check if every player is in ready state
			for player = 1, global_rr.num_players do
				if (not cursor_data[player].state.ready) then 
					all_players_ready = false 
				end
			end
		 
			-- go to the round robin lobby
			if all_players_ready then  
				return main_dumb_transition, {round_robin_lobby, "", 0, 0}
			end
			
		--2P Netlay
		elseif select_screen.character_select_mode == "2p_net_vs" then
			if not do_messages() then
				return main_dumb_transition, {main_select_mode, loc("ss_disconnect").."\n\n"..loc("ss_return"), 60, 300}
			end

		--rr netplay character select
		elseif cursor_data[1].state.ready and select_screen.character_select_mode == "rr_netplay_char_select" then	
			return	  
		end
  end 
end

return select_screen


