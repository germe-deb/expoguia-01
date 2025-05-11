-- SPDX-License-Identifier: MIT

-- Librería de UI hecha para ExpoGuía.
local ui = {}

-- Centra un objeto dentro de un contenedor, devolviendo los offsets en X e Y.
-- contW Ancho del contenedor.
-- contH Alto del contenedor.
-- bjW Ancho del objeto.
-- objH Alto del objeto.
-- aliX (Opcional) Alineación horizontal (0: izquierda, 1: derecha; por defecto 0.5).
-- aliY (Opcional) Alineación vertical (0: arriba, 1: abajo; por defecto 0.5).
-- return offX, offY: Desplazamientos en X e Y para alinear el objeto según lo indicado.
function ui.centered(contW, contH, objW, objH, aliX, aliY)
  -- por defecto alinear al centro en X y Y.
  aliX = aliX or 0.5
  aliY = aliY or 0.5

  local offX = (contW - objW) * aliX
  local offY = (contH - objH) * aliY

  return offX, offY
end

function ui.centeredtext(texto, alix, aliy, fuente, style, contW, contH)
    love.graphics.push()
    fuente = fuente or font_scp_16
    love.graphics.setFont(fuente)

	local color1, color2, color3, color4 = love.graphics.getColor()
    -- centrado
	local w, h
    local safe_x, safe_y, safe_w, safe_h = love.window.getSafeArea()
	
	w = contW or safe_w
	h = contH or safe_h 
	local offsetx, offsety = ui.centered(w, h, fuente:getWidth(texto), fuente:getHeight(), alix, aliy)

    
    if style == "normal" or style == nil then end
    if style == "bold" then end
    if style == "italic" then end
    if style == "enmarked" then
		love.graphics.push()
		-- 24 38 47
		love.graphics.setColor(24/255, 38/255, 47/255, 0.75)

		local boxoffsetx, boxoffsety = offsetx - 0.4*fuente:getHeight(), offsety - 0.25*fuente:getHeight()
		local boxwidth = fuente:getWidth(texto) + 0.8*fuente:getHeight()
		local boxheight = fuente:getHeight() + 0.5*fuente:getHeight()
		love.graphics.rectangle("fill", boxoffsetx, boxoffsety, boxwidth, boxheight)
		love.graphics.pop()
    end
    -- if style == fancy then end
	love.graphics.setColor(color1, color2, color3, color4)
		
	love.graphics.translate(math.floor(offsetx), math.floor(offsety))    
    love.graphics.print(texto)
    love.graphics.pop()
end

-- Lerp function
-- funciona así:
-- a es la posición inicial, o la posición real actual
-- b es la posición destino
-- t es la velocidad
function ui.lerp(a, b, t)
    return a + (b - a) * t
end

return ui
