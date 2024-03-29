local buffer = require("IBUFFER")
local image = require("IMAGE")
local color = require("COLOR")
local event = require("event")
local unicode = require("unicode")
local fs = require("filesystem")
local kb = require("keyboard")
local term = require("term")
local gpu = require("component").gpu

local ui = {
    eventHandling=false,
    ID = {
        BOX                  = 1,
        WINDOW               = 2,
        LABEL                = 3,
        STANDART_BUTTON      = 4,
        BEAUTIFUL_BUTTON     = 5,
        IMAGED_BUTTON        = 6,
        STANDART_TEXTBOX     = 7,
        BEAUTIFUL_TEXTBOX    = 8,
        STANDART_CHECKBOX    = 9,
        CONTEXT_MENU         = 10,
        LISTBOX              = 11,
        SCROLLBAR            = 12,
        STANDART_PROGRESSBAR = 13,
        IMAGE                = 14,
        CANVAS               = 15
    }
}

function ui.initialize(gpuFilling)
    buffer.initialize(nil, nil, gpuFilling)
end

function ui.exit(bColor, tColor, gpuFilling)
    local newBColor, newTColor = bColor, tColor
    local width, height = gpu.getResolution()
    if not bColor then newBColor = 0x1C1C1C end
    if not tColor then newTColor = 0xFFFFFF end
    if not gpuFilling then
      gpu.setBackground(newBColor)
      gpu.setForeground(newTColor)
      gpu.fill(1, 1, width, height, " ")
      term.clear()
    end
    os.exit()
end

function ui.shutdown()
    buffer.shutdown()
    ui.exit()
end

local function codeToSymbol(code)
    local symbol
    if code ~= 0 and code ~= 13 and code ~= 8 and code ~= 9 and code ~= 200 and code ~= 208 and code ~= 203 and code ~= 205 and not kb.isControlDown() then
        symbol = unicode.char(code)
        if kb.isShiftPressed then symbol = unicode.upper(symbol) end
    end
    return symbol
end

function ui.addQuotes(text)
    return string.format('%q', text)
end

function ui.checkClick(obj, x, y)
    if x >= obj.globalX and x <= obj.globalX + obj.width - 1 and y >= obj.globalY and y <= obj.globalY + obj.height - 1 then
        for num, object in pairs(obj.objects) do
            local clickedObj = ui.checkClick(object, x, y)
            if clickedObj then return clickedObj end
        end
        return obj
    end
end

function ui.centerSquare(width, height)
    local sWidth, sHeight = gpu.getResolution()
    return math.floor(sWidth / 2 - width / 2) + 1, math.floor(sHeight / 2 - height / 2) + 1
end

function ui.centerText(text, width)
    return math.floor(width / 2 - unicode.len(text) / 2)
end

function ui.resizeText(text, max)
    if unicode.len(text) > max then return unicode.sub(text, 1, max - 1) .. "…" else return text end
end

function ui.strfind(str, pattern, init, plain)
    if init then
        if init < 0 then
            init = -#unicode.sub(str,init)
        elseif init > 0 then
            init = #unicode.sub(str, 1, init - 1) + 1
        end
    end
    a, b = string.find(str, pattern, init, plain)
    if a then
        local ap, bp = str:sub(1, a - 1), str:sub(a,b)
        a = unicode.len(ap) + 1
        b = a + unicode.len(bp) - 1
        return a, b
    else return a end
end

function ui.getFormatOfFile(path)
  local fileName = fs.name(path)
  local first, second = ui.strfind(fileName, "(.)%.[%d%w]*$")
  if first then return unicode.sub(fileName, first + 1, -1) end
end

local function addObject(toObj, obj)
    obj.globalX, obj.globalY = toObj.globalX + obj.x - 1, toObj.globalY + obj.y - 1
    table.insert(toObj.objects, obj)
    obj.index = #toObj.objects
end

local function removeObject(onObj, obj)
    onObj.objects[obj.index] = nil
end

local function cleanObjects(obj)
    obj.objects = {}
end

local function checkProperties(x, y, width, height, props)
    local newProps = props
    newProps.x, newProps.y, newProps.globalX, newProps.globalY, newProps.width, newProps.height, newProps.objects = x, y, x, y, width, height, {}
    if props.args == nil then newProps.args = {} end
    if props.args.visible == nil then newProps.args.visible = true end
    if props.args.enabled == nil then newProps.args.enabled = true end
    if props.args.active == nil then newProps.args.active = false end
    return newProps
end

--  BOX  -------------------------------------------------------------------------------------------------
local function drawBox(obj)
    if not obj.args.hideBox then
    local symbol = " "
    if obj.args.symbol then symbol = obj.args.symbol end
        if obj.args.alpha then
            buffer.fillBlend(obj.globalX, obj.globalY, obj.width, obj.height, obj.color, obj.args.alpha, obj.args.dPixel)
        else
            buffer.fill(obj.globalX, obj.globalY, obj.width, obj.height, symbol, obj.color, nil, obj.args.dPixel)
        end
    end
end

function ui.box(x, y, width, height, aColor, args)
    return checkProperties(x, y, width, height, {
        color=aColor, args=args, id=ui.ID.BOX, draw=drawBox, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  WINDOW  -------------------------------------------------------------------------------------------------
local function drawWindow(obj)
    if obj.args.alpha then
        buffer.fillBlend(obj.globalX, obj.globalY, obj.width, obj.height, obj.color, obj.args.alpha, obj.args.dPixel)
    else
        buffer.fill(obj.globalX, obj.globalY, obj.width, obj.height, " ", obj.bColor, nil, false)
        buffer.fill(obj.globalX, obj.globalY, obj.width, 1, " ", obj.barColor, nil, false)
        buffer.drawText(obj.globalX + ui.centerText(obj.title, obj.width), obj.globalY, nil, obj.tColor, obj.title)
    end
    if obj.shadow then
        buffer.fillBlend(obj.globalX + obj.width, obj.globalY * 2, 1, obj.height * 2, 0, 0.5, true)
        buffer.fillBlend(obj.globalX + 1, (obj.globalY + obj.height) * 2 - 1, obj.width - 1, 1, 0, 0.5, true)
    end
end

function ui.window(x, y, width, height, bColor, barColor, tColor, title, shadow, args)
    local newX, newY = x, y
    if not x or not y then newX, newY = ui.centerSquare(width, height) end
    return checkProperties(newX, newY, width, height, {
        bColor=bColor, barColor=barColor, tColor=tColor, title=title, shadow=shadow, args=args, id=ui.ID.WINDOW, draw=drawWindow, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  LABEL  -----------------------------------------------------------------------------------------------
local function drawLabel(obj)
    buffer.drawText(obj.globalX, obj.globalY, obj.bColor, obj.tColor, obj.text)
end

local function setLabelText(obj, text)
    local length = unicode.len(obj.text)
    obj.width, obj.text = length, text
end

function ui.label(x, y, bColor, tColor, text, args)
    local newText = text
    if not text then newText = "" end
    return checkProperties(x, y, unicode.len(newText), 1, {
        bColor=bColor, tColor=tColor, text=newText, args=args, id=ui.ID.LABEL, setText=setLabelText, draw=drawLabel, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  STANDART BUTTON  -------------------------------------------------------------------------------------
local function drawStandartButton(obj)
    local symbol, bColor, tColor = " ", obj.bColor, obj.tColor
    if obj.args.symbol then symbol = obj.args.symbol end
    if obj.args.active then
        bColor = obj.tColor
        tColor = obj.bColor
    end
    if obj.args.alpha then
        buffer.fillBlend(obj.globalX, obj.globalY, obj.width, obj.height, bColor, obj.args.alpha)
    else
        buffer.fill(obj.globalX, obj.globalY, obj.width, obj.height, symbol, bColor, nil)
    end
    if obj.args.indent then
        buffer.drawText(obj.globalX + obj.args.indent, math.floor(obj.globalY + obj.height / 2), nil, tColor, obj.text)
    else
        buffer.drawText(obj.globalX + math.floor(obj.width / 2 - unicode.len(obj.text) / 2), math.floor(obj.globalY + obj.height / 2), nil, tColor, obj.text)
    end
end

local function toggleButton(obj, notDrawWhenToggling)
    if obj.args.active then
        obj.args.active = false
    else
        obj.args.active = true
    end
    if notDrawWhenToggling then obj:draw() else ui.draw(obj) end
end

local function flashButton(obj, delay)
    if obj.args.toggling then
        if obj.args.active then obj.args.active = false else obj.args.active = true end
        if not obj.args.notDrawWhenToggling then ui.draw(obj) end
    else
       obj.args.active = true
       ui.draw(obj)
       os.sleep(delay or 0.3)
       obj.args.active = false
       ui.draw(obj)
    end
end

function ui.standartButton(x, y, width, height, bColor, tColor, text, func, args)
    local newWidth = width
    if not width then newWidth = unicode.len(text) + 2 end
    return checkProperties(x, y, newWidth, height, {
        bColor=bColor, tColor=tColor, text=text, args=args, id=ui.ID.STANDART_BUTTON, draw=drawStandartButton, touch=func, flash=flashButton, toggle=toggleButton, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  BEAUTIFUL BUTTON  ------------------------------------------------------------------------------------
local function drawBeautifulButton(obj)
    local bColor, tColor = obj.bColor, obj.tColor
    if obj.args.symbol then symbol = obj.args.symbol end
    if obj.args.active then
        bColor = obj.tColor
        tColor = obj.bColor
        if obj.args.alpha then
            buffer.fillBlend(obj.globalX, obj.globalY * 2, obj.width, obj.height * 2, bColor, obj.args.alpha, true)
        else
            buffer.fill(obj.globalX, obj.globalY * 2, obj.width, 4, " ", bColor, nil, true)
        end
    else
        if obj.args.alpha then
            buffer.fillBlend(obj.globalX, obj.globalY, obj.width, obj.height, bColor, obj.args.alpha, false)
        else
            buffer.fill(obj.globalX, obj.globalY, obj.width, obj.height, " ", bColor, nil, false)
        end
        local up = "┌" .. string.rep("─", obj.width - 2) .. "┐"
        local down = "└" .. string.rep("─", obj.width - 2) .. "┘"
        local x2, y = obj.globalX + obj.width - 1, obj.globalY
        buffer.drawText(obj.globalX, y, nil, tColor, up)
        y = y + 1
        for i = 1, obj.height - 2 do
            buffer.drawText(obj.globalX, y, nil, tColor, "│")
            buffer.drawText(x2, y, nil, tColor, "│")
            y = y + 1
        end
        buffer.drawText(obj.globalX, y, nil, tColor, down)
    end
    buffer.drawText(math.floor(obj.globalX + obj.width / 2 - unicode.len(obj.text) / 2), math.floor(obj.globalY + obj.height / 2), nil, tColor, obj.text)
end

function ui.beautifulButton(x, y, width, height, bColor, tColor, text, func, args)
    local newWidth, newHeight = width, height
    if not width then newWidth = unicode.len(text) + 4 end
    if not height then newHeight = 3 end
    return checkProperties(x, y, newWidth, newHeight, {
        bColor=bColor, tColor=tColor, text=text, args=args, id=ui.ID.BEAUTIFUL_BUTTON, draw=drawBeautifulButton, touch=func, toggle=toggleButton, flash=flashButton, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  IMAGED BUTTON  ---------------------------------------------------------------------------------------
local function drawImagedButton(obj)
    if obj.args.active then
        buffer.drawImage(obj.globalX, obj.globalY, image.invert(obj.image))
    else
        buffer.drawImage(obj.globalX, obj.globalY, obj.image)
    end
end

function ui.imagedButton(x, y, data, func, args)
    return checkProperties(x, y, data.width, data.height, {
        image=data, args=args, id=ui.ID.IMAGED_BUTTON, draw=drawImagedButton, touch=func, flash=flashButton, toggle=toggleButton, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  STANDART TEXBOX  -------------------------------------------------------------------------------------
local function drawStandartTextbox(obj)
    local symbol, bColor, tColor = " ", obj.bColor, obj.tColor
    if obj.args.symbol then symbol = obj.args.symbol end
    if obj.args.active then
        bColor = obj.tColor
        tColor = obj.bColor
    end
    if obj.args.alpha then
        buffer.fillBlend(obj.globalX, obj.globalY, obj.width, obj.height, bColor, obj.args.alpha, obj.args.dPixel)
    else
        buffer.fill(obj.globalX, obj.globalY, obj.width, obj.height, symbol, bColor, nil, obj.args.dPixel)
    end
    local length = unicode.len(obj.text)
    if length < obj.width then
        if length == 0 then
            buffer.drawText(obj.globalX, obj.globalY, nil, tColor, obj.title)
        else
            buffer.drawText(obj.globalX, obj.globalY, nil, tColor, obj.text)
        end
    else
        buffer.drawText(obj.globalX, obj.globalY, nil, tColor, unicode.sub(obj.text, length - (obj.width - 1), -1))
    end
end

local function writeTextbox(obj)
    obj.args.active = true
    ui.draw(obj)
    while ui.eventHandling do
        local e = {event.pull()}
        local clickedObj
        if e[1] == "touch" then
            obj.args.active = false
            ui.draw(obj)
            if obj.enter then obj.enter(obj.text) end
            break
        elseif e[1] == "clipboard" then
            obj.text = obj.text .. e[3]
            ui.draw(obj)
            if obj.textChanged then obj.textChanged(obj.text) end
        elseif e[1] == "key_down" then
            if e[4] == 0x1C then -- ENTER
                obj.args.active = false
                ui.draw(obj)
                if obj.enter then obj.enter(obj.text) end
                break
            elseif e[4] == 0x0E then -- DELETE
                if obj.text ~= "" then obj.text = unicode.sub(obj.text, 1, -2) end
                ui.draw(obj)
            else
                if unicode.len(obj.text) < obj.max then
                    local symbol = codeToSymbol(e[3])
                    if symbol then obj.text = obj.text .. symbol end
                    ui.draw(obj)
                    if obj.textChanged then obj.textChanged(obj.text) end
                end
            end
        end
    end
end

function ui.standartTextbox(x, y, width, bColor, tColor, title, max, args)
    local newMax = max
    if not max then newMax = 1000 end
    return checkProperties(x, y, width, 1, {
        bColor=bColor, tColor=tColor, text="", title=title, max=newMax, args=args, id=ui.ID.STANDART_TEXTBOX, draw=drawStandartTextbox, write=writeTextbox, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  BEAUTIFUL TEXBOX  ------------------------------------------------------------------------------------
local function drawBeautifulTextbox(obj)
    local bColor, tColor = obj.bColor, obj.tColor
    if obj.args.symbol then symbol = obj.args.symbol end
    if obj.args.active then
        bColor = obj.tColor
        tColor = obj.bColor
    end
    if obj.args.alpha then
        buffer.fillBlend(obj.globalX, obj.globalY * 2, obj.width, 4, bColor, nil, obj.args.alpha, true)
    else
        buffer.fill(obj.globalX, obj.globalY * 2, obj.width, 4, " ", bColor, nil, true)
    end
    local length = unicode.len(obj.text)
    if length < obj.width - 2 then
        if length == 0 then
            buffer.drawText(obj.globalX + 1, obj.globalY + 1, nil, tColor, obj.title)
        else
            buffer.drawText(obj.globalX + 1, obj.globalY + 1, nil, tColor, obj.text)
        end
    else
        buffer.drawText(obj.globalX + 1, obj.globalY + 1, nil, tColor, unicode.sub(obj.text, length - (obj.width - 3), -1))
    end
end

function ui.beautifulTextbox(x, y, width, bColor, tColor, title, max, args)
    local newMax = max
    if not max then newMax = 1000 end
    return checkProperties(x, y, width, 3, {
        bColor=bColor, tColor=tColor, text="", title=title, max=newMax, args=args, id=ui.ID.BEAUTIFUL_TEXTBOX, draw=drawBeautifulTextbox, write=writeTextbox, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  STANDART CHECKBOX  -----------------------------------------------------------------------------------
local function drawStandartCheckbox(obj)
    local bColor, tColor, symbol = obj.bColor, obj.tColor, "X"
    if obj.args.symbol then symbol = obj.args.symbol end
    if obj.args.active then
        bColor = obj.tColor
        tColor = obj.bColor
    end
    if not obj.args.checked then symbol = " " end
    buffer.setPixel(obj.globalX, obj.globalY, symbol, bColor, tColor)
end

local function checkCheckbox(obj, delay)
    obj.args.active = true
    ui.draw(obj)
    os.sleep(delay or 0.3)
    obj.args.active = false
    if obj.args.checked then obj.args.checked = false else obj.args.checked = true end
    ui.draw(obj)
end

function ui.standartCheckbox(x, y, bColor, tColor, args)
    return checkProperties(x, y, 1, 1, {
        bColor=bColor, tColor=tColor, args=args, id=ui.ID.STANDART_CHECKBOX, draw=drawStandartCheckbox, check=checkCheckbox, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  CONTEXT MENU  ----------------------------------------------------------------------------------------
local function drawContextMenu(obj)
    if obj.args.visible then
        obj.image = buffer.crop(obj.globalX, obj.globalY, obj.width + 1, obj.height + 1)
        for i = 1, #obj.objs do
            if obj.args.alpha then
                buffer.fillBlend(obj.globalX, obj.globalY + i - 1, obj.width, 1, obj.bColor, obj.args.alpha)
            else
                buffer.fill(obj.globalX, obj.globalY + i - 1, obj.width, 1, " ", obj.bColor)
            end
            if obj.objs[i][1] == -1 then
                buffer.fill(obj.globalX, obj.globalY + i - 1, obj.width, 1, "─", nil, color.invert(obj.bColor))
            else
                buffer.drawText(obj.globalX + 1, obj.globalY + i - 1, nil, obj.tColor, obj.objs[i][1])
            end
        end
        if obj.shadow then
            buffer.fillBlend(obj.globalX + obj.width, obj.globalY * 2, 1, obj.height * 2, 0, 0.5, true)
            buffer.fillBlend(obj.globalX + 1, (obj.globalY + obj.height) * 2 - 1, obj.width - 1, 1, 0, 0.5, true)
        end
    end
end

local function doContextMenu(obj, doNotDraw)
    local state = true
    obj.args.visible = true
    if not doNotDraw then drawContextMenu(obj) end
    buffer.draw()
    while state do
        local e = {event.pull()}
        if e[1] == "touch" then
            local clickedObj, clickedSep
            for i = 1, #obj.objs do
                if e[3] >= obj.globalX and e[3] <= obj.globalX + obj.width - 1 and e[4] == obj.globalY + i - 1 then
                    if not (obj.objs[i][1] == -1) then
                        buffer.fill(obj.globalX, obj.globalY + i - 1, obj.width, 1, " ", color.invert(obj.bColor))
                        buffer.drawText(obj.globalX + 1, obj.globalY + i - 1, nil, color.invert(obj.tColor), obj.objs[i][1])
                        buffer.draw()
                        os.sleep(0.3)
                        buffer.fill(obj.globalX, obj.globalY + i - 1, obj.width, 1, " ", obj.bColor)
                        buffer.drawText(obj.globalX + 1, obj.globalY + i - 1, nil, obj.tColor, obj.objs[i][1])
                        buffer.draw()
                    end
                    clickedObj = obj.objs[i]
                    break
                end
            end
            if not clickedObj or not (clickedObj[1] == -1) then
                obj.args.visible, state = false, false
                buffer.drawImage(obj.globalX, obj.globalY, obj.image)
                if obj.args.closing then obj.args.closing() end
                buffer.draw()
                if clickedObj and clickedObj[2] then clickedObj[2](clickedObj[3]) end
            end
        end
    end
end

local function addContextMenuObject(obj, text, func, args)
    if not (text == -1) then
        local length = unicode.len(text)
        if length + 2 > obj.width then obj.width = length + 2 end
    end
    obj.height = obj.height + 1
    table.insert(obj.objs, {text, func, args})
end

local function removeContextMenuObject(obj, num)
    obj.objs[num] = nil
    obj.height = obj.height - 1
end

function ui.contextMenu(x, y, bColor, tColor, shadow, args)
    local newWidth, newArgs = 1, args
    if args.width then newWidth = args.width end
    newArgs.visible = false
    return checkProperties(x, y, newWidth, 0, {
        bColor=bColor, tColor=tColor, shadow=shadow, args=newArgs, objs={}, id=ui.ID.CONTEXT_MENU, show=doContextMenu, draw=drawContextMenu, addObj=addContextMenuObject, removeObj=removeContextMenuObject
    })
end

--  LISTBOX  -------------------------------------------------------------------------------------------------
local function drawListBox(obj)
    if obj.args.alpha then
        buffer.fillBlend(obj.globalX, obj.globalY, obj.width, obj.height, obj.bColor, obj.args.alpha, false)
    else
        buffer.fill(obj.globalX, obj.globalY, obj.width, obj.height, symbol, obj.bColor, nil, false)
    end
    if obj.shadow then
        buffer.fillBlend(obj.globalX + obj.width, obj.globalY * 2, 1, obj.height * 2, 0, 0.5, true)
        buffer.fillBlend(obj.globalX + 1, (obj.globalY + obj.height) * 2 - 1, obj.width - 1, 1, 0, 0.5, true)
    end
    for i = 1, #obj.objects do
        obj.objects[i].y = i
    end
end

local function addListBoxObject(obj, text, func, args)
    local newArgs = args or {}
    newArgs.indent = 1
    table.insert(obj.objects, ui.standartButton(1, 1, obj.width, 1, obj.bColor, obj.tColor, text, func, newArgs))
end

function ui.listBox(x, y, width, height, bColor, tColor, shadow, args)
    return checkProperties(x, y, width, height, {
        bColor=bColor, tColor=tColor, shadow=shadow, args=args, objs={}, id=ui.ID.LISTBOX, draw=drawListBox, addObj=addListBoxObject, cleanObjects=cleanObjects
    })
end

--  SCROLLBAR  -------------------------------------------------------------------------------------------
local function drawScrollbar(obj)
    buffer.fill(obj.globalX, obj.globalY, obj.width, obj.height, " ", obj.bColor, obj.tColor)
    buffer.setDrawing(obj.globalX, obj.globalY, obj.width, obj.height)
    ui.drawObject(obj.object, obj.globalX + 1, obj.globalY + 1)
    buffer.setDefaultDrawing()
    local lineHeight = math.floor(obj.height / (obj.object.height / obj.height))
    if lineHeight < 1 then lineHeight = 1 end
    if lineHeight > obj.height then lineHeight = obj.height end
    if not obj.args.hideBar and lineHeight < obj.height then
        buffer.fill(obj.globalX + obj.width - 1, obj.globalY, 1, obj.height, " ", obj.bColor, nil)
        buffer.fill(obj.globalX + obj.width - 1, obj.globalY + obj.position - 1, 1, lineHeight, " ", obj.tColor, nil)
    end
end

local function scrollbarScroll(obj, position, side)
    if obj.object.height > obj.height then
        if position == -1 then
            if side == 1 then
                obj.position = obj.position - 1
            else
                obj.position = obj.position + 1
            end
        else obj.position = position end
        local lineHeight = math.floor(obj.height / (obj.object.height / obj.height))
        if lineHeight < 1 then lineHeight = 1 end
        if lineHeight > obj.height then lineHeight = obj.height end
        if obj.position + lineHeight - 1 > obj.height then
            obj.position = obj.height - lineHeight + 1
        elseif obj.position < 1 then
            obj.position = 1
        end
        obj.object.y = -math.floor((obj.position - 1) * (obj.object.height / obj.height))
        ui.draw(obj)
    end
end

local function checkScrollbarClick(obj, x, y)
    if x == obj.globalX + obj.width - 1 and y >= obj.globalY + obj.position - 1 and y <= obj.globalY + obj.position + math.floor(obj.height / (obj.object.height / obj.height)) - 2 then
        return true
    end
end

function ui.scrollbar(x, y, width, height, bColor, tColor, object, args)
    return checkProperties(x, y, width, height, {
        bColor=bColor, tColor=tColor, object=object, position=1, args=args, id=ui.ID.SCROLLBAR, scroll=scrollbarScroll, draw=drawScrollbar, addObj=addObject, removeObj=removeObject
    })
end

--  PROGRESSBAR  -----------------------------------------------------------------------------------------
local function drawStandartProgressBar(obj)
    buffer.fill(obj.globalX, obj.globalY, obj.width, obj.height, " ", obj.bColor, nil)
    buffer.fill(obj.globalX, obj.globalY, math.floor((obj.width / obj.max) * obj.progress), obj.height, " ", obj.pColor, nil)
end

local function setPBProgress(obj, progress)
    obj.progress = progress
    ui.draw(obj)
end

function ui.standartProgressBar(x, y, width, height, bColor, pColor, max, progress, args)
    return checkProperties(x, y, width, height, {
        bColor=bColor, pColor=pColor, max=max, progress=progress, args=args, id=ui.ID.SCROLLBAR, setProgress=setPBProgress, draw=drawStandartProgressBar, addObj=addObject, removeObj=removeObject
    })
end

--  IMAGE  -----------------------------------------------------------------------------------------------
local function drawImage(obj)
    buffer.drawImage(obj.globalX, obj.globalY, obj.image)
end

function ui.image(x, y, data)
    return checkProperties(x, y, data.width, data.height, {
        image=data, id=ui.ID.IMAGE, draw=drawImage, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  CANVAS  ----------------------------------------------------------------------------------------------
local function drawCanvas(obj)
    buffer.drawImage(obj.globalX, obj.globalY, image.replaceNullSymbols(obj.image, "▒", -1, 0xFFFFFF))
end

function ui.canvas(x, y, currBColor, currTColor, currSymbol, data)
    return checkProperties(x, y, data.width, data.height, {
        image=data, currBColor=currBColor, currTColor=currTColor, currSymbol=currSymbol, drawing=true, id=ui.ID.CANVAS, draw=drawCanvas, addObj=addObject, removeObj=removeObject, cleanObjects=cleanObjects
    })
end

--  DRAWING  ---------------------------------------------------------------------------------------------
function ui.drawObject(obj, x, y)
    local newX, newY = x, y
    if x or y then newX, newY = x + obj.x - 1, y + obj.y - 1
    else newX, newY = obj.globalX, obj.globalY end
    if obj.args.visible and obj.args.enabled then
        obj.globalX, obj.globalY = newX, newY
        obj:draw(newX, newY)
        if obj.objects then
            for i = 1, #obj.objects do
                if obj.objects[i].args.visible and obj.objects[i].args.enabled then
                    ui.drawObject(obj.objects[i], newX, newY)
                end
            end
        end
    end
end

function ui.draw(obj, drawAll)
    if obj then ui.drawObject(obj) end
    buffer.draw(drawAll)
end

--  EVENT HANDLING  --------------------------------------------------------------------------------------
function ui.handleEvents(obj, args)
    args = args or {}
    ui.eventHandling = true
    ui.checkingObject = obj
    ui.args = args
    while ui.eventHandling do
        local e = {event.pull(ui.args.delay)}
        local clickedObj
        if e[3] and e[4] then clickedObj = ui.checkClick(ui.checkingObject, e[3], e[4]) end
        if clickedObj and clickedObj.args.enabled and clickedObj.args.visible then
            local newClickedObj = clickedObj
            -- Checking scrollbar object
            if clickedObj.object then
                local state = 1
                if clickedObj.args.hideBar then state = 0 end
                buffer.setDrawing(clickedObj.globalX, clickedObj.globalY, clickedObj.width - state, clickedObj.height)
                if e[3] < clickedObj.globalX + clickedObj.width - state then
                    local newClickedObj2 = ui.checkClick(clickedObj.object, e[3], e[4])
                    if newClickedObj2 then newClickedObj = newClickedObj2 end
                end
            end
            if e[1] == "touch" then
                if e[5] == 0 and not newClickedObj.args.disableActive and (newClickedObj.id == ui.ID.STANDART_BUTTON or newClickedObj.id == ui.ID.BEAUTIFUL_BUTTON
                or newClickedObj.id == ui.ID.IMAGED_BUTTON) then newClickedObj:flash()
                elseif newClickedObj.id == ui.ID.STANDART_TEXTBOX or newClickedObj.id == ui.ID.BEAUTIFUL_TEXTBOX then newClickedObj:write()
                elseif newClickedObj.id == ui.ID.STANDART_CHECKBOX then newClickedObj:check()
                elseif newClickedObj.id == ui.ID.CANVAS and newClickedObj.drawing then
                    local x, y = e[3] - newClickedObj.globalX + 1, e[4] - newClickedObj.globalY + 1
                    if newClickedObj.currSymbol == -1 then
                        newClickedObj.image:setPixel(x, y, -1, 0xFFFFFF)
                        buffer.new:setPixel(e[3], e[4], "▒", newClickedObj.currTransColor, 0xFFFFFF)
                        buffer.old:setPixel(e[3], e[4], "▒", newClickedObj.currTransColor, 0xFFFFFF)
                        local symbol, bColor, tColor = buffer.getPixel(e[3], e[4])
                        gpu.setBackground(bColor)
                        gpu.setForeground(tColor)
                        gpu.set(e[3], e[4], "▒")
                    else
                        newClickedObj.image:setPixel(x, y, newClickedObj.currSymbol, newClickedObj.currBColor)
                        buffer.new:setPixel(e[3], e[4], newClickedObj.currSymbol, newClickedObj.currBColor, newClickedObj.currTColor)
                        buffer.old:setPixel(e[3], e[4], newClickedObj.currSymbol, newClickedObj.currBColor, newClickedObj.currTColor)
                        gpu.setBackground(newClickedObj.currBColor)
                        gpu.setForeground(newClickedObj.currTColor)
                        gpu.set(e[3], e[4], newClickedObj.currSymbol)
                    end
                end
                if clickedObj.id == ui.ID.SCROLLBAR then
                    if not clickedObj.args.hideBar and checkScrollbarClick(clickedObj, e[3], e[4]) then
                        clickedObj.scrolling = true
                        clickedObj.scrollingY = e[4] - clickedObj.globalY - clickedObj.position + 2
                    end
                end
                if newClickedObj.touch then
                    newClickedObj.touch(newClickedObj.args.touchArgs, e[3], e[4], e[5], e[6])
                end
                if ui.args.touch then ui.args.touch(newClickedObj, e[3], e[4], e[5], e[6]) end
            elseif e[1] == "drag" then
                if clickedObj.id == ui.ID.SCROLLBAR then
                    if not checkScrollbarClick(clickedObj, e[3], e[4]) then
                        clickedObj.scrolling = false
                        clickedObj.scrollingY = nil
                    end
                    if clickedObj.scrollingY and e[4] - clickedObj.globalY - clickedObj.scrollingY + 2 > 0 then
                        clickedObj:scroll(e[4] - clickedObj.globalY - clickedObj.scrollingY + 2)
                    end
                end
                if newClickedObj.id == ui.ID.CANVAS and newClickedObj.drawing then
                    local x, y = e[3] - newClickedObj.globalX + 1, e[4] - newClickedObj.globalY + 1
                    if newClickedObj.currSymbol == -1 then
                        newClickedObj.image:setPixel(x, y, -1, 0xFFFFFF)
                        buffer.new:setPixel(e[3], e[4], "▒", newClickedObj.currTransColor, 0xFFFFFF)
                        buffer.old:setPixel(e[3], e[4], "▒", newClickedObj.currTransColor, 0xFFFFFF)
                        local symbol, bColor, tColor = buffer.getPixel(e[3], e[4])
                        gpu.setBackground(bColor)
                        gpu.setForeground(tColor)
                        gpu.set(e[3], e[4], "▒")
                    else
                        newClickedObj.image:setPixel(x, y, newClickedObj.currSymbol, newClickedObj.currBColor, newClickedObj.currBColor)
                        buffer.new:setPixel(e[3], e[4], newClickedObj.currSymbol, newClickedObj.currBColor, newClickedObj.currTColor)
                        buffer.old:setPixel(e[3], e[4], newClickedObj.currSymbol, newClickedObj.currBColor, newClickedObj.currTColor)
                        gpu.setBackground(newClickedObj.currBColor)
                        gpu.setForeground(newClickedObj.currTColor)
                        gpu.set(e[3], e[4], newClickedObj.currSymbol)
                    end
                end
                if clickedObj and clickedObj.drag then clickedObj.drag(newClickedObj.args.dragArgs) end
                if ui.args.drag then ui.args.drag(newClickedObj, e[3], e[4], e[5], e[6]) end
            elseif e[1] == "drop" then
                if clickedObj.id == ui.ID.SCROLLBAR then
                    clickedObj.scrolling = false
                    clickedObj.scrollingY = nil
                end
                if newClickedObj == ui.ID.CANVAS then ui.draw(newClickedObj) end
                if args.drop then args.drop(newClickedObj, e[3], e[4], e[5], e[6]) end
            elseif e[1] == "scroll" then
                if clickedObj and clickedObj.scroll then clickedObj:scroll(-1, e[5]) end
                if ui.args.scroll then ui.args.scroll(newClickedObj, e[3], e[4], e[5], e[6]) end
            end
            buffer.setDefaultDrawing()
        end
        if ui.args.whileFunc then ui.args.whileFunc() end
    end 
end

return ui