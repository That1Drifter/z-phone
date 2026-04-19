PhoneBridge = PhoneBridge or {}

local function getModeValue(value)
    if type(value) ~= 'string' then
        return 'auto'
    end

    return value:lower()
end

local function detectFramework(mode)
    if mode == 'qb' then
        return 'qb'
    end

    if mode == 'qbox' then
        return 'qbox'
    end

    if GetResourceState('qbx_core') == 'started' then
        return 'qbox'
    end

    return 'qb'
end

local function detectInventory(mode)
    if mode == 'qb' then
        return 'qb'
    end

    if mode == 'ox' then
        return 'ox'
    end

    if GetResourceState('ox_inventory') == 'started' then
        return 'ox'
    end

    return 'qb'
end

local function detectTarget(mode)
    if mode == 'qb' then
        return 'qb'
    end

    if mode == 'ox' then
        return 'ox'
    end

    if GetResourceState('ox_target') == 'started' then
        return 'ox'
    end

    return 'qb'
end

local function getQBCoreObject()
    if GetResourceState('qb-core') ~= 'started' and GetResourceState('qbx_core') ~= 'started' then
        error('[z-phone] qb-core/qbx_core is required but not started.')
    end

    local ok, coreObject = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if ok and coreObject then
        return coreObject
    end

    if GetResourceState('qbx_core') == 'started' then
        error('[z-phone] qbx_core is running but qb bridge export is unavailable. Enable qbx qb-bridge (qbx:enablebridge true).')
    end

    error('[z-phone] Unable to acquire core object from qb-core export.')
end

PhoneBridge.FrameworkMode = detectFramework(getModeValue(Config.Framework))
PhoneBridge.InventoryMode = detectInventory(getModeValue(Config.Inventory))
PhoneBridge.TargetMode = detectTarget(getModeValue(Config.Target))
PhoneBridge.Core = getQBCoreObject()
PhoneCore = PhoneBridge.Core

function PhoneBridge.GetCore()
    return PhoneBridge.Core
end

function PhoneBridge.IsQbox()
    return PhoneBridge.FrameworkMode == 'qbox'
end

function PhoneBridge.HasItem(itemName)
    if IsDuplicityVersion() then
        return false
    end

    if type(itemName) ~= 'string' or itemName == '' then
        return false
    end

    if PhoneBridge.InventoryMode == 'ox' and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:Search('count', itemName)
        return (tonumber(count) or 0) > 0
    end

    return PhoneBridge.Core.Functions.HasItem(itemName)
end

function PhoneBridge.PlayerHasItem(playerObj, itemName)
    if not playerObj or type(itemName) ~= 'string' or itemName == '' then
        return false
    end

    if PhoneBridge.InventoryMode == 'ox' and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(playerObj.PlayerData.source, itemName)
        return (tonumber(count) or 0) > 0
    end

    return playerObj.Functions.GetItemByName(itemName) ~= nil
end

function PhoneBridge.NotifyClient(message, notifyType)
    if IsDuplicityVersion() then
        return
    end

    if lib and lib.notify then
        local notifyMap = {
            primary = 'inform',
            success = 'success',
            error = 'error',
            warning = 'warning',
            info = 'inform'
        }

        lib.notify({
            description = tostring(message or ''),
            type = notifyMap[notifyType] or 'inform'
        })
        return
    end

    PhoneBridge.Core.Functions.Notify(message, notifyType or 'primary')
end

function PhoneBridge.NotifyServer(target, message, notifyType)
    if not IsDuplicityVersion() then
        return
    end

    if PhoneBridge.IsQbox() and GetResourceState('qbx_core') == 'started' then
        local notifyMap = {
            primary = 'inform',
            success = 'success',
            error = 'error',
            warning = 'warning',
            info = 'inform'
        }

        exports.qbx_core:Notify(target, message, notifyMap[notifyType] or 'inform')
        return
    end

    TriggerClientEvent('QBCore:Notify', target, message, notifyType or 'primary')
end

function PhoneBridge.RegisterPublicPhoneTargets(models, eventName)
    if type(models) ~= 'table' or #models == 0 then
        return
    end

    if PhoneBridge.TargetMode == 'ox' and GetResourceState('ox_target') == 'started' then
        exports.ox_target:addModel(models, {
            {
                name = 'z_phone_public_phone',
                icon = 'fas fa-phone-volume',
                label = 'Public Phone',
                onSelect = function()
                    TriggerEvent(eventName)
                end,
                distance = 1.0
            }
        })

        return
    end

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetModel(models, {
            options = {
                {
                    type = 'client',
                    event = eventName,
                    icon = 'fas fa-phone-volume',
                    label = 'Public Phone',
                },
            },
            distance = 1.0
        })
    end
end
