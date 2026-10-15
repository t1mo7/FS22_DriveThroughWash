----------------------------------------------------------------------------------------------------
-- DriveThroughWash
--
-- Turns every wash station on the map into an automatic drive-through car wash.
-- Any vehicle (plus everything attached to it) that is inside the wash zone of a
-- wash station is cleaned automatically. No need to leave the vehicle.
--
-- A placeable counts as a wash station when:
--   * it has the base game high pressure washer specialization (base game washer
--     and most wash bay mods), or
--   * its xml file name contains "wash" (e.g. wash bay / car wash building mods)
--
-- Washing runs on the server, dirt is synced to clients by the Washable specialization.
----------------------------------------------------------------------------------------------------

DriveThroughWash = {}
DriveThroughWash.MOD_NAME = g_currentModName

-- Settings ----------------------------------------------------------------------------------------
DriveThroughWash.WASH_RADIUS        = 10     -- horizontal distance (m) from the station centre
DriveThroughWash.WASH_HEIGHT        = 8      -- max vertical distance (m) from the station centre
DriveThroughWash.WASH_DURATION      = 3000   -- ms to fully clean a completely dirty vehicle
DriveThroughWash.STATION_SCAN_INTERVAL = 2000 -- ms between rescans of placed buildings
DriveThroughWash.CLEAN_THRESHOLD    = 0.01   -- dirt amount counted as "clean"
DriveThroughWash.DEBUG              = false  -- draw wash zones and log info
----------------------------------------------------------------------------------------------------

DriveThroughWash.stations = {}
DriveThroughWash.scanTimer = 0
DriveThroughWash.wasWashing = false

local function log(fmt, ...)
    print(string.format("[DriveThroughWash] " .. fmt, ...))
end

local function getText(key, fallback)
    if g_i18n ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    return fallback
end

local function getPlaceables()
    local mission = g_currentMission
    if mission.placeableSystem ~= nil and mission.placeableSystem.placeables ~= nil then
        return mission.placeableSystem.placeables
    end
    return mission.placeables or {}
end

local function getVehicles()
    local mission = g_currentMission
    if mission.vehicleSystem ~= nil and mission.vehicleSystem.vehicles ~= nil then
        return mission.vehicleSystem.vehicles
    end
    return mission.vehicles or {}
end

function DriveThroughWash.isWashStation(placeable)
    if placeable == nil or placeable.rootNode == nil or placeable.isDeleted then
        return false
    end

    if placeable.spec_highPressureWasher ~= nil then
        return true
    end

    local filename = placeable.configFileName
    if filename ~= nil and string.find(string.lower(filename), "wash", 1, true) ~= nil then
        return true
    end

    return false
end

function DriveThroughWash:scanStations()
    self.stations = {}
    for _, placeable in pairs(getPlaceables()) do
        if DriveThroughWash.isWashStation(placeable) then
            table.insert(self.stations, placeable)
        end
    end

    if self.DEBUG then
        log("found %d wash station(s)", #self.stations)
    end
end

function DriveThroughWash:isInWashZone(node)
    if node == nil or node == 0 or not entityExists(node) then
        return false
    end

    local vx, vy, vz = getWorldTranslation(node)
    for _, station in ipairs(self.stations) do
        if not station.isDeleted and station.rootNode ~= nil and entityExists(station.rootNode) then
            local sx, sy, sz = getWorldTranslation(station.rootNode)
            local dx, dz = vx - sx, vz - sz
            if dx * dx + dz * dz <= self.WASH_RADIUS * self.WASH_RADIUS
                and math.abs(vy - sy) <= self.WASH_HEIGHT then
                return true
            end
        end
    end

    return false
end

--- Lowers the dirt of a vehicle by 'amount'. Returns true when the vehicle is (now) clean.
function DriveThroughWash.washVehicle(vehicle, amount)
    local spec = vehicle.spec_washable
    if spec == nil or spec.washableNodes == nil or vehicle.setNodeDirtAmount == nil then
        return true
    end

    local isClean = true
    for _, nodeData in ipairs(spec.washableNodes) do
        if nodeData.dirtAmount > 0 then
            local newAmount = math.max(nodeData.dirtAmount - amount, 0)
            -- force the last step so the client is guaranteed to receive the 0 value
            vehicle:setNodeDirtAmount(nodeData, newAmount, newAmount == 0)
            if newAmount > DriveThroughWash.CLEAN_THRESHOLD then
                isClean = false
            end
        end
    end

    return isClean
end

--- Returns the vehicle itself plus everything attached to it (implements, trailers).
local function getVehicleCombination(vehicle)
    local rootVehicle = vehicle.rootVehicle or vehicle
    if rootVehicle.getChildVehicles ~= nil then
        return rootVehicle:getChildVehicles()
    end
    return { vehicle }
end

function DriveThroughWash:washVehiclesInZones(dt)
    local amount = dt / self.WASH_DURATION
    local washed = {}

    for _, vehicle in pairs(getVehicles()) do
        if washed[vehicle] == nil and vehicle.spec_washable ~= nil and not vehicle.isDeleted
            and self:isInWashZone(vehicle.rootNode) then
            -- wash the whole combination, so long trailers get clean too
            for _, part in pairs(getVehicleCombination(vehicle)) do
                if washed[part] == nil then
                    washed[part] = true
                    if part.spec_washable ~= nil and not part.isDeleted then
                        DriveThroughWash.washVehicle(part, amount)
                    end
                end
            end
        end
    end
end

--- Client feedback for the player's own vehicle.
function DriveThroughWash:updatePlayerFeedback()
    local vehicle = g_currentMission.controlledVehicle
    if vehicle == nil or vehicle.getDirtAmount == nil or vehicle.spec_washable == nil
        or not self:isInWashZone(vehicle.rootNode) then
        self.wasWashing = false
        return
    end

    local isDirty = false
    for _, part in pairs(getVehicleCombination(vehicle)) do
        if part.getDirtAmount ~= nil and part.spec_washable ~= nil
            and #part.spec_washable.washableNodes > 0
            and part:getDirtAmount() > self.CLEAN_THRESHOLD then
            isDirty = true
            break
        end
    end

    if isDirty then
        g_currentMission:addExtraPrintText(getText("dtw_washing", "Washing vehicle..."))
        self.wasWashing = true
    elseif self.wasWashing then
        self.wasWashing = false
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            getText("dtw_vehicleWashed", "Vehicle washed"))
    end
end

function DriveThroughWash:drawDebug()
    for _, station in ipairs(self.stations) do
        if station.rootNode ~= nil and entityExists(station.rootNode) then
            local x, y, z = getWorldTranslation(station.rootNode)
            local steps = 24
            for i = 0, steps - 1 do
                local a1 = (i / steps) * 2 * math.pi
                local a2 = ((i + 1) / steps) * 2 * math.pi
                local r = self.WASH_RADIUS
                drawDebugLine(x + math.cos(a1) * r, y + 0.5, z + math.sin(a1) * r, 0, 0.6, 1,
                              x + math.cos(a2) * r, y + 0.5, z + math.sin(a2) * r, 0, 0.6, 1)
            end
        end
    end
end

-- Mod event listener -------------------------------------------------------------------------------

function DriveThroughWash:loadMap(name)
    self.stations = {}
    self.scanTimer = 0
    log("loaded (radius %.1fm, wash time %.1fs)", self.WASH_RADIUS, self.WASH_DURATION / 1000)
end

function DriveThroughWash:deleteMap()
    self.stations = {}
end

function DriveThroughWash:update(dt)
    if g_currentMission == nil then
        return
    end

    self.scanTimer = self.scanTimer - dt
    if self.scanTimer <= 0 then
        self.scanTimer = self.STATION_SCAN_INTERVAL
        self:scanStations()
    end

    if #self.stations == 0 then
        return
    end

    if g_currentMission:getIsServer() then
        self:washVehiclesInZones(dt)
    end

    if g_currentMission:getIsClient() then
        self:updatePlayerFeedback()
        if self.DEBUG then
            self:drawDebug()
        end
    end
end

addModEventListener(DriveThroughWash)
