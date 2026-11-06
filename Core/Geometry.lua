local _, Addon = ...

local Geometry = {}
Addon.Geometry = Geometry

local function getCanvasSize()
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight()

    if not width or width <= 0 then
        width = GetScreenWidth and GetScreenWidth() or 0
    end
    if not height or height <= 0 then
        height = GetScreenHeight and GetScreenHeight() or 0
    end

    return width, height
end

function Geometry:Calculate(profile)
    local width, height = getCanvasSize()
    if width <= 0 or height <= 0 then
        return nil, "UI canvas dimensions are unavailable"
    end

    local share = math.max(25, math.min(90, tonumber(profile.mainhandWidthPercent) or 50)) / 100
    local seam = math.max(0, tonumber(profile.seamUiUnits) or 0)
    if seam >= width * 0.25 then
        return nil, "Seam offset exceeds 25% of the canvas"
    end

    local mainhandWidth = (width - seam) * share
    local workspaceWidth = width - seam - mainhandWidth

    if workspaceWidth < 1 then
        return nil, "Offhand workspace is too narrow"
    end

    local mainhandLeft
    local workspaceLeft
    if profile.mainhandSide == "right" then
        workspaceLeft = 0
        mainhandLeft = workspaceWidth + seam
    else
        mainhandLeft = 0
        workspaceLeft = mainhandWidth + seam
    end

    return {
        canvasWidth = width,
        canvasHeight = height,
        mainhand = {
            left = mainhandLeft,
            right = mainhandLeft + mainhandWidth,
            width = mainhandWidth,
        },
        workspace = {
            left = workspaceLeft,
            right = workspaceLeft + workspaceWidth,
            width = workspaceWidth,
            centerX = workspaceLeft + workspaceWidth / 2 - width / 2,
            centerY = 0,
        },
        seam = seam,
    }
end
