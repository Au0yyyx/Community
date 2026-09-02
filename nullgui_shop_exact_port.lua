if not game:IsLoaded()then game.Loaded:Wait()end
local RS=game:GetService("ReplicatedStorage");local Players=game:GetService("Players");local Env=getgenv and getgenv()or _G
local old=Env.__NullShopExactPort;if old and old.Destroy then old:Destroy()end
local App={Connections={},Selected={}};Env.__NullShopExactPort=App
local calc=Env.__NullscapeShopAI_V1
if not(calc and calc.Calculate)then Env.__NullscapeShopAIEmbedded=true;loadstring(game:HttpGet("https://raw.githubusercontent.com/Au0yyyx/Community/main/nullscape_shop_ai.lua?t="..os.time()))();calc=Env.__NullscapeShopAI_V1 end
if calc.Frame then calc.Frame.Visible=false end
local root=(gethui and gethui())or game.CoreGui;local host
for _,x in ipairs(root:GetDescendants())do if x.Name=="Shop AI"and x:IsA("ScrollingFrame")and x.Parent.Name=="Elements"then host=x break end end
assert(host,"Open/reload NULLGUI first")
for _,x in ipairs(host:GetChildren())do if x.Name~="UIListLayout"then x.Visible=false end end
local oldPort=host:FindFirstChild("ExactShopCalculator");if oldPort then oldPort:Destroy()end
local port=Instance.new("Frame");port.Name="ExactShopCalculator";port.BackgroundColor3=Color3.fromRGB(240,240,242);port.BorderSizePixel=0;port.Size=UDim2.new(1,-8,0,900);port.LayoutOrder=-100;port.Parent=host
host.CanvasSize=UDim2.fromOffset(0,900)
local function txt(parent,text,pos,size,font,color,align)local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=text;l.Position=pos;l.Size=size;l.Font=font or Enum.Font.Gotham;l.TextColor3=color or Color3.fromRGB(25,25,28);l.TextSize=13;l.TextWrapped=true;l.TextXAlignment=align or Enum.TextXAlignment.Left;l.Parent=parent;return l end
txt(port,"Nullscape Shop Calculator",UDim2.fromOffset(12,8),UDim2.new(1,-24,0,30),Enum.Font.GothamBold,Color3.fromRGB(20,20,23)).TextSize=20
local status=txt(port,"Reading game...",UDim2.fromOffset(12,38),UDim2.new(1,-24,0,24),Enum.Font.GothamMedium,Color3.fromRGB(70,70,78))
local money=txt(port,"Golden Gifts left: 0",UDim2.fromOffset(12,67),UDim2.new(1,-24,0,24),Enum.Font.GothamBold,Color3.fromRGB(118,88,0))
local best=txt(port,"Best option: ...",UDim2.fromOffset(12,94),UDim2.new(1,-24,0,42),Enum.Font.GothamBold,Color3.fromRGB(20,120,70))
local function section(name,y)local l=txt(port,name,UDim2.fromOffset(12,y),UDim2.new(1,-24,0,25),Enum.Font.GothamBold);l.TextSize=17;return l end
section("Owned Upgrades",140);section("Shop",345);section("Protection Altars",560);section("Purification Costs",725)
local ownedGrid=Instance.new("ScrollingFrame");ownedGrid.Position=UDim2.fromOffset(10,170);ownedGrid.Size=UDim2.new(1,-20,0,165);ownedGrid.BackgroundTransparency=1;ownedGrid.BorderSizePixel=0;ownedGrid.ScrollBarThickness=4;ownedGrid.ScrollingDirection=Enum.ScrollingDirection.X;ownedGrid.Parent=port
local shopGrid=ownedGrid:Clone();shopGrid.Position=UDim2.fromOffset(10,375);shopGrid.Parent=port
local altarGrid=ownedGrid:Clone();altarGrid.Position=UDim2.fromOffset(10,590);altarGrid.Size=UDim2.new(1,-20,0,125);altarGrid.Parent=port
local curseGrid=altarGrid:Clone();curseGrid.Position=UDim2.fromOffset(10,755);curseGrid.Parent=port
local function gridLayout(p)local u=Instance.new("UIListLayout");u.FillDirection=Enum.FillDirection.Horizontal;u.Padding=UDim.new(0,8);u.Parent=p;u:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()p.CanvasSize=UDim2.fromOffset(u.AbsoluteContentSize.X+8,0)end)end
for _,g in ipairs({ownedGrid,shopGrid,altarGrid,curseGrid})do gridLayout(g)end
local liveInfo=RS.UpgradeFolder.UpgradeInfo
local function icon(u)local v=liveInfo:FindFirstChild(u.name:gsub("[^%w]",""))or liveInfo:FindFirstChild(u.id or "");v=v and v:FindFirstChild("Icon");return v and v.Value or ""end
local function card(parent,name,sub,image,color,click)
 local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(105,parent==altarGrid or parent==curseGrid and 110 or 150);b.BackgroundColor3=color or Color3.fromRGB(218,220,225);b.BorderSizePixel=0;b.Text="";b.AutoButtonColor=click~=nil;b.Parent=parent;Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
 local im=Instance.new("ImageLabel");im.BackgroundTransparency=1;im.Position=UDim2.new(.5,-36,0,8);im.Size=UDim2.fromOffset(72,72);im.Image=image or "";im.ScaleType=Enum.ScaleType.Fit;im.Parent=b
 local n=txt(b,name,UDim2.fromOffset(5,82),UDim2.new(1,-10,0,35),Enum.Font.GothamBold);n.TextSize=11;n.TextXAlignment=Enum.TextXAlignment.Center
 local s=txt(b,sub,UDim2.fromOffset(5,119),UDim2.new(1,-10,0,25),Enum.Font.GothamMedium,Color3.fromRGB(65,65,70));s.TextSize=10;s.TextXAlignment=Enum.TextXAlignment.Center
 if click then b.MouseButton1Click:Connect(function()click(b)end)end;return b
end
local curses={{"LAP 2",400},{"Mart Slide",330},{"Nothing?",325},{"Bloodier Meat",300},{"Beacon Mirage",300}}
local last="";task.spawn(function()while port.Parent do local s,choices,basket,spent=calc.Calculate();local signature=s.level..":"..s.money..":"..s.players..":"..s.difficulty..":"..s.party
 if signature~=last then last=signature;for _,g in ipairs({ownedGrid,shopGrid,altarGrid,curseGrid})do for _,x in ipairs(g:GetChildren())do if not x:IsA("UIListLayout")then x:Destroy()end end end
  status.Text=string.format("Level %d  •  %s  •  %s  •  %d player(s)",s.level,s.difficulty,s.party,s.players);money.Text=string.format("Golden Gifts left: %.0f",s.money)
  best.Text=choices[1]and string.format("Best option: %s — %d GG",choices[1].u.name,choices[1].cost)or "Best option: Save your Golden Gifts"
  for _,u in ipairs(calc.Upgrades)do local n=s.owned[u.name]or 0;if n>0 then card(ownedGrid,u.name,"Owned x"..n,icon(u),Color3.fromRGB(197,201,210))end end
  for _,it in ipairs(choices)do local affordable=it.cost<=s.money;card(shopGrid,it.u.name,it.cost.." GG",icon(it.u),affordable and Color3.fromRGB(215,217,222)or Color3.fromRGB(235,178,178),function(b)App.Selected[it.u.name]=not App.Selected[it.u.name];b.BackgroundColor3=App.Selected[it.u.name]and Color3.fromRGB(170,220,185)or(affordable and Color3.fromRGB(215,217,222)or Color3.fromRGB(235,178,178))end)end
  local pct=(s.party=="solo"or s.party=="duo")and.05 or.1;local base=(s.party=="solo"or s.party=="duo")and 12.5 or 50;local pm=(s.party=="solo"or s.party=="duo")and s.players or math.sqrt(s.players)/1.75
  for lv=3,7 do local c=math.ceil(base*(1+pct*(lv-3))*pm);card(altarGrid,"Protection Altar","Level "..lv.." • "..c.." GG","",c<=s.money and Color3.fromRGB(215,217,222)or Color3.fromRGB(235,178,178))end
  for _,c in ipairs(curses)do local mult=s.level<=25 and 1 or(1+math.floor((s.level-25)/5)*.1);local price=math.floor(c[2]*mult*math.sqrt(s.players));card(curseGrid,c[1],price.." GG","",price<=s.money and Color3.fromRGB(215,217,222)or Color3.fromRGB(235,178,178))end
 end;task.wait(.35)end end)
function App:Destroy()if port then port:Destroy()end;Env.__NullShopExactPort=nil end

