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
local f=Instance.new("Frame");f.Size=UDim2.fromOffset(390,255);f.Position=UDim2.new(1,-405,.5,-128);f.BackgroundColor3=Color3.fromRGB(10,13,20);f.BackgroundTransparency=.08;f.BorderSizePixel=0;f.Active=true;f.Draggable=true;f.Visible=Env.__NullscapeShopAIEmbedded~=true;f.Parent=gui;Instance.new("UICorner",f).CornerRadius=UDim.new(0,10);App.Frame=f;App.Gui=gui
local st=Instance.new("UIStroke",f);st.Color=Color3.fromRGB(94,215,255);st.Thickness=2
local function text(y,h,size,color,font)local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Position=UDim2.fromOffset(14,y);l.Size=UDim2.new(1,-28,0,h);l.Font=font or Enum.Font.Code;l.TextSize=size;l.TextColor3=color;l.TextWrapped=true;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Top;l.Parent=f;return l end
local title=text(8,24,15,Color3.fromRGB(110,225,255),Enum.Font.GothamBold);title.Text="NULLSCAPE // SHOP AI"
local partyButton=Instance.new("TextButton");partyButton.Size=UDim2.fromOffset(105,22);partyButton.Position=UDim2.new(1,-113,0,7);partyButton.BackgroundColor3=Color3.fromRGB(24,43,57);partyButton.TextColor3=Color3.fromRGB(135,230,255);partyButton.Font=Enum.Font.GothamBold;partyButton.TextSize=10;partyButton.Text="PARTY: AUTO";partyButton.Parent=f;Instance.new("UICorner",partyButton).CornerRadius=UDim.new(0,6)
local stats=text(36,20,11,Color3.fromRGB(205,215,230));local best=text(62,60,12,Color3.fromRGB(125,255,160),Enum.Font.GothamBold)
local ranked=text(124,106,11,Color3.fromRGB(235,235,245));local foot=text(234,15,9,Color3.fromRGB(145,155,175));foot.Text="RightShift hide • Sticks calculator data"
local hidden=false;local function con(sig,fn)local c=sig:Connect(fn);App.Connections[#App.Connections+1]=c;return c end
local partyModes={false,"solo","duo","party","party-plus"};local partyModeIndex=1
con(partyButton.MouseButton1Click,function()partyModeIndex=partyModeIndex%#partyModes+1;App.PartyOverride=partyModes[partyModeIndex]or nil;partyButton.Text="PARTY: "..(App.PartyOverride and App.PartyOverride:upper()or "AUTO")end)
con(UIS.InputBegan,function(i,p)if not p and i.KeyCode==Enum.KeyCode.RightShift then hidden=not hidden;f.Visible=not hidden end end)
task.spawn(function()while not App.Destroyed do local s,choices,basket,spent=calculate()
 stats.Text=string.format("LEVEL %d  •  %d PLAYER(S)  •  %s/%s  •  %.0f GG%s",s.level,s.players,s.difficulty,s.party,s.money,s.nothing and "  •  NOTHING? -15%"or "")
 local names={};for _,it in ipairs(basket.list)do names[#names+1]=string.format("%s %s(%d)",it.u.name,it.stack>1 and("x"..it.stack.." ")or "",it.cost)end
 best.Text=#names>0 and("BEST BASKET — "..spent.." GG\n"..table.concat(names,"  +  "))or "BEST BASKET\nSave your Golden Gifts — nothing eligible is worth buying yet."
 local lines={"BEST INDIVIDUAL OPTIONS"};for i=1,math.min(4,#choices)do local it=choices[i];lines[#lines+1]=string.format("%d. %s%s — %d GG  [%d]",i,it.u.name,it.stack>1 and(" (stack "..it.stack..")")or "",it.cost,math.floor(it.score+.5))end
 ranked.Text=table.concat(lines,"\n");App.Snapshot={Settings=stats.Text,Best=best.Text,Ranked=ranked.Text,Party=s.party};task.wait(.5)end end)
function App:Destroy()if self.Destroyed then return end;self.Destroyed=true;for _,c in ipairs(self.Connections)do pcall(function()c:Disconnect()end)end;gui:Destroy();if Env[KEY]==self then Env[KEY]=nil end end
print("[Nullscape Shop AI] Loaded")

