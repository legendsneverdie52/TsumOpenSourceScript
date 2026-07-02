

if getgenv().__TTH_LOADED then warn("[TTH] already running, aborting duplicate") return end
getgenv().__TTH_LOADED = true

pcall(function()
    for _,f in ipairs({"uip100","Avilon","Rayfield","kiwisense","tungtunghook","FluentScriptHub"}) do
        if isfolder and isfolder(f) then pcall(function() delfolder(f) end) end
    end
end)
pcall(function()
    for _,g in ipairs({"OrionLib","Rayfield","WindUI","Kavo","MacLib","Ilias","LatesUI","KyriLib","Skeet","Gamesense","Onyx","Fates","Xenon","linoria","LinoriaLib","UI_Library","ProtoSmasher","Synapse","Avilon","Serotonin","Sirius"}) do
        getgenv()[g]=nil
    end
end)

for _,d in ipairs({"UnluaXO","Unluraph","unluraph","LuraphDeobf","LuraphUnpack","JunkieDeobf","Codex_Dumper","ScriptDumper","LineByLine","__DEBUG_DUMP","getscriptbytecode_hook","bytecode_dumper","loadstring_hook","httpget_hook","dumper_output","dump_target","__leak"}) do
    if getgenv()[d] then warn("[TTH] dumper detected: "..d); return end
end

if not game:IsLoaded() then game.Loaded:Wait() end
print("[TTH] booting v8.0 rayfield...")

local RAY_URLS = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
}
local Rayfield
for i,url in ipairs(RAY_URLS) do
    local ok, res = pcall(function()
        local body = game:HttpGet(url)
        if not body or #body < 500 then error("empty body") end
        local f = loadstring(body)
        if not f then error("loadstring nil") end
        return f()
    end)
    if ok and res and type(res.CreateWindow) == "function" then
        Rayfield = res
        print("[TTH] rayfield loaded from url #"..i)
        break
    else
        warn("[TTH] rayfield try #"..i.." failed: "..tostring(res))
    end
end
if not Rayfield then warn("[TTH] all rayfield urls failed"); return end

local Players     = game:GetService("Players")
local RS          = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local Workspace   = game:GetService("Workspace")
local Lighting    = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer
local Cam         = Workspace.CurrentCamera
local isMobile    = UIS.TouchEnabled and not UIS.KeyboardEnabled
local Terrain     = Workspace:FindFirstChildOfClass("Terrain")

local State = {
    ESP = false, ScanDropped = false,
    DropColor = Color3.fromRGB(255,220,50),
    ShowName=false, NameSize=16,
    ShowDist=false, DistSize=14,
    ShowPrice=false, PriceSize=14,
    ShowEco=false, EcoSize=14,
    ShowSpawn=false, SpawnSize=14,
    OffArrows=false,
    Chams=false, ChamsColor=Color3.fromRGB(255,255,255), ChamsTrans=0.5,
    RenderDistOn=false, RenderDist=100,
    Rarity = {
        Common    = { Enabled=false, Color=Color3.fromRGB(180,180,180) },
        Uncommon  = { Enabled=true,  Color=Color3.fromRGB(80,200,80)   },
        Rare      = { Enabled=true,  Color=Color3.fromRGB(80,150,255)  },
        Epic      = { Enabled=true,  Color=Color3.fromRGB(180,80,255)  },
        Legendary = { Enabled=true,  Color=Color3.fromRGB(255,180,0)   },
    },
    FilterEnabled=false, FilterChance=false, FilterPrice=false,
    MaxChance=100, MinPrice=0, MaxPrice=99999999,
    Speed=16, InfJump=false,
    RGBNick=false, RGBSpeed=1,
    Skin=false, SkinAssetId="117642723095749", SkinScale=1,
    SkinYOff=0, SkinOffZ=0, SkinRotY=0, SkinSpin=0,
    SkinHide=true, SkinFollow=true,
    Companion=false, CompMode="Follow", CompDist=6, CompHeight=2, OrbitSpeed=1,
    CompModelId="117642723095749", CompScale=1, CompColor=Color3.fromRGB(94,213,213),
    Potato=false,
    ClanC={ Color3.fromRGB(255,90,120), Color3.fromRGB(255,180,60), Color3.fromRGB(80,220,120), Color3.fromRGB(80,160,255), Color3.fromRGB(200,100,240) },
}
local Rarities = {"Common","Uncommon","Rare","Epic","Legendary"}

local MeshMap, NameMap = {}, {}
local function FetchDatabases()
    local MAIN = "https://raw.githubusercontent.com/awaky1337/base/refs/heads/main/database.lua"
    local s1, mainRaw = pcall(function() return game:HttpGet(MAIN) end)
    local db
    if s1 and mainRaw then
        local f = loadstring(mainRaw); db = f and f()
    end
    if not db or type(db.Items) ~= "table" then
        db = { Items = { Shirt = {}, Pants = {} } }
    end

    local ACCS = "https://raw.githubusercontent.com/awaky1337/base/refs/heads/main/accs_db"
    local s2, accsRaw = pcall(function() return game:HttpGet(ACCS) end)
    local accessories = {}
    if s2 and accsRaw then
        accsRaw = string.gsub(accsRaw, '\\"', '"')
        local f = loadstring("return {"..accsRaw.."}")
        local ad = f and f() or {}
        accessories = ad.Accessory or {}
    end

    for _,item in ipairs(accessories) do
        if item.meshId and item.meshId ~= "" then
            local mId = string.gsub(item.meshId:lower(), "\\\\", "")
            MeshMap[mId] = MeshMap[mId] or {}
            table.insert(MeshMap[mId], item)
        else
            NameMap[item.name:lower()] = item
        end
    end
    for _,cat in ipairs({"Shirt","Pants"}) do
        if db.Items[cat] then
            for _,item in ipairs(db.Items[cat]) do
                item.accessoryType = cat
                local added = false
                for _,key in ipairs({"meshId","templateId","textureId"}) do
                    if item[key] and item[key] ~= "" then
                        local kId = string.gsub(item[key]:lower(), "\\\\", "")
                        MeshMap[kId] = MeshMap[kId] or {}
                        table.insert(MeshMap[kId], item)
                        added = true
                    end
                end
                if not added then NameMap[item.name:lower()] = item end
            end
        end
    end
end

local PARENT = gethui and gethui() or game:GetService("CoreGui")
local old = PARENT:FindFirstChild("TTH_ESP"); if old then old:Destroy() end
local oldH = PARENT:FindFirstChild("TTH_HL"); if oldH then oldH:Destroy() end

local espGui = Instance.new("ScreenGui")
espGui.Name="TTH_ESP"; espGui.ResetOnSpawn=false; espGui.IgnoreGuiInset=true; espGui.DisplayOrder=999
espGui.Parent = PARENT

local hlFolder = Instance.new("Folder")
hlFolder.Name="TTH_HL"; hlFolder.Parent = PARENT
local HighlightPool = {}
for i=1,31 do
    local h = Instance.new("Highlight"); h.Enabled=false; h.Parent = hlFolder
    table.insert(HighlightPool, h)
end

local CachedItems = {}

local function AddItemToCache(obj)
    if not obj then return end
    local droppedFolder = Workspace:FindFirstChild("DroppedItems")
    local isInDropped, inShopZone = false, false
    local a = obj
    while a and a ~= Workspace and a ~= game do
        if a:IsA("Model") and Players:GetPlayerFromCharacter(a) then return end
        if droppedFolder and a == droppedFolder then isInDropped = true end
        if string.find(a.Name, "Shop_ShopZone_") == 1 then inShopZone = true end
        a = a.Parent
    end
    if not isInDropped and not inShopZone then return end
    if isInDropped and not State.ScanDropped then return end

    local ids = {}
    local function addId(x)
        if x:IsA("MeshPart") or x:IsA("SpecialMesh") then
            if x.MeshId ~= "" then table.insert(ids, x.MeshId:lower()) end
        elseif x:IsA("Shirt") then
            if x.ShirtTemplate ~= "" then table.insert(ids, x.ShirtTemplate:lower()) end
        elseif x:IsA("Pants") then
            if x.PantsTemplate ~= "" then table.insert(ids, x.PantsTemplate:lower()) end
        elseif x:IsA("ShirtGraphic") then
            if x.Graphic ~= "" then table.insert(ids, x.Graphic:lower()) end
        elseif x:IsA("Decal") then
            if x.Texture ~= "" then table.insert(ids, x.Texture:lower()) end
        end
    end
    if obj:IsA("Model") then
        for _,c in ipairs(obj:GetDescendants()) do addId(c) end
    else addId(obj) end

    local detected
    for _,rawId in ipairs(ids) do
        local mId = string.gsub(rawId, "\\\\", "")
        local numMatch = string.match(mId, "%d+")
        local candidates
        for k,items in pairs(MeshMap) do
            if k == mId or string.match(k, "%d+") == numMatch then
                candidates = items; break
            end
        end
        if candidates then
            if #candidates == 1 then
                detected = candidates[1]; break
            else
                local objN = obj.Name:lower()
                local parN = obj.Parent and obj.Parent.Name:lower() or ""
                for _,it in ipairs(candidates) do
                    local iN = it.name:lower()
                    if objN == iN or parN == iN or string.find(parN, iN, 1, true) then
                        detected = it; break
                    end
                end
                if not detected then detected = candidates[1] end
                break
            end
        end
    end
    if not detected then
        local n = obj.Name:lower()
        if NameMap[n] then detected = NameMap[n] end
    end
    if not detected then return end

    local posType, pos = 0, nil
    if obj:IsA("BasePart") then posType=1; pos=obj.Position
    elseif obj:IsA("Model") then
        if obj.PrimaryPart then posType=2; pos=obj.PrimaryPart.Position
        else posType=3; local ok,piv=pcall(function() return obj:GetPivot() end); if ok and piv then pos=piv.Position end
        end
    end
    if not pos then return end

    for _,cd in pairs(CachedItems) do
        if cd.Data and cd.Data.name == detected.name and cd.Position
        and (cd.Position - pos).Magnitude < 5 then return end
    end

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.GothamBold
    lbl.TextColor3=Color3.new(1,1,1); lbl.RichText=true
    lbl.AnchorPoint=Vector2.new(0.5,0.5); lbl.AutomaticSize=Enum.AutomaticSize.XY
    lbl.Visible=false; lbl.Parent = espGui
    local st=Instance.new("UIStroke", lbl); st.Thickness=1.5; st.Color=Color3.new(0,0,0)
    st.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual

    local arr = Instance.new("TextLabel")
    arr.BackgroundTransparency=1; arr.Font=Enum.Font.GothamBold
    arr.Text="v"; arr.TextColor3=Color3.new(1,1,1); arr.TextSize=20
    arr.AnchorPoint=Vector2.new(0.5,0.5); arr.Visible=false; arr.Parent=espGui
    local st2=Instance.new("UIStroke", arr); st2.Thickness=1.5; st2.Color=Color3.new(0,0,0)

    local target = obj
    local mannequin
    if obj.Name == "Mannequin" then mannequin = obj
    elseif obj:IsA("Instance") and obj:FindFirstChild("Mannequin") then mannequin = obj:FindFirstChild("Mannequin")
    elseif obj.Parent and obj.Parent:FindFirstChild("Mannequin") then mannequin = obj.Parent:FindFirstChild("Mannequin")
    elseif obj.Parent and obj.Parent.Parent and obj.Parent.Parent:FindFirstChild("Mannequin") then mannequin = obj.Parent.Parent:FindFirstChild("Mannequin") end
    if mannequin then target = mannequin
    elseif obj:IsA("Model") then
        for _,c in ipairs(obj:GetDescendants()) do
            if c:IsA("MeshPart") or (c:IsA("Part") and c:FindFirstChildOfClass("SpecialMesh")) then
                target = c; break
            end
        end
        if target == obj and obj.PrimaryPart then target = obj.PrimaryPart end
    end

    CachedItems[obj] = {
        Data=detected, Label=lbl, Arrow=arr,
        Target=target, PosType=posType, Position=pos, IsDropped=isInDropped,
    }
end

local function RemoveItemFromCache(obj)
    local c = CachedItems[obj]; if not c then return end
    if c.Label then pcall(function() c.Label:Destroy() end) end
    if c.Arrow then pcall(function() c.Arrow:Destroy() end) end
    CachedItems[obj] = nil
end

local DBReady, ESPReady = false, false
task.spawn(function() FetchDatabases(); DBReady = true end)

local HookedFolders = {}
local function hookFolder(folder)
    if not folder or HookedFolders[folder] then return end
    HookedFolders[folder] = true
    local list = folder:GetDescendants()
    for i,d in ipairs(list) do
        AddItemToCache(d)
        if i % 40 == 0 then task.wait() end
    end
    folder.DescendantAdded:Connect(AddItemToCache)
    folder.DescendantRemoving:Connect(RemoveItemFromCache)
end

task.spawn(function()
    while not DBReady do task.wait(0.1) end
    local targets = {}
    local drop = Workspace:FindFirstChild("DroppedItems")
    if drop then table.insert(targets, drop) end
    for _,c in ipairs(Workspace:GetChildren()) do
        if string.find(c.Name, "Shop_ShopZone_") == 1 then
            table.insert(targets, c)
        end
    end
    for _,f in ipairs(targets) do
        hookFolder(f)
        task.wait()
    end
    Workspace.ChildAdded:Connect(function(c)
        if c.Name == "DroppedItems" or string.find(c.Name, "Shop_ShopZone_") == 1 then
            task.wait(0.5)
            hookFolder(c)
        end
    end)
    ESPReady = true
end)

local function OffscreenPos(pos)
    local vs = Cam.ViewportSize
    local center = vs / 2
    local offset = Vector2.new(pos.X, pos.Y) - center
    if pos.Z < 0 then offset = -offset end
    local ang = math.atan2(offset.Y, offset.X)
    local rx, ry = math.cos(ang), math.sin(ang)
    local pad = 40
    local bx, by = center.X - pad, center.Y - pad
    local sc = math.min(bx / math.abs(rx), by / math.abs(ry))
    return Vector2.new(center.X + rx * sc, center.Y + ry * sc), ang
end

RS.RenderStepped:Connect(function()
    if not ESPReady then return end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local activeHL = 0
    for _,h in ipairs(HighlightPool) do h.Enabled = false end

    for obj, cd in pairs(CachedItems) do
        local data = cd.Data
        local rar = State.Rarity[data.rarity or "Common"]
        cd.Label.Visible = false; cd.Arrow.Visible = false
        if obj.Parent then
            local isDrop = cd.IsDropped
            local go = true
            if isDrop then
                if not State.ScanDropped then go = false end
            else
                if not State.ESP or not rar or not rar.Enabled then go = false end
                if go and State.FilterEnabled then
                    if State.FilterChance and (not data.spawnChance or data.spawnChance > State.MaxChance) then go = false end
                    if go and State.FilterPrice then
                        local pr = data.fairPrice or 0
                        if pr < State.MinPrice or pr > State.MaxPrice then go = false end
                    end
                end
            end
            if go then
                local position
                if cd.PosType == 1 then position = obj.Position
                elseif cd.PosType == 2 and obj.PrimaryPart then position = obj.PrimaryPart.Position
                elseif cd.PosType == 3 then
                    local okp, piv = pcall(function() return obj:GetPivot() end)
                    if okp and piv then position = piv.Position end
                end
                if position then
                    local sp, on = Cam:WorldToViewportPoint(position)
                    local meters = hrp and math.floor((hrp.Position - position).Magnitude * 0.28) or 0
                    if State.RenderDistOn and meters > State.RenderDist then
                        -- skip
                    elseif on then
                        local yOff = 0
                        pcall(function()
                            if cd.Target:IsA("Model") then yOff = cd.Target:GetExtentsSize().Y / 2
                            elseif cd.Target:IsA("BasePart") then yOff = cd.Target.Size.Y / 2 end
                        end)
                        local top = Cam:WorldToViewportPoint(position + Vector3.new(0, yOff + 0.5, 0))
                        local parts = {}
                        if State.ShowName then
                            local nm = isDrop and ("DROP "..data.name) or data.name
                            table.insert(parts, string.format('<font size="%d"><b>%s</b></font>', State.NameSize, nm))
                        end
                        if State.ShowPrice and data.fairPrice then
                            table.insert(parts, string.format('<font size="%d">$%s</font>', State.PriceSize, tostring(data.fairPrice)))
                        end
                        if State.ShowEco and data.economyProfile then
                            table.insert(parts, string.format('<font size="%d">%s</font>', State.EcoSize, tostring(data.economyProfile)))
                        end
                        local txt = table.concat(parts, " ")
                        if State.ShowDist and hrp then
                            txt = txt .. string.format('\n<font size="%d" color="#FFFFFF">[%dm]</font>', State.DistSize, meters)
                        end
                        if State.ShowSpawn and data.spawnChance then
                            txt = txt .. string.format('\n<font size="%d" color="#FFFFFF">chance %s%%</font>', State.SpawnSize, tostring(data.spawnChance))
                        end
                        cd.Label.Text = txt
                        cd.Label.Position = UDim2.new(0, top.X, 0, top.Y)
                        cd.Label.AnchorPoint = Vector2.new(0.5, 1)
                        cd.Label.ZIndex = math.floor(10000 - sp.Z)
                        cd.Label.Visible = true
                        if State.Chams and activeHL < 31 then
                            activeHL = activeHL + 1
                            local h = HighlightPool[activeHL]
                            h.Adornee = cd.Target
                            h.FillColor = State.ChamsColor
                            h.OutlineColor = Color3.new(1,1,1)
                            h.FillTransparency = State.ChamsTrans
                            h.OutlineTransparency = 0.2
                            h.Enabled = true
                        end
                    elseif State.OffArrows then
                        local edge, ang = OffscreenPos(sp)
                        local nm = isDrop and ("DROP "..data.name) or data.name
                        cd.Label.Text = string.format("<b>%s</b> <font size='10'>(%s)</font>", nm, data.rarity or "Normal")
                        local offD = 20
                        local tp = edge - Vector2.new(math.cos(ang) * offD, math.sin(ang) * offD)
                        cd.Label.Position = UDim2.new(0, tp.X, 0, tp.Y)
                        cd.Label.AnchorPoint = Vector2.new(
                            (tp.X > Cam.ViewportSize.X/2) and 1 or 0,
                            (tp.Y > Cam.ViewportSize.Y/2) and 1 or 0)
                        local bZ = math.floor(10000 - math.abs(sp.Z))
                        cd.Label.ZIndex = bZ
                        cd.Label.Visible = true
                        cd.Arrow.Position = UDim2.new(0, edge.X, 0, edge.Y)
                        cd.Arrow.Rotation = math.deg(ang) - 90
                        cd.Arrow.ZIndex = bZ
                        cd.Arrow.Visible = true
                    end
                end
            end
        end
    end
end)

local function setSpeed(v)
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v end
end
UIS.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local nameTag = LP.PlayerGui:FindFirstChild("LocalResellerNameTag")
local mainCont = nameTag and nameTag:FindFirstChild("MainContainer")
local clanLbl, clanGrad
local clanOrig = {text=nil, color=nil}
local function grabClan()
    if not mainCont then return end
    for _,d in ipairs(mainCont:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name:lower():find("clan") then
            clanLbl = d
            if not clanOrig.text then clanOrig.text = d.Text; clanOrig.color = d.TextColor3 end
            break
        end
    end
end
grabClan()

local nickLbl, nickOrig
local function grabNick()
    if not mainCont or nickLbl then return end
    for _,d in ipairs(mainCont:GetDescendants()) do
        if d:IsA("TextLabel") and (d.Name:lower():find("nick") or d.Name:lower():find("name")) then
            nickLbl = d; nickOrig = d.TextColor3; break
        end
    end
end
grabNick()
RS.RenderStepped:Connect(function()
    if not State.RGBNick then return end
    grabNick()
    if nickLbl then
        local hue = (tick() * (State.RGBSpeed or 1) * 0.15) % 1
        nickLbl.TextColor3 = Color3.fromHSV(hue, 1, 1)
    end
end)

local function applyClanColors()
    if not clanLbl then return end
    if clanGrad then clanGrad:Destroy(); clanGrad=nil end
    clanGrad = Instance.new("UIGradient", clanLbl); clanGrad.Name = "__TTH_ClanGradient"
    local kp = {}
    for i,c in ipairs(State.ClanC) do
        table.insert(kp, ColorSequenceKeypoint.new((i-1)/(#State.ClanC-1), c))
    end
    clanGrad.Color = ColorSequence.new(kp)
end

local Skin = { Model = nil, SpinAccum = 0 }
local invisConn
local function stopInvisLoop()
    if invisConn then invisConn:Disconnect(); invisConn = nil end
    local char = LP.Character
    if char then
        for _,d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then d.LocalTransparencyModifier = 0
            elseif d:IsA("Decal") then d.Transparency = 0 end
        end
    end
end
local function startInvisLoop()
    if invisConn then return end
    invisConn = RS.RenderStepped:Connect(function()
        if not (State.Skin and State.SkinHide) then return end
        local char = LP.Character; if not char then return end
        for _,d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.LocalTransparencyModifier ~= 1 then d.LocalTransparencyModifier = 1
            elseif d:IsA("Decal") and d.Transparency ~= 1 then d.Transparency = 1 end
        end
    end)
end
local function prepModel(objs)
    local root = objs[1]
    local m
    if root:IsA("Model") then m = root
    elseif root:IsA("BasePart") then
        m = Instance.new("Model"); root.Parent = m; m.PrimaryPart = root
    else
        m = Instance.new("Model")
        for _,c in ipairs(root:GetChildren()) do c.Parent = m end
    end
    if not (m.PrimaryPart and m.PrimaryPart.Parent) then
        local pp = m:FindFirstChildWhichIsA("BasePart", true); if pp then m.PrimaryPart = pp end
    end
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true; d.CanCollide = false; d.CanQuery = false
            d.CanTouch = false; d.Massless = true; d.Locked = true
        end
    end
    return m
end
local function unloadSkin()
    if Skin.Model then pcall(function() Skin.Model:Destroy() end); Skin.Model = nil end
end
local function loadSkin(assetId)
    unloadSkin()
    local uri = "rbxassetid://"..tostring(assetId)
    local ok, objs = pcall(function() return game:GetObjects(uri) end)
    if not ok or not objs or #objs == 0 then warn("[TTH] skin load fail:", assetId); return end
    local m = prepModel(objs)
    pcall(function() m:ScaleTo(State.SkinScale) end)
    m.Name = "__TTH_Skin"; m.Parent = Workspace; Skin.Model = m
end
local function applySkin(on)
    if not on then
        unloadSkin(); stopInvisLoop(); return
    end
    if State.SkinHide then startInvisLoop() end
    if State.SkinAssetId and tostring(State.SkinAssetId) ~= "" then
        loadSkin(State.SkinAssetId)
    end
end
RS.Heartbeat:Connect(function(dt)
    if not State.Skin then
        if Skin.Model then unloadSkin() end
        return
    end
    if not Skin.Model or not Skin.Model.Parent then
        if State.SkinAssetId and tostring(State.SkinAssetId) ~= "" then loadSkin(State.SkinAssetId) end
        return
    end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    Skin.SpinAccum = Skin.SpinAccum + (State.SkinSpin or 0) * dt
    local _, charYaw, _ = hrp.CFrame:ToOrientation()
    local yawBase = State.SkinFollow and charYaw or 0
    local cf = CFrame.new(hrp.Position)
        * CFrame.Angles(0, yawBase + math.rad((State.SkinRotY or 0) + Skin.SpinAccum), 0)
        * CFrame.new(0, State.SkinYOff or 0, State.SkinOffZ or 0)
    pcall(function() Skin.Model:PivotTo(cf) end)
end)

local compModel
local function killComp()
    if compModel then pcall(function() compModel:Destroy() end); compModel=nil end
end
local function pivotComp(cf)
    if not compModel then return end
    if compModel:IsA("Model") then pcall(function() compModel:PivotTo(cf) end)
    elseif compModel:IsA("BasePart") then compModel.CFrame = cf end
end
local function getCompPos()
    if not compModel then return nil end
    if compModel:IsA("Model") then
        local ok, piv = pcall(function() return compModel:GetPivot() end)
        if ok and piv then return piv.Position end
    elseif compModel:IsA("BasePart") then
        return compModel.Position
    end
end
local function anchorAll(m)
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true; d.CanCollide = false; d.Massless = true
        elseif d:IsA("Humanoid") then
            d.HealthDisplayDistance = 0; d.NameDisplayDistance = 0
        end
    end
end
local function spawnComp()
    killComp()
    local built
    pcall(function()
        local arr = game:GetObjects("rbxassetid://"..tostring(State.CompModelId))
        if arr and arr[1] then
            local m = arr[1]; m.Name = "__TTH_Companion"
            if m:IsA("Model") then
                anchorAll(m)
                if not m.PrimaryPart then
                    local any = m:FindFirstChildWhichIsA("BasePart", true)
                    if any then m.PrimaryPart = any end
                end
                pcall(function() m:ScaleTo(State.CompScale or 1) end)
                m.Parent = Workspace; built = m
            elseif m:IsA("BasePart") then
                m.Anchored = true; m.CanCollide = false
                m.Size = m.Size * (State.CompScale or 1)
                m.Parent = Workspace; built = m
            end
        end
    end)
    if not built then
        local part = Instance.new("Part")
        part.Name = "__TTH_Companion"
        part.Size = Vector3.new(3,3,3) * (State.CompScale or 1)
        part.Anchored = true; part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = State.CompColor or Color3.fromRGB(94,213,213)
        part.Shape = Enum.PartType.Ball
        pcall(function()
            local sm = Instance.new("SpecialMesh", part)
            sm.MeshType = Enum.MeshType.FileMesh
            sm.MeshId = "rbxassetid://"..tostring(State.CompModelId)
            sm.Scale = Vector3.new(1,1,1) * (State.CompScale or 1)
        end)
        part.Parent = Workspace; built = part
    end
    compModel = built
end
RS.Heartbeat:Connect(function()
    if not (State.Companion and compModel) then return end
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if State.CompMode == "Follow" then
        local behind = hrp.Position - hrp.CFrame.LookVector * State.CompDist + Vector3.new(0, State.CompHeight, 0)
        local cur = getCompPos() or behind
        pivotComp(CFrame.new(cur:Lerp(behind, 0.15), hrp.Position))
    else
        local t = tick() * State.OrbitSpeed
        local off = Vector3.new(math.cos(t)*State.CompDist, State.CompHeight, math.sin(t)*State.CompDist)
        pivotComp(CFrame.new(hrp.Position + off, hrp.Position))
    end
end)

local origLighting = {
    Brightness=Lighting.Brightness, GlobalShadows=Lighting.GlobalShadows,
    FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
}
local potatoTouched = {}
local function stash(inst, prop, val) table.insert(potatoTouched, {inst=inst, prop=prop, old=val}) end
local function safeSet(inst, prop, val)
    local oldv = inst[prop]
    local ok = pcall(function() inst[prop] = val end)
    if ok then stash(inst, prop, oldv) end
end
local function setPotato(on)
    if on then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function() Lighting.GlobalShadows=false end)
        pcall(function() Lighting.Brightness=1 end)
        pcall(function() Lighting.FogEnd=1e6 end)
        pcall(function() Lighting.FogStart=1e6 end)
        for _,e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("ColorCorrectionEffect")
            or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
                if e.Enabled then safeSet(e, "Enabled", false) end
            end
        end
        if Terrain then
            for _,pr in ipairs({"Decoration","WaterWaveSize","WaterWaveSpeed","WaterReflectance","WaterTransparency"}) do
                pcall(function()
                    local v = Terrain[pr]
                    if pr == "Decoration" then safeSet(Terrain, pr, false)
                    elseif pr == "WaterTransparency" then safeSet(Terrain, pr, 1)
                    else safeSet(Terrain, pr, 0) end
                end)
            end
        end
        for _,d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke")
            or d:IsA("Trail") or d:IsA("Sparkles") or d:IsA("Beam") then
                if d.Enabled then safeSet(d, "Enabled", false) end
            elseif d:IsA("MeshPart") then
                pcall(function() safeSet(d, "RenderFidelity", Enum.RenderFidelity.Performance) end)
            elseif d:IsA("Texture") or d:IsA("Decal") then
                safeSet(d, "Transparency", 1)
            elseif d:IsA("BasePart") then
                if d.Material == Enum.Material.Glass
                or d.Material == Enum.Material.ForceField
                or d.Material == Enum.Material.Neon then
                    safeSet(d, "Material", Enum.Material.Plastic)
                end
                if d.Reflectance > 0 then safeSet(d, "Reflectance", 0) end
            end
        end
    else
        pcall(function() Lighting.GlobalShadows = origLighting.GlobalShadows end)
        pcall(function() Lighting.Brightness = origLighting.Brightness end)
        pcall(function() Lighting.FogEnd = origLighting.FogEnd end)
        pcall(function() Lighting.FogStart = origLighting.FogStart end)
        for _,r in ipairs(potatoTouched) do
            pcall(function() r.inst[r.prop] = r.old end)
        end
        potatoTouched = {}
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    end
end

local Window = Rayfield:CreateWindow({
    Name = "tungtunghook",
    LoadingTitle = "tungtunghook",
    LoadingSubtitle = "v8.0 | rayfield",
    ShowText = "tungtunghook",
    ConfigurationSaving = { Enabled = true, FolderName = "tungtunghook", FileName = "config" },
    Discord = { Enabled = false },
    KeySystem = false,
})

local Tabs = {
    Items    = Window:CreateTab("items"),
    Move     = Window:CreateTab("move"),
    Name     = Window:CreateTab("names"),
    Skin     = Window:CreateTab("skin"),
    Comp     = Window:CreateTab("comp"),
    Misc     = Window:CreateTab("misc"),
    Settings = Window:CreateTab("config"),
}

Tabs.Items:CreateSection("global")
Tabs.Items:CreateToggle({ Name = "esp",           CurrentValue = false, Flag = "esp",      Callback = function(v) State.ESP = v end })
Tabs.Items:CreateToggle({ Name = "dropped items", CurrentValue = false, Flag = "esp_drop", Callback = function(v) State.ScanDropped = v end })
Tabs.Items:CreateToggle({ Name = "limit range",   CurrentValue = false, Flag = "esp_rd",   Callback = function(v) State.RenderDistOn = v end })
Tabs.Items:CreateSlider({ Name = "range (m)", Range = {10, 500}, Increment = 1, Suffix = " m", CurrentValue = 100, Flag = "esp_rdv", Callback = function(v) State.RenderDist = v end })

Tabs.Items:CreateSection("display")
Tabs.Items:CreateToggle({ Name = "offscreen arrows", CurrentValue = false, Flag = "disp_off", Callback = function(v) State.OffArrows = v end })
Tabs.Items:CreateToggle({ Name = "chams",            CurrentValue = false, Flag = "ch_on",    Callback = function(v) State.Chams = v end })
Tabs.Items:CreateColorPicker({ Name = "chams color", Color = State.ChamsColor, Flag = "ch_c",  Callback = function(c) State.ChamsColor = c end })
Tabs.Items:CreateSlider({ Name = "chams trans", Range = {0, 1}, Increment = 0.01, Suffix = "", CurrentValue = 0.5, Flag = "ch_t", Callback = function(v) State.ChamsTrans = v end })
Tabs.Items:CreateToggle({ Name = "show name",     CurrentValue = false, Flag = "disp_n",  Callback = function(v) State.ShowName = v end })
Tabs.Items:CreateSlider({ Name = "name size",     Range = {10, 40}, Increment = 1, Suffix = " px", CurrentValue = 16, Flag = "disp_ns", Callback = function(v) State.NameSize = math.floor(v) end })
Tabs.Items:CreateToggle({ Name = "show distance", CurrentValue = false, Flag = "disp_d",  Callback = function(v) State.ShowDist = v end })
Tabs.Items:CreateSlider({ Name = "dist size",     Range = {10, 40}, Increment = 1, Suffix = " px", CurrentValue = 14, Flag = "disp_ds", Callback = function(v) State.DistSize = math.floor(v) end })
Tabs.Items:CreateToggle({ Name = "show price",    CurrentValue = false, Flag = "disp_p",  Callback = function(v) State.ShowPrice = v end })
Tabs.Items:CreateSlider({ Name = "price size",    Range = {10, 40}, Increment = 1, Suffix = " px", CurrentValue = 14, Flag = "disp_ps", Callback = function(v) State.PriceSize = math.floor(v) end })
Tabs.Items:CreateToggle({ Name = "show economy",  CurrentValue = false, Flag = "disp_e",  Callback = function(v) State.ShowEco = v end })
Tabs.Items:CreateSlider({ Name = "eco size",      Range = {10, 40}, Increment = 1, Suffix = " px", CurrentValue = 14, Flag = "disp_es", Callback = function(v) State.EcoSize = math.floor(v) end })
Tabs.Items:CreateToggle({ Name = "show spawn %",  CurrentValue = false, Flag = "disp_sp", Callback = function(v) State.ShowSpawn = v end })
Tabs.Items:CreateSlider({ Name = "spawn size",    Range = {10, 40}, Increment = 1, Suffix = " px", CurrentValue = 14, Flag = "disp_sps", Callback = function(v) State.SpawnSize = math.floor(v) end })

Tabs.Items:CreateSection("rarity")
for _,r in ipairs(Rarities) do
    Tabs.Items:CreateToggle({ Name = r:lower(), CurrentValue = State.Rarity[r].Enabled, Flag = "rar_"..r,
        Callback = function(v) State.Rarity[r].Enabled = v end })
    Tabs.Items:CreateColorPicker({ Name = r:lower().." color", Color = State.Rarity[r].Color, Flag = "rarc_"..r,
        Callback = function(c) State.Rarity[r].Color = c end })
end

Tabs.Items:CreateSection("filters")
Tabs.Items:CreateToggle({ Name = "enable filter", CurrentValue = false, Flag = "filt_on", Callback = function(v) State.FilterEnabled = v end })
Tabs.Items:CreateToggle({ Name = "by chance",     CurrentValue = false, Flag = "filt_ch", Callback = function(v) State.FilterChance = v end })
Tabs.Items:CreateInput({ Name = "max chance %", PlaceholderText = "100", CurrentValue = tostring(State.MaxChance), RemoveTextAfterFocusLost = false, Flag = "filt_mc", Callback = function(v)
    local n = tonumber(v); if n then State.MaxChance = n end
end })
Tabs.Items:CreateToggle({ Name = "by price", CurrentValue = false, Flag = "filt_pr", Callback = function(v) State.FilterPrice = v end })
Tabs.Items:CreateInput({ Name = "min price", PlaceholderText = "0", CurrentValue = tostring(State.MinPrice), RemoveTextAfterFocusLost = false, Flag = "filt_min", Callback = function(v)
    local n = tonumber(v); if n then State.MinPrice = n end
end })
Tabs.Items:CreateInput({ Name = "max price", PlaceholderText = "99999999", CurrentValue = tostring(State.MaxPrice), RemoveTextAfterFocusLost = false, Flag = "filt_max", Callback = function(v)
    local n = tonumber(v); if n then State.MaxPrice = n end
end })

Tabs.Move:CreateSection("movement")
Tabs.Move:CreateSlider({ Name = "walkspeed", Range = {16, 120}, Increment = 1, Suffix = "", CurrentValue = 16, Flag = "mov_sp",
    Callback = function(v) State.Speed = v; setSpeed(v) end })
Tabs.Move:CreateToggle({ Name = "infinite jump", CurrentValue = false, Flag = "mov_inf", Callback = function(v) State.InfJump = v end })

Tabs.Name:CreateSection("custom nick")
Tabs.Name:CreateInput({ Name = "nick", PlaceholderText = "leave empty to reset", CurrentValue = "", RemoveTextAfterFocusLost = false, Flag = "nick", Callback = function(v)
    if not mainCont then return end
    for _,d in ipairs(mainCont:GetDescendants()) do
        if d:IsA("TextLabel") and (d.Name:lower():find("nick") or d.Name:lower():find("name")) then
            if v ~= "" then d.Text = v end
        end
    end
end })

Tabs.Name:CreateSection("badges")
local BadgeIdsUI = {Dev=10885640682, YT=1275974017, TT=137014429261024, Mod=9209424449, Verify=138018675655074}
for k,id in pairs(BadgeIdsUI) do
    Tabs.Name:CreateToggle({ Name = k:lower().." badge", CurrentValue = false, Flag = "bd_"..k, Callback = function(v)
        if not mainCont then return end
        for _,d in ipairs(mainCont:GetDescendants()) do
            if d:IsA("ImageLabel") and tostring(d.Image):find(tostring(id)) then
                d.Visible = v
            end
        end
    end })
end

Tabs.Name:CreateSection("clan tag")
Tabs.Name:CreateInput({ Name = "clan text", PlaceholderText = "custom clan text", CurrentValue = "", RemoveTextAfterFocusLost = false, Flag = "clan_txt", Callback = function(v)
    grabClan()
    if clanLbl then
        if v == "" and clanOrig.text then clanLbl.Text = clanOrig.text
        else clanLbl.Text = v end
    end
end })
Tabs.Name:CreateButton({ Name = "reset clan", Callback = function()
    grabClan()
    if clanLbl and clanOrig.text then
        clanLbl.Text = clanOrig.text; clanLbl.TextColor3 = clanOrig.color
        if clanGrad then clanGrad:Destroy(); clanGrad = nil end
    end
end })

Tabs.Name:CreateSection("clan colors (gradient)")
for i=1,5 do
    Tabs.Name:CreateColorPicker({ Name = "slot "..i, Color = State.ClanC[i], Flag = "clanc_"..i, Callback = function(c)
        State.ClanC[i] = c; applyClanColors()
    end })
end
Tabs.Name:CreateButton({ Name = "apply gradient", Callback = applyClanColors })

Tabs.Name:CreateSection("rgb nick")
Tabs.Name:CreateToggle({ Name = "rgb nick", CurrentValue = false, Flag = "rgb_n", Callback = function(v)
    State.RGBNick = v
    if not v and nickLbl and nickOrig then nickLbl.TextColor3 = nickOrig end
end })
Tabs.Name:CreateSlider({ Name = "rgb speed", Range = {0.1, 10}, Increment = 0.1, Suffix = "x", CurrentValue = 1, Flag = "rgb_ns", Callback = function(v) State.RGBSpeed = v end })

Tabs.Skin:CreateSection("skin")
Tabs.Skin:CreateToggle({ Name = "enable", CurrentValue = false, Flag = "sk_on", Callback = function(v)
    State.Skin = v; applySkin(v)
end })
Tabs.Skin:CreateInput({ Name = "asset id", PlaceholderText = "rbx asset id", CurrentValue = tostring(State.SkinAssetId), RemoveTextAfterFocusLost = false, Flag = "sk_aid", Callback = function(v)
    if v and v ~= "" then
        State.SkinAssetId = v
        if State.Skin then applySkin(true) end
    end
end })
Tabs.Skin:CreateToggle({ Name = "hide real character", CurrentValue = true, Flag = "sk_hide", Callback = function(v)
    State.SkinHide = v
    if State.Skin then
        if v then startInvisLoop() else stopInvisLoop() end
    end
end })
Tabs.Skin:CreateToggle({ Name = "follow char rotation", CurrentValue = true, Flag = "sk_follow", Callback = function(v)
    State.SkinFollow = v
end })
Tabs.Skin:CreateSlider({ Name = "scale", Range = {0.1, 6}, Increment = 0.05, Suffix = "x", CurrentValue = 1, Flag = "sk_scale",
    Callback = function(v)
        State.SkinScale = v
        if Skin.Model then pcall(function() Skin.Model:ScaleTo(v) end) end
    end })
Tabs.Skin:CreateSlider({ Name = "y offset",   Range = {-20, 20},  Increment = 0.1, Suffix = "",       CurrentValue = 0, Flag = "sk_yoff",  Callback = function(v) State.SkinYOff = v end })
Tabs.Skin:CreateSlider({ Name = "z offset",   Range = {-20, 20},  Increment = 0.1, Suffix = "",       CurrentValue = 0, Flag = "sk_zoff",  Callback = function(v) State.SkinOffZ = v end })
Tabs.Skin:CreateSlider({ Name = "rotation y", Range = {0, 360},   Increment = 1,   Suffix = " deg",   CurrentValue = 0, Flag = "sk_roty",  Callback = function(v) State.SkinRotY = v end })
Tabs.Skin:CreateSlider({ Name = "spin speed", Range = {-360, 360},Increment = 1,   Suffix = " deg/s", CurrentValue = 0, Flag = "sk_spin",  Callback = function(v) State.SkinSpin = v end })
Tabs.Skin:CreateButton({ Name = "reload skin", Callback = function() if State.Skin then loadSkin(State.SkinAssetId) end end })

Tabs.Comp:CreateSection("companion")
Tabs.Comp:CreateToggle({ Name = "enable", CurrentValue = false, Flag = "cp_on", Callback = function(v)
    State.Companion = v
    if v then spawnComp() else killComp() end
end })
Tabs.Comp:CreateDropdown({ Name = "mode", Options = {"Follow","Orbit"}, CurrentOption = { "Follow" }, MultipleOptions = false, Flag = "cp_mode", Callback = function(v)
    local pick = type(v) == "table" and v[1] or v
    State.CompMode = pick or "Follow"
end })
Tabs.Comp:CreateSlider({ Name = "distance",  Range = {2, 20},  Increment = 0.1, Suffix = " m", CurrentValue = 6, Flag = "cp_dist",  Callback = function(v) State.CompDist = v end })
Tabs.Comp:CreateSlider({ Name = "height",    Range = {-3, 10}, Increment = 0.1, Suffix = " m", CurrentValue = 2, Flag = "cp_hgt",   Callback = function(v) State.CompHeight = v end })
Tabs.Comp:CreateSlider({ Name = "orbit spd", Range = {0.1, 5}, Increment = 0.05,Suffix = "x",  CurrentValue = 1, Flag = "cp_orb",   Callback = function(v) State.OrbitSpeed = v end })

Tabs.Comp:CreateSection("model")
Tabs.Comp:CreateInput({ Name = "asset id", PlaceholderText = "rbx asset id", CurrentValue = tostring(State.CompModelId), RemoveTextAfterFocusLost = false, Flag = "cp_aid", Callback = function(v)
    if v and v ~= "" then
        State.CompModelId = v; if State.Companion then spawnComp() end
    end
end })
Tabs.Comp:CreateSlider({ Name = "scale", Range = {0.1, 6}, Increment = 0.05, Suffix = "x", CurrentValue = 1, Flag = "cp_scale", Callback = function(v)
    State.CompScale = v; if State.Companion then spawnComp() end
end })
Tabs.Comp:CreateColorPicker({ Name = "fallback color", Color = State.CompColor, Flag = "cp_col", Callback = function(c)
    State.CompColor = c
    if compModel and compModel:IsA("BasePart") then compModel.Color = c end
end })
Tabs.Comp:CreateButton({ Name = "respawn", Callback = function() if State.Companion then spawnComp() end end })

Tabs.Misc:CreateSection("graphics")
Tabs.Misc:CreateToggle({ Name = "potato mode", CurrentValue = false, Flag = "ms_potato", Callback = function(v)
    State.Potato = v; setPotato(v)
end })

Tabs.Settings:CreateSection("menu")
Tabs.Settings:CreateParagraph({ Title = "toggle ui", Content = "default hotkey: K. rebind via Rayfield settings tab." })
Tabs.Settings:CreateButton({ Name = "unload tungtunghook", Callback = function()
    killComp()
    if State.Skin then applySkin(false) end
    if State.Potato then setPotato(false) end
    for o,c in pairs(CachedItems) do
        if c.Label then pcall(function() c.Label:Destroy() end) end
        if c.Arrow then pcall(function() c.Arrow:Destroy() end) end
        CachedItems[o] = nil
    end
    if espGui  then pcall(function() espGui:Destroy() end) end
    if hlFolder then pcall(function() hlFolder:Destroy() end) end
    unloadSkin(); stopInvisLoop()
    if clanGrad then pcall(function() clanGrad:Destroy() end) end
    pcall(function() Rayfield:Destroy() end)
    getgenv().__TTH_LOADED = nil
end })

pcall(function() Rayfield:LoadConfiguration() end)

pcall(function()
    Rayfield:Notify({
        Title = "tungtunghook v8.0",
        Content = "rayfield ui loaded.",
        Duration = 5,
    })
end)
