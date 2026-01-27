---
name: "roblox-extraction-knit"
description: "Roblox 搜打撤 + Knit + ConfigFolder/ToolFolder 项目专用 Skill"
---

# Roblox 搜打撤 Knit Skill

本 Skill 面向当前这个基于 **Knit 框架** 的 Roblox 搜打撤项目，
约束 AI 在实现逻辑时优先使用：

- `ServerScriptService/Services` 下的 Knit 服务结构
- `ReplicatedStorage/ConfigFolder` 中的配置模块
- `ReplicatedStorage/ToolFolder` 中的通用工具模块
- 以及项目里已有的 AI、物品、子弹等体系

目标是：让后续自动生成的代码风格、目录与现有工程保持一致，
并减少“新造轮子”。

## 技术栈与目录约定

- 核心服务器框架：Knit
- 配置模块：位于 `ReplicatedStorage/ConfigFolder`（如 `GameConfig`, `ItemConfig`, `MonsterConfig` 等）
- 工具模块：位于 `ReplicatedStorage/ToolFolder`（如 `Interface.lua`, `PathfindingMove.lua` 等）
- 服务目录：`ServerScriptService/Services`（如 `MonsterService`, `ItemService`, `PlayerService`）
- AI 管理与状态机：`ServerScriptService/AIManagerFolder`（`AIManager.lua` + `Idle/Patrol/Attack/Dead` 等状态）
- 将来可能引入：ProfileService（持久化）、Fusion（UI）——如已存在则优先复用

## 触发时机（何时使用本 Skill）

在以下场景，Solo Coder 应优先按本 Skill 的约定思考与生成代码：

- 创建或修改 Knit 服务：战斗、怪物、物品掉落、任务、背包、装备、子弹等
- 需要从 `ConfigFolder` 读取或写入配置驱动的数据与行为
- 复用 `ToolFolder` 里的工具方法（如通用 UI、Tween、射线检测、路径寻路等）
- 扩展怪物 AI / 状态机（巡逻、追击、攻击、死亡表现）
- 处理搜打撤核心流程：下岛、搜刮、战斗、撤离、结算
- 将来接入 ProfileService 时的玩家数据读写；接入 Fusion 时的 UI 逻辑

## 编码风格与约束

- 服务必须通过 `Knit.CreateService` 创建，导出 `KnitInit` / `KnitStart` 等生命周期函数
- 所有公共 API 都挂在服务对象上（服务器端方法、Client 信号）
- 访问配置时：
  - 使用 `ReplicatedStorage:WaitForChild("ConfigFolder")` 中的模块
  - 尽量避免硬编码魔法数字，优先查表
- 调用工具时：
  - 使用 `ReplicatedStorage:WaitForChild("ToolFolder")` 下现有模块
  - 不重复写已经在 `Interface.lua` 等模块里实现过的工具逻辑
- Lua 代码中的函数应带“函数级注释”，说明用途与参数，而不是零碎的行内注释

## 典型 Knit 服务骨架示例

> 用于战斗/子弹/掉落等逻辑时，可以以此为模板扩展。

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local CombatService = Knit.CreateService({
    Name = "CombatService",
    Client = {
        FireBullet = Knit.CreateSignal(),
    },
})

-- 初始化服务（函数级注释）：
-- 用于在服务器启动时读取配置、初始化状态，不执行重型逻辑或无限循环。
function CombatService:KnitInit()
end

-- 服务启动入口（函数级注释）：
-- 在所有服务就绪后调用，用于建立事件连接、启动心跳逻辑等。
function CombatService:KnitStart()
end

-- 处理玩家开火请求（函数级注释）：
-- 按 GameConfig 与玩家状态计算伤害，并调用 BulletService 等子系统。
-- @param player Player 发起攻击的玩家
-- @param fireData table 包含射击方向、目标、是否暴击等信息
function CombatService:ServerFire(player, fireData)
end

return CombatService
```

## 配置与工具访问约定

- 配置读取示例：
  - 怪物配置：`local MonsterConfig = require(ConfigFolder:WaitForChild("MonsterConfig"))`
  - 物品配置：`local ItemConfig = require(ConfigFolder:WaitForChild("ItemConfig"))`
  - 游戏全局：`local GameConfig = require(ConfigFolder:WaitForChild("GameConfig"))`
- 工具调用示例：
  - 效果与 UI：从 `ToolFolder.Interface` 中复用，如 `Interface.PlayEffect`, `Interface.TweenProgressBarSize` 等
  - 路径寻路：从 `ToolFolder.PathfindingMove` 中复用移动逻辑
- 新逻辑尽量通过“查配置 + 调用工具模块”实现，而不是在服务内部硬编码所有细节。

## 设计原则（针对搜打撤玩法）

- 一切以“配置驱动”为优先：怪物属性、掉落方案、武器参数、动画 ID 尽量放到 `ConfigFolder`
- 服务之间通过 Knit 服务调用或 Client 信号通信，避免随意使用 `_G` 或跨层级引用
- 搜索（搜）、战斗（打）、撤离（撤）的关键环节应拆成清晰子系统：
  - 怪物与 AI：`MonsterService` + `AIManager` 状态机
  - 物品与掉落：`ItemService` + `SpecialItemService`
  - 战斗与子弹：`CombatService` + `BulletService`
  - 任务与进度：`QuestService`
  - 玩家属性与成长：`PlayerService`，将来可接入 ProfileService

## 提示语示例（供后续调用参考）

- 「为现有怪物 AI 新增一个远程攻击状态，按 MonsterConfig 配置的射程与攻击间隔工作。」
- 「在 ItemService 里增加一个按掉落方案 ID 生成战利品的函数，使用 ConfigFolder 配置驱动。」
- 「实现一个 BulletService，按玩家开火请求在服务端做射线检测与伤害结算。」
- 「基于 GameConfig 的动画映射，在 PlayerService 里新增一个通用 playAnimation 接口，支持冷却时间控制播放速度。」

当模型检测到这是一个「Roblox + Knit + 搜打撤」仓库，并且用户需求符合以上场景时，应启用本 Skill 中的约定来生成或修改代码。

