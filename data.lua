local function copyPrototype(type, name, newName)
  if not data.raw[type][name] then error("type "..type.." "..name.." doesn't exist") end
  local p = table.deepcopy(data.raw[type][name])
  p.name = newName
  if p.minable and p.minable.result then
    p.minable.result = newName
  end
  if p.place_result then
    p.place_result = newName
  end
  if p.result then
    p.result = newName
  end
  if p.results then
		for _,result in pairs(p.results) do
			if result.name == name then
				result.name = newName
			end
		end
	end
  return p
end


local magic_lamp_item = copyPrototype("item","constant-combinator","magic-lamp")
local magic_lamp_entity = copyPrototype("constant-combinator","constant-combinator","magic-lamp")


magic_lamp_entity.sprites ={
    layers = {
    {
        scale = 1,
        filename = "__magic-lamp__/graphics/magic-lamp.png",
        width = 42,
        height = 42,
        frame_count = 1,
        shift = util.by_pixel(0, -2.5),
        hr_version =
        {
            scale = 0.5,
            filename = "__magic-lamp__/graphics/hr-magic-lamp.png",
            width = 84,
            height = 84,
            frame_count = 1,
            shift = util.by_pixel(0, -2.5),
        }
    },{
    scale = 1,
    filename = "__magic-lamp__/graphics/magic-lamp-shadow.png",
    width = 50,
    height = 30,
    frame_count = 1,
    draw_as_shadow = true,
    shift = util.by_pixel(10, 4),
    hr_version =
        {
        scale = 0.5,
        filename = "__magic-lamp__/graphics/hr-magic-lamp-shadow.png",
        width = 100,
        height = 60,
        frame_count = 1,
        draw_as_shadow = true,
        shift = util.by_pixel(10, 4),
        }
    },
}}

local connections = magic_lamp_entity.circuit_wire_connection_points
for k, _ in pairs(connections) do
    connections[k] = {
    shadow =
    {
      red = util.by_pixel(7, -8),
      green = util.by_pixel(24, -8)
    },
    wire =
    {
      red = util.by_pixel(-8.5, -19.5),
      green = util.by_pixel(8, -19.5)
    }
  }
end

local icon = "__magic-lamp__/graphics/magic-lamp-icon.png"
magic_lamp_item.icon = icon
magic_lamp_entity.icon = icon
magic_lamp_item.order = "d[other]-aa[magic-lamp]"
magic_lamp_entity.order = "z-d[other]-aa[magic-lamp]"

-- Common tech with Utility Combinators and Optera's Inventory Sensor
if data.raw["technology"]["circuit-network-2"] then
  table.insert( data.raw["technology"]["circuit-network-2"].effects,
    {
        type = "unlock-recipe",
        recipe = "magic-lamp"
    } )
else
  data:extend({
    {
      type = "technology",
      name = "circuit-network-2",
      icon = "__base__/graphics/technology/circuit-network.png",
      icon_size = 128,
      prerequisites = {"circuit-network", "advanced-electronics"},
      effects =
      {
        {
          type = "unlock-recipe",
          recipe = "magic-lamp"
        }
      },
      unit =
      {
        count = 150,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
        },
        time = 30
      },
      order = "a-d-d"
    }
  })
end

data:extend({
  {
    type = "font",
    name = "default-mono",
    from = "default-mono",
    size = 30,
    border = true,
    border_color = {}
  },
  magic_lamp_item,
  magic_lamp_entity,
  {
    type = "recipe",
    name = "magic-lamp",
    enabled = false,
    ingredients =
    {
      {"small-lamp", 1},
      {"electronic-circuit", 1},
    },
    result="magic-lamp",
  },
})
