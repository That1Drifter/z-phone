local QBCore = exports['qb-core']:GetCoreObject()
local NUIActionCooldowns = {}

local function isNuiRateLimited(action, durationMs)
    local now = GetGameTimer()
    local lastTick = NUIActionCooldowns[action] or 0

    if (now - lastTick) < durationMs then
        return true
    end

    NUIActionCooldowns[action] = now
    return false
end

local function normalizeTransferAmount(value)
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

local function GetInvoiceFromID(id)
    for k, v in pairs(PhoneData.Invoices) do
        if v.id == id then
            return k
        end
    end
end

-- NUI Callback

RegisterNUICallback('GetBankContacts', function(_, cb)
    cb(PhoneData.Contacts)
end)

RegisterNUICallback('CanTransferMoney', function(data, cb)
    if isNuiRateLimited('bank-transfer', 900) then
        cb({
            TransferedMoney = false,
            NewBalance = PlayerData.money['bank'],
            message = 'Please wait a moment before sending again.'
        })
        return
    end

    local amount = normalizeTransferAmount(data and data.amountOf)
    local iban = normalizeBankAccount(data and data.sendTo)
    local reference = normalizeReference(data and data.reference)

    if not amount or not iban then
        cb({
            TransferedMoney = false,
            NewBalance = PlayerData.money['bank'],
            message = 'Invalid transfer details.'
        })
        return
    end

    if PlayerData.money['bank'] < amount then
        cb({
            TransferedMoney = false,
            NewBalance = PlayerData.money['bank'],
            message = 'You do not have enough bank balance.'
        })
        return
    end

    QBCore.Functions.TriggerCallback('qb-phone:server:CanTransferMoney', function(success, newBalance, message)
        cb({
            TransferedMoney = success or false,
            NewBalance = newBalance or PlayerData.money['bank'],
            message = message
        })
    end, amount, iban, reference)
end)

RegisterNUICallback('GetInvoices', function(_, cb)
    cb(PhoneData.Invoices)
end)

RegisterNUICallback('PayInvoice', function(data, cb)
    if isNuiRateLimited('pay-invoice', 900) then
        cb({ success = false, message = 'Please wait a moment before trying again.' })
        return
    end

    local invoiceId = tonumber(data and data.invoiceId)
    if not invoiceId then
        cb({ success = false, message = 'Invalid invoice.' })
        return
    end

    QBCore.Functions.TriggerCallback('qb-phone:server:PayMyInvoice', function(result)
        cb(result or { success = false, message = 'Unable to pay invoice.' })
    end, invoiceId)
end)

RegisterNUICallback('DeclineInvoice', function(data, cb)
    if isNuiRateLimited('decline-invoice', 900) then
        cb({ success = false, message = 'Please wait a moment before trying again.' })
        return
    end

    local invoiceId = tonumber(data and data.invoiceId)
    if not invoiceId then
        cb({ success = false, message = 'Invalid invoice.' })
        return
    end

    QBCore.Functions.TriggerCallback('qb-phone:server:DeclineMyInvoice', function(result)
        cb(result or { success = false, message = 'Unable to decline invoice.' })
    end, invoiceId)
end)

RegisterNUICallback('GetInvoiceDetails', function(data, cb)
    if not data or not data.invoiceId then
        cb({ success = false, message = 'Invalid invoice ID.' })
        return
    end

    local invoiceId = tonumber(data.invoiceId)
    local invoice = nil

    for _, inv in pairs(PhoneData.Invoices) do
        if inv.id == invoiceId then
            invoice = inv
            break
        end
    end

    if not invoice then
        cb({ success = false, message = 'Invoice not found.' })
        return
    end

    cb({
        success = true,
        invoice = {
            id = invoice.id,
            sender = invoice.sender or 'Unknown Sender',
            society = invoice.society or 'General Invoice',
            amount = invoice.amount or 0,
            timestamp = invoice.time or os.time(),
            status = 'Pending',
            reason = invoice.reason or 'No description provided'
        }
    })
end)

RegisterNUICallback('GetInvoiceStats', function(_, cb)
    local totalPending = 0
    local invoiceCount = 0

    if PhoneData.Invoices then
        for _, invoice in pairs(PhoneData.Invoices) do
            invoiceCount = invoiceCount + 1
            totalPending = totalPending + (tonumber(invoice.amount) or 0)
        end
    end

    cb({
        pendingCount = invoiceCount,
        totalAmount = totalPending,
        averageAmount = invoiceCount > 0 and math.floor(totalPending / invoiceCount) or 0
    })
end)

-- Events
RegisterNetEvent('qb-phone:client:RemoveBankMoney', function(amount)
    if amount > 0 then
        SendNUIMessage({
            action = "PhoneNotification",
            PhoneNotify = {
                title = "Withdrawal",
                text = "$"..amount.." removed from your balance",
                icon = "fas fa-arrow-down",
                color = "#ef4444",
                timeout = 3500,
            },
        })
    end
end)

RegisterNetEvent('qb-phone:client:AddBankMoney', function(amount)
    if amount > 0 then
        SendNUIMessage({
            action = "PhoneNotification",
            PhoneNotify = {
                title = "Deposit",
                text = "$"..amount.." added to your balance",
                icon = "fas fa-arrow-up",
                color = "#22c55e",
                timeout = 3500,
            },
        })
    end
end)

RegisterNetEvent("qb-phone-new:client:BankNotify", function(text)
    SendNUIMessage({
        action = "PhoneNotification",
        NotifyData = {
            title = "Banking",
            content = text,
            icon = "fas fa-building-columns",
            timeout = 3500,
            color = "#0ea5e9",
        },
    })
end)

RegisterNetEvent('qb-phone:client:InvoiceNotification', function(sender, amount, invoiceId)
    SendNUIMessage({
        action = "PhoneNotification",
        PhoneNotify = {
            title = "Invoice Alert",
            text = "$"..amount.." invoice from "..sender,
            icon = "fas fa-file-invoice-dollar",
            color = "#f59e0b",
            timeout = 4500,
        },
    })
end)

RegisterNetEvent('qb-phone:client:AcceptorDenyInvoice', function(id, name, job, senderCID, amount, resource)
    local invoiceData = {
        id = id,
        citizenid = QBCore.Functions.GetPlayerData().citizenid,
        sender = name,
        society = job,
        sendercitizenid = senderCID,
        amount = amount,
        time = os.time(),
        status = 'pending'
    }

    table.insert(PhoneData.Invoices, invoiceData)

    -- Show rich notification with actions
    local success = exports['z-phone']:PhoneNotification(
        "New Invoice",
        'Invoice of $'..amount..' from '..name..' ('..job..')',
        'fas fa-file-invoice-dollar',
        '#f59e0b',
        "NONE",
        'fas fa-check-circle',
        'fas fa-times-circle'
    )

    if success then
        TriggerServerEvent('qb-phone:server:PayMyInvoice', id)
    else
        TriggerServerEvent('qb-phone:server:DeclineMyInvoice', id)
    end

    SendNUIMessage({
        action = "refreshInvoice",
        invoices = PhoneData.Invoices,
    })
end)

RegisterNetEvent('qb-phone:client:RemoveInvoiceFromTable', function(id)
    local table = GetInvoiceFromID(id)
    if table then
        PhoneData.Invoices[table] = nil

        SendNUIMessage({
            action = "refreshInvoice",
            invoices = PhoneData.Invoices,
        })
    end
end)
