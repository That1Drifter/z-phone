local QBCore = exports['qb-core']:GetCoreObject()
local ActionCooldowns = {
    transfer = {},
    payInvoice = {},
    declineInvoice = {},
}

local function isRateLimited(cache, key, durationMs)
    local now = GetGameTimer()
    local lastTick = cache[key] or 0

    if (now - lastTick) < durationMs then
        return true
    end

    cache[key] = now
    return false
end

local function normalizeAmount(value)
    local amount = math.floor(tonumber(value) or 0)
    if amount < 1 then
        return nil
    end

    return amount
end

local function normalizeBankAccount(value)
    if type(value) ~= 'string' then
        return nil
    end

    local account = value:upper():gsub('%s+', ''):gsub('[^%w%-]', '')
    if account == '' or #account > 32 then
        return nil
    end

    return account
end

local function normalizeReference(value)
    if type(value) ~= 'string' then
        return ''
    end

    local reference = value:gsub('[%c\r\n]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return reference:sub(1, 60)
end

local function buildTransferReason(prefix, account, reference)
    if reference ~= '' then
        return ("%s #%s (%s)"):format(prefix, account, reference)
    end

    return ("%s #%s"):format(prefix, account)
end

local function getInvoicesForCitizenId(citizenId)
    if not citizenId or citizenId == '' then
        return {}
    end

    return MySQL.query.await('SELECT * FROM phone_invoices WHERE citizenid = ? ORDER BY id DESC', {citizenId}) or {}
end

local function findInvoiceForPlayer(player, invoiceId)
    local normalizedInvoiceId = tonumber(invoiceId)
    if not player or not normalizedInvoiceId then
        return nil
    end

    local result = MySQL.query.await('SELECT * FROM phone_invoices WHERE id = ? AND citizenid = ? LIMIT 1', {
        normalizedInvoiceId,
        player.PlayerData.citizenid
    }) or {}

    return result[1]
end

local function removeInvoiceForPlayer(player, invoiceId)
    local normalizedInvoiceId = tonumber(invoiceId)
    if not player or not normalizedInvoiceId then
        return 0
    end

    return MySQL.update.await('DELETE FROM phone_invoices WHERE id = ? AND citizenid = ?', {
        normalizedInvoiceId,
        player.PlayerData.citizenid
    }) or 0
end

local function createInvoiceForPlayer(billedPlayer, billerPlayer, amount)
    if not billedPlayer or not billerPlayer or not amount then
        return nil
    end

    local billerName = ("%s %s"):format(
        billerPlayer.PlayerData.charinfo.firstname,
        billerPlayer.PlayerData.charinfo.lastname
    )
    local society = tostring((billerPlayer.PlayerData.job and billerPlayer.PlayerData.job.name) or 'invoice')
    local reason = tostring(billerPlayer.PlayerData.job and billerPlayer.PlayerData.job.label or 'Invoice')

    return MySQL.insert.await(
        'INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid, time, reason, account_name, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            billedPlayer.PlayerData.citizenid,
            amount,
            society,
            billerName,
            billerPlayer.PlayerData.citizenid,
            os.time(),
            reason,
            'checking',
            'pending'
        }
    )
end

local function payInvoiceForPlayer(source, invoiceId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return {
            success = false,
            message = 'Player not found.'
        }
    end

    local invoice = findInvoiceForPlayer(Player, invoiceId)
    if not invoice then
        return {
            success = false,
            message = 'Invoice no longer exists.'
        }
    end

    local amount = normalizeAmount(invoice.amount)
    if not amount then
        return {
            success = false,
            message = 'Invalid invoice amount.'
        }
    end

    if Player.PlayerData.money.bank < amount then
        return {
            success = false,
            message = 'You do not have enough bank balance.'
        }
    end

    local senderCitizenId = invoice.sendercitizenid
    local senderPlayer = senderCitizenId and QBCore.Functions.GetPlayerByCitizenId(senderCitizenId)
    local society = tostring(invoice.society or 'invoice')
    local payerName = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)

    Player.Functions.RemoveMoney('bank', amount, 'paid-invoice')

    if senderPlayer and Config.BillingCommissions and Config.BillingCommissions[society] then
        local commission = math.ceil(amount * Config.BillingCommissions[society])
        senderPlayer.Functions.AddMoney('bank', commission)
    end

    if senderPlayer then
        TriggerClientEvent('qb-phone:client:CustomNotification', senderPlayer.PlayerData.source,
            "Invoice paid by " .. payerName .. ".",
            "Recent invoice of $" .. amount .. " has been paid.",
            "fas fa-file-invoice-dollar",
            "#22c55e",
            7500
        )
        TriggerClientEvent('qb-phone:client:InvoiceNotification', senderPlayer.PlayerData.source, payerName, amount)
    end

    local removedRows = removeInvoiceForPlayer(Player, invoiceId)
    if removedRows < 1 then
        return {
            success = false,
            message = 'Invoice no longer exists.'
        }
    end

    TriggerClientEvent('qb-phone:client:RemoveInvoiceFromTable', source, invoiceId)

    return {
        success = true,
        newBalance = Player.PlayerData.money.bank,
        message = ("Invoice paid for $%s."):format(amount)
    }
end

local function declineInvoiceForPlayer(source, invoiceId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return {
            success = false,
            message = 'Player not found.'
        }
    end

    local invoice = findInvoiceForPlayer(Player, invoiceId)
    if not invoice then
        return {
            success = false,
            message = 'Invoice no longer exists.'
        }
    end

    local senderCitizenId = invoice.sendercitizenid
    local senderPlayer = senderCitizenId and QBCore.Functions.GetPlayerByCitizenId(senderCitizenId)
    local declinerName = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)

    local removedRows = removeInvoiceForPlayer(Player, invoiceId)
    if removedRows < 1 then
        return {
            success = false,
            message = 'Invoice no longer exists.'
        }
    end

    if senderPlayer then
        TriggerClientEvent('qb-phone:client:CustomNotification', senderPlayer.PlayerData.source,
            "Invoice declined by " .. declinerName .. ".",
            "Recent invoice of $" .. tostring(invoice.amount) .. " has been declined.",
            "fas fa-file-invoice-dollar",
            "#1DA1F2",
            7500
        )
    end

    TriggerClientEvent('qb-phone:client:RemoveInvoiceFromTable', source, invoiceId)

    return {
        success = true,
        message = 'Invoice declined.'
    }
end

-- Events

RegisterNetEvent('qb-phone:server:InvoiceHandler')

-- EVENT HANDLER(S) --

-- Has player paid something this --
--[[AddEventHandler('qb-phone:server:InvoiceHandler', function(paid, amount, source, resource)

    if paid and resource == GetCurrentResourceName() then
        if amount >= config.minPayment then
            if Config.RenewedBanking then
                local cid = Player.PlayerData.citizenid
                local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
                exports['Renewed-Banking']:handleTransaction(cid, "Phone Invoice", amount, "Paid off phone invoice of $"..amount, name, name, "withdraw")
            end
            -- Do shit
        end
    end
end)]]

QBCore.Functions.CreateCallback('qb-phone:server:CanTransferMoney', function(source, cb, amount, iban, reference)
    local Player = QBCore.Functions.GetPlayer(source)
    amount = normalizeAmount(amount)
    iban = normalizeBankAccount(iban)
    reference = normalizeReference(reference)

    if not Player or not amount or not iban then
        cb(false, Player and Player.PlayerData.money.bank or 0, 'Invalid transfer details.')
        return
    end

    if isRateLimited(ActionCooldowns.transfer, source, 1200) then
        cb(false, Player.PlayerData.money.bank, 'Please wait before sending another transfer.')
        return
    end

    local senderAccount = normalizeBankAccount(Player.PlayerData.charinfo.account or '')
    if senderAccount and senderAccount == iban then
        cb(false, Player.PlayerData.money.bank, 'You cannot transfer to your own account.')
        return
    end

    if Player.PlayerData.money.bank < amount then
        cb(false, Player.PlayerData.money.bank, 'You do not have enough bank balance.')
        return
    end

    local query = '%"account":"' .. iban .. '"%'
    local result = MySQL.query.await('SELECT citizenid, money FROM players WHERE charinfo LIKE ? LIMIT 1', {query})
    if result[1] == nil then
        cb(false, Player.PlayerData.money.bank, 'Account does not exist.')
        return
    end

    if result[1].citizenid == Player.PlayerData.citizenid then
        cb(false, Player.PlayerData.money.bank, 'You cannot transfer to your own account.')
        return
    end

    local receiver = QBCore.Functions.GetPlayerByCitizenId(result[1].citizenid)
    Player.Functions.RemoveMoney('bank', amount, buildTransferReason('Money sent to account', iban, reference))

    if receiver ~= nil then
        receiver.Functions.AddMoney('bank', amount, buildTransferReason('Money received from account', senderAccount or 'unknown', reference))
        local senderName = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
        local notifyText = reference ~= '' and ("Incoming transfer of $" .. amount .. " from " .. senderName .. " (" .. reference .. ")")
            or ("Incoming transfer of $" .. amount .. " from " .. senderName)
        TriggerClientEvent("qb-phone-new:client:BankNotify", receiver.PlayerData.source, notifyText)
    else
        local receiverMoney = json.decode(result[1].money)
        receiverMoney.bank = (receiverMoney.bank + amount)
        MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {json.encode(receiverMoney), result[1].citizenid})
    end

    cb(true, Player.PlayerData.money.bank, 'Transfer completed.')
end)

QBCore.Functions.CreateCallback('qb-phone:server:PayMyInvoice', function(source, cb, invoiceId)
    local actionKey = ('%s:%s'):format(source, tonumber(invoiceId) or 0)
    if isRateLimited(ActionCooldowns.payInvoice, actionKey, 1400) then
        cb({ success = false, message = 'Please wait before trying again.' })
        return
    end

    cb(payInvoiceForPlayer(source, invoiceId))
end)

QBCore.Functions.CreateCallback('qb-phone:server:DeclineMyInvoice', function(source, cb, invoiceId)
    local actionKey = ('%s:%s'):format(source, tonumber(invoiceId) or 0)
    if isRateLimited(ActionCooldowns.declineInvoice, actionKey, 1000) then
        cb({ success = false, message = 'Please wait before trying again.' })
        return
    end

    cb(declineInvoiceForPlayer(source, invoiceId))
end)

RegisterNetEvent('qb-phone:server:PayMyInvoice', function(invoiceId)
    local actionKey = ('%s:%s'):format(source, tonumber(invoiceId) or 0)
    if isRateLimited(ActionCooldowns.payInvoice, actionKey, 1400) then
        return
    end

    payInvoiceForPlayer(source, invoiceId)
end)

RegisterNetEvent('qb-phone:server:DeclineMyInvoice', function(invoiceId)
    local actionKey = ('%s:%s'):format(source, tonumber(invoiceId) or 0)
    if isRateLimited(ActionCooldowns.declineInvoice, actionKey, 1000) then
        return
    end

    declineInvoiceForPlayer(source, invoiceId)
end)


RegisterNetEvent('qb-phone:server:CreateInvoice', function(billed, _, amount)
    local src = source
    local billedID = tonumber(billed)
    local cash = normalizeAmount(amount)
    local billedCID = QBCore.Functions.GetPlayer(billedID)
    local billerInfo = QBCore.Functions.GetPlayer(src)

    if not billedID or not cash or not billedCID or not billerInfo then return end
    if billerInfo.PlayerData.citizenid == billedCID.PlayerData.citizenid then
        TriggerClientEvent('QBCore:Notify', src, 'You Cannot Bill Yourself', 'error')
        return
    end

    local invoiceId = createInvoiceForPlayer(billedCID, billerInfo, cash)
    if not invoiceId then
        TriggerClientEvent('QBCore:Notify', src, 'Failed To Send Invoice', 'error')
        return
    end

    TriggerClientEvent('qb-phone:RefreshPhone', billedCID.PlayerData.source)
    TriggerClientEvent('QBCore:Notify', src, 'Invoice Successfully Sent', 'success')
    TriggerClientEvent('QBCore:Notify', billedCID.PlayerData.source, 'New Invoice Received')
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetInvoices', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    cb(getInvoicesForCitizenId(Player.PlayerData.citizenid))
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetInvoiceStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({
            pendingCount = 0,
            totalAmount = 0,
            averageAmount = 0,
            overdueCount = 0
        })
        return
    end

    local invoices = getInvoicesForCitizenId(Player.PlayerData.citizenid)
    local pendingCount = #invoices
    local totalAmount = 0
    local overdueCount = 0
    local currentTime = os.time()
    local overdueDays = 7 * 24 * 60 * 60-- 7 days in seconds

    for _, invoice in pairs(invoices) do
        totalAmount = totalAmount + (tonumber(invoice.amount) or 0)
        if currentTime - (tonumber(invoice.time) or 0) > overdueDays then
            overdueCount = overdueCount + 1
        end
    end

    cb({
        pendingCount = pendingCount,
        totalAmount = totalAmount,
        averageAmount = pendingCount > 0 and math.floor(totalAmount / pendingCount) or 0,
        overdueCount = overdueCount
    })
end)

QBCore.Commands.Add('bill', 'Bill A Player', {{name = 'id', help = 'Player ID'}, {name = 'amount', help = 'Fine Amount'}}, false, function(source, args)
    local biller = QBCore.Functions.GetPlayer(source)
    local billed = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local amount = normalizeAmount(args[2])

    if not biller then
        return
    end

    if biller and billed and biller.PlayerData.citizenid == billed.PlayerData.citizenid then
        TriggerClientEvent('QBCore:Notify', source, 'You Cannot Bill Yourself', 'error')
        return
    end

    local billerJob = biller.PlayerData.job and biller.PlayerData.job.name or ''
    if billerJob == 'police' or billerJob == 'ambulance' or billerJob == 'mechanic' then
        if billed ~= nil then
                if amount then
                    local invoiceId = createInvoiceForPlayer(billed, biller, amount)
                    if not invoiceId then
                        TriggerClientEvent('QBCore:Notify', source, 'Failed To Send Invoice', 'error')
                        return
                    end

                    TriggerClientEvent('qb-phone:RefreshPhone', billed.PlayerData.source)
                    TriggerClientEvent('QBCore:Notify', source, 'Invoice Successfully Sent', 'success')
                    TriggerClientEvent('QBCore:Notify', billed.PlayerData.source, 'New Invoice Received')
                else
                    TriggerClientEvent('QBCore:Notify', source, 'Must Be A Valid Amount Above 0', 'error')
                end
        else
            TriggerClientEvent('QBCore:Notify', source, 'Player Not Online', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'No Access', 'error')
    end
end)
