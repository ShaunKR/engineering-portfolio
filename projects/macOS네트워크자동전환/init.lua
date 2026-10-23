
-- ================================================
-- Hammerspoon Wi-Fi / 네트워크 자동 관리
-- 업무·현장 Wi-Fi 및 서버망 정적 라우팅
-- ================================================

-- 1. 기본 설정
local targetSSID = "Field-WiFi"
local staticLocation = "FieldNetwork"
local dhcpLocation = "Automatic"

local expectedIP = "192.0.2.10"
local routeNetwork = "198.51.100.96/27"
local routeGateway = "192.0.2.1"

local routeScript = "/usr/local/sbin/add-site-route"

-- 2. 전역 감시자 및 상태
wifiWatcher = nil
routeWatcher = nil
switchTimer = nil

local routeInProgress = false
local currentGeneration = 0

-- 3. 로그 및 알림
local function log(message)
    print("[Site Network] " .. message)
end

local function notify(message)
    log(message)

    hs.notify.new({
        title = "네트워크 자동 전환",
        informativeText = message
    }):send()
end

-- 4. 현재 네트워크 위치 확인
local function getCurrentLocation()
    local output = hs.execute("/usr/sbin/scselect 2>&1")

    if not output then
        return nil
    end

    for line in output:gmatch("[^\r\n]+") do
        if line:match("^%s*%*") then
            return line:match("%((.-)%)")
        end
    end

    return nil
end

-- 5. 네트워크 위치 변경
local function switchLocation(location)
    local current = getCurrentLocation()

    if current == location then
        log("이미 적용된 네트워크 위치: " .. location)
        return true
    end

    local command =
        "/usr/sbin/scselect " ..
        string.format("%q", location) .. " 2>&1"

    local output, success = hs.execute(command)

    if success then
        notify("네트워크 위치 변경: " .. location)
        return true
    end

    log("위치 변경 실패: " .. tostring(output))
    return false
end

-- 6. 현재 Wi-Fi 및 IP 확인
local function isSiteReady()
    if hs.wifi.currentNetwork() ~= targetSSID then
        return false
    end

    local ip = hs.execute(
        "/usr/sbin/ipconfig getifaddr en0 2>/dev/null"
    )

    ip = (ip or ""):gsub("%s+", "")

    return ip == expectedIP
end

-- 7. 정적 라우팅 존재 여부 확인
local function hasSiteRoute()
    local output = hs.execute(
        "/usr/sbin/netstat -rn -f inet 2>&1"
    )

    if not output then
        return false
    end

    for line in output:gmatch("[^\r\n]+") do
        local destination, gateway =
            line:match("^%s*(%S+)%s+(%S+)")

        if destination and gateway then
            local validDestination =
                destination == routeNetwork
                or destination == "198.51.100.96"

            if validDestination
                and gateway == routeGateway then
                return true
            end
        end
    end

    return false
end

-- 8. 인증 창 없이 정적 라우팅 추가
local function addSiteRoute()
    if not isSiteReady() then
        return
    end

    if routeInProgress then
        return
    end

    if hasSiteRoute() then
        log("서버망 라우팅 정상")
        return
    end

    routeInProgress = true

    local command =
        "/usr/bin/sudo -n " ..
        routeScript .. " 2>&1"

    local output, success = hs.execute(command)

    routeInProgress = false

    if success and hasSiteRoute() then
        notify("서버망 라우팅 자동 설정 완료: " ..
            routeNetwork)
    else
        log("라우팅 추가 실패: " .. tostring(output))
        notify("서버망 라우팅 설정 실패")
    end
end

-- 9. IP 적용 대기 후 라우팅 설정
local function waitForNetwork(attempt, generation)
    if generation ~= currentGeneration then
        return
    end

    if hs.wifi.currentNetwork() ~= targetSSID then
        return
    end

    if isSiteReady() then
        log("고정 IP 적용 확인: " .. expectedIP)
        addSiteRoute()
        return
    end

    if attempt < 10 then
        switchTimer = hs.timer.doAfter(2, function()
            waitForNetwork(attempt + 1, generation)
        end)
    else
        notify("Site 고정 IP 적용 실패")
    end
end

-- 10. Wi-Fi 변경 감지
function ssidChangedCallback()
    local currentSSID = hs.wifi.currentNetwork()

    if not currentSSID then
        log("Wi-Fi 전환 중: SSID 확인 대기")
        return
    end

    currentGeneration = currentGeneration + 1
    local generation = currentGeneration

    if switchTimer then
        switchTimer:stop()
        switchTimer = nil
    end

    log("현재 Wi-Fi: " .. currentSSID)

    if currentSSID == targetSSID then

        if not switchLocation(staticLocation) then
            notify("Site 네트워크 위치 변경 실패")
            return
        end

        log("Site 고정 IP 적용 대기")

        switchTimer = hs.timer.doAfter(3, function()
            waitForNetwork(1, generation)
        end)

    else

        if switchLocation(dhcpLocation) then
            log("일반 Wi-Fi DHCP 모드 적용")
        end

    end
end

-- 11. Wi-Fi 감시자 등록
wifiWatcher =
    hs.wifi.watcher.new(ssidChangedCallback):start()

-- 12. 30초마다 정적 라우팅 확인 및 복구
routeWatcher = hs.timer.doEvery(30, function()

    if hs.wifi.currentNetwork() ~= targetSSID then
        return
    end

    if not isSiteReady() then
        return
    end

    if not hasSiteRoute() then
        log("정적 라우팅 누락 감지: 복구 시작")
        addSiteRoute()
    end

end)

-- 13. Hammerspoon 시작 시 네트워크 확인
ssidChangedCallback()

hs.alert.show("Site 네트워크 자동 관리 시작")
