
function Init()
    strategy:name("Strategy 248");
    strategy:description("Strategy 248 V1");

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


local orders = {};
local curPrice;

function Update()

    if (orders[1] ~= nil) then
        updateOrder();


    elseif (orders[1] == nil) then
        local limit, stop;
        local positions = {};
        if (direction == 1) then
            curPrice = instance.ask[NOW];
            stop = curPrice - stopSpace;
            positions[2] = curPrice - spaces[1];
            positions[3] = curPrice - spaces[1] - spaces[2];
            positions[4] = curPrice - spaces[1] - spaces[2] - spaces[3];
        else
            curPrice = instance.bid[NOW];
            stop = curPrice + stopSpace;
            positions[2] = curPrice + spaces[1];
            positions[3] = curPrice + spaces[1] + spaces[2];
            positions[4] = curPrice + spaces[1] + spaces[2] + spaces[3];
        end
        positions[1] = curPrice;
        for i=1, 4 do
            if (direction == 1) then
                limit = positions[i] + limitSpace;
                if (limit < positions[1]) then
                    limit = positions[1];
                end
            else
                limit = positions[i] - limitSpace;
                if (limit > positions[1]) then
                    limit = positions[1];
                end
            end
            orders[i] = open(positions[i], ORDER_IDS[i], limit, stop);
        end
    end
end

function open(position, openId, limit, stop)

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

    if (curPrice == position) then
        valuemap.OrderType = "OM";
    else
        if (direction == 1) then
            valuemap.OrderType = "LE";
        else
            valuemap.OrderType = "SE";
        end
        valuemap.Rate = position;
    end
    
    valuemap.RateLimit = limit;
    valuemap.RateStop = stop;

    valuemap.EntryLimitStop = 'Y';
    local success, orderId = terminal:execute(openId, valuemap);
    print("Open : success = " ..tostring(success).. ", orderId = " ..orderId);
    return orderId;
end

local lastSize = 0;
function updateOrder()

    if (core.host:findTable("trades"):find("OpenOrderReqID", orders[1]) == nil) then
        closeAll();
        lastSize = 0;
        return;
    end

    local allLimit, size = 0;
    for i=2, 4 do
        local row = core.host:findTable("trades"):find("OpenOrderReqID", orders[i]);
        if (row == nil) then
            size = i - 1;
            break;
        elseif (row ~= nil) then
            allLimit = row:cell("Limit");
        end
    end

    if ((size > 1) and (size > lastSize)) then
        local enum, row;
        enum = core.host:findTable("orders"):enumerator();
        row = enum:next();
        while row ~= nil do
            if (row:cell("Type") == "L") then
                for i=1, size-1 do
                    if (row:cell("RequestID") == orders[i]) then
                        valuemap = core.valuemap();
                        valuemap.Command = "EditOrder";
                        valuemap.OfferID = instrumentOfferId;
                        valuemap.AcctID = accountInfo;
                        valuemap.OrderID = row:cell("OrderID");
                        valuemap.Rate = allLimit;
                        local success, msg = terminal:execute(EDIT_ID, valuemap);
                    end
                end
            end
            row = enum:next();
        end
    end

    if (size ~= lastSize) then
        lastSize = size;
    end
end

function closeAll()
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
    orders = {};
end


function AsyncOperationFinished(cookie, success, message)
    print("AsyncOperationFinished() : cookie = " ..cookie);
end




