local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
local cfg = module("vrp_vendas", "cfg/config")

vRPvd = {}
vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP")
VDclient = Tunnel.getInterface("vrp_vendas")
Gclient = Tunnel.getInterface("vrp_adv_garages")
Tunnel.bindInterface("vrp_vendas",vRPvd)
Proxy.addInterface("vrp_vendas",vRPvd)

-- vRP
vRP._prepare("sRP/vendas",[[
    CREATE TABLE IF NOT EXISTS vrp_vendas(
        id INTEGER AUTO_INCREMENT,
        dono INTEGER,
        dono_nome VARCHAR(255),
        telefone VARCHAR(20),
        modelo VARCHAR(255),
        placa VARCHAR(20),
        preco INTEGER,
        slot INTEGER,
        CONSTRAINT pk_vendas PRIMARY KEY(id)
    )
]])

vRP._prepare("sRP/inserir_venda","INSERT INTO vrp_vendas(dono, dono_nome, telefone, modelo, placa, preco, slot) VALUES(@dono, @dono_nome, @telefone, @modelo, @placa, @preco, @slot)")
vRP._prepare("sRP/get_venda","SELECT * FROM vrp_vendas WHERE dono = @dono")
vRP._prepare("sRP/get_vendas","SELECT * FROM vrp_vendas")
vRP._prepare("sRP/remover_venda","DELETE FROM vrp_vendas WHERE slot = @slot")
vRP._prepare("sRP/mover_veiculo","UPDATE vrp_user_vehicles SET user_id = @tuser_id WHERE user_id = @user_id AND vehicle = @vehicle")
vRP._prepare("sRP/get_dinheiro","SELECT bank FROM vrp_user_moneys WHERE user_id = @user_id")
vRP._prepare("sRP/set_banco","UPDATE vrp_user_moneys SET bank = @bank WHERE user_id = @user_id")

async(function()
    vRP.execute("sRP/vendas")
    vRPvd.carregarVendas()
end)

local vendas = cfg.vendas

local comprador = {}

function updateTable(t1, t2)
    for k,v in pairs(t2) do
      t1[k] = v
    end
end

function vRPvd.carregarVendas()
    local Svendas = vRP.query('sRP/get_vendas')
    for k,v in pairs(Svendas) do
        vendas[v.slot].ocupado = true
        updateTable(vendas[v.slot], v)
    end
end

-- Function para colocar o carro a venda
function vRPvd.colocarVenda(k)
    local source = source
    local user_id = vRP.getUserId(source)
    local identity = vRP.getUserIdentity(user_id)
    local verificar_possui = vRP.query("sRP/get_venda", {dono = user_id})
    if #verificar_possui < cfg.limite_venda then
        local modelo = VDclient.getModel(source)
        local inVehicle = VDclient.IsInVehicle(source)
        local verificar_dono = vRP.query("vRP/get_vehicle", {user_id = user_id, vehicle = modelo})
        if inVehicle == true then
            if #verificar_dono ~= 0 then
                local amount = vRP.prompt(source, "Preço que você quer colocar o veiculo a venda","")
                local amount = parseInt(amount)
                if amount > 0 then
                    local veiculo = {
                        dono = user_id,
                        dono_nome = identity.name .. " " ..identity.firstname,
                        telefone = identity.phone,
                        modelo = modelo,
                        preco = amount,
                        slot = k,
                        placa = identity.registration
                    }
                    vRP.execute("sRP/inserir_venda", veiculo)
                    VDclient.AvisoSucesso(source)
                    vendas[k].ocupado = true
                    updateTable(vendas[k], veiculo)
                    for uid,src in pairs(vRP.getUsers()) do
                        VDclient.setVendas(src, vendas)
                    end
                    -- Seta a venda
                    local a_venda = json.decode(vRP.getSData("a_venda:u"..user_id))
                    if not a_venda then a_venda = {} end
                    a_venda[string.lower(modelo)] = true
                    vRP.setSData("a_venda:u"..user_id, json.encode(a_venda))
                    -- Retira o veiculo do player
                    VDclient.despawnVeiculo(source)
                    -- Spawna ele
                    vRPvd.spawnarCarro(user_id, veiculo)
                    vRPvd.despawnarCarro(user_id, veiculo)
                else
                    VDclient.valorInvalido(source)
                end
            else
                VDclient.naoPertence(source)
            end
        else
            VDclient.estaForaVeiculo(source)
        end
    else
        VDclient.limiteVenda(source)
    end
end

function vRPvd.entrarVenda(k)
    comprador[source] = k
end

function vRPvd.sairVenda(k)
    comprador[source] = nil
end

-- Function para spawnar o carro
function vRPvd.spawnarCarro(user_id, veiculo)
    local source = vRP.getUserSource(user_id)
    local data = vRP.getSData("custom:u"..veiculo.dono.."veh_"..veiculo.modelo)
    local custom = json.decode(data)
    VDclient.spawnVeiculo(source, custom, veiculo)
end

-- Function para despawnar todos os carro
function vRPvd.despawnarCarro(user_id, veiculo)
    local source = vRP.getUserSource(user_id)
    VDclient.despawnAllVeiculo(source, veiculo)
end

-- Comando chat
AddEventHandler('chatMessage', function(source, name, msg)
    sm = stringsplit(msg, " ");
    if type(comprador[source]) ~= 'nil' then
        -- Comprar
        if sm[1] == "/comprar" then
            local k = comprador[source]
            local tuser_id = vRP.getUserId(source)
            local id_dono = vendas[k].dono
            local preco_db = vendas[k].preco
            local modelo_db = vendas[k].modelo
            local online = vRP.getUserSource(id_dono)
            if tuser_id ~= id_dono then
                if vRP.tryPayment(tuser_id, preco_db) then
                    vendas[k].ocupado = false
                    for uid,src in pairs(vRP.getUsers()) do
                        VDclient.setVendas(src, vendas)
                    end
                    vRP.execute('sRP/mover_veiculo', {user_id = id_dono, tuser_id = tuser_id, vehicle = modelo_db})
                    vRP.execute('sRP/remover_venda', {slot = k})
                    local data = vRP.getSData("custom:u"..id_dono.."veh_"..modelo_db)
                    local custom = json.decode(data)
                    vRP.setSData("custom:u"..tuser_id.."veh_"..modelo_db, json.encode(custom))
    			    vRP.setSData("custom:u"..id_dono.."veh_"..modelo_db, json.encode())
                    if online then
                        local banco = vRP.getBankMoney(id_dono)
                        vRP.setBankMoney(id_dono, preco_db+tonumber(banco))
                        vRPclient._notify(online, "~b~[SRP]~w~ Seu veiculo foi vendido!")
                    else
                        local bank =  vRP.scalar('sRP/get_dinheiro', {user_id = id_dono})
                        vRP.execute('sRP/set_banco', {user_id = id_dono, bank = preco_db+tonumber(bank)})
                    end
                    VDclient.despawnVeiculo(source)
                    VDclient.AvisoCompraSucesso(source)
                    local a_venda = json.decode(vRP.getSData("a_venda:u"..id_dono))
                    a_venda[string.lower(modelo_db)] = nil
                    vRP.setSData("a_venda:u"..id_dono, json.encode(a_venda))
                else
                    VDclient.avisoDinheiroInsuficiente(source)
                end
            else
                VDclient.seuVeiculo(source)
            end
            CancelEvent()
        end

        -- Remover
        if sm[1] == "/remover" then
            local k = comprador[source]
            local nuser_id = vRP.getUserId(source)
            local id_dono = vendas[k].dono
            local modelo_db = vendas[k].modelo
            if nuser_id == id_dono then
              vRP.execute("sRP/remover_venda", {slot = k})
              vendas[k].ocupado = false
              for uid,src in pairs(vRP.getUsers()) do
                VDclient.setVendas(src, vendas)
              end
              VDclient.despawnVeiculo(source)
              VDclient.removidoSucesso(source)
              local a_venda = json.decode(vRP.getSData("a_venda:u"..id_dono))
              a_venda[string.lower(modelo_db)] = nil
              vRP.setSData("a_venda:u"..id_dono, json.encode(a_venda))
            else
                VDclient.naoPertence(source)
            end
            CancelEvent()
        end
    end
end)

local spawn_veh = false
AddEventHandler("vRP:playerSpawn", function(user_id, source, first_spawn)
    if user_id then
        spawn_veh = true
        for uid,src in pairs(vRP.getUsers()) do
            VDclient.setVendas(src, vendas)
        end
        if spawn_veh then
            for k,v in pairs(vendas) do
                if v.ocupado then
                    vRPvd.despawnarCarro(user_id, v)
                    SetTimeout(5000, function()
                        vRPvd.spawnarCarro(user_id, v)
                    end)
                end
            end
        end
    end
end)

function stringsplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end