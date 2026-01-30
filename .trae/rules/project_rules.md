# 项目规则（boat_fuben）

本项目为 Roblox Studio 游戏项目，主要使用 Lua/Luau，结合 Knit、ProfileService 等框架进行客户端/服务端开发。

## 技术栈与结构

- 引擎：Roblox（Luau）
- 主要框架：
  - Knit（服务端 Service / 客户端 Controller 架构）
  - ProfileService（玩家数据持久化）
- 目录结构（只列核心约定）：
  - `src/ReplicatedStorage/ConfigFolder`：各类配置（GameConfig、ItemConfig、MonsterConfig 等）
  - `src/ReplicatedStorage/ToolFolder`：通用工具模块（Interface、TweenInterface、UIEffects 等）
  - `src/ReplicatedStorage/Packages`：第三方依赖（Knit、ProfileService 及 sleitnick 系列库）
  - `src/ServerScriptService/Services`：Knit 服务端 Service
  - `src/ServerScriptService/AIManagerFolder`：怪物 AI 状态机
  - `src/StarterPlayer`：客户端脚本（玩家输入、UI、动画等）

## 代码风格与约定

- 语言：统一使用中文注释描述游戏逻辑、配置含义。
- 模块：优先使用 Knit Service / Controller 组织业务，不随意新增散落脚本。
- 配置：所有可调节数值（掉落、属性、品质枚举等）放在 `ConfigFolder` 对应配置文件中，不直接硬编码在业务脚本里。
- 工具函数：通用逻辑（UI 动效、寻路、属性工具等）尽量放在 `ToolFolder` 下统一复用。
- 函数注释：新增对外接口或重要函数时，应在函数前增加函数级注释，简要说明用途、关键参数和返回值（使用中文）。

## Knit 使用约定

- Service 放在 `src/ServerScriptService/Services`，通过 `Knit.CreateService` 创建，并导出 `KnitStart` / `KnitInit`。
- 客户端通过 `Knit.GetService("ServiceName")` 访问服务暴露的 `Client` 接口信号与方法。
- 客户端与服务端通信尽量统一使用 Knit 自带 Comm/Signal，不直接新建 RemoteEvent/RemoteFunction。

## 数据与配置约定

- 玩家数据：通过 ProfileService 管理，读写玩家数据时注意只在服务器上操作，避免在客户端直接持久化。
- 物品：
  - 物品基础信息来自 `ItemConfig`；
  - 通用枚举（物品类型、品质类型、任务类型等）来自 `GameConfig`；
  - 掉落相关逻辑走 `ItemService` / `SpecialItemService`，不要在其他地方直接生成 Workspace 物品。

## 运行、调试与校验

- 当前项目没有统一的命令行构建、测试或 Lint 命令，主要依赖 Roblox Studio 的 Play 模式进行验证。
- 修改服务端或客户端关键逻辑后：
  - 在 Studio 中至少进行一次本地 Play 测试；
  - 观察输出窗口（打印、警告）是否异常。
- 如果后续引入 Rojo / Luau 类型检查 / Lint 工具，对应命令应补充到本文件，便于自动执行：
  - 代码风格检查命令：_暂未配置_
  - 类型检查命令：_暂未配置_
  - 自动化测试命令：_暂未配置_

## 其他约定

- 不在服务器上直接信任客户端传入的数据（例如伤害数值、物品 ID），统一由服务器根据配置计算与校验。
- 新增系统时优先复用现有工具模块（例如 UI 动画统一用 `TweenInterface` / `UIEffects`，路径移动统一用 `PathfindingMove`）。
- 回答问题时，不要贴出代码，只回答问题的思路或解决方案。

