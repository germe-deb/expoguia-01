-- SPDX-FileCopyrightText: 2025 dpkgluci
-- SPDX-FileCopyrightText: 2025 germe-deb <dpkg.luci@protonmail.com>
--
-- SPDX-License-Identifier: MIT

math.randomseed(os.time())


-- lick
local lick = require "lib/lick/lick"
lick.updateAllFiles = true
lick.clearPackages = true

lick.reset = true
lick.debug = true

-- dkjson
local json = require "lib/dkjson"

-- variables
local apptitle = "ExpoGuía"
local titlewide = love.graphics.newImage("assets/images/title-wide.png")
local titleinline = love.graphics.newImage("assets/images/title-inline.png")


-- mis librerías
local ui = require "assets/scripts/ui"

-- stands
local stands = {
    list = {},      -- lista completa de stands
    active = {},    -- stands seleccionados
    visible = {}    -- stands que pasan los filtros
}

-- automatizar los ID de los stands
function assignStandIds(stands)
    for i, stand in ipairs(stands) do
        stand.id = i
    end
    return stands
end

local jsonFile = love.filesystem.read("assets/json/stands.json")
if jsonFile then
    stands.list = json.decode(jsonFile)
    stands.list = assignStandIds(stands.list) -- Asignar IDs automáticamente
    stands.visible = stands.list
end
jsonFile = nil

-- juego
local gstate = 0
local debug = false
local showingstandinfo = false
ui.debug = debug
local fullscreen = false
-- ui.fullscreen = fullscreen
local safe_x, safe_y, safe_w, safe_h = 0, 0, 0, 0

local ui_unit = {x = 0, y = 0}
local area = {x = 0, y = 0}

local panel = {
    height = safe_h,    -- Altura fija en desktop
    width = 374,        -- Ancho fijo del panel
    x = -374,          -- Empieza fuera de la pantalla por la izquierda
    targetX = -374,    -- Target X position cuando está cerrado
    y = 0,             -- Y position fija en desktop
    -- Mobile properties
    targetHeight = 0,
    targetY = safe_h,
}

local panelScroll = {
    offset = 0,
    target = 0,
    maxScroll = 0,
    isDragging = false
}

-- variables para el botón de filtros
local filterbutton = {
    text = "Filtrar",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    buttoncolor = 1,
    icon = love.graphics.newImage("assets/images/filter_opt.png"),
    touchingbutton = false
}
local showingfilters = false

local function showversion()
	local version = 0.1
	print(apptitle .. " - version: " .. version)
	love.event.quit(0)
end

local function showhelp()
	local version = 0.1
	print(apptitle .. " - version: " .. version)
	print("help")
	print("====================================")
	print("	-h: show help")
	print("	-v: print version")
	print("	-M: force Mobile ui")
	print("	-D: force Desktop ui")
	print("	-d: debug info")
	love.event.quit(0)
end

-- fuente
-- local font_scp_16 = love.graphics.newFont("assets/fonts/SourceCodePro-Regular.otf", 16)
-- local font_scp_32 = love.graphics.newFont("assets/fonts/SourceCodePro-Regular.otf", 32)
local font_asap_16 = love.graphics.newFont("assets/fonts/Asap-Regular.otf", 16)
local font_asap_32 = love.graphics.newFont("assets/fonts/Asap-Regular.otf", 32)


-- Platform detection
local getplatform = love.system.getOS()
local mobile = false
if getplatform == "Android" or getplatform == "iOS" then
    mobile = true
-- elseif getplatform == "Windows" or getplatform == "Linux" or getplatform == "OS X" then
else
    mobile = false
end

local floorswitch = {
	currentfloor = 1,
	text = "ir a planta alta",
	x = 0,
	y = 0,
	w = 0,
	h = 0,
	buttoncolor = 1,
	animstate = 0,
	animtimer = 0,
	stair_up = love.graphics.newImage("assets/images/stair_up_opt.png"),
	stair_down = love.graphics.newImage("assets/images/stair_down_opt.png")
}

local touchingbutton = false

local swRmargx = 1.2*font_asap_16:getHeight()
local swRmargy = 0.7*font_asap_16:getHeight()
local swRx = floorswitch.x - swRmargx
local swRy = floorswitch.y - swRmargy
local swRw = floorswitch.w + swRmargx*2
local swRh = floorswitch.h + swRmargy*2

state1coordsset = false

local baseX = 0  -- Se actualizará en love.update
local baseY = 0  -- Se actualizará en love.update

-- autobloqueo.
local lock = {
	state = false,
	timer = 0
}

-- mapa
local mapposx, mapposy, mapscale = 0,0,1

local map = {
	floor1 = love.graphics.newImage("assets/images/example1.png"),
	floor2 = love.graphics.newImage("assets/images/example2.png"),
	x = 0,
	y = 0,
	s = 1, -- scale
	lx = 0, -- l es de lerp
	ly = 0, -- estas coordenadas se van a usar en animaciones
	ls = 1 -- como el cambio de la pantalla principal al mapa
}
-- la forma de usarlas va a ser así:
-- x, y, w, h, s van a ser usadas de manera directa por las funciones.
-- lx, ly, lw, lh, ls van a ser usadas para mostrar.
-- excepto en ciertas ocasiones como al abrir el programa,
-- las funciones l deben ser lerpeadas en love.update.

local puntero = {
	isDragging = false,
	lastx = 0,
	lasty = 0,
	lastPinchDist = nil
}

-- Añadir esta variable con las otras variables de estado
local initialScaleSet = false

function love.load()

    -- Obtener los argumentos de la línea de comandos
    local arguments = love.arg.parseGameArguments(arg)
    for i, v in ipairs(arguments) do
        if v == "-d" then debug = true end
        if v == "-M" then
        	mobile = true
        	fullscreen= false
        end
        if v == "-D" then
        	mobile = false
        	fullscreen= true
        end
        if v == "-v" then showversion() end
        if v == "-h" then showhelp() end
    end


    safe_x, safe_y, safe_w, safe_h = love.window.getSafeArea()

	-- panel.y = safe_h
    -- panel.targetY = safe_h

	-- cuestiones del mapa
	if mobile then
		map.x, map.y = safe_w*0.5, safe_h*0.5
		map.lx, map.ly = safe_w*0.5, safe_h*0.5
	elseif not mobile then
		map.x, map.y = safe_w*0.75, safe_h*0.5
		map.lx, map.ly = safe_w*0.75, safe_h*0.5
	end
    -- tratar de no inhibir el apagado automático de la pantalla
    love.window.setDisplaySleepEnabled(true)
	-- pantalla completa
    love.window.setFullscreen(fullscreen) 

	changefloor(1)
	
    -- lógica del botón de cambio de piso
	floorswitch.w = font_asap_16:getWidth(floorswitch.text) + floorswitch.stair_up:getWidth() + 10
    floorswitch.h = font_asap_16:getHeight()
	
    floorswitch.x, floorswitch.y = ui.centered(safe_w, safe_h*0.1, floorswitch.w, floorswitch.h)
   	floorswitch.y = safe_h*0.9+floorswitch.y

    -- lógica del botón de filtros
    filterbutton.w = font_asap_16:getWidth(filterbutton.text) + filterbutton.icon:getWidth() + 10
    filterbutton.h = font_asap_16:getHeight()
    filterbutton.x = safe_w - filterbutton.w - 20
    filterbutton.y = (safe_h * 0.1 - filterbutton.h) * 0.5

    -- Cargar datos de stands desde JSON
    local jsonFile = love.filesystem.read("assets/json/stands.json")
    if jsonFile then
        stands.list = json.decode(jsonFile)
        stands.visible = stands.list  -- Inicialmente todos visibles
        if debug then
            print("Stands cargados:", #stands.list)
        end
    end
end

function love.update(dt)

	if dt > 0.07 then
		dt = 0.07
	end

	safe_x, safe_y, safe_w, safe_h = love.window.getSafeArea()
	ui_unit.x = safe_w / 100
	ui_unit.y = safe_h / 100

	if gstate ~= 0 and lock.state == false then
		lock.state = true
	elseif gstate == 0 then
		lock.state = false
		lock.timer = 0
	end

	-- Check if there's any active touch or mouse press
	local isHolding = false
	
	-- Check for touch
	local touches = love.touch.getTouches()
	if #touches > 0 then
		isHolding = true
	end
	
	-- Check for mouse
	if love.mouse.isDown(1) then
		isHolding = true
	end

	if lock.state == true then
		if isHolding then
			lock.timer = 0
		else
			lock.timer = lock.timer + 1*dt
		end
	end

	if lock.timer >= 10 then
		lock.state = false
		changestate(0)
		changefloor(1)
	end

    -- ui.setBaseCoordinates(baseX, baseY)

	
    -- lógica del botón de cambio de piso
	
	swRmargx = 1.2*font_asap_16:getHeight()
	swRmargy = 0.7*font_asap_16:getHeight()

    -- Calcular el ancho total incluyendo ícono
    local totalWidth = font_asap_16:getWidth(floorswitch.text) + 
                      (floorswitch.currentfloor == 1 and floorswitch.stair_up:getWidth() or floorswitch.stair_down:getWidth()) + 
                      10 -- espacio entre ícono y texto

    floorswitch.w = totalWidth
    floorswitch.x, floorswitch.y = ui.centered(safe_w, safe_h*0.1, totalWidth, floorswitch.h)
    floorswitch.y = safe_h*0.9+floorswitch.y

    swRx = floorswitch.x - swRmargx
    swRy = floorswitch.y - swRmargy
    swRw = floorswitch.w + swRmargx*2
    swRh = floorswitch.h + swRmargy*2
	
    -- lógica del botón de filtros
    filterbutton.x = safe_w - filterbutton.w - 0.05*safe_h
    filterbutton.y = (safe_h * 0.1 - filterbutton.h) * 0.5


	-- actualizar color de vuelta a blanco para el botón de piso.
	if floorswitch.buttoncolor < 1 and not touchingbutton then
    	floorswitch.buttoncolor = floorswitch.buttoncolor+2*dt
    elseif floorswitch.buttoncolor > 1.1 then
    	floorswitch.buttoncolor = 1
   	end

    -- actualizar color de vuelta a blanco para el botón de filtros
    if filterbutton.buttoncolor < 1 and not filterbutton.touchingbutton then
        filterbutton.buttoncolor = filterbutton.buttoncolor+2*dt
    elseif filterbutton.buttoncolor > 1.1 then
        filterbutton.buttoncolor = 1
    end

   	-- map position lerp
   	map.lx = ui.lerp(map.lx, map.x, dt * 8)
   	map.ly = ui.lerp(map.ly, map.y, dt * 8)
   	map.ls = ui.lerp(map.ls, map.s, dt * 8)
   	-- map.lx = ui.lerp(map.lx, map.x, dt * 8)
   	-- map.ly = ui.lerp(map.ly, map.y, dt * 8)

	-- animar el piso
	animatefloor(floor, dt)

	-- código para que el mapa no se escape de la ventana
	local m = floorswitch.currentfloor == 1 and map.floor1 or map.floor2

	-- Calcular el tamaño actual del mapa con la escala
	local mapWidth = m:getWidth() * map.ls
	local mapHeight = m:getHeight() * map.ls

	-- Calcular las coordenadas de los bordes del mapa
	local mapLeft = map.x - (mapWidth / 2)  -- Borde izquierdo
	local mapRight = map.x + (mapWidth / 2) -- Borde derecho
	local mapTop = map.y - (mapHeight / 2)  -- Borde superior
	local mapBottom = map.y + (mapHeight / 2)-- Borde inferior

	-- Definir los límites de la pantalla (como porcentajes)
	local screenLeftLimit = safe_w * 0.8
	local screenRightLimit = safe_w * 0.2
	local screenTopLimit = safe_h * 0.7
	local screenBottomLimit = safe_h * 0.3

	-- Aplicar límites horizontales
	if mapLeft > screenLeftLimit then
	    map.x = screenLeftLimit + (mapWidth / 2)
	end
	if mapRight < screenRightLimit then
	    map.x = screenRightLimit - (mapWidth / 2)
	end

	-- Aplicar límites verticales
	if mapTop > screenTopLimit then
	    map.y = screenTopLimit + (mapHeight / 2)
	end
	if mapBottom < screenBottomLimit then
	    map.y = screenBottomLimit - (mapHeight / 2)
	end

    -- Update panel animations
    if mobile then
        panel.height = ui.lerp(panel.height, panel.targetHeight, dt * 8)
        panel.y = ui.lerp(panel.y, panel.targetY, dt * 8)
    else
        panel.x = ui.lerp(panel.x, panel.targetX, dt * 8)
    end
    
    -- Actualizar estado del panel
    if (mobile and panel.targetHeight == 0 and panel.height < 1) or
       (not mobile and panel.targetX == -panel.width and panel.x < -panel.width + 1) then
        showingstandinfo = false
    end

    -- Actualizar posición del scroll con lerp
    panelScroll.offset = ui.lerp(panelScroll.offset, panelScroll.target, 0.2)
end

function love.draw()
    -- Ajustar la posición vertical según el teclado
    love.graphics.push()
    love.graphics.translate(safe_x, safe_y)
    
    -- setear el background a azul profundo
    love.graphics.setBackgroundColor(24/255, 38/255, 47/255)
    -- setear la fuente por defecto
    love.graphics.setFont(font_asap_16)
    
    -- setear el color a blanco
    love.graphics.setColor(1, 1, 1, 1)

    drawui()

    love.graphics.pop()
end

function drawui()

	local _, _, safe_w, safe_h = love.window.getSafeArea()
	w, h = safe_w, safe_h
	if gstate == 0 then -- título
		
		love.graphics.setColor(1, 1, 1, 1)
		if mobile then
			map.x, map.y = safe_w*0.5, safe_h*0.5
			map.s = 0.5
			map.ls = map.s
			-- sacar la escala
			-- definimos el ancho target
			local targetWidth = safe_w * 0.75
			-- decimos que la escala es el target dividido el ancho de la imágen
		   	local titlescale = targetWidth / titlewide:getWidth()
		   	-- estos son los valores de ancho y alto ajustados por la escala
		   	-- son requeridos por los offsets
			local titlewidth  = titlewide:getWidth()*titlescale
			local titleheight = titlewide:getHeight()*titlescale
			-- esta función saca los offsets de dibujado
			local posx, posy = ui.centered(safe_w, safe_h, titlewidth, titleheight, 0.5, 0.5)
			-- sintaxis de love.graphics.draw
			-- love.graphics.draw( drawable, x, y, r, sx, sy, ox, oy, kx, ky )
			love.graphics.draw(titlewide, posx, posy, 0, titlescale, titlescale)
			
			-- love.graphics.setColor(1, 1, 1, 1)
			-- ui.centeredtext(apptitle, 0.5, 0.15, font_asap_32)
		else
			map.x, map.y = safe_w*0.75, safe_h*0.5
			
			drawmap()
			-- versión para escritorio
			-- sacar la escala
			-- definimos el ancho target
			local targetWidth = safe_w*0.5 * 0.75
			-- decimos que la escala es el target dividido el ancho de la imágen
		   	local titlescale = targetWidth / titlewide:getWidth()
		   	-- estos son los valores de ancho y alto ajustados por la escala
		   	-- son requeridos por los offsets
			local titlewidth  = titlewide:getWidth()*titlescale
			local titleheight = titlewide:getHeight()*titlescale
			-- esta función saca los offsets de dibujado
			local posx, posy = ui.centered(safe_w*0.5, safe_h, titlewidth, titleheight, 0.5, 0.5)
			-- sintaxis de love.graphics.draw
			-- love.graphics.draw( drawable, x, y, r, sx, sy, ox, oy, kx, ky )
			love.graphics.draw(titlewide, posx, posy, 0, titlescale, titlescale)
			
			-- love.graphics.setColor(1, 1, 1, 1)
			-- love.graphics.rectangle("fill", 0, 0, safe_w/2, safe_h)
			-- love.graphics.setColor(0, 0.19, 0.26)
			-- ui.centeredtext(apptitle, 0.5, 0.5, font_asap_32, "normal", safe_w/2, safe_h)
		end
		-- love.graphics.setColor(0, 0.19, 0.26, 0.75)
		-- love.graphics.rectangle("fill", w*0.25, h*0.8, w*0.5, h*0.1)
		love.graphics.setColor(1, 1, 1, 1)
		ui.centeredtext("Toca para empezar", 0.5, 0.87, font_asap_32, "enmarked")
	elseif gstate == 1 then -- menú posterior

		-- dibujar el mapa
		drawmap()
		-- dibujar información de los stands
		
		-- dibujar un rectangulo arriba
		love.graphics.setColor(13/255, 27/255, 36/255, 1)
		love.graphics.rectangle("fill", safe_w*0, safe_h*0, safe_w*1, safe_h*0.1)
		
		 -- Dibujar botón de filtros
        local fbx = filterbutton.x
        local fby = filterbutton.y
        local fbw = filterbutton.w
        local fbh = filterbutton.h
        -- Fondo del botón
        local r = (24+(filterbutton.buttoncolor*(255-24)))/255
        local g = (38+(filterbutton.buttoncolor*(255-37)))/255
        local b = (47+(filterbutton.buttoncolor*(255-47)))/255
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 
            fbx - swRmargx, 
            fby - swRmargy, 
            fbw + swRmargx*2, 
            fbh + swRmargy*2)
        -- Ícono y texto
        local textColor = 1 - (filterbutton.buttoncolor * (1 - 38/255))
        love.graphics.setColor(textColor, textColor, textColor, 1)
        love.graphics.draw(filterbutton.icon, fbx, fby + (fbh - filterbutton.icon:getHeight())*0.5)
        love.graphics.print(filterbutton.text, fbx + filterbutton.icon:getWidth() + 10, fby)

		-- dibujar un rectangulo abajo
		love.graphics.setColor(13/255, 27/255, 36/255, 1)
		love.graphics.rectangle("fill", safe_w*0, safe_h*0.9, safe_w*1, safe_h*1.0)
		-- dibujar el título pequeño arriba a la izquierda
		-- sacar la escala
		-- definimos el ancho target
		local targetHeight = safe_h*0.052
		-- decimos que la escala es el target dividido el ancho de la imágen
		local titlescale = targetHeight / titleinline:getHeight()
		-- estos son los valores de ancho y alto ajustados por la escala
		-- son requeridos por los offsets
		local titlewidth  = titleinline:getWidth()*titlescale
		local titleheight = titleinline:getHeight()*titlescale
		-- esta función saca los offsets de dibujado
		local posx, posy = ui.centered(safe_w, safe_h*0.11, titlewidth, titleheight, 0.05, 0.5)
		-- sintaxis de love.graphics.draw
		-- love.graphics.draw( drawable, x, y, r, sx, sy, ox, oy, kx, ky )
		love.graphics.setColor(1, 1, 1, 1) -- antes nos aseguramos de dibujar con blanco
		love.graphics.draw(titleinline, posx, posy, 0, titlescale, titlescale)
		love.graphics.setColor(0, 0, 0, 0.3)
		love.graphics.rectangle("fill", swRx, swRy+0.01*safe_h, swRw, swRh)
		-- inventar una cuenta matemática para que cuando
		-- floorswitch.buttoncolor sea 0, el color de este botón
		-- sea (13/255, 27/255, 36/255), y cuando
		-- floorswitch.buttoncolor sea 1, el color de este botón
		-- sea 1, 1, 1
		
		-- primera ocurrencia: una regla de 3 simple con un offset
		-- vamos a hacerlo por canal
		
		-- si buttoncolor es 0, entonces
		-- 1 ... 255/255
		-- 0 ... 13/255
		-- osea, un offset de 13, y un máximo de 255-13
		-- quedaría así la regla:
		-- offset = 13
		-- 1 ... 242
		-- 0 ... X
		
		-- ahora los colores son: (24/255, 38/255, 47/255)
		
		local r = (24+(floorswitch.buttoncolor*(255-24)))/255
		local g = (38+(floorswitch.buttoncolor*(255-37)))/255
		local b = (47+(floorswitch.buttoncolor*(255-47)))/255
		love.graphics.setColor(r, g, b, 1)
		love.graphics.rectangle("fill", swRx, swRy, swRw, swRh)
		
		-- Invertir el color del texto e ícono
		local textColor = 1 - (floorswitch.buttoncolor * (1 - 38/255))
		love.graphics.setColor(textColor, textColor, textColor, 1)
		love.graphics.setFont(font_asap_16)
		
		-- Dibujamos el ícono según el piso actual
		local icon = floorswitch.currentfloor == 1 and floorswitch.stair_up or floorswitch.stair_down
		love.graphics.draw(icon, 
			floorswitch.x, 
			floorswitch.y + (floorswitch.h - icon:getHeight())*0.5)
			
		-- Dibujamos el texto con offset para el ícono
		love.graphics.print(floorswitch.text, 
			floorswitch.x + icon:getWidth() + 10, 
			floorswitch.y)
		
		if showingstandinfo then drawstandinfo() end
		if showingfilters then ui.renderwindow("filter", font_asap_32, font_asap_16) end
		if showingabout then ui.renderwindow("about", font_asap_32, font_asap_16) end
	
	end

	-- dibujar un rectangulo oscuro por si acaso nomás
	-- love.graphics.setColor(13/255, 27/255, 36/255, 1)
	-- love.graphics.rectangle("fill", safe_w*-1, safe_h*1, safe_w*3, safe_h*1)
	
    -- INTERFAZ DEBUG
    if debug then showdebuginfo() end
end

function drawmap()
	local m
	if floorswitch.currentfloor == 1 then
		m = map.floor1
	elseif floorswitch.currentfloor == 2 then
		m = map.floor2
	end

	if gstate == 0 then
		-- codigo para sacar la escala
		local targetWidth = safe_w*0.45
		-- decimos que la escala es el target dividido el ancho de la imágen
	   	map.s = targetWidth / m:getWidth()
		initialScaleSet = false -- Reset cuando volvemos al estado 0
	elseif gstate == 1 and not initialScaleSet then
	   	-- codigo para sacar la escala INICIAL (ahora solo una vez)
		local targetHeight = safe_h*0.75
		-- decimos que la escala es el target dividido el ancho de la imágen
	   	map.s = targetHeight / m:getHeight()
		initialScaleSet = true -- Marcar que ya se estableció la escala inicial
	end
	
	love.graphics.setColor(1, 1, 1, 1) -- antes nos aseguramos de dibujar con blanco
	
	-- Dibujar el mapa base
	love.graphics.draw(m, map.lx, map.ly, 0, map.ls, map.ls, 
		0.5*m:getHeight(), 0.5*m:getWidth())
	
	-- Dibujar los stands
	for _, stand in ipairs(stands.visible) do
		if stand.floor == floorswitch.currentfloor then
			-- Convertir coordenadas del stand a coordenadas de pantalla
			local screenX = map.lx + (stand.x * map.ls)
			local screenY = map.ly + (stand.y * map.ls)
			
			-- Dibujar punto del stand
			if isStandActive(stand) then
				-- Stand seleccionado - color amarillo
				love.graphics.setColor(1, 1, 0, 1)
				love.graphics.circle("fill", screenX, screenY, 7 * map.ls)
			else
				-- Stand normal - usar color según especialidad
				if stand.especialidad == "E" then
					love.graphics.setColor(69/255, 155/255, 246/255, 1)
				elseif stand.especialidad == "C" then
					love.graphics.setColor(256/255, 160/255, 52/255, 1)
				elseif stand.especialidad == "IPP" then
					love.graphics.setColor(137/255, 233/255, 53/255, 1)
				else
					love.graphics.setColor(55/255, 246/255, 137/255, 1)
				end
				love.graphics.circle("fill", screenX, screenY, 5 * map.ls)
			end
		end
		love.graphics.setColor(1, 1, 1, 1)
	end
end

-- Función auxiliar para verificar si un stand está activo
function isStandActive(stand)
    for _, activeStand in ipairs(stands.active) do
        -- Comparar todas las propiedades relevantes ya que ahora no tenemos IDs en el JSON
        if activeStand.x == stand.x and 
           activeStand.y == stand.y and 
           activeStand.floor == stand.floor and
           activeStand.texto == stand.texto and
           activeStand.curso == stand.curso and
           activeStand.especialidad == stand.especialidad then
            return true
        end
    end
    return false
end

function showstandinfo(touchedStands)
    if showingstandinfo then
        hidestandinfo()
        -- Forzar una actualización inmediata
        love.graphics.present()
        love.timer.sleep(0.016)
    end

    if mobile then
        panel.height = 0
        panel.y = safe_h
        panel.targetHeight = safe_h * 0.5
        panel.targetY = safe_h * 0.5
    else
        panel.x = -panel.width
        panel.targetX = 0
        panel.height = safe_h
    end

    panelScroll.offset = 0
    panelScroll.target = 0
    panelScroll.maxScroll = 0
    panelScroll.isDragging = false

    stands.active = touchedStands
    showingstandinfo = true
end

function drawstandinfo()
    -- Siempre dibujamos el panel en desktop, solo verificamos height en mobile
    if mobile and panel.height <= 0 then return end
    
    love.graphics.setColor(1, 1, 1, 0.8)
    if mobile then
        love.graphics.rectangle("fill", 0, panel.y, safe_w, panel.height)
    else
        love.graphics.rectangle("fill", panel.x, 0, panel.width, safe_h)
    end

    -- Calcular maxScroll basado en el contenido
    local totalHeight = #stands.active * (180 + 10) + 10
    local visibleHeight = mobile and panel.height or safe_h
    panelScroll.maxScroll = math.max(0, totalHeight - visibleHeight)

    -- Actualizar posición del scroll con lerp
    panelScroll.offset = ui.lerp(panelScroll.offset, panelScroll.target, 0.2)

    -- Solo dibujar tarjetas si el panel es visible
    if (mobile and panel.height > 10) or (not mobile and panel.x > -panel.width) then
        -- Crear un stencil para recortar las tarjetas
        love.graphics.stencil(function()
            if mobile then
                love.graphics.rectangle("fill", 0, panel.y, safe_w, panel.height)
            else
                love.graphics.rectangle("fill", panel.x, 0, panel.width, safe_h)
            end
        end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)

        for i, stand in ipairs(stands.active) do
            local padding1 = 10
            local padding2 = 14
            local cardW = 350
            local cardH = 180
            local cardX, cardY
            
            if mobile then
                cardX = (safe_w - cardW) * 0.5
                cardY = panel.y + padding1 + ((cardH + padding1) * (i-1)) - panelScroll.offset
            else
                cardX = panel.x + 12
                cardY = padding1 + ((cardH + padding1) * (i-1)) - panelScroll.offset
            end
            
            -- Draw card background
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", cardX, cardY, cardW, cardH)
            
            -- Draw card specialty background
            if stand.especialidad == "E" then
                love.graphics.setColor(69/255, 155/255, 246/255, 1)
            elseif stand.especialidad == "C" then
                love.graphics.setColor(256/255, 160/255, 52/255, 1)
            elseif stand.especialidad == "IPP" then
                love.graphics.setColor(137/255, 233/255, 53/255, 1)
            else
                love.graphics.setColor(55/255, 246/255, 137/255, 1)
            end
            love.graphics.rectangle("fill", cardX+padding1, cardY+cardH-55-padding1, cardW-(padding1*2), 55)
            
            -- Draw card content
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setFont(font_asap_32)
            love.graphics.print(stand.texto, cardX + padding1, cardY + padding2)
            love.graphics.print(stand.curso .. stand.especialidad, cardX + padding1*2, cardY + cardH - 55 -3)
        end

        love.graphics.setStencilTest()
    end
end

function changestate(state)
	if state == 0 then
		gstate = 0
		if mobile then
			map.x, map.y = safe_w*0.5, safe_h*0.5
		elseif not mobile then
			map.x, map.y = safe_w*0.75, safe_h*0.5			
		end
		state1coordsset = false
		initialScaleSet = false
		changefloor(1)
	elseif state ==1 then
		gstate = 1
		if not state1coordsset then
			map.x, map.y = safe_w*0.5, safe_h*0.5
			state1coordsset = true
		end
	end
end

function changefloor(floor)
	showingstandinfo = false
	-- si el piso actual es diferente a floor,
	if floorswitch.currentfloor ~= floor and
	-- y el estado de la animación es 0
	floorswitch.animstate == 0 then
		-- hacer la animación de cambio de piso
		-- setear el estado animstate al piso al cual se va a ir
		if floor == 1 then
			floorswitch.animstate = 1
		elseif floor == 2 then
			floorswitch.animstate = 2
		end
		initialScaleSet = false
		floorswitch.animtimer = 0
	end

	if floor == 1 and floorswitch.animtimer > 0.01 then
		floorswitch.currentfloor = 1
		floorswitch.text = "Ir a Planta Alta"
	elseif floor == 2 and floorswitch.animtimer > 0.01 then
		floorswitch.currentfloor = 2
		floorswitch.text = "Ir a Planta Baja"
	end

	floordest = floorswitch.animstate
	floorcurr = floorswitch.currentfloor

	local m
	if floorswitch.currentfloor == 1 then
		m = map.floor1
	elseif floorswitch.currentfloor == 2 then
		m = map.floor2
	end
		
	-- si floorcurr es mayor a 0 y es menor al destino
	-- por ejemplo, piso actual 1 y destino 2	
	if tonumber(floorcurr) == 1 and tonumber(floordest) == 2 then
		map.y = map.ly + 0.25*m:getHeight()	
		
	-- si floordest es mayor a 0 y es menor al actual
	-- por ejemplo, piso actual 2 y destino 1
	elseif tonumber(floorcurr) == 2 and tonumber(floordest) == 1 then
		map.y = map.ly - 0.25*m:getHeight()
		
	end
	
	
end

function animatefloor(floor, dt)
	floordest = floorswitch.animstate
	floorcurr = floorswitch.currentfloor

	if floordest ~= 0 then
		floorswitch.animtimer = floorswitch.animtimer + 1*dt
	end

	local m
	if floorswitch.currentfloor == 1 then
		m = map.floor1
	elseif floorswitch.currentfloor == 2 then
		m = map.floor2
	end
	-- si floorcurr es mayor a 0 y es menor al destino
	-- por ejemplo, piso actual 1 y destino 2
	if tonumber(floorcurr) == 1 and tonumber(floordest) == 2 then
		if floorswitch.animtimer > 0.01 then
			changefloor(floordest)
			map.y = safe_h*0.5 - m:getHeight()*0.25
			map.ly = safe_h*0.5 - m:getHeight()*0.25
			floorswitch.animtimer = 0
			floorswitch.animstate = -1
			floorcurr = floordest
		end
		
	-- si floordest es mayor a 0 y es menor al actual
	-- por ejemplo, piso actual 2 y destino 1
	elseif tonumber(floorcurr) == 2 and tonumber(floordest) == 1 then
		if floorswitch.animtimer > 0.01 then
			changefloor(floordest)
			map.y = safe_h*0.5 + m:getHeight()*0.25
			map.ly = safe_h*0.5 + m:getHeight()*0.25
			floorswitch.animtimer = 0
			floorswitch.animstate = -1
			floorcurr = floordest
		end
	end

	if floorswitch.animstate == -1 then
		map.y = safe_h*0.5
		map.x = safe_w*0.5
		floorswitch.animstate = 0
	end
end

function togglefilters()
	-- Alternar entre mostrar y ocultar los filtros en pantalla
    showingfilters = not showingfilters
end

function zooming(deltaZoom, x, y)
    -- Límites de zoom (ajusta estos valores según necesites)
    local minZoom = 0.25
    local maxZoom = 6
    
    -- Guardar escala anterior para cálculos
    local oldScale = map.s
    
    -- Aplicar el zoom con límites
    map.s = math.min(maxZoom, math.max(minZoom, map.s + deltaZoom))
    
    -- Si el zoom cambió, ajustar la posición del mapa para zoom hacia el punto
    if oldScale ~= map.s then
        local dx = x - map.x
        local dy = y - map.y
        local scaleFactor = map.s / oldScale
        
        map.x = x - dx * scaleFactor
        map.y = y - dy * scaleFactor
    end
end

function love.wheelmoved(x, y)
    if gstate == 1 and not showingstandinfo then
        local mx, my = love.mouse.getPosition()
        local zoomSpeed = 0.1
        zooming(y * zoomSpeed, mx, my)
    end
	lock.timer = 0
end

function handleMoving(x, y, dx, dy, istouch)
    if gstate == 1 then
        -- Check if we're interacting with the panel
        local isInPanel = false
        if showingstandinfo then
            if mobile then
                isInPanel = y >= panel.y
            else
                isInPanel = x >= panel.x and x <= panel.x + panel.width
            end
            
            -- If dragging started in panel, handle panel scroll
            if isInPanel and puntero.isDragging then
                if mobile then
                    panelScroll.target = math.max(0, math.min(panelScroll.maxScroll, panelScroll.target - dy))
                else
                    -- En desktop también necesitamos scroll vertical
                    panelScroll.target = math.max(0, math.min(panelScroll.maxScroll, panelScroll.target - dy))
                end
                return
            end
        end
        
        -- If not interacting with panel, handle map movement normally
        if not isInPanel then
            local touches = love.touch.getTouches()
            local numTouches = #touches
            
            if numTouches >= 2 then
                -- Obtener las posiciones de los dos primeros toques
                local x1, y1 = love.touch.getPosition(touches[1])
                local x2, y2 = love.touch.getPosition(touches[2])
                
                -- Calcular la distancia actual entre los toques
                local currentDist = math.sqrt((x2-x1)^2 + (y2-y1)^2)
                
                -- Si es el primer frame del pinch, guardar la distancia inicial
                if not puntero.lastPinchDist then
                    puntero.lastPinchDist = currentDist
                end
                
                -- Calcular el factor de zoom basado en el cambio de distancia
                local pinchDelta = currentDist - puntero.lastPinchDist
                local zoomSpeed = 0.005
                local deltaZoom = pinchDelta * zoomSpeed
                
                -- Punto central del pinch para zoom
                local centerX = (x1 + x2) / 2
                local centerY = (y1 + y2) / 2
                
                -- Aplicar zoom
                zooming(deltaZoom, centerX, centerY)
                
                -- También permitir movimiento durante el zoom
                if puntero.isDragging then
                    -- Usar el centro del pinch para el movimiento
                    local adjustedDx = dx / numTouches
                    local adjustedDy = dy / numTouches
                    
                    map.x = map.x + adjustedDx
                    map.y = map.y + adjustedDy
                end
                
                -- Actualizar la última distancia
                puntero.lastPinchDist = currentDist
            else
                -- Resetear la distancia del pinch cuando no hay dos dedos
                puntero.lastPinchDist = nil
                
                -- Manejar el arrastre normal
                if puntero.isDragging then
                    -- Dividir el movimiento por la cantidad de toques
                    local adjustedDx = dx / math.max(1, numTouches)
                    local adjustedDy = dy / math.max(1, numTouches)
                    
                    map.x = map.x + adjustedDx
                    map.y = map.y + adjustedDy
                end
            end
            
            -- Actualizar última posición siempre
            if puntero.isDragging then
                puntero.lastx = x
                puntero.lasty = y
            end
        end
    end
end

function standcheck(x, y)
    -- Verificar si el toque está en el área válida del mapa
    if y > safe_h * 0.1 and y < safe_h * 0.9 then
        local m = floorswitch.currentfloor == 1 and map.floor1 or map.floor2
        
        -- Convertir coordenadas de pantalla a coordenadas relativas al mapa
        local relX = (x - map.lx) / map.ls
        local relY = (y - map.ly) / map.ls
        
        -- Radio de tolerancia para toques (ajustable según necesidad)
        local touchRadius = 20 / map.ls
        
        -- Buscar stands tocados
        local touchedStands = {}
        for _, stand in ipairs(stands.visible) do
            if stand.floor == floorswitch.currentfloor then
                local dx = stand.x - relX
                local dy = stand.y - relY
                local distance = math.sqrt(dx*dx + dy*dy)
                
                if distance < touchRadius then
                    table.insert(touchedStands, stand)
                    if debug then
                        print(string.format("Stand tocado: %s (Curso %d)", 
						stand.texto, stand.curso))
                    end
                end
            end
        end
		if debug then print(string.format("Relative map coordinates: x=%.2f, y=%.2f", relX, relY)) end
        
        -- Si encontramos stands, mostrar su información
        if #touchedStands > 0 then
            -- Si ya hay un stand activo y tocamos el mismo, cerrar el panel
            if showingstandinfo and #stands.active == 1 and
               #touchedStands == 1 and
               stands.active[1].id == touchedStands[1].id then
                hidestandinfo()
            else
                stands.active = touchedStands
                showingstandinfo = true
                showstandinfo(touchedStands)
            end
        end
    end
end

function love.keypressed(key, scancode, isrepeat)
    if key == 'escape' then
        love.event.quit()
    elseif key == "f11" then
        fullscreen = not fullscreen
        love.window.setFullscreen(fullscreen)
    elseif key == "f6" then
        debug = not debug
    elseif key == "f7" then
        mobile = not mobile
    -- teclas para cambiar el estado
    elseif key == "f1" then
		changestate(0)
    -- teclas para cambiar el estado
    elseif key == "f2" then
		changestate(1)
    elseif key == "f3" then
        showingstandinfo = not showingstandinfo
    elseif key == "f4" then
        showingabout = not showingabout
    end

    -- debug, mover el mapa
    if key == "up" then
        map.y = map.y - 10
    elseif key == "left" then
        map.x = map.x - 10
    elseif key == "down" then
        map.y = map.y + 10
    elseif key == "right" then
        map.x = map.x + 10
    end
end

function love.keyreleased(key, scancode, isrepeat)

end


-- Esta función sólo se llama cuando hay una interacción con la pantalla.
function handleInteraction(x, y, presstype, inputtype)
    -- volver el timer a 0 al tocar
    lock.timer = 0
    
    if gstate == 0 then
        changestate(1)
        return
    end
    
    if gstate == 1 then
        local isInPanel = false
        if showingstandinfo then
            if mobile then
                isInPanel = y >= panel.y
            else
                isInPanel = x >= panel.x and x <= panel.x + panel.width
            end
            
            -- Si tocamos fuera del panel, cerrar el panel
            if (mobile and y < panel.y) or
               (not mobile and (x < panel.x or x > panel.x + panel.width)) then
                hidestandinfo()
            end
        end

        -- Si estamos tocando dentro del panel, solo manejar scroll
        if isInPanel then
            puntero.isDragging = true
            puntero.lastx = x
            puntero.lasty = y
            return
        end

        -- Procesar botones y otras interacciones normalmente
        local buttonPressed = false
        
        -- Comprobar botón de filtros
        local fbx = filterbutton.x - swRmargx
        local fby = filterbutton.y - swRmargy
        local fbw = filterbutton.w + swRmargx*2
        local fbh = filterbutton.h + swRmargy*2
        
        if x > fbx and x < fbx+fbw and
           y > fby and y < fby+fbh then
            filterbutton.touchingbutton = true
            filterbutton.buttoncolor = 0
            buttonPressed = true
        end

        -- si se toca el botón de cambio de piso
        if x > swRx and x < swRx+swRw and
           y > swRy and y < swRy+swRh then
            touchingbutton = true
            floorswitch.buttoncolor = 0
            buttonPressed = true
        end

        -- si se toca el Título
        local targetHeight = safe_h*0.052
        local ts = targetHeight / titleinline:getHeight()
        local tw = titleinline:getWidth()*ts
        local th = titleinline:getHeight()*ts
        local tx, ty = ui.centered(safe_w, safe_h*0.11, tw, th, 0.05, 0.5)

        if x > tx and x < tx+tw and
           y > ty and y < ty+th then
            changestate(0)
            buttonPressed = true
        end

        -- Si no se presionó ningún botón, iniciar arrastre o checkear stands
        if not buttonPressed then
            puntero.isDragging = true
            puntero.lastx = x
            puntero.lasty = y
            if not showingstandinfo then
                standcheck(x, y)
            end
        end
    end
end

function handleRelease(x, y, releasetype, inputtype)
    if gstate == 1 then
        -- Comprobar si estábamos tocando el botón y seguimos sobre él
        if touchingbutton and
           x > swRx and x < swRx+swRw and
           y > swRy and y < swRy+swRh then
            -- Cambiar el piso al soltar
            if floorswitch.currentfloor == 1 then
                changefloor(2)
            else
                changefloor(1)
            end
        end
        touchingbutton = false

        -- Comprobar si estábamos tocando el botón de filtros y seguimos sobre él
        local fbx = filterbutton.x - swRmargx
        local fby = filterbutton.y - swRmargy
        local fbw = filterbutton.w + swRmargx*2
        local fbh = filterbutton.h + swRmargy*2
        
        if filterbutton.touchingbutton and
           x > fbx and x < fbx+fbw and
           y > fby and y < fby+fbh then
            togglefilters()
        end
        filterbutton.touchingbutton = false
    end
    -- Finalizar arrastre
    puntero.isDragging = false
end

function love.mousemoved(x, y, dx, dy, istouch)
    if not istouch then  -- Solo si no es un toque
        handleMoving(x, y, dx, dy, false)
    end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    handleMoving(x, y, dx, dy, true)
end

-- Modificar love.touchpressed para usar la nueva función
function love.touchpressed(id, x, y, dx, dy, pressure)
    handleInteraction(x, y, "pressed", "touch")
end

function love.mousepressed(x, y, button, istouch)
    if button == 1 and not istouch then  -- Solo click izquierdo y no es un toque
        handleInteraction(x, y, "pressed", "mouse")
    end
end

function love.mousereleased(x, y, button, istouch)
    if button == 1 and not istouch then  -- Solo click izquierdo y no es un toque
        handleRelease(x, y, "released", "mouse")
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    handleRelease(x, y, "released", "touch")
end

function showdebuginfo()
	-- mover el cursor hacia abajo
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", 0, 0, safe_w, safe_h)
    love.graphics.setFont(font_asap_16)
    love.graphics.print("gstate: " .. tostring(gstate), 10, 1*20)
    love.graphics.print("mobile: " .. tostring(mobile), 10, 2*20)
    love.graphics.print("safe_w: " .. tostring(safe_w), 10, 3*20)
    love.graphics.print("safe_h: " .. tostring(safe_h), 10, 4*20)
    love.graphics.print("1px= " .. tostring(love.window.toPixels(1)), 10, 5*20)
    love.graphics.print("ui_unit.x: " .. tostring(ui_unit.x), 10, 6*20)
    love.graphics.print("ui_unit.y: " .. tostring(ui_unit.y), 10, 7*20)
    love.graphics.print("lock.state: " .. tostring(lock.state), 10, 8*20)
    love.graphics.print("lock.timer: " .. tostring(lock.timer), 10, 9*20)
    if map.floor1 then
        love.graphics.print("floor1: OK", 10, 10*20)
    else
        love.graphics.print("floor1: NULL", 10, 10*20)
    end
    if map.floor2 then
        love.graphics.print("floor2: OK", 10, 11*20)
    else
        love.graphics.print("floor2: NULL", 10, 11*20)
    end
	love.graphics.print("floorswitch.animstate: " .. tostring(floorswitch.animstate), 10, 12*20)
	love.graphics.print("floorswitch.currentfloor: " .. tostring(floorswitch.currentfloor), 10, 13*20)
    
    -- Añadir información sobre el mapa y coordenadas
    local m = floorswitch.currentfloor == 1 and map.floor1 or map.floor2
    if m then
        love.graphics.print("Map dimensions:", 10, 14*20)
        love.graphics.print(string.format("  Width: %d", m:getWidth()), 10, 15*20)
        love.graphics.print(string.format("  Height: %d", m:getHeight()), 10, 16*20)
        love.graphics.print(string.format("  Scale: %.2f", map.ls), 10, 17*20)
        
        -- Mostrar coordenadas del mouse relativas al mapa
        local mx, my = love.mouse.getPosition()
        local relX = (mx - map.lx) / map.ls
        local relY = (my - map.ly) / map.ls
        love.graphics.print(string.format("Mouse relative coords: %.2f, %.2f", relX, relY), 10, 18*20)
    end
    
    -- Mostrar información de toques activos
    local touches = love.touch.getTouches()
    for i, id in ipairs(touches) do
        local tx, ty = love.touch.getPosition(id)
        love.graphics.print("Touch " .. i ..
        					": x=" .. tx ..
        					" y=" .. ty,
        					0, 200 + i * 20)
    end
end

function hidestandinfo()
    if mobile then
        panel.targetHeight = 0
        panel.targetY = safe_h
    else
        -- Usar la misma lógica que en móvil: primero setear la posición actual
        panel.x = panel.x
        -- Luego setear el target
        panel.targetX = -panel.width
    end
    
    panelScroll.offset = 0
    panelScroll.target = 0
    panelScroll.isDragging = false
end
