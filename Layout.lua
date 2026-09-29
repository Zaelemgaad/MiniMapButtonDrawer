local _, MBF = ...
local Layout = {}
MBF.Layout = Layout
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil

function Layout.Clamp(value, low, high)
    return max(low, min(high, value))
end

function Layout.NearestEdge(x, y, width, height, preferred)
    x, y = Layout.Clamp(x, 0, width), Layout.Clamp(y, 0, height)
    local distances = {LEFT = x, RIGHT = width - x, BOTTOM = y, TOP = height - y}
    local edge = distances[preferred] and preferred or "RIGHT"
    for _, candidate in ipairs({"LEFT", "RIGHT", "TOP", "BOTTOM"}) do
        if distances[candidate] < distances[edge] then edge = candidate end
    end
    local offset = (edge == "LEFT" or edge == "RIGHT") and y / height or x / width
    return edge, Layout.Clamp(offset, 0, 1)
end

function Layout.Calculate(edge, offset, count, size, width, height, page, tabThickness)
    local vertical = edge == "LEFT" or edge == "RIGHT"
    local normal, tangent = width, height
    if not vertical then normal, tangent = height, width end
    local gap, padding = max(3, floor(size / 8)), max(4, floor(size / 6))
    local pitch = size + gap
    local thickness = Layout.Clamp(tabThickness or max(6, floor(size / 4)), 4, 24)
    local handleLength = min(tangent, floor(size * 1.6))
    local maxDepth = max(1, floor((normal - thickness - 2 * padding + gap) / pitch))
    local maxAlong = max(1, floor((tangent - 2 * padding + gap) / pitch))
    local capacity = maxDepth * maxAlong
    local pages = max(1, ceil(count / capacity))
    page = Layout.Clamp(page or 1, 1, pages)
    local first = (page - 1) * capacity + 1
    local visible = min(capacity, max(0, count - first + 1))
    local depthCells = min(maxDepth, max(min(10, visible), ceil(visible / maxAlong)))
    local alongCells = depthCells > 0 and ceil(visible / depthCells) or 0
    local depth = visible > 0 and 2 * padding + depthCells * pitch - gap or 0
    local along = visible > 0 and 2 * padding + alongCells * pitch - gap or 0
    local handleCenter = Layout.Clamp(offset * tangent, handleLength / 2, tangent - handleLength / 2)
    local start = Layout.Clamp(handleCenter - along / 2, 0, tangent - along)
    local result = {
        edge = edge, vertical = vertical, thickness = thickness, handleLength = handleLength,
        center = handleCenter, start = start, depth = depth, along = along,
        width = vertical and depth or along, height = vertical and along or depth,
        page = page, pages = pages, first = first, last = first + visible - 1, cells = {},
    }
    for index = 1, visible do
        local d, a = (index - 1) % depthCells, floor((index - 1) / depthCells)
        local x, y
        if vertical then
            x = padding + d * pitch
            if edge == "RIGHT" then x = depth - padding - size - d * pitch end
            y = along - padding - size - a * pitch
        else
            x = padding + a * pitch
            y = padding + d * pitch
            if edge == "TOP" then y = depth - padding - size - d * pitch end
        end
        result.cells[index] = {x = x, y = y}
    end
    return result
end

function Layout.PanelPosition(layout, progress, width, height)
    local travel = (layout.depth + layout.thickness) * progress
    if layout.edge == "LEFT" then return -layout.depth + travel, layout.start end
    if layout.edge == "RIGHT" then return width - travel, layout.start end
    if layout.edge == "BOTTOM" then return layout.start, -layout.depth + travel end
    return layout.start, height - travel
end

function Layout.MigrateProfile(old, width, height)
    old = type(old) == "table" and old or {}
    local edge, offset = old.edge, tonumber(old.offset) or 0.5
    if edge ~= "LEFT" and edge ~= "RIGHT" and edge ~= "TOP" and edge ~= "BOTTOM" then
        edge = "RIGHT"
        local point = old.MBF_FrameLocation
        if type(point) == "table" then
            local anchor = tostring(point[2] or point[1] or "TOPRIGHT")
            local x = anchor:find("LEFT") and 0 or (anchor:find("RIGHT") and width or width / 2)
            local y = anchor:find("BOTTOM") and 0 or (anchor:find("TOP") and height or height / 2)
            edge, offset = Layout.NearestEdge(x + (tonumber(point[3]) or 0),
                y + (tonumber(point[4]) or 0), width, height, "RIGHT")
        end
    end
    local oldScale, oldOpacity = tonumber(old.addonScale), tonumber(old.opacity)
    local size = tonumber(old.size) or (oldScale and 32 * oldScale) or 32
    local transparency = tonumber(old.transparency)
    if not transparency then transparency = oldOpacity and (1 - oldOpacity) * 100 or 20 end
    local excluded, included = {}, {}
    for _, name in ipairs(old.MBF_Ignore or {}) do excluded[name] = true end
    for _, name in ipairs(old.MBF_Include or {}) do included[name] = true end
    for name, value in pairs(old.excluded or {}) do excluded[name] = value and true or nil end
    for name, value in pairs(old.included or {}) do included[name] = value and true or nil end
    return {edge = edge, offset = Layout.Clamp(offset, 0, 1),
        size = Layout.Clamp(floor(size + 0.5), 20, 56),
        tabThickness = Layout.Clamp(tonumber(old.tabThickness) or max(6, floor(size / 4)), 4, 24),
        roundedTab = old.roundedTab == true,
        tabRed = Layout.Clamp(tonumber(old.tabRed) or 209, 0, 255),
        tabGreen = Layout.Clamp(tonumber(old.tabGreen) or 166, 0, 255),
        tabBlue = Layout.Clamp(tonumber(old.tabBlue) or 64, 0, 255),
        buttonTransparency = Layout.Clamp(tonumber(old.buttonTransparency) or transparency, 0, 100),
        transparency = Layout.Clamp(transparency, 0, 100), excluded = excluded, included = included}
end
