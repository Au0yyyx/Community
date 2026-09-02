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
local f=Instance.new("Frame");f.Name="CompactWebsiteShop";f.Size=UDim2.fromOffset(470,500);f.Position=UDim2.new(1,-485,.5,-250);f.BackgroundColor3=Color3.new(0,0,0);f.BorderSizePixel=0;f.Active=true;f.Draggable=false;f.Visible=false;f.Parent=gui;Instance.new("UICorner",f).CornerRadius=UDim.new(0,14);App.Frame=f;App.Gui=gui
local stroke=Instance.new("UIStroke",f);stroke.Color=Color3.fromRGB(168,85,247);stroke.Thickness=2
local grad=Instance.new("UIGradient",f);grad.Rotation=90;grad.Color=ColorSequence.new(Color3.fromRGB(38,17,58),Color3.fromRGB(0,0,0))
local function label(parent,t,pos,size,font,ts,color,xa)local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=t;l.Position=pos;l.Size=size;l.Font=font or Enum.Font.Gotham;l.TextSize=ts or 12;l.TextColor3=color or Color3.new(1,1,1);l.TextXAlignment=xa or Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Center;l.TextTruncate=Enum.TextTruncate.AtEnd;l.Parent=parent;return l end
label(f,"NULLSCAPE SHOP CALCULATOR",UDim2.fromOffset(14,7),UDim2.new(1,-174,0,27),Enum.Font.GothamBold,16,Color3.fromRGB(245,233,255))
local moving,resizing=false,false
local function toggle(text,x,fn)local b=Instance.new("TextButton");b.Position=UDim2.new(1,x,0,8);b.Size=UDim2.fromOffset(66,23);b.BackgroundColor3=Color3.fromRGB(17,17,17);b.BorderSizePixel=0;b.Text=text..": OFF";b.TextColor3=Color3.fromRGB(216,180,254);b.Font=Enum.Font.GothamBold;b.TextSize=9;b.Parent=f;Instance.new("UICorner",b).CornerRadius=UDim.new(0,7);local s=Instance.new("UIStroke",b);s.Color=Color3.fromRGB(126,34,206);b.MouseButton1Click:Connect(function()local on=fn();b.Text=text..(on and ": ON"or": OFF");b.BackgroundColor3=on and Color3.fromRGB(72,28,105)or Color3.fromRGB(17,17,17)end)end
toggle("MOVE",-146,function()moving=not moving;f.Draggable=moving;return moving end);toggle("RESIZE",-74,function()resizing=not resizing;return resizing end)
local grip=Instance.new("TextButton");grip.AnchorPoint=Vector2.new(1,1);grip.Position=UDim2.new(1,-3,1,-3);grip.Size=UDim2.fromOffset(18,18);grip.BackgroundTransparency=1;grip.Text=">>";grip.TextColor3=Color3.fromRGB(216,180,254);grip.Parent=f
local dragStart,startSize,ri
con(grip.InputBegan,function(i)if resizing and i.UserInputType==Enum.UserInputType.MouseButton1 then dragStart=i.Position;startSize=f.AbsoluteSize;ri=i end end)
con(UIS.InputChanged,function(i)if ri and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-dragStart;f.Size=UDim2.fromOffset(math.clamp(startSize.X+d.X,400,800),math.clamp(startSize.Y+d.Y,320,760))end end)
con(UIS.InputEnded,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then ri=nil end end)
local scroll=Instance.new("ScrollingFrame");scroll.Name="WebsiteContent";scroll.Position=UDim2.fromOffset(8,40);scroll.Size=UDim2.new(1,-16,1,-48);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=5;scroll.ScrollBarImageColor3=Color3.fromRGB(168,85,247);scroll.CanvasSize=UDim2.fromOffset(0,895);scroll.Parent=f
local function panel(y,h)local p=Instance.new("Frame");p.Position=UDim2.fromOffset(6,y);p.Size=UDim2.new(1,-17,0,h);p.BackgroundColor3=Color3.fromRGB(18,7,28);p.BackgroundTransparency=.08;p.BorderSizePixel=0;p.Parent=scroll;Instance.new("UICorner",p).CornerRadius=UDim.new(0,12);local s=Instance.new("UIStroke",p);s.Color=Color3.fromRGB(168,85,247);s.Thickness=2;return p end
local controls=panel(2,82);label(controls,"LIVE SETTINGS",UDim2.fromOffset(10,4),UDim2.new(1,-20,0,18),Enum.Font.GothamBold,13,Color3.fromRGB(245,233,255))
local function chip(x,w,name)local q=Instance.new("Frame");q.Position=UDim2.fromOffset(x,29);q.Size=UDim2.fromOffset(w,43);q.BackgroundColor3=Color3.fromRGB(17,17,17);q.BorderSizePixel=0;q.Parent=controls;Instance.new("UICorner",q).CornerRadius=UDim.new(0,8);local st=Instance.new("UIStroke",q);st.Color=Color3.fromRGB(126,34,206);label(q,name,UDim2.fromOffset(6,1),UDim2.new(1,-12,0,14),Enum.Font.GothamBold,8,Color3.fromRGB(216,180,254));return label(q,"—",UDim2.fromOffset(6,16),UDim2.new(1,-12,0,22),Enum.Font.GothamMedium,10)end
local lv,pc,pt,df=chip(9,73,"LEVEL"),chip(88,76,"PLAYERS"),chip(170,106,"PARTY SIZE"),chip(282,140,"DIFFICULTY")
local liveInfo=RS:FindFirstChild("UpgradeFolder")and RS.UpgradeFolder:FindFirstChild("UpgradeInfo")
local function icon(u)if not liveInfo then return""end;local k=(u.id or u.name or""):gsub("[^%w]","");local v=liveInfo:FindFirstChild(k)or liveInfo:FindFirstChild((u.name or""):gsub("[^%w]",""));v=v and v:FindFirstChild("Icon");return v and v.Value or""end
local function section(y,h,title)local p=panel(y,h);label(p,title,UDim2.fromOffset(10,5),UDim2.new(1,-20,0,22),Enum.Font.GothamBold,16,Color3.fromRGB(245,233,255));local money=label(p,"Golden Gifts left: 0",UDim2.new(1,-220,0,5),UDim2.fromOffset(210,22),Enum.Font.GothamBold,10,Color3.fromRGB(216,180,254),Enum.TextXAlignment.Right);local g=Instance.new("ScrollingFrame");g.Position=UDim2.fromOffset(9,32);g.Size=UDim2.new(1,-18,0,h-41);g.BackgroundTransparency=1;g.BorderSizePixel=0;g.ScrollBarThickness=3;g.ScrollingDirection=Enum.ScrollingDirection.X;g.CanvasSize=UDim2.fromOffset(0,0);g.Parent=p;local l=Instance.new("UIListLayout",g);l.FillDirection=Enum.FillDirection.Horizontal;l.Padding=UDim.new(0,8);l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()g.CanvasSize=UDim2.fromOffset(l.AbsoluteContentSize.X+4,0)end);return p,g,money end
local ownedP,ownedG=section(94,174,"Owned Upgrades");local shopP,shopG,shopMoney=section(278,174,"Shop");local altarP,altarG,altarMoney=section(462,174,"Protection Altars");local purifyP,purifyG,purifyMoney=section(646,174,"Purification Costs")
local best=panel(830,56);local bestA=label(best,"BEST OPTION",UDim2.fromOffset(10,5),UDim2.new(1,-20,0,20),Enum.Font.GothamBold,11,Color3.fromRGB(216,180,254));local bestB=label(best,"Calculating...",UDim2.fromOffset(10,25),UDim2.new(1,-20,0,22),Enum.Font.GothamMedium,10)
local selectedShop,selectedAltars,selectedPurify={},{},{}
local function clear(g)for _,x in ipairs(g:GetChildren())do if not x:IsA("UIListLayout")then x:Destroy()end end end
local function card(g,name,cost,img,state,click)local b=Instance.new("TextButton");b.Name="Card";b.Size=UDim2.fromOffset(96,124);b.BackgroundColor3=state=="selected"and Color3.fromRGB(29,78,216)or(state=="blocked"and Color3.fromRGB(75,28,35)or Color3.fromRGB(8,8,8));b.BorderSizePixel=0;b.Text="";b.AutoButtonColor=click~=nil;b.Parent=g;Instance.new("UICorner",b).CornerRadius=UDim.new(0,8);local st=Instance.new("UIStroke",b);st.Color=state=="selected"and Color3.fromRGB(147,197,253)or Color3.fromRGB(168,85,247);local im=Instance.new("ImageLabel");im.BackgroundTransparency=1;im.Position=UDim2.fromOffset(13,4);im.Size=UDim2.fromOffset(70,70);im.Image=img or"";im.ScaleType=Enum.ScaleType.Fit;im.Parent=b;local c=label(b,cost and(cost.." GG")or"OWNED",UDim2.fromOffset(5,73),UDim2.new(1,-10,0,18),Enum.Font.GothamBold,10,Color3.new(1,1,1),Enum.TextXAlignment.Center);c.BackgroundColor3=Color3.new(0,0,0);c.BackgroundTransparency=.25;label(b,name,UDim2.fromOffset(4,94),UDim2.new(1,-8,0,26),Enum.Font.GothamBold,9,Color3.fromRGB(245,233,255),Enum.TextXAlignment.Center);if click then b.MouseButton1Click:Connect(click)end end
local last="";task.spawn(function()while not App.Destroyed do local s,choices,basket,spent=calculate();local sig=string.format("%s:%s:%s:%s:%s:%s:%s",s.level,s.money,s.players,s.difficulty,s.party,next(selectedShop)~=nil,next(selectedAltars)~=nil);lv.Text=tostring(s.level);pc.Text=tostring(s.players);pt.Text=s.party:upper();df.Text=s.difficulty:upper()..(s.nothing and" / NOTHING?"or"")
 clear(ownedG);clear(shopG);clear(altarG);clear(purifyG);local selectedTotal=0
 for _,u in ipairs(Upgrades)do local n=s.owned[u.name]or 0;if n>0 then card(ownedG,u.name,nil,icon(u),n>0 and"selected"or nil)end end
 for _,it in ipairs(choices)do if selectedShop[it.u.name]then selectedTotal+=it.cost end end
 for _,it in ipairs(choices)do local sel=selectedShop[it.u.name];local blocked=not sel and selectedTotal+it.cost>s.money;card(shopG,it.u.name,it.cost,icon(it.u),sel and"selected"or(blocked and"blocked"or nil),function()selectedShop[it.u.name]=not selectedShop[it.u.name]or nil end)end
 local solo=s.party=="solo"or s.party=="duo";local pct=solo and .05 or .1;local base=solo and 12.5 or 50;local pm=solo and math.max(1,s.players)or math.sqrt(math.max(1,s.players))/1.75
 for off=0,4 do local al=math.max(1,s.level)+off;local cost=math.floor(((s.money-selectedTotal)*pct)+(base*math.max(1,al-4)*pm));local sel=selectedAltars[al];if sel then selectedTotal+=sel end;card(altarG,"Level "..al,sel or cost,"",sel and"selected"or(selectedTotal+cost>s.money and"blocked"or nil),function()selectedAltars[al]=selectedAltars[al]and nil or cost end)end
 local vals={{"LAP 2",400},{"Mart Slide",330},{"Nothing?",325},{"Bloodier Meat",300},{"Beacon Mirage",300}};local lm=math.min(12,math.floor(s.level/5)*2)
 for _,v in ipairs(vals)do local cost=math.floor(v[2]*lm*math.sqrt(math.max(1,s.players)));local sel=selectedPurify[v[1]];if sel then selectedTotal+=cost end;card(purifyG,v[1],cost,"",sel and"selected"or(selectedTotal+cost>s.money and"blocked"or nil),function()selectedPurify[v[1]]=not selectedPurify[v[1]]or nil end)end
 local remain=s.money-selectedTotal;shopMoney.Text="Golden Gifts left: "..remain;altarMoney.Text=shopMoney.Text;purifyMoney.Text=shopMoney.Text;altarP.BackgroundTransparency=s.level>=8 and .08 or .55;purifyP.BackgroundTransparency=s.level>=14 and .08 or .55
 bestA.Text=choices[1]and("BEST OPTION • "..choices[1].u.name.." — "..choices[1].cost.." GG")or"BEST OPTION • SAVE YOUR GOLDEN GIFTS";bestB.Text="Selected total: "..selectedTotal.." GG  •  Remaining: "..remain.." GG"
 local lines={};for i=1,math.min(4,#choices)do lines[#lines+1]=string.format("%d. %s — %d GG",i,choices[i].u.name,choices[i].cost)end;App.Snapshot={Settings=string.format("LEVEL %d • %d PLAYER(S) • %s/%s • %.0f GG",s.level,s.players,s.difficulty,s.party,s.money),Best=bestA.Text,Ranked=table.concat(lines,"\n"),Party=s.party};task.wait(.5)end end)
function App:Destroy()if self.Destroyed then return end;self.Destroyed=true;for _,c in ipairs(self.Connections)do pcall(function()c:Disconnect()end)end;gui:Destroy();if Env[KEY]==self then Env[KEY]=nil end end
print("[Nullscape Shop AI] Loaded")

