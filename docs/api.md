# Integration

If you want to use the highlight library, call the function `IsValid` on the `highlight` table:

```Lua
if IsValid( highlight ) then -- true when installed, otherwise false
-- your highlight code here
end
```

# Colors

> **NOTE**<br>
> Users are able to modify colors to suit their preferences.

If you want to add a unique highlight color, use the method `AddColor`:

```Lua
if IsValid( highlight ) then
	highlight.AddColor( 'legendary', '128 0 255 255' )
end
```

# Classes

To make your entity have a highlight, you must assign a color to it via `AddClass`:

```Lua
if IsValid( highlight ) then
	highlight.AddClass( 'sent_ball', 'legendary' )
end
```

# Drawing

> **NOTE**<br>
> Drawing manually means your entity is separate from the render queue.

To draw a highlight manually, all you need to do is call `Draw`:

```Lua
ENT.PrintName = 'Rare Item'
ENT.RareColor = Color( 255, 0, 0 ) -- red

function ENT:Draw( flags )

	self:DrawModel( flags )

	if IsValid( highlight ) then
		-- draw highlight via a field without AddColor/AddClass
		highlight.Draw( self:WorldSpaceCenter(), self.RareColor, self.PrintName )
	end

end
```
