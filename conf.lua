function love.conf(t)
  t.title = "Expo Guía"
  t.version = "11.5"
  t.console = true
  t.window.resizable = true
  t.window.vsync = true
  t.window.msaa = 4  -- Añadir esta línea para activar el antialiasing

  t.modules.touch = true
  t.window.touch = true
  t.modules.graphics = true
end
