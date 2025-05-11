-- SPDX-FileCopyrightText: 2025 dpkgluci
--
-- SPDX-License-Identifier: MIT

-- math.randomseed(os.time())


-- lick
local lick = require "lib/lick/lick"
lick.updateAllFiles = true
lick.clearPackages = true

lick.reset = true
lick.debug = true

-- dkjson
local json = require "lib/dkjson"

-- variables
apptitle = "ExpoGuía"
titlewide = love.graphics.newImage("assets/images/title-wide.png")
titleinline = love.graphics.newImage("assets/images/title-inline.png")

-- mis librerías
local ui = require "assets/scripts/ui"


-- juego
gstate = 0
local debug = false
ui.debug = debug
local fullscreen = false
-- ui.fullscreen = fullscreen
local safe_x, safe_y, safe_w, safe_h = 0, 0, 0, 0

local ui_unit = {x = 0, y = 0}
local area = {x = 0, y = 0}

function showversion()
	local version = 0.1
	print(apptitle .. " - version: " .. version)
	love.event.quit(0)
end

function showhelp()
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
local font_scp_16 = love.graphics.newFont("assets/fonts/SourceCodePro-Regular.otf", 16)
local font_scp_32 = love.graphics.newFont("assets/fonts/SourceCodePro-Regular.otf", 32)
local font_asap_16 = love.graphics.newFont("assets/fonts/Asap-Regular.otf", 16)
local font_asap_32 = love.graphics.newFont("assets/fonts/Asap-Regular.otf", 32)


-- Platform detection
local getplatform = love.system.getOS()
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
	buttoncolor = 1
}
local touchingbutton = false

local swRmargx = 1.2*font_asap_16:getHeight()
local swRmargy = 0.7*font_asap_16:getHeight()
local swRx = floorswitch.x - swRmargx
local swRy = floorswitch.y - swRmargy
local swRw = floorswitch.w + swRmargx*2
local swRh = floorswitch.h + swRmargy*2

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
	floor1 = love.graphics.newImage("assets/images/default_grid.jpg"),
	floor2 = love.graphics.newImage("assets/images/default_grid.jpg"),
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

	floorswitch.text = "Ir a Planta Alta"
	
    -- lógica del botón de cambio de piso
	floorswitch.w, floorswitch.h = font_asap_16:getWidth(floorswitch.text), font_asap_16:getHeight()
	
    floorswitch.x, floorswitch.y = ui.centered(safe_w, safe_h*0.1, floorswitch.w, floorswitch.h)
   	floorswitch.y = safe_h*0.9+floorswitch.y

end

function love.update(dt)
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
	end

    -- ui.setBaseCoordinates(baseX, baseY)

	
    -- lógica del botón de cambio de piso
	
	swRmargx = 1.2*font_asap_16:getHeight()
	swRmargy = 0.7*font_asap_16:getHeight()
	swRx = floorswitch.x - swRmargx
	swRy = floorswitch.y - swRmargy
	swRw = floorswitch.w + swRmargx*2
	swRh = floorswitch.h + swRmargy*2

    floorswitch.x, floorswitch.y = ui.centered(safe_w, safe_h*0.1, font_asap_16:getWidth(floorswitch.text), font_asap_16:getHeight())
   	floorswitch.y = safe_h*0.9+floorswitch.y
	

	-- actualizar color de vuelta a blanco.
	if floorswitch.buttoncolor < 1 and not touchingbutton then
    	floorswitch.buttoncolor = floorswitch.buttoncolor+2*dt
    elseif floorswitch.buttoncolor > 1.1 then
    	floorswitch.buttoncolor = 1
   	end

   	-- map position lerp
   	map.lx = ui.lerp(map.lx, map.x, dt * 8)
   	map.ly = ui.lerp(map.ly, map.y, dt * 8)
   	-- map.lx = ui.lerp(map.lx, map.x, dt * 8)
   	-- map.ly = ui.lerp(map.ly, map.y, dt * 8)
end

-- Modificar la función love.draw
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
		
		if mobile then
			map.x, map.y = safe_w*0.5, safe_h*0.5
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
		map.x, map.y = safe_w*0.5, safe_h*0.5

		drawmap()
		-- dibujar un rectangulo arriba
		love.graphics.setColor(13/255, 27/255, 36/255, 1)
		love.graphics.rectangle("fill", safe_w*0, safe_h*0, safe_w*1, safe_h*0.1)

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
		
		-- Invertir el color del texto
		-- Cuando buttoncolor es 0 (fondo oscuro) -> texto blanco (1)
		-- Cuando buttoncolor es 1 (fondo claro) -> texto gris oscuro (38/255)
		local textColor = 1 - (floorswitch.buttoncolor * (1 - 38/255))
		love.graphics.setColor(textColor, textColor, textColor, 1)
		love.graphics.print(floorswitch.text, floorswitch.x, floorswitch.y)

		
	
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
	love.graphics.draw(m, map.lx, map.ly, 0, map.ls, map.ls, 0.5*map.floor1:getHeight(), 0.5*map.floor1:getWidth())
end

function changestate(state)
	if state == 0 then
		gstate = 0
		if mobile then
			map.x, map.y = safe_w*0.5, safe_h*0.5
		elseif not mobile then
			map.x, map.y = safe_w*0.75, safe_h*0.5			
		end
	elseif state ==1 then
		gstate = 1
		if mobile then
			map.x, map.y = safe_w*0.5, safe_h*0.5
		elseif not mobile then
			map.x, map.y = safe_w*0.5, safe_h*0.5			
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
	-- teclas para cambiar el estado
    elseif key == "f3" then
            gstate = 2
    end
end


-- Esta función sólo se llama cuando hay una interacción con la pantalla.
function handleInteraction(x, y, presstype, inputtype)

	
    -- volver el timer a 0 al tocar
	lock.timer = 0
    
    if debug then
        print("Touch coordinates: ", x, y)
    end

	
    if gstate == 0 then
		-- si se toca la pantalla en la pantalla de título, cambiar al mapa
		changestate(1)
		-- avisar que se cambió a la pantalla del mapa
		if debug then print("gstate is now 1") end
		floorswitch.currentfloor = 1
		floorswitch.text = "Ir a Planta Alta"
		
	elseif gstate ==1 then
		-- acá es donde se pone complicado
		
		-----------------------------------------------------
		-- si se toca el botón de cambio de piso
		local areatouched = false
		if x > swRx and x < swRx+swRw and
		   y > swRy and y < swRy+swRh then
		    -- entonces, se tocó.
		    areatouched = true
		    touchingbutton = true
		    floorswitch.buttoncolor = 0
		else
		    -- no se tocó.
		    areatouched = false
		end

		-----------------------------------------------------
		-- si se toca el Título
		areatouched = false

		local targetHeight = safe_h*0.052
		-- decimos que la escala es el target dividido el ancho de la imágen
	   	local ts = targetHeight / titleinline:getHeight()
	   	
		local tw  = titleinline:getWidth()*ts
		local th = titleinline:getHeight()*ts
		local tx, ty = ui.centered(safe_w, safe_h*0.11, tw, th, 0.05, 0.5)

		if 	x > tx and	x < tx+tw and
			y > ty and	y < ty+th then
			-- entonces, se tocó.
			areatouched = true
		else
			-- no se tocó.
			areatouched = false
		end

		-- si se tocó, y el piso era 1, entonces ahora es 2
		if areatouched then
			changestate(0)
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
                floorswitch.currentfloor = 2
                floorswitch.text = "Ir a Planta Baja"
            else
                floorswitch.currentfloor = 1
                floorswitch.text = "Ir a Planta Alta"
            end
        end
        touchingbutton = false
    end
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

function love.mousemoved(x, y, dx, dy, istouch)
    --[[
		if button == 1 and not istouch then  -- Solo click izquierdo y no es un toque
			handleInteraction(x, y, "released", "mouse")
		end
	]]
end

function love.touchmoved(id, x, y, dx, dy, pressure)
	-- Implementar arrastre si lo necesitas
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
