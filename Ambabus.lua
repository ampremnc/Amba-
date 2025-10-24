-- Performance Safe Mode + Dark Screen (KRNL Compatible)
-- Aman & ringan tanpa exploit berisiko

pcall(function()
    setfpscap(15) -- Batasi FPS ke 15 biar makin irit CPU
end)

-- Nonaktifkan efek berat
local Lighting = game:GetService("Lighting")
Lighting.GlobalShadows = false
Lighting.Brightness = 0
Lighting.FogEnd = 1
Lighting.FogStart = 0
Lighting.FogColor = Color3.fromRGB(0, 0, 0)
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.OutdoorAmbient = Color3.new(0,0,0)
Lighting.Ambient = Color3.new(0,0,0)

-- Matikan efek visual tambahan
for _, v in pairs(Lighting:GetChildren()) do
    if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
        v.Enabled = false
    end
end

-- Hapus partikel dan efek di workspace
for _, v in pairs(workspace:GetDescendants()) do
    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
        v.Enabled = false
    end
end

-- Buat overlay layar gelap (tanpa hilangkan GUI bawaan)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Name = "DarkScreen"

local Frame = Instance.new("Frame")
Frame.BackgroundColor3 = Color3.new(0, 0, 0)
Frame.Size = UDim2.new(1, 0, 1, 0)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

ScreenGui.Parent = game.CoreGui

print("[✔] Performance Safe Mode aktif - Grafik diturunkan dan layar digelapkan.")
