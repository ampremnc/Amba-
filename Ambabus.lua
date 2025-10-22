-- Headless Graphics Minimizer (safe)
-- Jalankan lewat executor (Codex) pada setiap instance.
-- Tujuan: turunkan load grafis & disabled efek berat.

local success, err

-- Services
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Try to get UserGameSettings safely
local UserSettingsObj
success, UserSettingsObj = pcall(function() return UserSettings() end)
local UserGameSettings
if success and UserSettingsObj then
    pcall(function() UserGameSettings = UserSettingsObj:GetService("UserGameSettings") end)
end

-- CONFIG (ubah jika perlu)
local GRAPHICS_LEVEL = 1        -- 1 = lowest
local TEXTURE_QUALITY = 1      -- conceptual; applied via pcall where available
local DISABLE_SHADOWS = true
local DISABLE_PARTICLES = true
local DISABLE_TRAILS = true
local DISABLE_DECALS = true
local DISABLE_POSTPROCESS = true

-- Safe: apply user game settings
local function applyUserGameSettings()
    if UserGameSettings then
        pcall(function()
            if UserGameSettings.SetGraphicsQualityLevel then
                UserGameSettings:SetGraphicsQualityLevel(GRAPHICS_LEVEL)
            elseif UserGameSettings.SetQualityLevel then
                UserGameSettings:SetQualityLevel(GRAPHICS_LEVEL)
            end
        end)
        -- try to reduce texture streaming / quality if fields exposed
        pcall(function()
            if UserGameSettings:SetFidelityLevel then
                -- some environments expose fidelity; try set low
                UserGameSettings:SetFidelityLevel(1)
            end
        end)
    end
end

-- Disable expensive lighting & post effects
local function minimizeLighting()
    pcall(function()
        Lighting.GlobalShadows = not DISABLE_SHADOWS and Lighting.GlobalShadows or false
        Lighting.FogEnd = 100000
        Lighting.Brightness = 1
        -- disable post effects (Bloom/ColorCorrection/etc)
        if DISABLE_POSTPROCESS then
            for _, obj in pairs(Lighting:GetDescendants()) do
                if obj:IsA("PostEffect") or obj:IsA("PostEffect") then
                    pcall(function() obj.Enabled = false end)
                end
            end
        end
    end)
end

-- Disable particle emitters, trails, and reduce texture/mesh detail
local function disableWorkspaceEffects()
    pcall(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if DISABLE_PARTICLES and obj:IsA("ParticleEmitter") then
                pcall(function() obj.Enabled = false end)
            elseif DISABLE_TRAILS and obj:IsA("Trail") then
                pcall(function() obj.Enabled = false end)
            elseif DISABLE_DECALS and obj:IsA("Decal") then
                pcall(function() obj.Transparency = 1 end)
            elseif obj:IsA("Texture") then
                pcall(function() obj.Transparency = 1 end)
            elseif obj:IsA("MeshPart") or obj:IsA("SpecialMesh") then
                -- try to reduce mesh detail by scaling or disabling if available (non-destructive attempt)
                pcall(function()
                    if obj:IsA("MeshPart") and obj.TextureID and obj.TextureID ~= "" then
                        -- no direct API to lower mesh resolution; skip destructive ops
                    end
                end)
            end
        end
    end)
end

-- Attempt to limit decals/textures on characters
local function minimizePlayerVisuals()
    pcall(function()
        for _, pl in pairs(Players:GetPlayers()) do
            local char = pl.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("Decal") or part:IsA("Texture") then
                        pcall(function() part.Transparency = 1 end)
                    elseif part:IsA("ParticleEmitter") then
                        pcall(function() part.Enabled = false end)
                    elseif part:IsA("Trail") then
                        pcall(function() part.Enabled = false end)
                    end
                end
            end
        end
    end)
end

-- Periodic re-apply (some games recreate objects runtime)
local function periodicApply()
    -- run immediately
    applyUserGameSettings()
    minimizeLighting()
    disableWorkspaceEffects()
    minimizePlayerVisuals()

    -- set interval to re-apply every 10 seconds to catch spawned effects
    local interval = 10
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        interval = interval - dt
        if interval <= 0 then
            interval = 10
            -- re-apply non-destructively
            applyUserGameSettings()
            minimizeLighting()
            disableWorkspaceEffects()
            minimizePlayerVisuals()
        end
    end)

    -- return disconnect function for manual cleanup if needed
    return function()
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
end

-- Execute
local cleanupFunc = periodicApply()

print("[HeadlessMinimizer] Graphics settings applied. Effects minimized. Running periodic re-apply.")
print("[HeadlessMinimizer] This script does NOT perform gameplay automation.")

-- Expose optional API (safe)
local API = {}
function API.cleanup()
    if cleanupFunc then
        pcall(cleanupFunc)
        print("[HeadlessMinimizer] Cleaned up.")
    end
end

return API
