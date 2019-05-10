# vrp_vendas

No server.lua do vrp_adv_garages linha 174 mude o local choose para

```lua
local choose = function(player, choice)
    local vname = kitems[choice]
    if vname then
        -- spawn vehicle
        vRP.closeMenu(source)
        local data = vRP.getSData("custom:u"..user_id.."veh_"..vname)
        local custom = json.decode(data)
        if not cooldown[source] then
            local carros = json.decode(vRP.getSData("apreendido:u"..user_id))
            if not carros or not carros[vname] then
                local a_venda = json.decode(vRP.getSData("a_venda:u"..user_id))
                if not a_venda or not a_venda[vname] then
                    cooldown[source] = true
                    if Gclient.spawnGarageVehicle(source,veh_type,vname,pos) then
                        Gclient.setVehicleMods(source,custom)
                    else
                        vRPclient.notify(source,lang.garage.personal.out())
                    end
                else
                    vRPclient.notify(source,"Esse veiculo esta a venda!")
                end
            else
                vRPclient.notify(source,"Seu veiculo foi apreendido, retire-o no pátio do C.E.T")
            end
        end
    end
end
```
