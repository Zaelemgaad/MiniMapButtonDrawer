local _, MBF = ...
local Layout = {}
MBF.Layout = Layout
local min, max, floor = math.min, math.max, math.floor

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

function Layout.Calculate(edge, offset, count, size, width, height, page, tabThickness, flipped, dimensions)
    local vertical = edge == "LEFT" or edge == "RIGHT"
    local normal, tangent = width, height
    if not vertical then normal, tangent = height, width end
    local gap, padding = max(3, floor(size / 8)), max(4, floor(size / 6))
    local pitch = size + gap
    local thickness = Layout.Clamp(tabThickness or max(6, floor(size / 4)), 1, 24)
    local handleLength = min(tangent, floor(size * 1.6))
    local maxDepth, maxAlong = normal - thickness - 2 * padding, tangent - 2 * padding
    local maxPrimary = flipped and maxAlong or maxDepth
    local maxSecondary = flipped and maxDepth or maxAlong
    local limit = min(maxPrimary, 10 * pitch - gap)
    local sizes = {}
    for index = 1, count do
        local requested = dimensions and dimensions[index]
        local w, h = requested and requested.width or size, requested and requested.height or size
        local d, a = vertical and w or h, vertical and h or w
        local scale = min(1, maxDepth / d, maxAlong / a)
        d, a = d * scale, a * scale
        local p, s = flipped and a or d, flipped and d or a
        sizes[index] = {p = p, s = s, d = d, a = a, scale = scale}
        limit = max(limit, p)
    end
    local sheets = {{first = 1, last = 0, cells = {}, depth = 0, along = 0}}
    local sheet, p, s, rowHeight = sheets[1], 0, 0, 0
    for index, cell in ipairs(sizes) do
        if p > 0 and p + cell.p > limit + 0.001 then
            p, s, rowHeight = 0, s + rowHeight + gap, 0
        end
        if s + cell.s > maxSecondary + 0.001 and sheet.last >= sheet.first then
            sheet = {first = index, last = index - 1, cells = {}, depth = 0, along = 0}
            sheets[#sheets + 1] = sheet
            p, s, rowHeight = 0, 0, 0
        end
        local d, a = flipped and s or p, flipped and p or s
        sheet.cells[#sheet.cells + 1] = {d = d, a = a, size = cell}
        sheet.last = index
        sheet.depth, sheet.along = max(sheet.depth, d + cell.d), max(sheet.along, a + cell.a)
        p, rowHeight = p + cell.p + gap, max(rowHeight, cell.s)
    end
    page = Layout.Clamp(page or 1, 1, #sheets)
    sheet = sheets[page]
    local depth = count > 0 and sheet.depth + 2 * padding or 0
    local along = count > 0 and sheet.along + 2 * padding or 0
    local handleCenter = Layout.Clamp(offset * tangent, handleLength / 2, tangent - handleLength / 2)
    local start = Layout.Clamp(handleCenter - along / 2, 0, tangent - along)
    local result = {
        edge = edge, vertical = vertical, thickness = thickness, handleLength = handleLength,
        center = handleCenter, start = start, depth = depth, along = along,
        width = vertical and depth or along, height = vertical and along or depth,
        page = page, pages = #sheets, first = sheet.first, last = sheet.last, cells = {},
    }
    for index, packed in ipairs(sheet.cells) do
        local d, a, cell = packed.d, packed.a, packed.size
        local x, y
        if vertical then
            x = padding + d
            if edge == "RIGHT" then x = depth - padding - cell.d - d end
            y = along - padding - cell.a - a
        else
            x = padding + a
            y = padding + d
            if edge == "TOP" then y = depth - padding - cell.d - d end
        end
        result.cells[index] = {x = x, y = y, width = vertical and cell.d or cell.a,
            height = vertical and cell.a or cell.d, scale = cell.scale}
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
    local conflicts = {}
    for id, choice in pairs(type(old.conflicts) == "table" and old.conflicts or {}) do
        if type(id) == "string" and type(choice) == "table" then
            conflicts[id] = {host = choice.host == true, silent = choice.silent == true}
        end
    end
    for _, name in ipairs(old.MBF_Ignore or {}) do excluded[name] = true end
    for _, name in ipairs(old.MBF_Include or {}) do included[name] = true end
    for name, value in pairs(old.excluded or {}) do excluded[name] = value and true or nil end
    for name, value in pairs(old.included or {}) do included[name] = value and true or nil end
    return {edge = edge, offset = Layout.Clamp(offset, 0, 1),
        size = Layout.Clamp(floor(size + 0.5), 20, 56),
        tabThickness = Layout.Clamp(tonumber(old.tabThickness) or max(6, floor(size / 4)), 1, 24),
        roundedTab = old.roundedTab == true,
        flipOrientation = old.flipOrientation == true, conflicts = conflicts,
        tabRed = Layout.Clamp(tonumber(old.tabRed) or 209, 0, 255),
        tabGreen = Layout.Clamp(tonumber(old.tabGreen) or 166, 0, 255),
        tabBlue = Layout.Clamp(tonumber(old.tabBlue) or 64, 0, 255),
        buttonTransparency = Layout.Clamp(tonumber(old.buttonTransparency) or transparency, 0, 100),
        transparency = Layout.Clamp(transparency, 0, 100), excluded = excluded, included = included}
end
