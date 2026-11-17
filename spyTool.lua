--[[
    Spy Tool bootstrap

    Run in-game:
      loadstring(game:HttpGet("https://raw.githubusercontent.com/ProBaconHub/spyTool/refs/heads/main/spyTool.lua?t=" .. tostring(tick()), true))()

    Sync/update resolves the live main tip SHA via api.github.com, then downloads
    from raw.githubusercontent.com/<sha>/... to avoid branch-tip CDN staleness.

    To skip GitHub sync, set getgenv().__SpyToolDevSkipSync = true
]]

local REPO_OWNER = "ProBaconHub"
local REPO_NAME = "spyTool"
local REPO_BRANCH = "main"
local BRANCH_RAW_BASE = string.format(
    "https://raw.githubusercontent.com/%s/%s/refs/heads/%s",
    REPO_OWNER,
    REPO_NAME,
    REPO_BRANCH
)
local API_REPO_BASE = string.format(
    "https://api.github.com/repos/%s/%s",
    REPO_OWNER,
    REPO_NAME
)
local RAW_BASE = BRANCH_RAW_BASE
local _pinnedCommitSha = nil

local WORKSPACE_FOLDER = "spyTool"
local MANIFEST_REL = "manifest.json"
local MAIN_REL = "main.lua"
local BOOTSTRAP_REL = "spyTool.lua"
local INSTALLER_UI_REL = "installer/ui.lua"
local INSTALLER_SPINNER_REL = "installer/asset/spinner.png"
local INSTALLER_TMP_DIR = "__SpyToolInstallerTmp"
local DEV_MARKER_REL = ".dev"
local DEV_GENV_SKIP_SYNC = "__SpyToolDevSkipSync"
local DEV_GENV_FORCE_INSTALLER = "__SpyToolDevForceInstaller"
local DEV_HANDOFF_KEY = "__SpyToolLocalDevActive"
local DEV_BOOTSTRAP_KEY = "__SpyToolBootstrap"
local SPYTOOL_GENV_KEY = "__ProBaconHubSpyTool__"

local _httpBustSeq = 0

local function log(msg)
    print("[SpyTool] " .. tostring(msg))
end

local function getDevGenv()
    if type(getgenv) ~= "function" then
        return nil
    end
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        return env
    end
    return nil
end

local function hasDevMarkerFile()
    if type(isfile) ~= "function" then
        return false
    end
    return isfile(WORKSPACE_FOLDER .. "/" .. DEV_MARKER_REL) or isfile(DEV_MARKER_REL)
end

local function isDevSkipSync()
    local env = getDevGenv()
    if env and env[DEV_GENV_SKIP_SYNC] then
        return true
    end
    if env and env[DEV_HANDOFF_KEY] then
        return true
    end
    return hasDevMarkerFile()
end

local function isDevForceInstaller()
    local env = getDevGenv()
    return env ~= nil and env[DEV_GENV_FORCE_INSTALLER] == true
end

local function resolveLocalBootstrapPath()
    if type(isfile) ~= "function" then
        return nil
    end
    local primary = WORKSPACE_FOLDER .. "/" .. BOOTSTRAP_REL
    if isfile(primary) then
        return primary
    end
    if isfile(BOOTSTRAP_REL) then
        return BOOTSTRAP_REL
    end
    return nil
end

do
    local fromHandoff = (... == true)
    local env = getDevGenv()
    if not fromHandoff and env and env[DEV_HANDOFF_KEY] == true then
        fromHandoff = true
    end
    if env then
        env[DEV_HANDOFF_KEY] = nil
    end
    if not fromHandoff and hasDevMarkerFile() then
        local localPath = resolveLocalBootstrapPath()
        if localPath and type(readfile) == "function" then
            if env then
                env[DEV_GENV_SKIP_SYNC] = true
            end
            log("dev mode: handing off to local " .. localPath)
            local okRead, source = pcall(readfile, localPath)
            if not okRead or type(source) ~= "string" or source == "" then
                error("[SpyTool] failed to read local bootstrap: " .. tostring(source))
            end
            local chunk, compileErr = loadstring(source, "@" .. localPath)
            if not chunk then
                error("[SpyTool] failed to compile local bootstrap: " .. tostring(compileErr))
            end
            return chunk(true)
        end
        log("dev marker found but local spyTool.lua missing; continuing with remote bootstrap")
    end
end

local function withCacheBust(url)
    url = tostring(url or "")
    _httpBustSeq = _httpBustSeq + 1
    local bust = string.format(
        "t=%s_%d_%d",
        tostring(tick()):gsub("%.", ""),
        os.clock() * 1000000,
        _httpBustSeq
    )
    if url:find("?", 1, true) then
        return url .. "&" .. bust
    end
    return url .. "?" .. bust
end

local function requestNoCache(requestFn, url, extraHeaders)
    local headers = {
        ["Cache-Control"] = "no-cache, no-store, must-revalidate",
        ["Pragma"] = "no-cache",
        ["Expires"] = "0",
    }
    if type(extraHeaders) == "table" then
        for key, value in pairs(extraHeaders) do
            headers[key] = value
        end
    end
    local res = requestFn({
        Url = url,
        Method = "GET",
        Headers = headers,
    })
    if type(res) == "table" then
        return res.Body or res.body
    end
    return res
end

local function httpGet(url, extraHeaders)
    url = withCacheBust(url)
    local getters = {}

    if type(request) == "function" then
        getters[#getters + 1] = function()
            return requestNoCache(request, url, extraHeaders)
        end
    end
    if type(http) == "table" and type(http.request) == "function" then
        getters[#getters + 1] = function()
            return requestNoCache(http.request, url, extraHeaders)
        end
    end
    if type(syn) == "table" and type(syn.request) == "function" then
        getters[#getters + 1] = function()
            return requestNoCache(syn.request, url, extraHeaders)
        end
    end

    if type(game) == "userdata" or type(game) == "table" then
        getters[#getters + 1] = function()
            return game:HttpGet(url, true)
        end
        getters[#getters + 1] = function()
            return game:HttpGetAsync(url, true)
        end
        getters[#getters + 1] = function()
            return game:HttpGet(url)
        end
        getters[#getters + 1] = function()
            return game:HttpGetAsync(url)
        end
    end
    if type(httpget) == "function" then
        getters[#getters + 1] = function()
            return httpget(url, true)
        end
        getters[#getters + 1] = function()
            return httpget(url)
        end
    end

    local lastErr
    for _, getter in ipairs(getters) do
        local ok, body = pcall(getter)
        if ok and type(body) == "string" and #body > 0 then
            return body
        end
        lastErr = body
    end
    error("[SpyTool] HttpGet failed for " .. url .. ": " .. tostring(lastErr))
end

local function fingerprint(content)
    if type(content) ~= "string" then
        return "0:0000000000000000"
    end
    local h1, h2 = 0, 0
    for i = 1, #content do
        local b = string.byte(content, i)
        h1 = (h1 + b) % 4294967296
        h2 = (h2 + h1) % 4294967296
    end
    return string.format("%d:%08x%08x", #content, h1, h2)
end

local function decodeJson(text)
    local HttpService = game:GetService("HttpService")
    return HttpService:JSONDecode(text)
end

local function rawBaseForSha(sha)
    return string.format(
        "https://raw.githubusercontent.com/%s/%s/%s",
        REPO_OWNER,
        REPO_NAME,
        tostring(sha)
    )
end

local function parseCommitSha(data)
    if type(data) ~= "table" then
        return nil
    end
    if type(data.sha) == "string" and #data.sha >= 7 then
        return data.sha
    end
    if type(data.commit) == "table" and type(data.commit.sha) == "string" and #data.commit.sha >= 7 then
        return data.commit.sha
    end
    if type(data.object) == "table" and type(data.object.sha) == "string" and #data.object.sha >= 7 then
        return data.object.sha
    end
    return nil
end

local function resolveTipCommitSha()
    local apiHeaders = {
        ["Accept"] = "application/vnd.github+json",
        ["User-Agent"] = "ProBaconHub-SpyTool",
    }
    local endpoints = {
        API_REPO_BASE .. "/commits/" .. REPO_BRANCH,
        API_REPO_BASE .. "/branches/" .. REPO_BRANCH,
        API_REPO_BASE .. "/git/ref/heads/" .. REPO_BRANCH,
    }
    local lastErr
    for _, endpoint in ipairs(endpoints) do
        local ok, body = pcall(httpGet, endpoint, apiHeaders)
        if ok and type(body) == "string" and #body > 0 then
            local decodeOk, data = pcall(decodeJson, body)
            if decodeOk then
                local sha = parseCommitSha(data)
                if sha then
                    return sha
                end
                lastErr = "response missing commit sha"
            else
                lastErr = data
            end
        else
            lastErr = body
        end
    end
    error("[SpyTool] failed to resolve tip commit for " .. REPO_BRANCH .. ": " .. tostring(lastErr))
end

local function ensureCommitPin(force)
    if force then
        _pinnedCommitSha = nil
    end
    if type(_pinnedCommitSha) == "string" and #_pinnedCommitSha >= 7 then
        RAW_BASE = rawBaseForSha(_pinnedCommitSha)
        return _pinnedCommitSha
    end
    local ok, shaOrErr = pcall(resolveTipCommitSha)
    if ok and type(shaOrErr) == "string" and #shaOrErr >= 7 then
        _pinnedCommitSha = shaOrErr
        RAW_BASE = rawBaseForSha(_pinnedCommitSha)
        log("pinned raw downloads to " .. _pinnedCommitSha:sub(1, 7) .. " (" .. REPO_BRANCH .. ")")
        return _pinnedCommitSha
    end
    RAW_BASE = BRANCH_RAW_BASE
    _pinnedCommitSha = nil
    log("commit pin failed; falling back to branch raw CDN: " .. tostring(shaOrErr))
    return nil
end

local function rawUrl(relPath)
    relPath = tostring(relPath or ""):gsub("^/+", "")
    return withCacheBust(RAW_BASE .. "/" .. relPath)
end

local function joinPath(...)
    local parts = { ... }
    local out = {}
    for _, part in ipairs(parts) do
        part = tostring(part or ""):gsub("\\", "/"):gsub("^/+", ""):gsub("/+$", "")
        if part ~= "" then
            out[#out + 1] = part
        end
    end
    return table.concat(out, "/")
end

local function ensureFolder(path)
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then
        return
    end
    path = path:gsub("\\", "/")
    local acc = ""
    for part in string.gmatch(path, "[^/]+") do
        acc = (acc == "") and part or (acc .. "/" .. part)
        if not isfolder(acc) then
            pcall(makefolder, acc)
        end
    end
end

local function parentDir(path)
    path = path:gsub("\\", "/")
    local dir = path:match("^(.*)/[^/]+$")
    return dir
end

local function writeFile(path, content)
    if type(writefile) ~= "function" then
        error("[SpyTool] writefile is unavailable on this executor")
    end
    local dir = parentDir(path)
    if dir then
        ensureFolder(dir)
    end
    writefile(path, content)
end

local function readLocal(path)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then
        return nil
    end
    if not isfile(path) then
        return nil
    end
    local ok, body = pcall(readfile, path)
    if ok and type(body) == "string" then
        return body
    end
    return nil
end

local function workspacePath(rel)
    return joinPath(WORKSPACE_FOLDER, rel)
end

local function resolveMainPath()
    local primary = workspacePath(MAIN_REL)
    local fallback = MAIN_REL
    if type(isfile) == "function" then
        if isfile(primary) then
            return primary
        end
        if isfile(fallback) then
            return fallback
        end
    end
    return primary
end

local function isFirstInstall()
    if type(isfile) ~= "function" then
        return true
    end
    if type(isfolder) == "function" and not isfolder(WORKSPACE_FOLDER) then
        return true
    end
    return not isfile(workspacePath(MAIN_REL))
end

local function resolveCustomAsset(path)
    local candidates = {}
    if type(getcustomasset) == "function" then
        candidates[#candidates + 1] = getcustomasset
    end
    if type(getsynasset) == "function" then
        candidates[#candidates + 1] = getsynasset
    end
    if getgenv then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            if type(env.getcustomasset) == "function" then
                candidates[#candidates + 1] = env.getcustomasset
            end
            if type(env.getsynasset) == "function" then
                candidates[#candidates + 1] = env.getsynasset
            end
        end
    end
    for _, fn in ipairs(candidates) do
        local ok, result = pcall(fn, path)
        if ok and type(result) == "string" and result ~= "" then
            return result
        end
    end
    return nil
end

local function resolveLocalInstallerPath(rel)
    local candidates = {
        workspacePath(rel),
        rel,
    }
    for _, path in ipairs(candidates) do
        if type(isfile) == "function" and isfile(path) then
            return path
        end
    end
    return nil
end

local function loadInstallerUi(preferLocal)
    local source = nil
    local sourceLabel = INSTALLER_UI_REL

    if preferLocal then
        local localUi = resolveLocalInstallerPath(INSTALLER_UI_REL)
        if localUi then
            source = readLocal(localUi)
            sourceLabel = localUi
            log("dev mode: loading installer from " .. localUi)
        end
    end

    if type(source) ~= "string" or source == "" then
        ensureCommitPin(false)
        source = httpGet(rawUrl(INSTALLER_UI_REL))
        sourceLabel = "remote:" .. INSTALLER_UI_REL
    end

    local chunk, err = loadstring(source, "@" .. sourceLabel)
    if not chunk then
        error("[SpyTool] failed to compile installer UI: " .. tostring(err))
    end
    local InstallerUI = chunk()
    if type(InstallerUI) ~= "table" or type(InstallerUI.new) ~= "function" then
        error("[SpyTool] installer UI module is invalid")
    end

    local spinnerImage = ""
    local trackedTemp = false
    local tmpSpinnerPath = joinPath(INSTALLER_TMP_DIR, "spinner.png")

    if preferLocal then
        local localSpinner = resolveLocalInstallerPath(INSTALLER_SPINNER_REL)
        if localSpinner then
            spinnerImage = resolveCustomAsset(localSpinner) or ""
        end
    end

    if spinnerImage == "" then
        ensureCommitPin(false)
        local okFetch, spinnerBody = pcall(httpGet, rawUrl(INSTALLER_SPINNER_REL))
        if okFetch and type(spinnerBody) == "string" and #spinnerBody > 0 and type(writefile) == "function" then
            ensureFolder(INSTALLER_TMP_DIR)
            local okWrite = pcall(writefile, tmpSpinnerPath, spinnerBody)
            if okWrite then
                spinnerImage = resolveCustomAsset(tmpSpinnerPath) or ""
                trackedTemp = spinnerImage ~= ""
            end
        end
    end

    local ui = InstallerUI.new({ spinnerImage = spinnerImage })
    if trackedTemp then
        ui:TrackTemp(tmpSpinnerPath, false)
        ui:TrackTemp(INSTALLER_TMP_DIR, true)
    end
    return ui
end

local function fetchRemoteManifest()
    ensureCommitPin(false)
    local body = httpGet(rawUrl(MANIFEST_REL))
    local data = decodeJson(body)
    if type(data) ~= "table" or type(data.files) ~= "table" then
        error("[SpyTool] remote manifest.json is invalid")
    end
    return data, body
end

local function collectPendingUpdates(remoteManifest)
    local pending = {}
    if type(remoteManifest) ~= "table" or type(remoteManifest.files) ~= "table" then
        return pending
    end
    for _, entry in ipairs(remoteManifest.files) do
        if type(entry) == "table" and type(entry.path) == "string" and type(entry.hash) == "string" then
            local dest = workspacePath(entry.path)
            local existing = readLocal(dest)
            if not (existing and fingerprint(existing) == entry.hash) then
                pending[#pending + 1] = entry
            end
        end
    end
    return pending
end

local function reportProgress(progressUi, done, total, fileName, statusText)
    if not progressUi then
        return
    end
    if statusText and type(progressUi.SetStatus) == "function" then
        progressUi:SetStatus(statusText)
    end
    if type(progressUi.SetProgress) == "function" then
        progressUi:SetProgress(done, total, fileName)
    elseif type(progressUi.onProgress) == "function" then
        progressUi.onProgress(done, total, fileName)
    end
    if fileName and type(progressUi.SetDetail) == "function" then
        progressUi:SetDetail(fileName)
    elseif fileName and type(progressUi.onFile) == "function" then
        progressUi.onFile(fileName)
    end
end

local function syncFromGitHub(progressUi)
    if type(writefile) ~= "function" or type(readfile) ~= "function" then
        log("filesystem APIs missing; skipping sync (expecting preinstalled files)")
        return false, { updated = 0, skipped = 0, failed = 0, pending = 0, sha = nil }
    end

    ensureFolder(WORKSPACE_FOLDER)

    reportProgress(progressUi, 0, 1, nil, "Resolving latest commit…")
    local tipSha = ensureCommitPin(true)
    reportProgress(progressUi, 0, 1, nil, "Fetching manifest…")
    local remoteManifest, remoteBody = fetchRemoteManifest()
    local pending = collectPendingUpdates(remoteManifest)

    local totalPending = #pending
    local updated = 0
    local failed = 0
    local skipped = #remoteManifest.files - totalPending
    local statsBase = { sha = tipSha or _pinnedCommitSha }

    if totalPending == 0 then
        pcall(writeFile, workspacePath(MANIFEST_REL), remoteBody)
        reportProgress(progressUi, 1, 1, nil, "Already up to date")
        log("sync complete: 0 updated, " .. tostring(skipped) .. " unchanged, 0 failed"
            .. (statsBase.sha and (" @ " .. tostring(statsBase.sha):sub(1, 7)) or ""))
        return true, {
            updated = 0,
            skipped = skipped,
            failed = 0,
            pending = 0,
            sha = statsBase.sha,
        }
    end

    reportProgress(progressUi, 0, totalPending, nil, "Updating files…")

    for i, entry in ipairs(pending) do
        local rel = entry.path
        local dest = workspacePath(rel)
        reportProgress(progressUi, i - 1, totalPending, rel, nil)
        local ok, bodyOrErr = pcall(httpGet, rawUrl(rel))
        if ok and type(bodyOrErr) == "string" then
            local body = bodyOrErr
            local fp = fingerprint(body)
            if fp ~= entry.hash then
                log("hash mismatch after download: " .. rel .. " (got " .. fp .. ", expected " .. entry.hash .. ")")
            end
            local writeOk, writeErr = pcall(writeFile, dest, body)
            if writeOk then
                updated = updated + 1
            else
                failed = failed + 1
                log("failed to write " .. dest .. ": " .. tostring(writeErr))
            end
        else
            failed = failed + 1
            log("failed to download " .. rel .. ": " .. tostring(bodyOrErr))
        end

        reportProgress(progressUi, i, totalPending, rel, nil)
    end

    pcall(writeFile, workspacePath(MANIFEST_REL), remoteBody)

    if totalPending > 0 then
        reportProgress(progressUi, totalPending, totalPending, nil, "Finishing…")
    end

    log(string.format(
        "sync complete: %d updated, %d unchanged, %d failed%s",
        updated,
        skipped,
        failed,
        statsBase.sha and (" @ " .. tostring(statsBase.sha):sub(1, 7)) or ""
    ))
    if failed > 0 and updated == 0 and skipped == 0 then
        error("[SpyTool] sync failed for all files")
    end
    return true, {
        updated = updated,
        skipped = skipped,
        failed = failed,
        pending = totalPending,
        sha = statsBase.sha,
    }
end

local function loadMain()
    local path = resolveMainPath()
    if type(readfile) ~= "function" then
        error("[SpyTool] readfile is unavailable on this executor")
    end
    if type(isfile) == "function" and not isfile(path) then
        error("[SpyTool] missing main script at workspace path: " .. path)
    end
    local ok, source = pcall(readfile, path)
    if not ok then
        error("[SpyTool] failed to readfile(" .. path .. "): " .. tostring(source))
    end
    if type(source) ~= "string" or source == "" then
        error("[SpyTool] main script is empty: " .. path)
    end
    local chunk, compileErr = loadstring(source, "@" .. path)
    if not chunk then
        error("[SpyTool] failed to compile " .. path .. ": " .. tostring(compileErr))
    end
    return chunk()
end

local function clearDevMarkers()
    if type(delfile) == "function" then
        pcall(delfile, WORKSPACE_FOLDER .. "/" .. DEV_MARKER_REL)
        pcall(delfile, DEV_MARKER_REL)
    end
    local env = getDevGenv()
    if env then
        env[DEV_HANDOFF_KEY] = nil
        env[DEV_GENV_SKIP_SYNC] = nil
        env[DEV_GENV_FORCE_INSTALLER] = nil
    end
end

local function destroyRunningTool()
    local env = getDevGenv()
    if not env then
        return
    end
    local tool = env[SPYTOOL_GENV_KEY]
    if type(tool) == "table" and type(tool.Destroy) == "function" then
        pcall(function()
            tool.Destroy({ defer = false, force = true })
        end)
    end
    env[SPYTOOL_GENV_KEY] = nil
end

local function reloadPublicBootstrap()
    ensureCommitPin(true)
    local source = httpGet(rawUrl(BOOTSTRAP_REL))
    local chunk, compileErr = loadstring(source, "@" .. BOOTSTRAP_REL .. "#public")
    if not chunk then
        error("[SpyTool] failed to compile public bootstrap: " .. tostring(compileErr))
    end
    return chunk()
end

local function fetchPublicVersionAndReload()
    log("fetching public release and reloading…")
    clearDevMarkers()
    destroyRunningTool()
    return reloadPublicBootstrap()
end

local function parseRemoteAppVersion(source)
    if type(source) ~= "string" then
        return nil
    end
    local ver = source:match('SPYTOOL_VERSION%s*=%s*"([^"]+)"')
        or source:match("SPYTOOL_VERSION%s*=%s*'([^']+)'")
    if type(ver) == "string" and ver ~= "" then
        return ver
    end
    return nil
end

local function checkForUpdates()
    local tipSha = ensureCommitPin(true)
    local remoteManifest = fetchRemoteManifest()
    local pending = collectPendingUpdates(remoteManifest)
    local remoteVersion = nil
    local okCore, coreBody = pcall(httpGet, rawUrl("modules/01_core.lua"))
    if okCore then
        remoteVersion = parseRemoteAppVersion(coreBody)
    end
    local pendingPaths = {}
    for i = 1, math.min(8, #pending) do
        pendingPaths[#pendingPaths + 1] = pending[i].path
    end
    return {
        available = #pending > 0,
        pending = #pending,
        sha = tipSha or _pinnedCommitSha,
        remoteVersion = remoteVersion,
        pendingPaths = pendingPaths,
    }
end

local function registerBootstrapApi(devMode)
    local env = getDevGenv()
    if not env then
        return
    end
    env[DEV_BOOTSTRAP_KEY] = {
        IsDev = function()
            return hasDevMarkerFile() or env[DEV_HANDOFF_KEY] == true or env[DEV_GENV_SKIP_SYNC] == true
        end,
        IsDevMode = function()
            return hasDevMarkerFile() or env[DEV_HANDOFF_KEY] == true or env[DEV_GENV_SKIP_SYNC] == true
        end,
        FetchPublicVersion = fetchPublicVersionAndReload,
        CheckForUpdates = checkForUpdates,
        UpdateToLatest = function(progressUi, opts)
            opts = opts or {}
            log("updating workspace files to latest…")
            if opts.clearDev ~= false then
                clearDevMarkers()
            end
            local bag = { ok = false, stats = nil }
            local callOk, callErr = pcall(function()
                local synced, stats = syncFromGitHub(progressUi)
                bag.ok = synced == true
                bag.stats = stats
            end)
            if not callOk then
                return false, tostring(callErr)
            end
            if not bag.ok then
                return false, "sync failed", bag.stats
            end
            local stats = bag.stats or {}
            local shouldReload = opts.reload == true and ((stats.updated or 0) > 0 or opts.forceReload == true)
            if shouldReload then
                if progressUi and type(progressUi.SetStatus) == "function" then
                    progressUi:SetStatus("Reloading…")
                end
                task.wait(0.2)
                destroyRunningTool()
                return reloadPublicBootstrap()
            end
            return true, stats
        end,
        DevMode = devMode == true,
    }
end

local devSkipSync = isDevSkipSync()
local forceInstaller = isDevForceInstaller()
registerBootstrapApi(devSkipSync)
if devSkipSync then
    log("dev mode active — GitHub sync disabled")
end

local installerUi = nil
local showInstaller = isFirstInstall() or (devSkipSync and forceInstaller)
if showInstaller then
    local uiOk, uiOrErr = pcall(loadInstallerUi, devSkipSync)
    if uiOk then
        installerUi = uiOrErr
        local accepted = false
        local waitOk, waitResult = pcall(function()
            return installerUi:WaitForAccept()
        end)
        if waitOk then
            accepted = waitResult == true
        else
            log("installer confirmation failed: " .. tostring(waitResult))
        end
        if not accepted then
            pcall(function()
                installerUi:Destroy()
            end)
            installerUi = nil
            log("installation cancelled by user")
            return nil
        end
        pcall(function()
            installerUi:ShowProgress("install")
        end)
        if devSkipSync then
            installerUi:SetStatus("Dev mode — using local files")
            installerUi:SetProgress(1, 1)
            task.wait(0.35)
        end
    else
        log("installer UI unavailable: " .. tostring(uiOrErr))
    end
end

local syncOk, syncErr = true, nil
if devSkipSync then
    log("dev mode: skipping syncFromGitHub")
else
    if not installerUi then
        local peekOk, remoteManifest = pcall(fetchRemoteManifest)
        local pending = 0
        if peekOk then
            pending = #collectPendingUpdates(remoteManifest)
        end
        if pending > 0 then
            local uiOk, uiOrErr = pcall(loadInstallerUi, false)
            if uiOk then
                installerUi = uiOrErr
                pcall(function()
                    installerUi:ShowUpdateProgress()
                end)
            else
                log("updater UI unavailable: " .. tostring(uiOrErr))
            end
        end
    end
    syncOk, syncErr = pcall(function()
        return syncFromGitHub(installerUi)
    end)
end

if installerUi then
    pcall(function()
        installerUi:Destroy()
    end)
    installerUi = nil
end

if not syncOk then
    log("sync skipped/failed: " .. tostring(syncErr))
    local mainPath = resolveMainPath()
    if type(isfile) == "function" and not isfile(mainPath) then
        error("[SpyTool] cannot sync and no local install at " .. mainPath)
    end
end

return loadMain()
