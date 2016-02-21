
function Init()
    strategy:name("Strategy 248");
    strategy:description("Strategy 248 V2");

    strategy.parameters:addGroup("Trading Parameters");
    strategy.parameters:addString("Account", "Account", "", "");
    strategy.parameters:setFlag("Account", core.FLAG_ACCOUNT);

    strategy.parameters:addInteger("firstDirection", "first direction", "", 1, -1, 1);
    strategy.parameters:addInteger("firstSpace", "First Space", "", 2, 0, 50);
    strategy.parameters:addInteger("secondSpace", "Second Space", "", 4, 0, 50);
    strategy.parameters:addInteger("thirdSpace", "Third Space", "", 8, 0, 50);
    strategy.parameters:addInteger("limitSpace", "limit Space", "", 10, 1, 50);
    strategy.parameters:addInteger("stopSpace", "Third Space", "", 30, 1, 50);
    
end

local GETHISTORY_ID = 1;
local EDIT_ID = 2;
local CLOSE_ID = 3;
local ORDER_IDS = {11, 12, 13, 14};

local instrumentOfferId;
local accountInfo;

local direction;
local spaces = {};
local limitSpace;
local stopSpace;
 
function Prepare(onlyName)
 
    local name;
    name = profile:id() .. "(" .. instance.bid:instrument() .. ")";
    instance:name(name);

    if onlyName then
        return ;
    end

    instrumentOfferId = core.host:findTable("offers"):find("Instrument", instance.bid:instrument()).OfferID;
    accountInfo = instance.parameters.Account;

    direction = instance.parameters.firstDirection;
    spaces[1] = instance.parameters.firstSpace;
    spaces[2] = instance.parameters.secondSpace;
    spaces[3] = instance.parameters.thirdSpace;
    limitSpace = instance.parameters.limitSpace;
    stopSpace = instance.parameters.stopSpace;
end


local orders = nil;
local curPrice;
local allLimit;
local allStop;

function Update()

    if (direction == 1) then
        curPrice = instance.ask[NOW];
    else
        curPrice = instance.bid[NOW];
    end

    if (orders ~= nil) then
        ifNeedDeleteAll();
    end

    if (orders == nil) then
        orders = {};
        if (direction == 1) then
            allLimit = curPrice + limitSpace;
            allStop = curPrice - stopSpace;
        else
            allLimit = curPrice - limitSpace;
            allStop = curPrice + stopSpace;
        end
        orders[1] = {
                        requestId = open(ORDER_IDS[1], allLimit, allStop), 
                        open = curPrice;
                    };
    end

    if (orders[1] ~= nil) then
        for i=2, 4 do
            if (orders[i] == nil) then
                if (direction == 1) then
                    local entry = orders[i-1].open - spaces[i-1];
                    if (curPrice <= entry) then
                        allLimit = curPrice + limitSpace;
                        if (allLimit < orders[1].open) then
                            allLimit = orders[1].open;
                        end
                        orders[i] = {
                                        requestId = open(ORDER_IDS[i], allLimit, allStop), 
                                        open = curPrice;
                                    };
                        updateEveryLimit();
                    else
                        break;
                    end
                else
                    local entry = orders[i-1].open + spaces[i-1];
                    if (curPrice >= entry) then
                        allLimit = curPrice - limitSpace;
                        if (allLimit > orders[1].open) then
                            allLimit = orders[1].open;
                        end
                        orders[i] = {
                                        requestId = open(ORDER_IDS[i], allLimit, allStop), 
                                        open = curPrice;
                                    };
                        updateEveryLimit();
                    else
                        break;
                    end
                end
            end
        end
    end
end

function open(openId, limit, stop)

    local valuemap = core.valuemap();

    valuemap.Command = "CreateOrder";
    valuemap.OfferID = instrumentOfferId;
    valuemap.AcctID = accountInfo;
    valuemap.Quantity = 1;
    if (direction == 1) then
        valuemap.BuySell = "B";
    else
        valuemap.BuySell = "S";
    end
    valuemap.CustomID = "MACROSS";
    valuemap.OrderType = "OM";
    
    valuemap.RateLimit = limit;
    valuemap.RateStop = stop;

    valuemap.EntryLimitStop = 'Y';
    local success, orderId = terminal:execute(openId, valuemap);
    print("Open : success = " ..tostring(success).. ", orderId = " ..orderId);
    return orderId;
end


function updateEveryLimit()
    
    local enum, row;
    enum = core.host:findTable("orders"):enumerator();
    row = enum:next();
    while row ~= nil do
        if (row:cell("Type") == "L") then
            valuemap = core.valuemap();
            valuemap.Command = "EditOrder";
            valuemap.OfferID = instrumentOfferId;
            valuemap.AcctID = accountInfo;
            valuemap.OrderID = row:cell("OrderID");
            valuemap.Rate = allLimit;
            local success, msg = terminal:execute(EDIT_ID, valuemap);
        end
        row = enum:next();
    end
end

function ifNeedDeleteAll()

    if (core.host:findTable("trades"):find("OpenOrderReqID", orders[1].requestId) == nil) then
        local enum, row;
        enum = core.host:findTable("orders"):enumerator();
        row = enum:next();
        while row ~= nil do
            local valuemap = core.valuemap();
            valuemap.Command = "DeleteOrder";
            valuemap.OrderID = row.OrderID;
            local success, msg = terminal:execute(CLOSE_ID, valuemap);
            row = enum:next();
        end
        
        local profit = core.host:findTable("Closed Trades"):find("OpenOrderReqID", orders[1].requestId):cell("GrossPL");
        if (profit < -1) then
            direction = 0 - direction;
        end
        
        orders = nil;
    end
end

function AsyncOperationFinished(cookie, success, message)
    print("AsyncOperationFinished() : cookie = " ..cookie);
end




