require("util")
local bit32 = bit32
local pairs = pairs
local ipairs = ipairs

local ml_defines = {
  configmode = {
    numeric = 1,
    iconstrip = 2,
    string = 3,

  },
  iconstrip_endian = {
    lsb_left = 1,
    lsb_right = 2,
  },
  datatype = {
    signed = 1,
    unsigned=2,
    float = 3,
  },
}

script.on_init(function()
  global = {
    --[[
    lamps[unit_number] = {
      entity = entity,
      config = {
        mode = ml_defines.configmode,
        iconstrip = {endian = ml_defines.iconstrip_endian},
        numeric = {
          icons = true,
          names = false,
          signals = {
            {signal=SignalID, type= ml_defines.datatype, hex=false},
          }
        }
      }
      render = {
        icons = {...}
        names = {...}
        values = {...}
        string = { id }
      }
    }
    ]]
    lamps = {

    },
    -- open[player.index] = unit_number
    open = {

    }
  }
end)

script.on_configuration_changed(function()
  local protos = {
    virtual = game.virtual_signal_prototypes,
    item = game.item_prototypes,
    fluid = game.fluid_prototypes,
  }
  for _,lamp in pairs(global.lamps) do
    if lamp.config.numeric and lamp.config.numeric.signals then
      for i,sig in pairs(lamp.config.numeric.signals) do
        if sig.signal and (not protos[sig.signal.type] or not protos[sig.signal.type][sig.signal.name]) then
          sig.signal = nil
        end
      end
    end
  end
end)

local function float_from_int(i)
  local sign = bit32.btest(i,0x80000000) and -1 or 1
  local exponent = bit32.rshift(bit32.band(i,0x7F800000),23)-127
  local significand = bit32.band(i,0x007FFFFF)

  if exponent == 128 then
    if significand == 0 then
      return sign/0 --[[infinity]]
    else
      return 0/0 --[[nan]]
    end
  end

  if exponent == -127 then
    if significand == 0 then
      return sign * 0 --[[zero]]
    else
      return sign * math.ldexp(significand,-149) --[[denormal numbers]]
    end
  end

  return sign * math.ldexp(bit32.bor(significand,0x00800000),exponent-23) --[[normal numbers]]
end

local function get_signals_filtered(filters,entity)
  --   filters = {
  --  SignalID,
  --  ...
  --  }
  local results = {}
  local get_signal = entity.get_merged_signal
  for i,f in pairs(filters) do
    results[i] = get_signal(f)
  end
  return results
end

local function get_signal_bit_set(set)
  local band,extract,replace = bit32.band,bit32.extract,bit32.replace
  local sigbits = {}
  local bitsleft = -1
  for _,sig in ipairs(set) do
    local newbits = band(sig.count,bitsleft)
    if newbits ~= 0 then
      for i=0,31 do
        local sigbit = extract(newbits,i)
        if sigbit==1 then
          sigbits[i+1] = sig.signal
          bitsleft = replace(bitsleft,0,i)
          if bitsleft == 0 then
            return sigbits
          end
        end
      end
    end
  end
  return sigbits
end

local function on_tick_numeric_lamp(lamp)
  local sigconfig = lamp.config.numeric.signals
  local filters = {}
  for i = 1,4 do
    local sigconfigi = sigconfig[i]
    if sigconfigi and sigconfigi.signal then
      filters[i] = sigconfigi.signal
    end
  end

  local filteredsignals = get_signals_filtered(filters, lamp.entity)

  for i=1,4 do
    local sigconfigi = sigconfig[i]
    if sigconfigi and sigconfigi.signal then
      local value = filteredsignals[i] or 0

      if sigconfigi.lastvalue ~= value then
        sigconfigi.lastvalue = value
        local hex = sigconfigi.hex
        local type = sigconfigi.type
        local format = hex and "0x%08x" or "%i"
        if type == ml_defines.datatype.signed and hex and value < 0 then
          -- negative hex
          value = -value
          format = "-0x%08x"

        elseif type == ml_defines.datatype.unsigned then
          --unsigned.
          format = hex and "0x%08x" or "%u"
          -- negative values get sign extended to 64bit by default, so fold it around ourselves...
          if value < 0 then value = value + 0x100000000 end

        elseif type == ml_defines.datatype.float then
          -- float. convert...
          value = float_from_int(value)
          format = hex and "%a" or "%g"
        end


        if lamp.render.values[i] and rendering.is_valid(lamp.render.values[i]) then
          rendering.set_text(lamp.render.values[i], format:format(value))
        else
          lamp.render.values[i] = rendering.draw_text{
            text= format:format(value),
            surface = lamp.entity.surface,
            target = lamp.entity,
            target_offset = { -0.5, -0.6 + i},
            color = {r=1,g=1,b=1, a=0.8},
            alignment = "right",
            font = "default-mono"
          }
        end

        if lamp.config.numeric.icons then
          local type = sigconfig[i].signal.type
          if type == "virtual" then type = "virtual-signal" end
          if lamp.render.icons[i] and rendering.is_valid(lamp.render.icons[i]) then
            rendering.set_sprite(lamp.render.icons[i], type .. "/" .. sigconfigi.signal.name)
          else
            lamp.render.icons[i] = rendering.draw_sprite{
              sprite = type .. "/" .. sigconfigi.signal.name,
              surface = lamp.entity.surface,
              target = lamp.entity,
              target_offset = { 0, i},
              tint = {r=1,g=1,b=1, a=0.6},
            }
          end
        else
          if lamp.render.icons[i] and rendering.is_valid(lamp.render.icons[i]) then
            rendering.destroy(lamp.render.icons[i])
            lamp.render.icons[i] = nil
          end
        end

        if lamp.config.numeric.names then
          local protos = {
            ["virtual"] = game.virtual_signal_prototypes,
            ["item"] = game.item_prototypes,
            ["fluid"] = game.fluid_prototypes
          }
          local name = protos[sigconfig[i].signal.type][sigconfig[i].signal.name].localised_name

          if lamp.render.names[i] and rendering.is_valid(lamp.render.names[i]) then
            rendering.set_text(lamp.render.names[i], name)
          else
            lamp.render.names[i] = rendering.draw_text{
              text= name,
              surface = lamp.entity.surface,
              target = lamp.entity,
              target_offset = { 0.5, -0.6 + i},
              color = {r=1,g=1,b=1, a=0.8},
              alignment = "left",
              font = "default-mono"
            }
          end
        else
          if lamp.render.names[i] and rendering.is_valid(lamp.render.names[i]) then
            rendering.destroy(lamp.render.names[i])
            lamp.render.names[i] = nil
          end
        end
      end
      --sigconfig[i] = {signal = nil, unsigned=false, hex=false, float=false
    else
      if lamp.render.names[i] and rendering.is_valid(lamp.render.names[i]) then
        rendering.destroy(lamp.render.names[i])
        lamp.render.names[i] = nil
      end
      if lamp.render.icons[i] and rendering.is_valid(lamp.render.icons[i]) then
        rendering.destroy(lamp.render.icons[i])
        lamp.render.icons[i] = nil
      end
      if lamp.render.values[i] and rendering.is_valid(lamp.render.values[i]) then
        rendering.destroy(lamp.render.values[i])
        lamp.render.values[i] = nil
      end
    end
  end
end

local function on_tick_iconstrip_lamp(lamp)
  local signals = lamp.entity.get_merged_signals() or {}
  local bits = get_signal_bit_set(signals)
  for i=1,32 do
    if bits[i] then
      local type = bits[i].type
      if type == "virtual" then type = "virtual-signal" end
      if lamp.render.iconstrip[i] and rendering.is_valid(lamp.render.iconstrip[i]) then
        rendering.set_sprite(lamp.render.iconstrip[i], type .. "/" .. bits[i].name)
      else
        local pos = {0,1}
        if lamp.config.iconstrip.endian == ml_defines.iconstrip_endian.lsb_left then
          pos[1] =  -16 + i
        else
          pos[1] =  16 - i
        end
        lamp.render.iconstrip[i] = rendering.draw_sprite{
          sprite = type .. "/" .. bits[i].name,
          surface = lamp.entity.surface,
          target = lamp.entity,
          target_offset = pos,
          tint = {r=1,g=1,b=1, a=0.6},
        }
      end
    else
      if lamp.render.iconstrip[i] and rendering.is_valid(lamp.render.iconstrip[i]) then
        rendering.destroy(lamp.render.iconstrip[i])
        lamp.render.iconstrip[i] = nil
      end
    end
  end
end


--[[
| bits | U+first   | U+last     | bytes | Byte_1   | Byte_2   | Byte_3   | Byte_4   |
+------+-----------+------------+-------+----------+----------+----------+----------+
|   7  | U+0000    | U+007F     |   1   | 0xxxxxxx |          |          |          |
|  11  | U+0080    | U+07FF     |   2   | 110xxxxx | 10xxxxxx |          |          |
|  16  | U+0800    | U+FFFF     |   3   | 1110xxxx | 10xxxxxx | 10xxxxxx |          |
|  21  | U+10000   | U+1FFFFF   |   4   | 11110xxx | 10xxxxxx | 10xxxxxx | 10xxxxxx |
+------+-----------+------------+-------+----------+----------+----------+----------+
--]]
-- convert an int to a string containing the encoded value
local function IntToUtf8(val)
    --[[make everythign unsigned values...]]
    if val < 0 then val = val + 0x100000000 end

    -- emptystring for invalid characters
    if val > 0x10FFFF or (val > 0xD800 and val < 0xDFFF) then return "" end

    local prefix, firstmask, startshift

    if val < 0x80 then
        --[[1 byte]]
        return string.char(val)
    elseif val < 0x0800 then
        --[[2 bytes]]
        prefix = 0xc0
        firstmask = 0x1f
        startshift = 6
    elseif val < 0x10000 then
        --[[3 bytes]]
        prefix = 0xe0
        firstmask = 0x0f
        startshift = 12
    else
        --[[4 bytes]]
        prefix = 0xf0
        firstmask = 0x07
        startshift = 18
    end

    local s = {}
    table.insert(s, string.char(bit32.bor(prefix, bit32.band(bit32.rshift(val,startshift),firstmask))))
    for shift=startshift-6,0,-6 do
        table.insert(s, string.char(bit32.bor(0x80, bit32.band(bit32.rshift(val,shift),0x3f))))
    end
    return table.concat(s)
end

local function write_config_to_cc(entity)
  local config = global.lamps[entity.unit_number].config
  local control = entity.get_or_create_control_behavior()

  local frame = {}
  frame[1] = {index = #frame+1, signal = {type="virtual", name="signal-dot"}, count = config.mode }
  if config.mode == ml_defines.configmode.numeric then
    if config.numeric then
      if config.numeric.icons then
        frame[1].count = frame[1].count + 0x40000000
      end
      if config.numeric.names then
        frame[1].count = frame[1].count + 0x20000000
      end
      if config.numeric.signals then
        for i=1,4 do
          if config.numeric.signals[i] then
            local count = config.numeric.signals[i].type
            if config.numeric.signals[i].hex then
              count = count + 0x40000000
            end
            frame[i+1] = {index = #frame+1, signal = config.numeric.signals[i].signal, count = count }
          else
            frame[i+1] = {index = #frame+1, signal = nil, count = 0 }
          end
        end
      end
    end
  elseif config.mode == ml_defines.configmode.iconstrip then
    if config.iconstrip then
      if config.iconstrip.endian == ml_defines.iconstrip_endian.lsb_right then
        frame[1].count = frame[1].count + 0x40000000
      end
    end
  end

  control.enabled = false
  control.parameters = frame

end

local function read_config_from_cc(entity)
  local config = global.lamps[entity.unit_number].config
  local control = entity.get_or_create_control_behavior()

  if not control.enabled then
    local frame = control.parameters

    if frame[1].signal.type == "virtual" and frame[1].signal.name == "signal-dot" then
      local mode = frame[1].count % 0x100
      if mode == ml_defines.configmode.numeric then
        config.mode = ml_defines.configmode.numeric
        config.numeric.icons = (bit32.band(frame[1].count, 0x40000000) ~= 0)
        config.numeric.names = (bit32.band(frame[1].count, 0x20000000) ~= 0)
        for i=1,4 do
          if frame[i+1].signal.name then
            config.numeric.signals[i].lastvalue = nil
            config.numeric.signals[i].signal = frame[i+1].signal
            config.numeric.signals[i].type = frame[i+1].count % 0x100
            if config.numeric.signals[i].type > ml_defines.datatype.float or config.numeric.signals[i].type < ml_defines.datatype.signed then
              config.numeric.signals[i].type = ml_defines.datatype.signed
            end
            config.numeric.signals[i].hex = (bit32.band(frame[i+1].count, 0x40000000) ~= 0)
          end
        end
      elseif mode == ml_defines.configmode.iconstrip then
        if bit32.band(frame[1].count, 0x40000000) ~= 0 then
          config.iconstrip.endian = ml_defines.iconstrip_endian.lsb_right
        else
          config.iconstrip.endian = ml_defines.iconstrip_endian.lsb_left
        end
      end
    end
  end
  -- and write it back in case any of it was invalid...
  write_config_to_cc(entity)
end

local function on_tick_string_lamp(lamp)
  local signals = lamp.entity.get_merged_signals() or {}
  local message = {}
  for _,sig in pairs(signals) do
    message[#message+1] = IntToUtf8(sig.count)
  end

  local newstring = table.concat(message)
  if lamp.laststring == nil or lamp.laststring ~= newstring then
    lamp.laststring = newstring
    -- render.string is a table to make reset logic happy. makes it easy to split long strings to multiple lines in the future too...
    if lamp.render.string[1] and rendering.is_valid(lamp.render.string[1]) then
      rendering.set_text(lamp.render.string[1], newstring)
    else
      lamp.render.string[1] = rendering.draw_text{
        text = {"", newstring},
        surface = lamp.entity.surface,
        target = lamp.entity,
        target_offset = {0,0.6},
        color = {r=1,g=1,b=1, a=0.6},
        alignment = "center",
        font = "default-mono"
      }
    end
  end
end

local lamp_handlers = {
  [ml_defines.configmode.numeric] = on_tick_numeric_lamp,
  [ml_defines.configmode.iconstrip] = on_tick_iconstrip_lamp,
  [ml_defines.configmode.string] = on_tick_string_lamp,
}

local function on_tick_lamp(lamp)
  local f = lamp_handlers[lamp.config.mode]
  if f then 
    f(lamp)
  end
end


script.on_event(defines.events.on_tick, function()
  if global.next_lamp and not global.lamps[global.next_lamp] then
    global.next_lamp=nil
  end
  for _=1, settings.global["magic-lamp-updates-per-tick"].value do
    local lamp
    global.next_lamp,lamp = next(global.lamps,global.next_lamp)

    if lamp then
      if lamp.entity.valid then
        on_tick_lamp(lamp)
      else
        global.lamps[global.next_lamp] = nil
        global.next_lamp = nil
      end
    else
      return
    end
  end
end)

local function create_iconstrip_frame(flow,stripconfig)
  local frame = flow.add{
      type = 'frame',
      name = "iconstrip_frame",
      caption = {"magic-lamp.iconstrip"},
      direction = 'vertical',
  }

  frame.add{
    type='drop-down',
    name='magic_lamp.endian',
    items = {
      {"magic-lamp.lsb-left"},
      {"magic-lamp.lsb-right"},
    },
    selected_index = stripconfig and stripconfig.endian or ml_defines.iconstrip_endian.lsb_left
  }
end


local function create_signal_frame(numframe,sigconfig,i)

  if not sigconfig then
    sigconfig = { type = ml_defines.datatype.signed, hex = false }
  end

  local sigframe = numframe.add{
      type = 'frame',
      name = i,
      direction = 'horizontal',
  }

  sigframe.add{
    type = 'choose-elem-button',
    name = 'magic_lamp.signal',
    elem_type = 'signal',
    signal = sigconfig and sigconfig.signal,
  }

  sigframe.add{
    type='drop-down',
    name='magic_lamp.datatype',
    items = {
      {"magic-lamp.datatype-signed"},
      {"magic-lamp.datatype-unsigned"},
      {"magic-lamp.datatype-float"},
    },
    selected_index = sigconfig and sigconfig.type or ml_defines.datatype.signed
  }

  sigframe.add{
    type = 'checkbox',
    name = 'magic_lamp.hex',
    caption = {"magic-lamp.hex"},
    state = sigconfig and sigconfig.hex,
  }
end

local function create_numeric_frame(flow,numconfig)
  local numframe = flow.add{
      type = 'frame',
      name = "numeric_frame",
      caption = {"magic-lamp.numeric"},
      direction = 'vertical',
  }

  numframe.add{
    type = 'checkbox',
    name = 'magic_lamp.icons',
    caption = {"magic-lamp.icons"},
    state = numconfig and numconfig.icons,
  }

  numframe.add{
    type = 'checkbox',
    name = 'magic_lamp.names',
    caption = {"magic-lamp.names"},
    state = numconfig and numconfig.names,
  }

  for i=1,4 do
    local sigconfig = numconfig and numconfig.signals and numconfig.signals[i]
    create_signal_frame(numframe,sigconfig,i)
  end
end

local function create_lamp_gui(entity,player,at_position)
  local config = global.lamps[entity.unit_number].config

  local flow = player.gui.screen.add{
      type = 'frame',
      name = "magic_lamp",
      caption = {"entity-name.magic-lamp"},
      direction = 'vertical',
  }

  local modeframe = flow.add{
      type = 'frame',
      name = "mode_frame",
      caption = {"magic-lamp.mode"},
      direction = 'vertical',
  }

  local mode = config.mode or ml_defines.configmode.numeric
  modeframe.add{
    type='drop-down',
    name='magic_lamp.mode',
    items = {
      {"magic-lamp.mode-numeric"},
      {"magic-lamp.mode-iconstrip"}, -- bitmask icon strip
      {"magic-lamp.mode-string"} -- string mode, utf32 strings on signals in prototype order
    },
    selected_index = mode
  }

  if mode==ml_defines.configmode.numeric then
    create_numeric_frame(flow,config.numeric)
  elseif mode==ml_defines.configmode.iconstrip then
    create_iconstrip_frame(flow,config.iconstrip)
  -- no extra config in string mode
  --elseif mode==ml_defines.configmode.string then
  --  create_string_frame(flow,config.string)
  end

  if at_position then
    flow.location = at_position
  else
    flow.force_auto_center()
  end
  return flow
end

local function reload_gui_after_change(entity,player)
  write_config_to_cc(entity)
  local at_location = player.opened.location
  player.opened.destroy()
  player.opened = create_lamp_gui(entity,player,at_location)
end

script.on_event(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  local player = game.players[event.player_index]
  if event.gui_type == defines.gui_type.entity and entity and entity.name == "magic-lamp" then
    global.open[player.index] = entity.unit_number
    player.opened = create_lamp_gui(entity,player)
  end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local player = game.players[event.player_index]
  if event.element.name == "magic_lamp.mode" then
    local lamp = global.lamps[global.open[player.index]]
    lamp.config.mode = event.element.selected_index
    reload_gui_after_change(lamp.entity,player)
    -- destroy all sprites to force re-render
    for _,t in pairs(lamp.render) do
      for i,id in pairs(t) do
        if rendering.is_valid(id) then
          rendering.destroy(id)
        end
      end
    end
    lamp.render = {
      icons = {},
      names = {},
      values = {},
      iconstrip = {},
      string = {},
    }
    if lamp.config.mode == ml_defines.configmode.numeric then
       for _,sig in pairs(lamp.config.numeric.signals) do
         sig.lastvalue = nil
       end
    end
    lamp.config.laststring = nil

  elseif event.element.name == "magic_lamp.endian" then
    local lamp = global.lamps[global.open[player.index]]
    lamp.config.iconstrip.endian = event.element.selected_index
    reload_gui_after_change(lamp.entity,player)
    -- destroy iconstrip sprites to force re-render
    for i,id in pairs(lamp.render.iconstrip) do
      if rendering.is_valid(id) then
        rendering.destroy(id)
      end
      lamp.render.names[i] = nil
    end
  elseif event.element.name == "magic_lamp.datatype" then
    local lamp = global.lamps[global.open[player.index]]
    local i = tonumber(event.element.parent.name)
    lamp.config.numeric.signals[i].type = event.element.selected_index
    lamp.config.numeric.signals[i].lastvalue = nil
    reload_gui_after_change(lamp.entity,player)
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local player = game.players[event.player_index]
  if event.element.name == "magic_lamp.icons" then
    local lamp = global.lamps[global.open[player.index]]
    lamp.config.numeric.icons = event.element.state
    reload_gui_after_change(lamp.entity,player)
    for _,sig in pairs(lamp.config.numeric.signals) do
      sig.lastvalue = nil
    end
  elseif event.element.name == "magic_lamp.names" then
    local lamp = global.lamps[global.open[player.index]]
    lamp.config.numeric.names = event.element.state
    reload_gui_after_change(lamp.entity,player)
    for _,sig in pairs(lamp.config.numeric.signals) do
      sig.lastvalue = nil
    end
  elseif event.element.name == "magic_lamp.hex" then
    local lamp = global.lamps[global.open[player.index]]
    local i = tonumber(event.element.parent.name)
    if not lamp.config.numeric.signals then lamp.config.numeric.signals = {} end
    local sigconfig = lamp.config.numeric.signals
    if not sigconfig[i] then
      sigconfig[i] = {
        signal = nil, unsigned=false, hex=false, float=false
      }
    end
    sigconfig[i].hex = event.element.state
    sigconfig[i].lastvalue = nil
    reload_gui_after_change(lamp.entity,player)
  end
end)

local disallowed_signals = {["signal-each"]=true,["signal-anything"]=true,["signal-everything"]=true,}
script.on_event(defines.events.on_gui_elem_changed, function(event)
  local player = game.players[event.player_index]
  if event.element.name == "magic_lamp.signal" then
    local lamp = global.lamps[global.open[player.index]]
    local i = tonumber(event.element.parent.name)
    if not lamp.config.numeric.signals then lamp.config.numeric.signals = {} end
    local sigconfig = lamp.config.numeric.signals
    if not sigconfig[i] then
      sigconfig[i] = {
        signal = nil, unsigned=false, hex=false, float=false
      }
    end
    local signal = event.element.elem_value
    if signal and signal.type == "virtual" and disallowed_signals[signal.name] then
      signal = nil
    end
    sigconfig[i].signal = signal
    sigconfig[i].lastvalue = nil
    reload_gui_after_change(lamp.entity,player)
  end
end)


script.on_event(defines.events.on_gui_closed, function(event)
  local player = game.get_player(event.player_index)
  local frame = event.element
  if event.gui_type == defines.gui_type.custom and frame and frame.valid and frame.name == "magic_lamp" then
    global.open[player.index] = nil
    frame.destroy()
  end
end)

local function strip_and_validate_config(config)
  local protos = {
    virtual = game.virtual_signal_prototypes,
    item = game.item_prototypes,
    fluid = game.fluid_prototypes,
  }

  if not config.mode then
    config.mode = ml_defines.configmode.numeric
  end
  if not config.iconstrip then
    config.iconstrip = {endian = ml_defines.iconstrip_endian.lsb_left, numeric=true}
  end

  if not config.numeric then
    config.numeric = {
      icons = true,
      names = false,
      signals = {
        {type=ml_defines.datatype.signed, hex=false},
        {type=ml_defines.datatype.signed, hex=false},
        {type=ml_defines.datatype.signed, hex=false},
        {type=ml_defines.datatype.signed, hex=false},
      },
    }
  elseif not config.numeric.signals then
    config.numeric.signals = {
      {type=ml_defines.datatype.signed, hex=false},
      {type=ml_defines.datatype.signed, hex=false},
      {type=ml_defines.datatype.signed, hex=false},
      {type=ml_defines.datatype.signed, hex=false},
    }
  else
    for _,sig in pairs(config.numeric.signals) do
      -- strip cached values
      sig.lastvalue = nil
      -- validate signal type
      if sig.signal and (not protos[sig.signal.type] or not protos[sig.signal.type][sig.signal.name]) then
        sig.signal = nil
      end
    end
  end
end

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  if event.destination.name== "magic-lamp" then
    if event.source.name == "magic-lamp" then
      -- transfer config
      local config = table.deepcopy(global.lamps[event.source.unit_number].config)
      strip_and_validate_config(config)
      global.lamps[event.destination.unit_number].config = config
    end
    -- ensure CC is correct after paste
    write_config_to_cc(event.destination)
  end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
  local player = game.get_player(event.player_index)
  local mapping = event.mapping.get()
  local blueprint = player.blueprint_to_setup
  if not blueprint.valid_for_read then
    blueprint = player.cursor_stack
    if not blueprint.valid_for_read then
      return
    end
  end
  local bpentities = blueprint.get_blueprint_entities()
  if bpentities then
    for i,bpent in pairs(bpentities) do
      if bpent.name == "magic-lamp" and mapping[i] and mapping[i].name == "magic-lamp" then
        local config = table.deepcopy(global.lamps[mapping[i].unit_number].config)
        strip_and_validate_config(config)
        local tag = {
          version = 1,
          config = config
        }
        blueprint.set_blueprint_entity_tag(i,"magic-lamp",tag)
      end
    end
  end
end)


local function on_built_entity(entity,cloned_from,tags)
  if entity.name == "magic-lamp" then
    global.lamps[entity.unit_number] = {
      entity = entity,
      config = {
        mode = ml_defines.configmode.numeric,
        iconstrip = {endian = ml_defines.iconstrip_endian.lsb_left, numeric=true},
        numeric = {
          icons = true,
          names = false,
          signals = {
            {type=ml_defines.datatype.signed, hex=false},
            {type=ml_defines.datatype.signed, hex=false},
            {type=ml_defines.datatype.signed, hex=false},
            {type=ml_defines.datatype.signed, hex=false},
          },
        },
      },
      render = {
        icons = {},
        names = {},
        values = {},
        iconstrip = {},
        string = {},
      }
    }
    if cloned_from then
      global.lamps[entity.unit_number].config = table.deepcopy(global.lamps[cloned_from.unit_number].config)
      return
    end
    if tags then
      local mltag = tags["magic-lamp"]
      if mltag then
        if mltag.version == 1 then
          local config = mltag.config
          strip_and_validate_config(config)
          global.lamps[entity.unit_number].config = config
          write_config_to_cc(entity)
          return
        else
          -- invalid version in print? ignore it until there's migration to do...
        end
      end
    end
    --read config from CC if valid, clear if not
    read_config_from_cc(entity)
  end
end

local function cleanup_lamp(unit_number)
  if global.lamps[unit_number] == nil then
    return
  end

  global.lamps[unit_number] = nil
  if global.next_lamp == unit_number then
    global.next_lamp = nil
  end
  for i,player in pairs(game.players) do
    if global.open[player.index] == unit_number then
      player.opened.destroy()
    end
  end
end

local function on_destroying_entity(entity)
  cleanup_lamp(entity.unit_number)
end

local function on_post_entity_died(ghost,unit_number)
  if ghost ~= nil and ghost.ghost_name == "magic-lamp" then
    local tags = ghost.tags or {}
    tags["magic-lamp"] = {
      version = 1,
      config = global.lamps[unit_number].config
    }
    ghost.tags = tags
  end
  cleanup_lamp(unit_number)
end

local filters = {
  {filter="name",name="magic-lamp"},
}

script.on_event(defines.events.on_built_entity, function(event) on_built_entity(event.created_entity,nil,event.tags) end, filters)
script.on_event(defines.events.on_robot_built_entity, function(event) on_built_entity(event.created_entity,nil,event.tags) end, filters)
script.on_event(defines.events.script_raised_built, function(event) on_built_entity(event.entity,nil,event.tags) end, filters)
script.on_event(defines.events.script_raised_revive, function(event) on_built_entity(event.entity,nil,event.tags) end, filters)

script.on_event(defines.events.on_entity_cloned, function(event) on_built_entity(event.destination,event.source) end, filters)

script.on_event(defines.events.on_pre_player_mined_item, function(event) on_destroying_entity(event.entity) end, filters)
script.on_event(defines.events.on_robot_pre_mined, function(event) on_destroying_entity(event.entity) end, filters)
script.on_event(defines.events.script_raised_destroy, function(event) on_destroying_entity(event.entity) end, filters)

script.on_event(defines.events.on_post_entity_died, function(event) on_post_entity_died(event.ghost,event.unit_number) end,
{{filter="type",type="constant-combinator"}})


script.on_event(defines.events.on_pre_chunk_deleted, function(event)
  for _,chunk in pairs(event.positions) do
    local x = chunk.x
    local y = chunk.y
    local area = {{x*32,y*32},{31+x*32,31+y*32}}
    for _,ent in pairs(game.get_surface(event.surface_index).find_entities_filtered{name = "magic-lamp",area = area}) do
      on_destroying_entity(ent)
    end
  end
end)
script.on_event(defines.events.on_pre_surface_cleared,function (event)
  for _,ent in pairs(game.get_surface(event.surface_index).find_entities_filtered{name = "magic-lamp"}) do
    on_destroying_entity(ent)
  end
end)
script.on_event(defines.events.on_pre_surface_deleted,function (event)
  for _,ent in pairs(game.get_surface(event.surface_index).find_entities_filtered{name = "magic-lamp"}) do
    on_destroying_entity(ent)
  end
end)