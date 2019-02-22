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


magic_lamp_item = copyPrototype("item","programmable-speaker","magic-lamp")
magic_lamp_entity = copyPrototype("programmable-speaker","programmable-speaker","magic-lamp")

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
})
