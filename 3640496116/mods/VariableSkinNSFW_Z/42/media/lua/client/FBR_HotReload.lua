--[[
====================================================================
 FBR_HotReload.lua   女性模型热重载（开发调试工具）
--------------------------------------------------------------------
 作用：进入「选择职业」/「设定角色」界面、以及角色创建好进入游戏时
       自动重载角色模型；也可在游戏内按快捷键，强制从磁盘重新读取
       角色模型网格文件
       （如你 mod 里的 models_X/Skinned/FemaleBody.fbx），
       无需退出游戏重进即可看到模型改动。

 原理（B42 原生机制，非破解手段）：
   1. reloadModelsMatching(pattern) —— 官方暴露给 Lua 的全局函数，
      遍历 ModelManager 已加载模型表，把名字包含 pattern 的
      ModelMesh 标记卸载并异步重新从磁盘读取（mod 覆盖仍然生效）。
   2. IsoGameCharacter:resetModelNextFrame() —— 下一帧重建角色的
      ModelInstance（与换衣服时走的同一条 ModelManager.Reset 流程），
      确保画面立刻刷新。

 注意：贴图（png）不在此管线内，改贴图仍需重启游戏。
====================================================================
]]

local FBR = {}

------------------------- 可配置项 -------------------------

-- 热重载快捷键（Keyboard.KEY_* 常量）
FBR.RELOAD_KEY = Keyboard.KEY_K

-- 要重载的网格匹配串：小写、"包含"匹配 ModelManager 内部 key。
-- 角色身体的内部 key 是 "skinned/femalebody&shader=basiceffect"。
FBR.MESH_PATTERNS = {
    "skinned/femalebody",   -- 女性身体（你的 mod 覆盖的 Skinned/FemaleBody.fbx）
    -- "skinned/malebody",   -- 男性身体，需要时取消注释
    -- "skinned/female_skeleton", -- 女性骷髅，需要时取消注释
    -- "skinned/clothes/",   -- 所有已加载的衣物模型，需要时取消注释
}

-- 是否同时重置场景内所有僵尸的模型（僵尸数量多时会顿一下）
FBR.RESET_ZOMBIES = true

-- 触发重载后等待多少 tick 再重建角色模型（文件是异步加载的，60≈1秒）
FBR.RESET_DELAY_TICKS = 90

-- 刚创建/选择好角色进入游戏时是否自动重载（true=自动，无需按快捷键）
FBR.AUTO_RELOAD_ON_CREATE_PLAYER = true

-- 角色生成后等待多少 tick 再触发自动重载
-- （要等 ModelManager 把身体模型加载完，匹配串才能命中，60≈1秒）
FBR.AUTO_RELOAD_DELAY_TICKS = 60

-- 打开「选择职业」/「设定角色」界面时是否自动重载（用于刷界面里的预览模型）
FBR.AUTO_RELOAD_ON_CHAR_CREATION = true

-- 界面打开后等待多少 tick 再触发（要等 3D 预览把身体模型加载出来）
FBR.MENU_RELOAD_DELAY_TICKS = 60

------------------------------------------------------------

local pendingReset = -1
local pendingAutoReload = -1
local pendingMenuReload = -1

local function resetCharacters()
    local player = getPlayer()
    if player then
        player:resetModelNextFrame()
        
    end

    if FBR.RESET_ZOMBIES then
        local cell = getCell()
        local list = cell and cell:getZombieList()
        if list then
            for i = 0, list:size() - 1 do
                local zed = list:get(i)
                if zed then
                    zed:resetModelNextFrame()
                end
            end
        end
    end
end

-- 主菜单「设定角色」界面的 3D 预览模型：
-- 走与换装/换发型相同的 setSurvivorDesc 流程强制重建预览的 ModelInstance
local function resetMenuAvatar()
    local ms = MainScreen and MainScreen.instance
    if not ms then return end
    if ms.avatar then
        ms.avatar:resetModelNextFrame()
    end
    local ccm = CharacterCreationMain and CharacterCreationMain.instance
    if ccm and ccm.avatarPanel and ms.desc then
        ccm.avatarPanel:setSurvivorDesc(ms.desc)
        print("[FBR] menu avatar model reset.")
    end
end

local function resetTargets()
    if getPlayer() then
        resetCharacters()
    else
        resetMenuAvatar()
    end
end

local function triggerReload()
    for _, pattern in ipairs(FBR.MESH_PATTERNS) do
        reloadModelsMatching(pattern)
    end
    pendingReset = FBR.RESET_DELAY_TICKS
    print("[FBR] reloadModelsMatching triggered, model reload in progress...")
end

local function cancelPending()
    pendingReset = -1
    pendingAutoReload = -1
    pendingMenuReload = -1
end

local function onKeyPressed(key)
    if key ~= FBR.RELOAD_KEY then return end
    if not getPlayer() then return end -- 主菜单里不按生效
    triggerReload()
end

-- 刚创建/选择好角色进入游戏（含死亡后新建角色）时自动触发一次重载
local function onCreatePlayer(playerIndex, player)
    if not FBR.AUTO_RELOAD_ON_CREATE_PLAYER then return end
    if playerIndex ~= 0 then return end -- 只处理本地玩家 1
    cancelPending()
    pendingAutoReload = FBR.AUTO_RELOAD_DELAY_TICKS
    print("[FBR] player created, auto model reload scheduled...")
end

-- 包装主菜单界面的 setVisible：打开「选择职业」/「设定角色」界面时安排一次重载
local hookedClasses = {}

local function hookMenuScreen(class, name)
    if not (class and class.setVisible) or hookedClasses[class] then return end
    hookedClasses[class] = true
    local original = class.setVisible
    class.setVisible = function(self, visible, joypadData)
        original(self, visible, joypadData)
        if visible and FBR.AUTO_RELOAD_ON_CHAR_CREATION then
            cancelPending()
            pendingMenuReload = FBR.MENU_RELOAD_DELAY_TICKS
            print("[FBR] " .. name .. " opened, auto model reload scheduled...")
        end
    end
end

-- mod 的 client lua 加载较早，界面类可能还没 require 进来，
-- 所以在 OnGameBoot（全部 vanilla lua 已加载完毕）时再安装钩子
local function installHooks()
    hookMenuScreen(CharacterCreationMain, "设定角色界面")
    hookMenuScreen(CharacterCreationProfession, "选择职业界面")
    hookMenuScreen(CoopCharacterCreationMain, "联机设定角色界面")
    hookMenuScreen(CoopCharacterCreationProfession, "联机选择职业界面")
end

Events.OnGameBoot.Add(installHooks)

-- 倒计时统一走这里；OnTick 只在游戏内触发（源码确认见 IngameState），
-- 主菜单/捏人界面由 OnPreUIDraw 驱动（UIManager 每帧触发）
local function tickCountdowns()
    if pendingMenuReload >= 0 then
        pendingMenuReload = pendingMenuReload - 1
        if pendingMenuReload == 0 then
            triggerReload()
        end
        return
    end

    if pendingAutoReload >= 0 then
        pendingAutoReload = pendingAutoReload - 1
        if pendingAutoReload == 0 then
            triggerReload()
        end
        return
    end

    if pendingReset < 0 then return end
    pendingReset = pendingReset - 1
    if pendingReset == 0 then
        resetTargets()
    end
end

local function onTick()
    tickCountdowns()
end

local function onPreUIDraw()
    if getPlayer() then return end -- 游戏内由 OnTick 驱动，避免双倍计数
    tickCountdowns()
end

Events.OnKeyPressed.Add(onKeyPressed)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnTick.Add(onTick)
Events.OnPreUIDraw.Add(onPreUIDraw)
