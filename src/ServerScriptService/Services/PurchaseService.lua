-- 充值购买服务

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local PurchaseService = Knit.CreateService({
    Name = 'PurchaseService',
    Client = {
        PurchaseProduct = Knit.CreateSignal(),
        PurchaseCompleted = Knit.CreateSignal(),
        PurchaseFailed = Knit.CreateSignal(),
    },
})

-- 存储待处理的购买请求
local PendingPurchases = {}
local ReviveProductId = 3438784006

-- 处理开发者产品购买回调
-- @param receiptInfo table 购买收据信息
-- @return Enum.ProductPurchaseDecision 购买决定
local function processReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- 检查是否有待处理的购买请求
    local pendingPurchase = PendingPurchases[receiptInfo.PlayerId]
    if not pendingPurchase then
        -- 如果没有待处理的购买请求，可能是重复处理或异常情况
        warn("No pending purchase found for player:", receiptInfo.PlayerId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- 验证产品ID是否匹配
    if pendingPurchase.productId ~= receiptInfo.ProductId then
        warn("Product ID mismatch for player:", receiptInfo.PlayerId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- 清理已处理的购买请求
    PendingPurchases[receiptInfo.PlayerId] = nil
    Knit.GetService("ReviveService"):BuyReviveByRob(player)
    
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- 客户端接口：购买复活
-- @param player Player 玩家对象
-- @param productId string 物品商品ID
-- @return boolean 是否成功发起购买
function PurchaseService:BuyRevive(player)
    -- 存储待处理的购买请求
    PendingPurchases[player.UserId] = {
        productId = ReviveProductId,
        timestamp = tick(),
    }

    -- 发起购买
    local success, errorMessage = pcall(function()
        game.MarketplaceService:PromptProductPurchase(player, ReviveProductId)
    end)

    return success
end

-- 清理过期的待处理购买请求
-- @param maxAge number 最大存活时间（秒）
function PurchaseService:CleanupPendingPurchases(maxAge)
    maxAge = maxAge or 300 -- 默认5分钟
    local currentTime = tick()
    
    for userId, purchaseData in pairs(PendingPurchases) do
        if currentTime - purchaseData.timestamp > maxAge then
            PendingPurchases[userId] = nil
        end
    end
end

function PurchaseService:KnitInit()
    -- 设置购买处理回调
    MarketplaceService.ProcessReceipt = processReceipt
end

function PurchaseService:KnitStart()
    -- 定期清理过期的待处理购买请求
    task.spawn(function()
        while true do
            task.wait(60) -- 每分钟清理一次
            self:CleanupPendingPurchases()
        end
    end)
end

return PurchaseService