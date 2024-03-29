local image = require("IMAGE")
local color = require("COLOR")
local unicode = require("unicode")
local gpu = require("component").gpu

local buffer = {initialized=false}

function buffer.initialize(width, height, gpuFilling)
    if not buffer.initialized then
        local newWidth, newHeight
        if width and height then
            newWidth, newHeight = width, height
        else
            newWidth, newHeight = gpu.getResolution()
        end
        buffer.width = newWidth
        buffer.height = newHeight
        buffer.dHeight = newHeight * 2
        buffer.drawX, buffer.drawY, buffer.drawW, buffer.drawH = 1, 1, buffer.width, buffer.height
        if not buffer.new then buffer.new = image.new("new", newWidth, newHeight) end
        if not buffer.old then buffer.old = image.new("old", newWidth, newHeight) end
        local index, symbol, tColor, bColor
        for h = 1, newHeight do
            for w = 1, newWidth do
                index = image.XYToIndex(w, h, newWidth)
                symbol, tColor, bColor = gpu.get(w, h)
                buffer.old.data[index]     = symbol
                buffer.new.data[index]     = symbol
                buffer.old.data[index + 1] = bColor
                buffer.new.data[index + 1] = bColor              
                buffer.old.data[index + 2] = tColor
                buffer.new.data[index + 2] = tColor
            end
        end
        --buffer.new:fill(1, 1, newWidth, newHeight, " ", 0x1C1C1C, 0xFFFFFF)
        --buffer.old:fill(1, 1, newWidth, newHeight, " ", 0x1C1C1C, 0xFFFFFF)
        --buffer.old = image.screenshot()
        --if gpuFilling then
        --    gpu.setBackground(0x1C1C1C)
        --    gpu.setForeground(0xFFFFFF)
        --    gpu.fill(1, 1, newWidth, newHeight, " ")
        --end
        buffer.initialized = true
    end
end

function buffer.shutdown()
  buffer.initialized = false
  buffer.old = nil
  buffer.new = nil
end

local function floor(number)
    return math.floor(number + 0.5)
end

local function checkPixel(x, y)
    if x >= buffer.drawX and x <= buffer.drawX + buffer.drawW - 1 and y >= buffer.drawY and y <= buffer.drawY + buffer.drawH - 1 then return true end
    return false
end

function buffer.setDrawing(x, y, width, height)
    buffer.drawX, buffer.drawY, buffer.drawW, buffer.drawH = x, y, width, height
end

function buffer.setDefaultDrawing()
    buffer.drawX, buffer.drawY, buffer.drawW, buffer.drawH = 1, 1, buffer.width, buffer.height
end

function buffer.setPixel(x, y, symbol, bColor, tColor)
    if checkPixel(x, y) and bColor ~= -1 then
        buffer.new:setPixel(x, y, symbol, bColor, tColor)
    end
end

function buffer.setDPixel(x, y, color)
    if checkPixel(x, math.floor(y / 2)) then
        buffer.new:setDPixel(x, y, color)
    end
end

function buffer.getPixel(x, y)
    return buffer.new:getPixel(x, y)
end

function buffer.fill(x, y, width, height, symbol, bColor, tColor, dPixel)
    local index
    for h = 1, height do
        for w = 1, width do
            if dPixel and checkPixel(x + w - 1, floor((y + h - 1) / 2)) then
                buffer.new:setDPixel(x + w - 1, y + h - 1, bColor)
            elseif checkPixel(x + w - 1, y + h - 1) then
                index = image.XYToIndex(x + w - 1, y + h - 1, buffer.new.width)
                if symbol then buffer.new.data[index] = symbol end
                if bColor then buffer.new.data[index + 1] = bColor end
                if tColor then buffer.new.data[index + 2] = tColor end
            end
        end
    end
end

function buffer.fillBlend(x, y, width, height, aColor, alpha, dPixel)
    local index
    for h = 1, height do
        for w = 1, width do
            local state = false
            if dPixel then state = checkPixel(x + w - 1, floor((y + h - 1) / 2)) else state = checkPixel(x + w - 1, y + h - 1) end
            if state then
                if dPixel then
                    index = image.XYToIndex(x + w - 1, floor((y + h - 1) / 2), buffer.new.width)
                    local num, subNum = math.modf((y + h - 1) / 2)
                    if subNum > 0.0 then
                        local oldS = buffer.new.data[index]
                        if buffer.new.data[index] == "▀" then
                            buffer.new.data[index + 2] = color.blend(buffer.new.data[index + 2], aColor, alpha)
                        elseif buffer.new.data[index] == "▄" then
                            buffer.new.data[index + 1] = color.blend(buffer.new.data[index + 1], aColor, alpha)
                        else
                            buffer.new.data[index] = "▀"
                            buffer.new.data[index + 2] = color.blend(buffer.new.data[index + 1], aColor, alpha)
                        end
                    else
                        local oldS = buffer.new.data[index]
                        if buffer.new.data[index] == "▀" then
                            buffer.new.data[index + 1] = color.blend(buffer.new.data[index + 1], aColor, alpha)
                        elseif buffer.new.data[index] == "▄" then
                            buffer.new.data[index + 2] = color.blend(buffer.new.data[index + 2], aColor, alpha)
                        else
                            buffer.new.data[index] = "▄"
                            buffer.new.data[index + 2] = color.blend(buffer.new.data[index + 1], aColor, alpha)
                        end
                    end
                else
                    index = image.XYToIndex(x + w - 1, y + h - 1, buffer.new.width)
                    buffer.new.data[index + 1] = color.blend(buffer.new.data[index + 1], aColor, alpha)
                    buffer.new.data[index + 2] = color.blend(buffer.new.data[index + 2], aColor, alpha)
                end
            end
        end
    end
end

function buffer.drawLine(x1, y1, x2, y2, symbol, bColor, tColor, dPixel)
    buffer.new:drawLine(x1, y1, x2, y2, symbol, bColor, tColor, dPixel)
end

function buffer.drawCircle(x, y, radius, aColor, dPixel)
    buffer.new:drawCircle(x, y, radius, aColor, dPixel)
end

function buffer.drawEllipse(x, y, width, height, aColor, dPixel)
    buffer.new:drawEllipse(x, y, width, height, aColor, dPixel)
end

function buffer.drawText(x, y, bColor, tColor, text)
    if y <= buffer.height then
        local index
        for i = 1, unicode.len(text) do
            index = image.XYToIndex(x + i - 1, y, buffer.new.width)
            if checkPixel(x + i - 1, y) then
                if bColor and bColor ~= -1 then buffer.new.data[index + 1] = bColor
                elseif buffer.new.data[index] == symbol then buffer.new.data[index + 1] = -1 end
                buffer.new.data[index] = unicode.sub(text, i, i)
                if tColor then buffer.new.data[index + 2] = tColor end
            end
        end
    end
end

function buffer.drawImage(x, y, img)
    if img.compressed then
        for bColor, data1 in pairs(img.data) do
            for tColor, data2 in pairs(data1) do
                for i = 1, #data2, 3 do
                    buffer.drawText(x + data2[i] - 1, y + data2[i + 1] - 1, bColor, tColor, data2[i + 2])
                end
            end
        end
    else
        buffer.drawImage(x, y, image.compress(img))
    end
end

function buffer.crop(x, y, width, height)
    if x <= buffer.width and y <= buffer.height then
        local newX, newY, newWidth, newHeight = x, y, width, height
        if x < 1 then newX = 1 end
        if y < 1 then newY = 1 end
        if x + width - 1 > buffer.width then newWidth = buffer.width - newX + 1 end
        if y + height - 1 > buffer.height then newHeight = buffer.height - newY + 1 end
        return image.crop(newX, newY, newWidth, newHeight, buffer.new)
    end
end

function buffer.draw(drawAll)
    if drawAll then
        buffer.new:draw(1, 1)
    else
        local compared = image.new("compared", buffer.old.width, buffer.old.height)
        local iP1, iP2
        for i = 1, #buffer.old.data, 3 do
            iP1, iP2 = i + 1, i + 2
            if buffer.old.data[i] ~= buffer.new.data[i] or buffer.old.data[iP1] ~= buffer.new.data[iP1] or buffer.old.data[iP2] ~= buffer.new.data[iP2] then
                table.insert(compared.data, buffer.new.data[i])
                table.insert(compared.data, buffer.new.data[iP1])
                table.insert(compared.data, buffer.new.data[iP2])
                buffer.old.data[i] = buffer.new.data[i]
                buffer.old.data[iP1] = buffer.new.data[iP1]
                buffer.old.data[iP2] = buffer.new.data[iP2]
            else
                table.insert(compared.data, -1)
                table.insert(compared.data, -1)
                table.insert(compared.data, -1)
            end
        end
        compared:draw(1, 1)
        compared = nil
    end
end

buffer.initialize()

return buffer