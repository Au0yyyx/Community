if not game:IsLoaded() then game.Loaded:Wait() end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local UIS=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")
local Env=getgenv and getgenv() or _G
local KEY="__NullscapeShopAI_V1"
if type(Env[KEY])=="table" and type(Env[KEY].Destroy)=="function" then Env[KEY]:Destroy() end

local DATA_URL="https://raw.githubusercontent.com/Stickstetris/NullscapeShopCalculator/main/upgrades.json"
local ok,raw=pcall(function() return game:HttpGet(DATA_URL) end)
assert(ok,"Shop calculator data failed to download: "..tostring(raw))
local Upgrades=HttpService:JSONDecode(raw)
local App={Connections={},Destroyed=false,PartyOverride=nil,NothingOverride=nil}
Env[KEY]=App

local aliases={
 betterjumppad="betterjumppads", highlightgifts="radar", triaorbs="triaorbs",
 enemyontop="radarmoduleenemies", radaraltars="radarmodulealtars",
 radartripmines="radarmoduletripmines", highlighttripmines="radarmoduletripmines",
 radarplayer="radarmoduleplayers", radarinstruments="radarmoduleinstruments",
}
local function key(s)return tostring(s):lower():gsub("[^%w\128-\255]","")end
local byKey={}
for _,u in ipairs(Upgrades)do byKey[key(u.name)]=u end
local function ownedMap()
 local out={};local folder=RS:FindFirstChild("UpgradeFolder");folder=folder and folder:FindFirstChild("Upgrades")
 if not folder then return out end
 for _,v in ipairs(folder:GetChildren())do if v:IsA("ValueBase")then
  local k=aliases[key(v.Name)]or key(v.Name);local u=byKey[k]
  if u then local n=tonumber(v.Value)or 0;if u.name=="Gift Magnet"and n>u.max then n=math.ceil(n/20)end
   out[u.name]=math.max(out[u.name]or 0,math.clamp(n,0,u.max or 1))end
 end end;return out
end
local function difficulty()
 local v=RS:FindFirstChild("Difficulty");v=v and v.Value or 1
 if type(v)=="string"then return v end
 -- Live Nullscape values are 1=Casual, 2=Standard, 3=Extreme.
 return ({[1]="Casual",[2]="Standard",[3]="Extreme"})[v]or "Standard"
end
local function party(players)
 if App.PartyOverride then return App.PartyOverride end
 -- MaxPlayers is always large in Nullscape, including reserved solo runs.
 -- Current attendance is the only replicated party-size signal available.
 return players==1 and "solo"or(players==2 and "duo"or(players>8 and "party-plus"or "party"))
end
local function nothingActive()
 if App.NothingOverride~=nil then return App.NothingOverride end
 local f=RS:FindFirstChild("CurseFolder");f=f and f:FindFirstChild("Curses")
 local v=f and (f:FindFirstChild("Nothing")or f:FindFirstChild("Nothing?"))
 return v and tonumber(v.Value)and v.Value>0 or false
end
local function settings()
 return{level=(RS:FindFirstChild("Level")and RS.Level.Value or 0),players=#Players:GetPlayers(),
  difficulty=difficulty(),party=party(#Players:GetPlayers()),money=(RS:FindFirstChild("GoldenGifts")and RS.GoldenGifts.Value or 0),
  nothing=nothingActive(),owned=ownedMap()}
end
local function baseCost(u,s,owned)
 local stacks=u.stackCosts
 if s.party=="solo"and type(u.stackCostsSolo)=="table"then stacks=u.stackCostsSolo
 elseif s.difficulty=="Casual"and type(u.stackCostsCasual)=="table"then stacks=u.stackCostsCasual
 elseif s.difficulty=="Extreme"and type(u.stackCostsExtreme)=="table"then stacks=u.stackCostsExtreme end
 if type(stacks)=="table"and stacks[owned+1]~=nil then return stacks[owned+1]end
 if s.party=="solo"and u.costSolo~=nil then return u.costSolo end
 if s.difficulty=="Casual"then return u.costCasual or u.cost end
 if s.difficulty=="Extreme"then return u.costExtreme or u.cost end
 return u.cost
end
local function cost(u,s,owned)
 local p=baseCost(u,s,owned)
 if s.party=="solo"and u.costSolo==nil and type(u.stackCostsSolo)~="table"then p*=1-(u.soloDiscount or 0)/100 end
 p*=math.sqrt(math.max(1,s.players));if s.party=="party-plus"and s.players>1 then p/=1.125 end
 if s.nothing then p*=.85 end;return math.ceil(p)
end
local radarModules={['Radar Module: Altars']=1,['Radar Module: Enemies']=1,['Radar Module: Tripmines']=1,['Radar Module: Players']=1,['Radar Module: Instruments']=1}
local function enemyActive(name)
 local f=RS:FindFirstChild("EnemyFolder");f=f and f:FindFirstChild("ActiveEnemies")
 local v=f and f:FindFirstChild(name)
 return v~=nil and(not v:IsA("ValueBase")or tonumber(v.Value)==nil or tonumber(v.Value)>0)
end
local function eligible(u,s,owned)
 local min=s.difficulty=="Casual"and(u.minLevelCasual or u.minLevel)or u.minLevel
 if s.level<min or owned>=(u.max or 1)then return false end
 if u.name=="Adrenaline"and not(s.party=="solo"or s.party=="duo")then return false end
 if (u.name=="Defuse Kit"or u.name=="Radar Module: Tripmines"or u.name=="Grace Wings")and s.difficulty=="Casual"then return false end
 if u.name=="Last Robloxian Standing"and s.players<=2 then return false end
 if u.name=="Radar Module: Players"and s.players<=1 then return false end
 if radarModules[u.name]and(s.owned.Radar or 0)<1 then return false end
 if u.name=="Pocket Bell"and((s.owned["Double Jump"]or 0)<1 or not enemyActive("Bell"))then return false end
 if u.name=="Panic Necklace"and(s.owned.Shield or 0)<1 then return false end
 if u.name=="Subspacial Barrier"and s.difficulty~="Casual"and(s.owned["Defuse Kit"]or 0)<3 then return false end
 if u.name=="Shark Tail"and(s.owned["Ninja Belt"]or 0)<1 then return false end
 if u.name=="Drowned Ægis"and(s.owned["More Altars"]or 0)<1 then return false end
 if u.name=="Radar Module: Instruments"and not enemyActive("Cadence")then return false end
 return true
end
local weights={
 ["Business License"]=96,["Paycheck"]=94,["Swiftness Ring"]=92,["Adrenaline"]=98,["Double Jump"]=96,
 ["Better Jump Pads"]=72,["Tria Orbs"]=78,["Medal"]=75,["Radar"]=79,["Grace Wings"]=88,
 ["Grapple Points"]=78,["Pocket Bell"]=90,["Advanced Gravity Coil"]=84,["Ice Skates"]=65,
 ["Fanny Pack"]=82,["Helmet"]=72,["More Altars"]=80,["Ninja Belt"]=88,["Larger Grapple Points"]=68,
 ["Shark Tail"]=94,["Gift Magnet"]=83,["Matrix Tetrahedron"]=100,["Sport Shoes"]=99,["Shield"]=100,
 ["Panic Necklace"]=93,["Miniature Hourglass"]=91,["Gift Idol"]=88,["Drowned Ægis"]=96,
 ["Defuse Kit"]=74,["Last Robloxian Standing"]=70,["Subspacial Barrier"]=86,
 ["Radar Module: Enemies"]=67,["Radar Module: Altars"]=58,["Radar Module: Tripmines"]=63,
 ["Radar Module: Players"]=35,["Radar Module: Instruments"]=42,
}
local function utility(u,s,stack)
 local x=weights[u.name]or 60
 local remaining=math.max(0,50-s.level)
 if u.name=="Business License"or u.name=="Paycheck"or u.name=="Fanny Pack"or u.name=="Medal"then x*=.65+math.min(1,remaining/25)end
 if s.difficulty=="Extreme"and(u.name=="Shield"or u.name=="Panic Necklace"or u.name=="Drowned Ægis"or u.name=="Subspacial Barrier")then x*=1.18 end
 if s.party=="solo"and u.name=="Last Robloxian Standing"then x*=.3 end
 if stack>1 then x*=.82^(stack-1)end
 return x
end
local function calculate()
 local s=settings();local choices={}
 for _,u in ipairs(Upgrades)do local own=s.owned[u.name]or 0
  -- Only expose the immediately purchasable stack. Treating later stacks as
  -- independent knapsack entries can recommend stack 5 without buying stack 4.
  if eligible(u,s,own)then local n=own+1
   local c=cost(u,s,own);choices[#choices+1]={u=u,stack=n,cost=c,score=utility(u,s,n),ratio=utility(u,s,n)/math.max(c,1)}
  end
 end
 table.sort(choices,function(a,b)return a.score>b.score end)
 -- Exact bounded knapsack for the best set of upgrades at the current GG amount.
 local budget=math.min(math.floor(s.money),15000);local dp={[0]={score=0,list={}}}
 for _,it in ipairs(choices)do for m=budget-it.cost,0,-1 do local old=dp[m]
  if old then local nm=m+it.cost;local ns=old.score+it.score;if not dp[nm]or ns>dp[nm].score then
   local list=table.clone(old.list);list[#list+1]=it;dp[nm]={score=ns,list=list}end end end end
 local best={score=-1,list={}};local spent=0;for m,v in pairs(dp)do if v.score>best.score then best=v;spent=m end end
 return s,choices,best,spent
end
App.Calculate=calculate;App.Upgrades=Upgrades

local gui=Instance.new("ScreenGui");gui.Name="NullscapeShopAI";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=99999;gui.Parent=(gethui and gethui())or CoreGui
local f=Instance.new("Frame");f.Name="CompactWebsiteShop";f.Size=UDim2.fromOffset(438,322);f.Position=UDim2.new(1,-452,.5,-161);f.BackgroundColor3=Color3.fromRGB(0,0,0);f.BorderSizePixel=0;f.Active=true;f.Draggable=false;f.Visible=false;f.Parent=gui;Instance.new("UICorner",f).CornerRadius=UDim.new(0,14);App.Frame=f;App.Gui=gui
local border=Instance.new("UIStroke",f);border.Color=Color3.fromRGB(168,85,247);border.Thickness=2
local grad=Instance.new("UIGradient",f);grad.Rotation=90;grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(38,17,58)),ColorSequenceKeypoint.new(.42,Color3.fromRGB(8,3,13)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))})
local function label(parent,text,pos,size,font,ts,color,xa)local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=text;l.Position=pos;l.Size=size;l.Font=font or Enum.Font.Gotham;l.TextSize=ts or 12;l.TextColor3=color or Color3.new(1,1,1);l.TextXAlignment=xa or Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Center;l.TextTruncate=Enum.TextTruncate.AtEnd;l.Parent=parent;return l end
label(f,"NULLSCAPE SHOP CALCULATOR",UDim2.fromOffset(14,8),UDim2.new(1,-178,0,25),Enum.Font.GothamBold,16,Color3.fromRGB(245,233,255))
local moving,resizing=false,false
local function headerToggle(text,x,callback)local b=Instance.new("TextButton");b.Position=UDim2.new(1,x,0,8);b.Size=UDim2.fromOffset(66,23);b.BackgroundColor3=Color3.fromRGB(17,17,17);b.BorderSizePixel=0;b.Text=text..": OFF";b.TextColor3=Color3.fromRGB(216,180,254);b.Font=Enum.Font.GothamBold;b.TextSize=9;b.Parent=f;Instance.new("UICorner",b).CornerRadius=UDim.new(0,7);local st=Instance.new("UIStroke",b);st.Color=Color3.fromRGB(126,34,206);b.MouseButton1Click:Connect(function()local on=callback();b.Text=text..(on and ": ON" or ": OFF");b.BackgroundColor3=on and Color3.fromRGB(72,28,105) or Color3.fromRGB(17,17,17)end);return b end
headerToggle("MOVE",-146,function()moving=not moving;f.Draggable=moving;return moving end)
headerToggle("RESIZE",-74,function()resizing=not resizing;return resizing end)
local grip=Instance.new("TextButton");grip.Name="ResizeGrip";grip.AnchorPoint=Vector2.new(1,1);grip.Position=UDim2.new(1,-3,1,-3);grip.Size=UDim2.fromOffset(18,18);grip.BackgroundTransparency=1;grip.Text=">>";grip.TextColor3=Color3.fromRGB(216,180,254);grip.TextSize=12;grip.Parent=f
local dragStart,startSize,resizeInput
con(grip.InputBegan,function(i)if resizing and i.UserInputType==Enum.UserInputType.MouseButton1 then dragStart=i.Position;startSize=f.AbsoluteSize;resizeInput=i end end)
con(UIS.InputChanged,function(i)if resizeInput and resizeInput.UserInputState~=Enum.UserInputState.End and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-dragStart;f.Size=UDim2.fromOffset(math.clamp(startSize.X+d.X,390,760),math.clamp(startSize.Y+d.Y,300,650))end end)
con(UIS.InputEnded,function(i)if i==resizeInput or i.UserInputType==Enum.UserInputType.MouseButton1 then resizeInput=nil end end)
local topLine=Instance.new("Frame");topLine.BorderSizePixel=0;topLine.BackgroundColor3=Color3.fromRGB(168,85,247);topLine.Position=UDim2.fromOffset(14,37);topLine.Size=UDim2.new(1,-28,0,2);topLine.Parent=f
local controls=Instance.new("Frame");controls.BackgroundTransparency=1;controls.Position=UDim2.fromOffset(14,46);controls.Size=UDim2.new(1,-28,0,43);controls.Parent=f
local function chip(x,w,caption)local q=Instance.new("Frame");q.Position=UDim2.fromOffset(x,0);q.Size=UDim2.fromOffset(w,43);q.BackgroundColor3=Color3.fromRGB(17,17,17);q.BorderSizePixel=0;q.Parent=controls;Instance.new("UICorner",q).CornerRadius=UDim.new(0,8);local st=Instance.new("UIStroke",q);st.Color=Color3.fromRGB(126,34,206);label(q,caption,UDim2.fromOffset(7,2),UDim2.new(1,-14,0,14),Enum.Font.GothamBold,9,Color3.fromRGB(216,180,254));return label(q,"—",UDim2.fromOffset(7,16),UDim2.new(1,-14,0,22),Enum.Font.GothamMedium,11)end
local levelV=chip(0,72,"CURRENT LEVEL");local playersV=chip(78,78,"PLAYERS");local partyV=chip(162,105,"PARTY SIZE");local diffV=chip(273,105,"DIFFICULTY")
local gg=label(f,"Golden Gifts left: 0",UDim2.fromOffset(14,94),UDim2.new(1,-28,0,20),Enum.Font.GothamBold,12,Color3.fromRGB(245,233,255))
local sectionTitle=label(f,"Shop",UDim2.fromOffset(14,116),UDim2.fromOffset(140,22),Enum.Font.GothamBold,16,Color3.fromRGB(245,233,255))
local page="shop"
local function pageButton(name,key,x)local b=Instance.new("TextButton");b.Position=UDim2.fromOffset(x,116);b.Size=UDim2.fromOffset(78,21);b.BackgroundColor3=Color3.fromRGB(17,17,17);b.BorderSizePixel=0;b.Text=name;b.TextColor3=Color3.fromRGB(216,180,254);b.Font=Enum.Font.GothamBold;b.TextSize=9;b.Parent=f;Instance.new("UICorner",b).CornerRadius=UDim.new(0,7);local st=Instance.new("UIStroke",b);st.Color=Color3.fromRGB(126,34,206);b.MouseButton1Click:Connect(function()page=key end)end
pageButton("UPGRADES","shop",170);pageButton("ALTARS","altars",254);pageButton("PURIFY","purify",338)
local grid=Instance.new("Frame");grid.BackgroundTransparency=1;grid.Position=UDim2.fromOffset(14,141);grid.Size=UDim2.new(1,-28,0,112);grid.Parent=f
local layout=Instance.new("UIListLayout",grid);layout.FillDirection=Enum.FillDirection.Horizontal;layout.Padding=UDim.new(0,8)
local liveInfo=RS:FindFirstChild("UpgradeFolder") and RS.UpgradeFolder:FindFirstChild("UpgradeInfo")
local function findIcon(u)if not liveInfo then return "" end;local key=(u.id or u.name):gsub("[^%w]","");local v=liveInfo:FindFirstChild(key) or liveInfo:FindFirstChild((u.name or ""):gsub("[^%w]",""));local i=v and v:FindFirstChild("Icon");return i and i.Value or "" end
local function card(it,index)local b=Instance.new("Frame");b.Name="ShopCard";b.Size=UDim2.fromOffset(94,112);b.BackgroundColor3=Color3.fromRGB(8,8,8);b.BorderSizePixel=0;b.LayoutOrder=index;b.Parent=grid;Instance.new("UICorner",b).CornerRadius=UDim.new(0,8);local st=Instance.new("UIStroke",b);st.Color=Color3.fromRGB(168,85,247);st.Transparency=.15;local im=Instance.new("ImageLabel");im.BackgroundTransparency=1;im.Position=UDim2.fromOffset(13,5);im.Size=UDim2.fromOffset(68,68);im.Image=findIcon(it.u);im.ScaleType=Enum.ScaleType.Fit;im.Parent=b;local cost=label(b,tostring(it.cost).." GG",UDim2.fromOffset(5,72),UDim2.new(1,-10,0,17),Enum.Font.GothamBold,11,Color3.new(1,1,1),Enum.TextXAlignment.Center);cost.BackgroundColor3=Color3.fromRGB(0,0,0);cost.BackgroundTransparency=.22;Instance.new("UICorner",cost).CornerRadius=UDim.new(0,5);label(b,it.u.name,UDim2.fromOffset(4,90),UDim2.new(1,-8,0,18),Enum.Font.GothamMedium,9,Color3.fromRGB(245,233,255),Enum.TextXAlignment.Center);return b end
local bestPanel=Instance.new("Frame");bestPanel.Position=UDim2.fromOffset(14,262);bestPanel.Size=UDim2.new(1,-28,0,45);bestPanel.BackgroundColor3=Color3.fromRGB(20,8,31);bestPanel.BorderSizePixel=0;bestPanel.Parent=f;Instance.new("UICorner",bestPanel).CornerRadius=UDim.new(0,9);local bst=Instance.new("UIStroke",bestPanel);bst.Color=Color3.fromRGB(168,85,247);bst.Transparency=.25
local best=label(bestPanel,"BEST OPTION • calculating...",UDim2.fromOffset(9,3),UDim2.new(1,-18,0,21),Enum.Font.GothamBold,11,Color3.fromRGB(216,180,254));local basketText=label(bestPanel,"",UDim2.fromOffset(9,21),UDim2.new(1,-18,0,20),Enum.Font.GothamMedium,10,Color3.fromRGB(255,255,255))
local partyModes={false,"solo","duo","party","party-plus"};local partyModeIndex=1
-- Visibility is controlled exclusively by NULLGUI's Compact In-Game Overlay toggle.
task.spawn(function()while not App.Destroyed do local s,choices,basket,spent=calculate();levelV.Text=tostring(s.level);playersV.Text=tostring(s.players);partyV.Text=(s.party or "auto"):upper();diffV.Text=(s.difficulty or "?"):upper();gg.Text=string.format("Golden Gifts left: %.0f%s",s.money,s.nothing and "   •   Nothing? −15%" or "");for _,x in ipairs(grid:GetChildren())do if x.Name=="ShopCard" then x:Destroy()end end;local shown={}
if page=="shop" then sectionTitle.Text="Shop";shown=choices
elseif page=="altars" then sectionTitle.Text=s.level>=8 and "Protection Altars" or "Altars (Level 8)";local solo=s.party=="solo" or s.party=="duo";local pct=solo and .05 or .1;local base=solo and 12.5 or 50;local pm=solo and math.max(1,s.players) or math.sqrt(math.max(1,s.players))/1.75;for off=0,4 do local lv=math.max(1,s.level)+off;shown[#shown+1]={u={name="Level "..lv},cost=math.floor((s.money*pct)+(base*math.max(1,lv-4)*pm))}end
else sectionTitle.Text=s.level>=14 and "Purification Costs" or "Purify (Level 14)";local vals={{"LAP 2",400},{"Mart Slide",330},{"Nothing?",325},{"Bloodier Meat",300},{"Beacon Mirage",300}};local lm=math.min(12,math.floor(s.level/5)*2);for _,v in ipairs(vals)do shown[#shown+1]={u={name=v[1]},cost=math.floor(v[2]*lm*math.sqrt(math.max(1,s.players)))}end end
for i=1,math.min(4,#shown)do card(shown[i],i)end;local names={};for _,it in ipairs(basket.list)do names[#names+1]=it.u.name..(it.stack>1 and(" x"..it.stack)or"")end;best.Text=choices[1]and("BEST OPTION • "..choices[1].u.name.." — "..choices[1].cost.." GG")or"BEST OPTION • SAVE YOUR GOLDEN GIFTS";basketText.Text=#names>0 and("Basket: "..table.concat(names," + ").."  ("..spent.." GG)")or"Nothing eligible is worth buying yet.";local lines={};for i=1,math.min(4,#choices)do local it=choices[i];lines[#lines+1]=string.format("%d. %s — %d GG",i,it.u.name,it.cost)end;App.Snapshot={Settings=string.format("LEVEL %d • %d PLAYER(S) • %s/%s • %.0f GG",s.level,s.players,s.difficulty,s.party,s.money),Best=best.Text,Ranked=table.concat(lines,"\n"),Party=s.party};task.wait(.5)end end)
function App:Destroy()if self.Destroyed then return end;self.Destroyed=true;for _,c in ipairs(self.Connections)do pcall(function()c:Disconnect()end)end;gui:Destroy();if Env[KEY]==self then Env[KEY]=nil end end
print("[Nullscape Shop AI] Loaded")

