-- Headless Ultra-Minimizer for multi-instance cloud (safe)
-- Execute with Codex (or any executor that supports client-side Luau).
-- PURPOSE: reduce rendering, disable effects/particles/sounds, hide GUI -> lower bandwidth & CPU/GPU usage.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

-- CONFIG
local REAPPLY_INTERVAL = 8        -- seconds, re-apply settings to catch newly spawned effects
local TARGET_FPS = 30             -- target FPS hint (not guaranteed)
local HIDE_ALL_GUI = true         -- hide scoreboard / chat / other GUIs
local DISABLE_SOUNDS = true
local DISABLE_PARTICLES = true
local DISABLE_TRAILS = true
local HIDE_DECALS_TEXTURES = true
local DISABLE_POSTPROCESS = true
local DISABLE_SHADOWS = true

-- Safe helper wrappers
local function safe(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok, res
end

-- Try set UserGameSettings / Graphics low
local function applyUserSettings()
    safe(function()
        local usuccess, UserSettingsObj = pcall(function() return UserSettings() end)
        if not usuccess or not UserSettingsObj then return end

        local ugsuccess, UserGameSettings = pcall(function() return UserSettingsObj:GetService("UserGameSettings") end)
        if not ugsuccess or not UserGameSettings then return end

        -- Try multiple possible API names
        pcall(function()
            if UserGameSettings.SetGraphicsQualityLevel then
                UserGameSettings:SetGraphicsQualityLevel(1)
            elseif UserGameSettings.SetQualityLevel then
                UserGameSettings:SetQualityLevel(1)
            end
        end)
        pcall(function()
            if UserGameSettings.SetFidelityLevel then
                UserGameSettings:SetFidelityLevel(1)
            end
        end)
    end)
end

-- Minimize Lighting & PostProcessing
local function minimizeLighting()
    safe(function()
        if DISABLE_SHADOWS then Lighting.GlobalShadows = false end
        Lighting.FogEnd = 100000
        Lighting.Brightness = 1
        Lighting.Ambient = Color3.new(0.8,0.8,0.8)
        -- Disable common post effects (Bloom, ColorCorrection, etc.)
        if DISABLE_POSTPROCESS then
            for _, obj in pairs(Lighting:GetDescendants()) do
                local t = obj.ClassName
                if t == "BloomEffect" or t == "ColorCorrectionEffect" or t == "DepthOfFieldEffect" or t == "SunRaysEffect" or t == "BlurEffect" or t == "Atmosphere" or t == "Sky" then
                    pcall(function() obj.Enabled = false end)
                end
            end
        end
    end)
end

-- Disable sounds globally
local function disableSounds()
    if not DISABLE_SOUNDS then return end
    safe(function()
        -- Mute SoundService
        pcall(function() SoundService.Volume = 0 end)
        -- Disable sounds in workspace
        for _, s in pairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") or s:IsA("SoundService") then
                pcall(function() s:Pause() end)
                pcall(function() s.Volume = 0 end)
            end
        end
    end)
end

-- Disable particles, trails, decals, textures
local function disableVisualEffects()
    safe(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if DISABLE_PARTICLES and obj:IsA("ParticleEmitter") then
                pcall(function() obj.Enabled = false end)
            elseif DISABLE_TRAILS and obj:IsA("Trail") then
                pcall(function() obj.Enabled = false end)
            elseif HIDE_DECALS_TEXTURES and obj:IsA("Decal") then
                pcall(function() obj.Transparency = 1 end)
            elseif HIDE_DECALS_TEXTURES and obj:IsA("Texture") then
                pcall(function() obj.Transparency = 1 end)
            elseif obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
                -- hide in-world GUIs
                pcall(function() obj.Enabled = false end)
            end
        end

        -- also apply to players' characters
        for _, pl in pairs(Players:GetPlayers()) do
            local char = pl.Character
            if char then
                for _, d in pairs(char:GetDescendants()) do
                    if d:IsA("ParticleEmitter") then pcall(function() d.Enabled = false end) end
                    if d:IsA("Trail") then pcall(function() d.Enabled = false end) end
                    if d:IsA("Decal") or d:IsA("Texture") then pcall(function() d.Transparency = 1 end) end
                end
            end
        end
    end)
end

-- Hide all GUIs (client-side)
local hiddenGuiContainers = {}
local function hideAllGui()
    if not HIDE_ALL_GUI then return end
    safe(function()
        -- Hide StarterGui core elements
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        end)
        -- Try to disable chat
        pcall(function()
            StarterGui:SetCore("ChatMakeSystemMessage", {Text = ""})
        end)
        -- Hide PlayerGui children
        for _, pl in pairs(Players:GetPlayers()) do
            local gui = pl:FindFirstChildOfClass("PlayerGui")
            if gui then
                for _, child in pairs(gui:GetChildren()) do
                    if child:IsA("ScreenGui") or child:IsA("BillboardGui") then
                        if not hiddenGuiContainers[child] then
                            hiddenGuiContainers[child] = child.Enabled
                            pcall(function() child.Enabled = false end)
                        end
                    end
                end
            end
        end
    end)
end

-- Try to remove expensive decals/textures on newly added objects (realtime hook)
local function watchWorkspace()
    local conn
    conn = Workspace.DescendantAdded:Connect(function(obj)
        pcall(function()
            if obj:IsA("ParticleEmitter") and DISABLE_PARTICLES then obj.Enabled = false end
            if obj:IsA("Trail") and DISABLE_TRAILS then obj.Enabled = false end
            if (obj:IsA("Decal") or obj:IsA("Texture")) and HIDE_DECALS_TEXTURES then obj.Transparency = 1 end
            if obj:IsA("Sound") and DISABLE_SOUNDS then obj.Volume = 0; if obj.Playing then pcall(function() obj:Pause() end) end end
            if obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then pcall(function() obj.Enabled = false end) end
        end)
    end)
    return conn
end

-- Limit animations / heavy scripts by pausing AnimationTracks where possible (non-destructive)
local function minimizeAnimations()
    safe(function()
        for _, pl in pairs(Players:GetPlayers()) do
            local char = pl.Character
            if char then
                for _, anim in pairs(char:GetDescendants()) do
                    if anim:IsA("Animation") or anim:IsA("AnimationTrack") then
                        -- cannot directly stop Animation objects, but can try stop tracks on Animator
                        if anim:IsA("AnimationTrack") then
                            pcall(function() anim:Stop() end)
                        end
                    end
                end
            end
        end
    end)
end

-- Attempt to suggest lower FPS (not always possible). We use RenderStepped hook light work only.
local lastTick = tick()
local function lightweightHeartbeat(dt)
    -- no heavy ops here
    local now = tick()
    if now - lastTick >= REAPPLY_INTERVAL then
        lastTick = now
        -- re-apply major minimizers periodically
        applyUserSettings()
        minimizeLighting()
        disableVisualEffects()
        disableSounds()
        hideAllGui()
        minimizeAnimations()
    end
end

-- Main: initial apply and connect watcher
applyUserSettings()
minimizeLighting()
disableVisualEffects()
disableSounds()
hideAllGui()
minimizeAnimations()
local wconn = watchWorkspace()
local hconn = RunService.Heartbeat:Connect(lightweightHeartbeat)

print("[HeadlessUltra] Applied headless minimizer. Periodic re-apply every " .. tostring(REAPPLY_INTERVAL) .. "s.")
print("[HeadlessUltra] This is non-automating; it only reduces visuals/sounds/UI to save resources.")

-- Safe cleanup function (call API.cleanup() to undo watchers; some settings may persist until restart)
local API = {}
function API.cleanup()
    if hconn and hconn.Disconnect then pcall(function() hconn:Disconnect() end) end
    if wconn and wconn.Disconnect then pcall(function() wconn:Disconnect() end) end
    -- restore any stored GUI states if needed
    for gui, wasEnabled in pairs(hiddenGuiContainers) do
        pcall(function() gui.Enabled = wasEnabled end)
    end
    -- best-effort restore some services
    pcall(function() SoundService.Volume = 1 end)
    pcall(function() Lighting.GlobalShadows = true end)
    print("[HeadlessUltra] cleanup invoked.")
end

return API
