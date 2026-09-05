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
local App={Connections={},Items={},Settings={ESP=false,Names=true,Hitboxes=false,HitRadius=8,Aim=false,AimSurvivors=false,AimEXE=true,AimFOV=160,AimSmooth=0.18,Wall=true,Fullbright=false,NoFog=false}}
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
 local b=Instance.new("BillboardGui");b.Name="OM_Tag";b.Size=UDim2.fromOffset(180,28);b.StudsOffset=Vector3.new(0,3.4,0);b.AlwaysOnTop=true;b.Parent=m
 local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.TextStrokeTransparency=.25;t.TextColor3=Color3.new(1,1,1);t.TextScaled=true;t.Font=Enum.Font.GothamBold;t.Parent=b
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
   if not App.Settings.Wall or not workspace:Raycast(cam.CFrame.Position,r.Position-cam.CFrame.Position,RaycastParams.new()) then best,score=m,s end
  end
 end end;return best
end
App.Connections[#App.Connections+1]=RunService.RenderStepped:Connect(function()
 local pf=playersFolder();if pf then for _,m in ipairs(pf:GetChildren())do local r=root(m);if m~=LP.Character and r then local v=item(m);local team=m:GetAttribute("Team");local col=team=="EXE" and Color3.fromRGB(255,65,65) or Color3.fromRGB(65,180,255);v.H.FillColor=col;v.H.OutlineColor=Color3.new(1,1,1);v.H.Enabled=App.Settings.ESP;v.B.Enabled=App.Settings.ESP and App.Settings.Names;local state=tostring(m:GetAttribute("State") or "default"):lower();local life=state:find("down") and "DOWNED" or (m:GetAttribute("LastLife") and "LAST LIFE" or "1ST LIFE");v.T.Text=string.format("%s [%s • %s]",m.Name,life,state:upper());v.R.Color=col;v.R.Size=Vector3.new(.15,App.Settings.HitRadius*2,App.Settings.HitRadius*2);v.R.CFrame=CFrame.new(r.Position+r.CFrame.LookVector*App.Settings.HitRadius-Vector3.new(0,2.7,0))*CFrame.Angles(0,0,math.rad(90));v.R.Transparency=(App.Settings.Hitboxes and attackActive(m)) and .7 or 1 end end end
 if App.Settings.Aim and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then local m=target();local r=root(m);local c=workspace.CurrentCamera;if r and c then c.CFrame=c.CFrame:Lerp(CFrame.lookAt(c.CFrame.Position,r.Position),App.Settings.AimSmooth) end end
 local l=game:GetService("Lighting");if App.Settings.Fullbright then l.Brightness=3;l.GlobalShadows=false end;if App.Settings.NoFog then l.FogEnd=1e6 end
end)
local e=Tabs.ESP:AddLeftGroupbox("ESP");e:AddToggle("OMESP",{Text="Player ESP",Default=false,Callback=function(v)App.Settings.ESP=v end});e:AddToggle("OMNames",{Text="Names, state and lives",Default=true,Callback=function(v)App.Settings.Names=v end});e:AddToggle("OMHitboxes",{Text="Visual attack hitboxes",Default=false,Callback=function(v)App.Settings.Hitboxes=v end});e:AddSlider("OMHitRadius",{Text="Attack hitbox radius",Default=8,Min=1,Max=30,Rounding=2,Suffix=" studs",Callback=function(v)App.Settings.HitRadius=v end})
local a=Tabs.Aim:AddLeftGroupbox("Aim Assist");a:AddToggle("OMAim",{Text="Aim assist (hold RMB)",Default=false,Callback=function(v)App.Settings.Aim=v end});a:AddToggle("OMAimSurv",{Text="Target survivors",Default=false,Callback=function(v)App.Settings.AimSurvivors=v end});a:AddToggle("OMAimEXE",{Text="Target EXE",Default=true,Callback=function(v)App.Settings.AimEXE=v end});a:AddSlider("OMFOV",{Text="Aim FOV",Default=160,Min=20,Max=500,Rounding=0,Callback=function(v)App.Settings.AimFOV=v end});a:AddSlider("OMSmooth",{Text="Aim smoothing",Default=.18,Min=.01,Max=1,Rounding=2,Callback=function(v)App.Settings.AimSmooth=v end});a:AddToggle("OMWall",{Text="Wall check",Default=true,Callback=function(v)App.Settings.Wall=v end})
local v=Tabs.Visuals:AddLeftGroupbox("Visuals");v:AddToggle("OMBright",{Text="Fullbright",Default=false,Callback=function(x)App.Settings.Fullbright=x end});v:AddToggle("OMFog",{Text="Remove fog",Default=false,Callback=function(x)App.Settings.NoFog=x end})
function App:Destroy()for _,c in ipairs(self.Connections)do pcall(c.Disconnect,c)end;for m in pairs(self.Items)do clear(m)end;if env.__OutcomeMemoriesSuite==self then env.__OutcomeMemoriesSuite=nil end;Library:Unload()end

