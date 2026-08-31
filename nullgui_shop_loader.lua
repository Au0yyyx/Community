local base = "https://raw.githubusercontent.com/Au0yyyx/Community/main/nullgui_shop/part%d.lua.txt?t=" .. os.time()
local chunks = table.create(6)
for index = 1, 6 do
    chunks[index] = game:HttpGet(string.format(base, index))
end
local source = table.concat(chunks)
local compiled, compileError = loadstring(source, "NULLGUI+ShopAI")
assert(compiled, compileError)
return compiled()

