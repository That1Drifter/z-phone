local QBCore = PhoneCore

-- Functions

local function notifyGarage(title, text, color)
    TriggerEvent('qb-phone:client:CustomNotification', title, text, 'fas fa-car', color, 2500)
end

local function trackVehicleByPlate(plate)
    if type(plate) ~= 'string' or plate == '' then
        return false
    end

    if GetResourceState('z-garages') == 'started' then
        local success = pcall(function()
            exports['z-garages']:TrackVehicleByPlate(plate)
        end)

        if success then
            return true
        end
    end

    TriggerEvent('qb-garages:client:TrackVehicleByPlate', plate)
    return true
end

-- NUI Callback

RegisterNUICallback('SetupGarageVehicles', function(_, cb)
    QBCore.Functions.TriggerCallback('qb-phone:server:GetGarageVehicles', function(vehicles)
        cb(vehicles)
    end)
end)

RegisterNUICallback('gps-vehicle-garage', function(data, cb)
    if type(data) ~= 'table' or type(data.veh) ~= 'table' then
        cb("ok")
        return
    end

    local veh = data.veh
    if trackVehicleByPlate(veh.plate) then
        notifyGarage('Garage', 'Your vehicle has been marked', '#2ecc71')
    else
        notifyGarage('Garage', 'This vehicle cannot be located', '#e74c3c')
    end
    cb("ok")
end)

RegisterNUICallback('sellVehicle', function(data, cb)
    if type(data) ~= 'table' then
        cb("ok")
        return
    end

    TriggerServerEvent('qb-phone:server:sendVehicleRequest', data)
    cb("ok")
end)

-- Events

RegisterNetEvent('qb-phone:client:sendVehicleRequest', function(data, sellerCitizenId)
    local success = exports['z-phone']:PhoneNotification("VEHICLE SALE", 'Purchase '..data.plate..' for $'..data.price, 'fas fa-map-pin', '#b3e0f2', "NONE", 'fas fa-check-circle', 'fas fa-times-circle')
    if success then
        TriggerServerEvent("qb-phone:server:sellVehicle", data, sellerCitizenId, 'accepted')
    else
        TriggerServerEvent("qb-phone:server:sellVehicle", data, sellerCitizenId, 'denied')
    end
end)

RegisterNetEvent('qb-phone:client:updateGarages', function()
    SendNUIMessage({
        action = "UpdateGarages",
    })
end)

