if not game:IsLoaded() then game.Loaded:Wait() end
local env=getgenv and getgenv() or _G
if env.__OutcomeMemoriesSuite and env.__OutcomeMemoriesSuite.Destroy then pcall(env.__OutcomeMemoriesSuite.Destroy,env.__OutcomeMemoriesSuite) end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local LP=Players.LocalPlayer
local req=request or http_request or (syn and syn.request)
local function get(url) if req then return req({Url=url,Method="GET"}).Body end return game:HttpGet(url) end
local Library=loadstring(get("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local Window=Library:CreateWindow({Title="Outcome Memories Suite",Footer="RightShift to toggle",Center=true,AutoShow=true,ToggleKeybind=Enum.KeyCode.RightShift})
local Tabs={ESP=Window:AddTab("ESP"),Aim=Window:AddTab("Aim"),Visuals=Window:AddTab("Visuals"),Settings=Window:AddTab("Settings")}
Library.Toggles=Library.Toggles or {};Library.Options=Library.Options or {}
local App={Connections={},Items={},WorldItems={},HPMax=setmetatable({},{__mode="k"}),Settings={Chams=false,CharacterESP=true,NameESP=true,TextESP=true,HpESP=false,Hitboxes=false,HitRadius=8,MineESP=false,EscapeESP=false,Aim=false,AimHold=true,SilentAim=false,TailsCannonSilentAim=false,AimSurvivors=false,AimEXE=true,AimFOV=160,AimSmooth=0.18,Wall=true,FOVCircle=true,AutoBlock=false,BlockRange=14,BlockDelay=.06,BlockHold=.18,BlockKey="F",ThreatAlerts=false,ThreatRange=45,RoundInfo=false,CooldownInfo=false,SpeedInfo=false,Fullbright=false,NoFog=false,LowEffects=false}}
env.__OutcomeMemoriesSuite=App
local function playersFolder() return workspace:FindFirstChild("Players") end
local function root(m)return m and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)end
local function alive(m)return root(m) and (not m:GetAttribute("State") or m:GetAttribute("State")~="dead")end
local function myTeam()local c=LP.Character;return c and c:GetAttribute("Team")end
local function wanted(m)
 local team=m:GetAttribute("Team");if not team then return false end
 if team=="Survivor" then return App.Settings.AimSurvivors end
 if team=="EXE" then return App.Settings.AimEXE end
 return false
end
local function attackActive(m)
    local ok, tagged = pcall(m.HasTag, m, "Hit")
    return (ok and tagged) or m:GetAttribute("Hit") == true
end
local function item(m)
 local v=App.Items[m];if v then return v end
 local h=Instance.new("Highlight");h.Name="OM_ESP";h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;h.FillTransparency=.62;h.OutlineTransparency=0;h.Parent=m
 local b=Instance.new("BillboardGui");b.Name="OM_Tag";b.Size=UDim2.fromOffset(220,78);b.StudsOffset=Vector3.new(0,4.2,0);b.AlwaysOnTop=true;b.Parent=m
 local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.TextStrokeTransparency=.15;t.TextColor3=Color3.new(1,1,1);t.TextScaled=false;t.TextSize=15;t.RichText=true;t.TextWrapped=false;t.Font=Enum.Font.GothamBold;t.Parent=b
 local ring=Instance.new("Part");ring.Name="OM_AttackHitbox";ring.Anchored=true;ring.CanCollide=false;ring.CanQuery=false;ring.CanTouch=false;ring.Shape=Enum.PartType.Cylinder;ring.Material=Enum.Material.Neon;ring.Transparency=.7;ring.Color=Color3.fromRGB(255,80,80);ring.Parent=workspace
 v={H=h,B=b,T=t,R=ring};App.Items[m]=v;return v
end
local function clear(m)local v=App.Items[m];if not v then return end;for _,x in pairs(v)do pcall(x.Destroy,x)end;App.Items[m]=nil end
local function target()
 local cam=workspace.CurrentCamera;local pf=playersFolder();local mr=root(LP.Character);if not cam or not pf or not mr then return end
 local mouse=UIS:GetMouseLocation();local best,score
 for _,m in ipairs(pf:GetChildren())do local r=root(m);if m~=LP.Character and r and alive(m) and wanted(m) then
  local p,on=cam:WorldToViewportPoint(r.Position);local s=(Vector2.new(p.X,p.Y)-mouse).Magnitude
  if on and s<=App.Settings.AimFOV and (not score or s<score) then
   local clear=true;if App.Settings.Wall then local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Exclude;rp.FilterDescendantsInstances={LP.Character,m};clear=workspace:Raycast(cam.CFrame.Position,r.Position-cam.CFrame.Position,rp)==nil end
   if clear then best,score=m,s end
  end
 end end;return best
end
App.Connections[#App.Connections+1]=RunService.RenderStepped:Connect(function()
 local pf=playersFolder();if pf then for _,m in ipairs(pf:GetChildren())do local r=root(m);if m~=LP.Character and r then local v=item(m);local team=m:GetAttribute("Team");local col=team=="EXE" and Color3.fromRGB(255,65,65) or Color3.fromRGB(65,180,255);v.H.FillColor=col;v.H.OutlineColor=Color3.new(1,1,1);v.H.Enabled=App.Settings.Chams;v.B.Enabled=App.Settings.CharacterESP or App.Settings.NameESP or App.Settings.TextESP or App.Settings.HpESP;local state=tostring(m:GetAttribute("State") or "default"):lower();local life=state:find("down") and "DOWNED" or (m:GetAttribute("LastLife") and "LAST LIFE" or "1ST LIFE");local lines={};if App.Settings.NameESP then lines[#lines+1]=m.Name end;if App.Settings.CharacterESP then lines[#lines+1]=tostring(m:GetAttribute("Character") or "Unknown") end;if App.Settings.TextESP then lines[#lines+1]=life.." • "..state:upper() end;local hp=m:FindFirstChild("Health");if App.Settings.HpESP and hp and hp:IsA("NumberValue") then local max=tonumber(hp:GetAttribute("MaxHealth") or m:GetAttribute("MaxHealth"));if not max then App.HPMax[m]=math.max(App.HPMax[m] or 0,hp.Value);max=App.HPMax[m] end;max=math.max(max or hp.Value,1);local ratio=math.clamp(hp.Value/max,0,1);local hex=ratio>.6 and "#55FF66" or (ratio>.3 and "#FFAA33" or "#FF4444");lines[#lines+1]=string.format('<font color="%s">HP: %.0f / %.0f</font>',hex,hp.Value,max) end;v.T.Text=table.concat(lines,"\n");v.R.Color=col;v.R.Size=Vector3.new(.15,App.Settings.HitRadius*2,App.Settings.HitRadius*2);v.R.CFrame=CFrame.new(r.Position+r.CFrame.LookVector*App.Settings.HitRadius-Vector3.new(0,2.7,0))*CFrame.Angles(0,0,math.rad(90));v.R.Transparency=(App.Settings.Hitboxes and attackActive(m)) and .7 or 1 end end end
 if App.Settings.Aim and (not App.Settings.AimHold or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then local m=target();local r=root(m);local c=workspace.CurrentCamera;if r and c then c.CFrame=c.CFrame:Lerp(CFrame.lookAt(c.CFrame.Position,r.Position),App.Settings.AimSmooth) end end
 local l=game:GetService("Lighting");if App.Settings.Fullbright then l.Brightness=3;l.GlobalShadows=false end;if App.Settings.NoFog then l.FogEnd=1e6 end
end)
local e=Tabs.ESP:AddLeftGroupbox("ESP");e:AddToggle("OMChams",{Text="Chams",Default=false,Callback=function(v)App.Settings.Chams=v end});e:AddToggle("OMCharacterESP",{Text="Character ESP (Sonic/Amy/etc.)",Default=true,Callback=function(v)App.Settings.CharacterESP=v end});e:AddToggle("OMNameESP",{Text="Player name ESP",Default=true,Callback=function(v)App.Settings.NameESP=v end});e:AddToggle("OMTextESP",{Text="State/life ESP",Default=true,Callback=function(v)App.Settings.TextESP=v end});e:AddToggle("OMHpESP",{Text="HP ESP",Default=false,Callback=function(v)App.Settings.HpESP=v end});e:AddToggle("OMHitboxes",{Text="Visual attack hitboxes",Default=false,Callback=function(v)App.Settings.Hitboxes=v end});e:AddSlider("OMHitRadius",{Text="Attack hitbox radius",Default=8,Min=1,Max=30,Rounding=2,Suffix=" studs",Callback=function(v)App.Settings.HitRadius=v end})
local a=Tabs.Aim:AddLeftGroupbox("Aim Assist / Aimbot");a:AddToggle("OMAim",{Text="Camera aimbot",Default=false,Callback=function(v)App.Settings.Aim=v end});a:AddToggle("OMAimHold",{Text="Require RMB",Default=true,Callback=function(v)App.Settings.AimHold=v end});a:AddToggle("OMSilentAim",{Text="Generic silent aim",Default=false,Callback=function(v)App.Settings.SilentAim=v end});a:AddToggle("OMTailsCannonSilent",{Text="Tails cannon silent aim",Default=false,Callback=function(v)App.Settings.TailsCannonSilentAim=v end});a:AddToggle("OMAimSurv",{Text="Target survivors",Default=false,Callback=function(v)App.Settings.AimSurvivors=v end});a:AddToggle("OMAimEXE",{Text="Target EXE",Default=true,Callback=function(v)App.Settings.AimEXE=v end});a:AddSlider("OMFOV",{Text="Aim FOV",Default=160,Min=20,Max=500,Rounding=0,Callback=function(v)App.Settings.AimFOV=v end});a:AddSlider("OMSmooth",{Text="Aim smoothing",Default=.18,Min=.01,Max=1,Rounding=2,Callback=function(v)App.Settings.AimSmooth=v end});a:AddToggle("OMWall",{Text="Wall check",Default=true,Callback=function(v)App.Settings.Wall=v end})
local v=Tabs.Visuals:AddLeftGroupbox("Visuals");v:AddToggle("OMBright",{Text="Fullbright",Default=false,Callback=function(x)App.Settings.Fullbright=x end});v:AddToggle("OMFog",{Text="Remove fog",Default=false,Callback=function(x)App.Settings.NoFog=x end})

-- World ESP: Tails Doll mines/tripwires and common objectives/pickups.
local function worldKind(x)
 local n=x.Name:lower()
 local tagged=false;pcall(function()tagged=x:HasTag("Traps")end)
 if tagged then return "TAILS DOLL TRIPMINE",Color3.fromRGB(255,70,40) end
 if n:find("escapering",1,true) or n:find("escape ring",1,true) or n:find("exitring",1,true) or n:find("ringescape",1,true) then return "ESCAPE RING",Color3.fromRGB(80,255,120) end
end
local function worldAdornee(x) if x:IsA("BasePart") then return x end;if x:IsA("Model") then return x.PrimaryPart or x:FindFirstChildWhichIsA("BasePart",true) end end
local function worldItem(x)
 local old=App.WorldItems[x];if old then return old end;local part=worldAdornee(x);local kind,col=worldKind(x);if not part or not kind then return end
 local h=Instance.new("Highlight");h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;h.FillColor=col;h.OutlineColor=Color3.new(1,1,1);h.FillTransparency=.45;h.Adornee=x;h.Parent=x
 local b=Instance.new("BillboardGui");b.Size=UDim2.fromOffset(170,24);b.StudsOffset=Vector3.new(0,2,0);b.AlwaysOnTop=true;b.Adornee=part;b.Parent=part
 local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=kind;t.TextColor3=col;t.TextStrokeTransparency=0;t.TextScaled=true;t.Font=Enum.Font.GothamBold;t.Parent=b
 old={H=h,B=b,Kind=kind};App.WorldItems[x]=old;return old
end
local function scanWorld()
 for _,x in ipairs(workspace:GetDescendants())do local kind=worldKind(x);if kind and (x:IsA("Model") or x:IsA("BasePart")) then local q=worldItem(x);if q then local on=(q.Kind=="TAILS DOLL TRIPMINE" and App.Settings.MineESP) or (q.Kind=="ESCAPE RING" and App.Settings.EscapeESP);q.H.Enabled=on;q.B.Enabled=on end end end
end
e:AddToggle("OMMineESP",{Text="Mine / tripwire ESP",Default=false,Callback=function(x)App.Settings.MineESP=x;scanWorld()end})
e:AddToggle("OMEscapeESP",{Text="Escape ring ESP",Default=false,Callback=function(x)App.Settings.EscapeESP=x;scanWorld()end})
App.Connections[#App.Connections+1]=workspace.DescendantAdded:Connect(function(x)
 task.defer(function() local kind=worldKind(x);if kind then local q=worldItem(x);if q then local on=(q.Kind=="TAILS DOLL TRIPMINE" and App.Settings.MineESP) or (q.Kind=="ESCAPE RING" and App.Settings.EscapeESP);q.H.Enabled=on;q.B.Enabled=on end end end)
end)
local CollectionService=game:GetService("CollectionService")
App.Connections[#App.Connections+1]=CollectionService:GetInstanceAddedSignal("Traps"):Connect(function(x)
 task.defer(function()local q=worldItem(x);if q then q.H.Enabled=App.Settings.MineESP;q.B.Enabled=App.Settings.MineESP end end)
end)

local fov
if Drawing and Drawing.new then fov=Drawing.new("Circle");fov.Filled=false;fov.Thickness=1;fov.NumSides=64;fov.Color=Color3.fromRGB(255,255,255);fov.Transparency=.8 end
a:AddToggle("OMFOVCircle",{Text="Show FOV circle",Default=true,Callback=function(x)App.Settings.FOVCircle=x end})

local info=Tabs.Visuals:AddRightGroupbox("Live Information")
local roundLabel=info:AddLabel("Round: disabled",true)
local threatLabel=info:AddLabel("Threat: disabled",true)
local cooldownLabel=info:AddLabel("Cooldowns: disabled",true)
local speedLabel=info:AddLabel("Speed: disabled",true)
info:AddToggle("OMRoundInfo",{Text="Round information",Default=false,Callback=function(x)App.Settings.RoundInfo=x end})
info:AddToggle("OMThreat",{Text="Threat alerts",Default=false,Callback=function(x)App.Settings.ThreatAlerts=x end})
info:AddSlider("OMThreatRange",{Text="Threat range",Default=45,Min=5,Max=150,Rounding=1,Suffix=" studs",Callback=function(x)App.Settings.ThreatRange=x end})
info:AddToggle("OMCooldownInfo",{Text="Ability / cooldown values",Default=false,Callback=function(x)App.Settings.CooldownInfo=x end})
info:AddToggle("OMSpeedInfo",{Text="Movement speed",Default=false,Callback=function(x)App.Settings.SpeedInfo=x end})

local performance=Tabs.Visuals:AddLeftGroupbox("Performance")
performance:AddToggle("OMLowEffects",{Text="Disable particles and trails",Default=false,Callback=function(x)App.Settings.LowEffects=x;if x then for _,d in ipairs(workspace:GetDescendants())do if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then d.Enabled=false end end end end})

-- Generic OM projectile/move silent aim. Only rewrites spatial arguments on
-- attack-like remotes and leaves ordinary networking untouched.
local oldNamecall
if type(hookmetamethod)=="function" and type(newcclosure)=="function" then
 oldNamecall=hookmetamethod(game,"__namecall",newcclosure(function(self,...)
  local method=getnamecallmethod();local args={...}
 if (App.Settings.SilentAim or App.Settings.TailsCannonSilentAim) and not (type(checkcaller)=="function" and checkcaller()) and (method=="FireServer" or method=="InvokeServer") then
   local remoteName=tostring(self.Name):lower();local attackRemote=remoteName:find("attack",1,true) or remoteName:find("move",1,true) or remoteName:find("projectile",1,true) or remoteName=="onclient"
   if attackRemote then local m=target();local tr=root(m);if tr then local predicted=tr.Position+tr.AssemblyLinearVelocity*.12;local char=LP.Character;local isTails=char and char:GetAttribute("Character")=="Tails";if App.Settings.TailsCannonSilentAim and isTails and root(char) then local rr=root(char);rr.CFrame=CFrame.lookAt(rr.Position,Vector3.new(predicted.X,rr.Position.Y,predicted.Z)) end;if App.Settings.SilentAim or (App.Settings.TailsCannonSilentAim and isTails) then for i,x in ipairs(args)do if typeof(x)=="Vector3" then args[i]=predicted elseif typeof(x)=="CFrame" then args[i]=CFrame.lookAt(x.Position,predicted) end end;return oldNamecall(self,table.unpack(args)) end end end
  end
  return oldNamecall(self,...)
 end))
end

local blockBox=Tabs.Aim:AddRightGroupbox("Auto Block")
blockBox:AddToggle("OMAutoBlock",{Text="Auto block (Knuckles/Eggman)",Default=false,Callback=function(x)App.Settings.AutoBlock=x end})
blockBox:AddSlider("OMBlockRange",{Text="Block threat range",Default=14,Min=3,Max=40,Rounding=2,Suffix=" studs",Callback=function(x)App.Settings.BlockRange=x end})
blockBox:AddSlider("OMBlockDelay",{Text="Reaction delay",Default=.06,Min=0,Max=.5,Rounding=3,Suffix="s",Callback=function(x)App.Settings.BlockDelay=x end})
blockBox:AddSlider("OMBlockHold",{Text="Block hold time",Default=.18,Min=.05,Max=1,Rounding=3,Suffix="s",Callback=function(x)App.Settings.BlockHold=x end})
blockBox:AddDropdown("OMBlockKey",{Text="Block key",Values={"Q","E","R","F","One","Two","Three"},Default="F",Multi=false,Callback=function(x)App.Settings.BlockKey=x end})
local VIM=game:GetService("VirtualInputManager");local lastBlock=0
local function projectileThreat(me)
 local folder=workspace:FindFirstChild("Projectile");if not folder then return false end
 for _,x in ipairs(folder:GetDescendants())do if x:IsA("BasePart") then local delta=me.Position-x.Position;if delta.Magnitude<=App.Settings.BlockRange then local velocity=x.AssemblyLinearVelocity;if velocity.Magnitude>1 and velocity.Unit:Dot(delta.Unit)>.45 then return true end end end end
 return false
end
App.Connections[#App.Connections+1]=RunService.Heartbeat:Connect(function()
 if not App.Settings.AutoBlock or os.clock()-lastBlock<.7 then return end
 local char=LP.Character;local me=root(char);local character=char and tostring(char:GetAttribute("Character"))
 if not me or (character~="Knuckles" and character~="Eggman") then return end
 local danger=projectileThreat(me);local pf=playersFolder()
 if not danger and pf then for _,m in ipairs(pf:GetChildren())do local er=root(m);if m:GetAttribute("Team")=="EXE" and er and (er.Position-me.Position).Magnitude<=App.Settings.BlockRange and attackActive(m) then danger=true;break end end end
 if danger then lastBlock=os.clock();local key=Enum.KeyCode[App.Settings.BlockKey] or Enum.KeyCode.F;task.delay(App.Settings.BlockDelay,function()if not App.Settings.AutoBlock then return end;VIM:SendKeyEvent(true,key,false,game);task.delay(App.Settings.BlockHold,function()VIM:SendKeyEvent(false,key,false,game)end)end)end
end)

local lastInfo=0
App.Connections[#App.Connections+1]=RunService.Heartbeat:Connect(function()
 if os.clock()-lastInfo<.15 then return end;lastInfo=os.clock()
 if fov then fov.Visible=App.Settings.Aim and App.Settings.FOVCircle;fov.Position=UIS:GetMouseLocation();fov.Radius=App.Settings.AimFOV end
 local gp=workspace:FindFirstChild("GameProperties")
 if App.Settings.RoundInfo and gp then local state=gp:FindFirstChild("State");local time=gp:FindFirstChild("Time");local exe=gp:FindFirstChild("EXE");roundLabel:SetText(string.format("%s | %ss | EXE: %s",state and state.Value or "?",time and time.Value or "?",exe and exe.Value or "?"))else roundLabel:SetText("Round: disabled")end
 local me=root(LP.Character);local nearest=math.huge;local nearestName="none";local pf=playersFolder();if me and pf then for _,m in ipairs(pf:GetChildren())do if m:GetAttribute("Team")=="EXE" and m~=LP.Character and root(m) then local d=(root(m).Position-me.Position).Magnitude;if d<nearest then nearest=d;nearestName=m.Name end end end end
 if App.Settings.ThreatAlerts then threatLabel:SetText(nearest<=App.Settings.ThreatRange and string.format("THREAT: %s • %.1f studs",nearestName,nearest) or "Threat: clear")else threatLabel:SetText("Threat: disabled")end
 if App.Settings.SpeedInfo and me then local vel=me.AssemblyLinearVelocity;speedLabel:SetText(string.format("Speed: %.2f studs/s",Vector3.new(vel.X,0,vel.Z).Magnitude))else speedLabel:SetText("Speed: disabled")end
 if App.Settings.CooldownInfo and LP.Character then local values={};for _,x in ipairs(LP.Character:GetChildren())do if x:IsA("NumberValue") and (x.Name:lower():find("cool",1,true) or x.Name:lower():find("charge",1,true) or x.Name:lower():find("mine",1,true) or x.Name:lower():find("energy",1,true)) then values[#values+1]=x.Name..": "..string.format("%.1f",x.Value) end end;cooldownLabel:SetText(#values>0 and table.concat(values," | ") or "Cooldowns: no exposed values")else cooldownLabel:SetText("Cooldowns: disabled")end
end)

function App:Destroy()for _,c in ipairs(self.Connections)do pcall(c.Disconnect,c)end;for m in pairs(self.Items)do clear(m)end;for _,q in pairs(self.WorldItems)do pcall(q.H.Destroy,q.H);pcall(q.B.Destroy,q.B)end;if fov then pcall(fov.Remove,fov)end;if env.__OutcomeMemoriesSuite==self then env.__OutcomeMemoriesSuite=nil end;Library:Unload()end

