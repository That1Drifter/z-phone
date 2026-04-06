local QBCore = exports['qb-core']:GetCoreObject()

local MAX_GALLERY_IMAGES = 50
local DEFAULT_TRUSTED_CAMERA_HOSTS = {
    ['cdn.discordapp.com'] = true,
    ['media.discordapp.net'] = true,
    ['images-ext-1.discordapp.net'] = true,
    ['images-ext-2.discordapp.net'] = true,
}

local function normalizeImageUrl(url)
    if type(url) ~= 'string' then return nil end
    url = url:match('^%s*(.-)%s*$')
    if not url or #url < 8 or #url > 1000 then return nil end
    if not url:match('^https?://') then return nil end
    return url
end

local function extractHostFromUrl(url)
    local host = tostring(url or ''):match('^https?://([^/%?#]+)')
    if not host then return nil end
    host = host:lower():gsub(':%d+$', '')
    return host
end

local function isTrustedCameraHost(url)
    local host = extractHostFromUrl(url)
    if not host then return false end

    if DEFAULT_TRUSTED_CAMERA_HOSTS[host] then
        return true
    end

    if host:sub(-16) == '.discordapp.com' then
        return true
    end

    if host:sub(-16) == '.discordapp.net' then
        return true
    end

    return false
end

local function fetchPlayerImages(citizenid)
    local rows = exports.oxmysql:executeSync(
        'SELECT `image`, `date` FROM phone_gallery WHERE citizenid = ? ORDER BY `date` DESC LIMIT ?',
        { citizenid, MAX_GALLERY_IMAGES }
    )

    if not rows then
        return {}
    end

    for index = #rows, 1, -1 do
        if not normalizeImageUrl(rows[index].image) then
            table.remove(rows, index)
        end
    end

    return rows
end

QBCore.Functions.CreateCallback('qb-phone:server:fetchImages', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    cb(fetchPlayerImages(Player.PlayerData.citizenid))
end)

QBCore.Functions.CreateCallback('qb-phone:server:SaveCapturedPhoto', function(source, cb, image)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    image = normalizeImageUrl(image)
    if not image then
        cb({ success = false, message = 'Invalid image URL.' })
        return
    end

    if not isTrustedCameraHost(image) then
        cb({ success = false, message = 'Untrusted upload host.' })
        return
    end

    local count = exports.oxmysql:executeSync(
        'SELECT COUNT(*) as total FROM phone_gallery WHERE citizenid = ?',
        { Player.PlayerData.citizenid }
    )

    if count and count[1] and count[1].total >= MAX_GALLERY_IMAGES then
        cb({ success = false, message = 'Gallery is full.' })
        return
    end

    exports.oxmysql:insert(
        'INSERT INTO phone_gallery (`citizenid`, `image`) VALUES (?, ?)',
        { Player.PlayerData.citizenid, image }
    )

    cb({ success = true, url = image })
end)

RegisterNetEvent('qb-phone:server:addImageToGallery', function(image)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    image = normalizeImageUrl(image)
    if not image then return end
    if not isTrustedCameraHost(image) then
        return
    end

    local count = exports.oxmysql:executeSync(
        'SELECT COUNT(*) as total FROM phone_gallery WHERE citizenid = ?',
        { Player.PlayerData.citizenid }
    )
    if count and count[1] and count[1].total >= MAX_GALLERY_IMAGES then
        TriggerClientEvent('qb-phone:notification', src, 'Gallery', 'Gallery full! Max ' .. MAX_GALLERY_IMAGES .. ' photos.', 'fa-solid fa-images', '#ef4444', 3000)
        return
    end

    exports.oxmysql:insert(
        'INSERT INTO phone_gallery (`citizenid`, `image`) VALUES (?, ?)',
        { Player.PlayerData.citizenid, image }
    )
end)

RegisterNetEvent('qb-phone:server:getImageFromGallery', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local images = fetchPlayerImages(Player.PlayerData.citizenid)
    TriggerClientEvent('qb-phone:refreshImages', src, images)
end)

RegisterNetEvent('qb-phone:server:RemoveImageFromGallery', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(data) ~= 'table' then return end

    local image = normalizeImageUrl(data.image)
    if not image then return end

    exports.oxmysql:execute(
        'DELETE FROM phone_gallery WHERE citizenid = ? AND image = ? LIMIT 1',
        { Player.PlayerData.citizenid, image }
    )
end)
