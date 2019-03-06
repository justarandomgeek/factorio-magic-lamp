function copyPrototype(type, name, newName)
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


magic_lamp_item = copyPrototype("item","constant-combinator","magic-lamp")
magic_lamp_entity = copyPrototype("constant-combinator","constant-combinator","magic-lamp")

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
