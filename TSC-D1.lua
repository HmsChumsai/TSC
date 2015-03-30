-- Last Modified Date: 20140620-00
require "ocs"

local cmdln = require "cmdline"
local fo = require "fo"
local tim = require "tim"
local maps = require "maps"
local accpos = require "accpos"
local mandator = require "mandator"
local mrg = require "mrg"

local depositId = ""
local entryFrom = ""
local entryTo = ""
local log_file = ""
local db_file = ""
local format = "PDF"

cmdln.add{ name="--logFile", descr="", func=function(x) log_file=x end }
cmdln.add{ name="--dbFile", descr="", func=function(x) db_file=x end }
cmdln.add{ name="--depositid", descr="", func=function(x) depositId=x end }
--cmdln.add{ name="--format", descr="", func=function(x) format=x end }
cmdln.add{ name="--from", descr="", func=function(x) entryFrom=x end }
cmdln.add{ name="--to", descr="",  func=function(x) entryTo=x end }

cmdln.parse( arg, true )
print("depositId: " .. depositId)
print("entryFrom: " .. entryFrom)
print("entryTo: " .. entryTo)
print("log_file: " .. log_file)
print("log_file: " .. log_file)
print("db_file: " .. db_file)
print("format: " .. format)

ocs.createInstance( "LUA" )
local function process()
  local dubi = require "dubi"
  --self defined common module
  local common = require "common"
  local confirmreport = require "confirmreport"
  local easygetter = require "easygetter"

  common.CheckValidTimeRange(entryFrom, entryTo)

  local CallForceMapping = {["Call"]="Call", ["Force"]="Force", ["None"]=""}
  local debug_mode = false

  local sql_column_text = ' TEXT DEFAULT "" '
  local sql_column_integer = ' INTEGER DEFAULT 0'
  local sql_column_real = ' REAL DEFAULT 0.0'
  local table_name_deposit = "deposit"
  local table_name_order = "DECIDE_order"
  local table_name_order2 = "DECIDE_order2"
  local table_name_margin = "margin"
  local database_tables = {
    {table_name_deposit, {'client_name'..sql_column_text,
      'account_no'..sql_column_text,
      'account_name'..sql_column_text,
      'trader_id'..sql_column_text,
      'trader_name'..sql_column_text,
      'credit_limit'..sql_column_real,
      'credit_available'..sql_column_real,
      'net_pos'..sql_column_text,
      'credit_calculation_method'..sql_column_text,
      'margin_calculation_method'..sql_column_text,
      'position_limit'..sql_column_text,
      'can_mark_to_market'..sql_column_text,
      'equity_balance_pre'..sql_column_real,
      'equity_balance_current'..sql_column_real,
      'excess_equity_bal_prev'..sql_column_real,
      'excess_quity_bal_current'..sql_column_real,
      'mkt_to_mkt_fut_previous'..sql_column_real,
      'mkt_to_mkt'..sql_column_real,
      'initial_margin_prev'..sql_column_real,
      'initial_margin_current'..sql_column_real,
      'maintenance_margin_prev'..sql_column_real,
      'maintenance_margin_current'..sql_column_real,
      'force_margin_prev'..sql_column_real,
      'force_margin_current'..sql_column_real,
      'min_cash_call_margin_prev'..sql_column_real,
      'cash_balance'..sql_column_real,
      'non_cash_collateral'..sql_column_real,
      'FC_collateral'..sql_column_real,
      'profit_loss'..sql_column_real,
      'premium'..sql_column_real,
      'call_margin_ammount'..sql_column_real,
      'call_force_amount'..sql_column_real,
      "total_comm_vat"..sql_column_real,
      'trade_date'..sql_column_text,
      'settlement_date'..sql_column_text,
      "cost"..sql_column_real,
    }},

    {table_name_order, {'order_id'..sql_column_text,
      'trade_date'..sql_column_text,
      'settlement_date'..sql_column_text,
      'session'..sql_column_text,
      'ordering_method'..sql_column_text,
      'underlying'..sql_column_text,
      'series'..sql_column_text,
      'long_short'..sql_column_text,
      'pos'..sql_column_text,
      'vol'..sql_column_integer,
      'match_vol'..sql_column_real,
      'match_price'..sql_column_real,
      'multiplier'..sql_column_integer,
      "comm_vat"..sql_column_real,
      'avg_price'..sql_column_real,
    }},

    {table_name_order2, { 'series'..sql_column_text,
      'side'..sql_column_text,
      "orders_unmat"..sql_column_real,
      "quantity"..sql_column_real,
      "cost"..sql_column_real,
      "mkt"..sql_column_real,
      "realized_pl"..sql_column_real,
      "unrealized_pl"..sql_column_real}},
      
      {table_name_margin, { 'margin_code'..sql_column_text,
    'margin_num'..sql_column_integer,
    }}
  }

  common.CreateTables(db_file, log_file, database_tables, debug_mode)

  local DECIDE_deposit_obj = fo.Deposit( tonumber(depositId) )

  local depositList = {}
  local depositItem = {}
  table.insert (depositItem, {'account_no', DECIDE_deposit_obj:getNumber()})
  table.insert (depositItem, {'account_name', DECIDE_deposit_obj:getName()})
  table.insert (depositItem, {'net_pos', common.BoolleanToYNMapping[DECIDE_deposit_obj:hasShortLongNetting()]})
  
    local position = DECIDE_deposit_obj:getPortfolio():getPositions() --- TEST
      for _,po in pairs(position) do 
          local pe = fo.PositionEvaluation { position=po }
          local Avgeprice = pe:getAvgePrice()
          
               table.insert(depositItem,{'cost',Avgeprice})
        end
  
  local client_obj = DECIDE_deposit_obj:getClient()
  table.insert (depositItem, {'client_name', client_obj:getName()})
  if( client_obj:hasAccountManager() ) then
    local account_manager = client_obj:getAccountManager()
    local trader_id = dubi.getSETTraderId( account_manager:getShortName())
    table.insert (depositItem, {'trader_name', account_manager:getName()})
    if( trader_id ~= nil) then
      -- ** pending to dev for multiple exchange
      table.insert (depositItem, {'trader_id', trader_id })
    end
  end

  -- Only Risk Array can is supported in DECIDE for now
  table.insert (depositItem, {'margin_calculation_method', 'Risk Array'})
  local orderVolLimit = easygetter.GetFirstActiveOVL(depositId)

  local marginTask = nil
  local margCalcSettings = nil
  local orderVolumeRisk = nil

  if (orderVolLimit ~= nil) then
    orderVolumeRisk = orderVolLimit:getUniqueRisk()
    if ( orderVolLimit:hasMarginTask() ) then
      marginTask = orderVolLimit:getMarginTask()
      margCalcSettings = marginTask:getMargCalcSettings()
    end
  end

  if ( orderVolLimit ~= nil ) then
    table.insert (depositItem, {'can_mark_to_market', common.BoolleanToYNMapping[orderVolLimit:includeUPL()]})
    table.insert (depositItem, {'min_cash_call_margin_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousCallAmount())})
    table.insert (depositItem, {'equity_balance_pre', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousEquityBalance())})
    table.insert (depositItem, {'excess_equity_bal_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousExcessEquityBalance())})
    table.insert (depositItem, {'mkt_to_mkt_fut_previous', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousFutureUPL())}) --- getDailyFutureRPLGross
    table.insert (depositItem, {'initial_margin_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousInitialMargin())})
    table.insert (depositItem, {'maintenance_margin_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousMaintenaceMargin())})
    table.insert (depositItem, {'force_margin_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousForceMargin())})
    table.insert (depositItem, {'non_cash_collateral', easygetter.EvenAmountToDouble(orderVolLimit:getNonCashCollateral())})
    table.insert (depositItem, {'FC_collateral', easygetter.EvenAmountToDouble(orderVolLimit:getForeignCollateral())})
  end

  if(margCalcSettings ~= nil) then
    table.insert (depositItem, {'credit_calculation_method', margCalcSettings:getName()})
  end

  if(orderVolumeRisk ~= nil) then
    table.insert (depositItem, {'credit_limit', easygetter.EvenAmountToDouble(orderVolumeRisk:getCreditLimit())})
    table.insert (depositItem, {'credit_available', easygetter.EvenAmountToDouble(orderVolumeRisk:getCreditAvailable())})
    -- need to confirm with BA if profit_loss(Total Real. Futures) is the same as Total Real / Receive
    table.insert (depositItem, {'profit_loss', easygetter.EvenAmountToDouble(orderVolumeRisk:getDailyFutureRPLGross())})
    local tur_sell = easygetter.EvenAmountToDouble(orderVolumeRisk:getTurnoverVolumeSell())
    local tur_buy = easygetter.EvenAmountToDouble(orderVolumeRisk:getTurnoverVolumeBuy())
    table.insert (depositItem, {'premium', tur_sell - tur_buy})
    table.insert (depositItem, {'equity_balance_current', easygetter.EvenAmountToDouble(orderVolumeRisk:getEquityBalance())})
    table.insert (depositItem, {'excess_quity_bal_current',easygetter.EvenAmountToDouble(orderVolumeRisk:getExcessEquityBalance()) })
    table.insert (depositItem, {'cash_balance',easygetter.EvenAmountToDouble(orderVolumeRisk:getCashBalance()) })
    table.insert (depositItem, {'call_margin_ammount',easygetter.EvenAmountToDouble(orderVolumeRisk:getCallAmount()) })
    table.insert (depositItem, {'call_force_amount',easygetter.EvenAmountToDouble(orderVolumeRisk:getForceAmount()) })
    table.insert (depositItem, {'mkt_to_mkt',easygetter.EvenAmountToDouble(orderVolumeRisk:getTotalFutureUPLGross())})
    table.insert (depositItem, {'initial_margin_current', easygetter.EvenAmountToDouble(orderVolumeRisk:getPositionMargin()) })
    table.insert (depositItem, {'maintenance_margin_current', easygetter.EvenAmountToDouble(orderVolumeRisk:getMaintenanceMargin()) })
    table.insert (depositItem, {'force_margin_current', easygetter.EvenAmountToDouble(orderVolumeRisk:getForceMargin()) })
  end

  --**table.insert (depositItem, {'position_limit', ''}) -- not available for now in Account Setting

  local orders = easygetter.GetOrders( depositId, entryFrom, entryTo )

  local orderList = {}
  local orderItem = {}

  local total_comm_vat = 0
  local have_get_trade_settlement_day = false

  for _,no in pairs( orders ) do
    local order = fo.Order( no )

    local orderHandlingType = order:getHandlingType()
    if (orderHandlingType == 'TradingOrder' or orderHandlingType == 'BlockTrade') then
      local orderlegs = order:getOrderLegs()
      for _,orderLeg in pairs(orderlegs) do
        orderItem = {}
        table.insert (orderItem, {'order_id', order:getOrderId()})
        local tradeDate = order:getEntryTime():getDateInUtcOffset(common.offsetTimeZoneSecs):toString("%d/%m/%Y")
        table.insert (depositItem, {'trade_date', tradeDate})
        local cdate = common.GetSettlementDateFromOrder(order);
        if( cdate ~= nil) then
          table.insert (depositItem, {'settlement_date', cdate:toString("%d/%m/%Y")})
          if( have_get_trade_settlement_day == false) then
            --table.insert (depositItem, {'trade_date', tradeDate})
            --have_get_trade_settlement_day = true
          end
        end

        --** pending to confirm
        local validTime = order:getValidTime()
        if ( validTime:isUnused() ) then
          table.insert (orderItem, {'session', 'GTC'})
        else
          if (validTime:getClockTime("MIDNIGHT_24"):compare( tim.ClockTime.max() ) < 0 ) then
            table.insert (orderItem, {'session', 'Day'})
          else
            table.insert (orderItem, {'session', 'Night'})
          end
        end
        
        if(order:hasTradingChannel()) then
          local trading_channel_name = order:getTradingChannel():getName()
          if (trading_channel_name == "DECIDE") then
            table.insert (orderItem, {'ordering_method', "Marketing"})
          elseif (trading_channel_name == "INTERNET") then
            table.insert (orderItem, {'ordering_method', "Internet"})
          end
        end

        local orderLegContract = orderLeg:getContract()
        if( orderLegContract:hasUnderlying()) then
          table.insert (orderItem, {'underlying',orderLegContract:getInstrument():getUnderlyingInstrument():getName()})
        end

        table.insert (orderItem, {'series', orderLegContract:getContractCode()})

        local LongShort = common.BuySellToLSMapping[orderLeg:getOrderKind()] or ''

        table.insert (orderItem, {'long_short', LongShort})

        table.insert (orderItem, {'pos', orderLeg:getOpenClose()})

        local open_qty = orderLeg:getOpenQty()

        local cancel_qty = 0
        -- BA to confirm whether need to include the expire order as cancel qty
        if(order:getStatus() == "Closed" and
          (order:getOrderClosedBy()=="PartExecCancel" or order:getOrderClosedBy()=="NoExecCancel" ) ) then
          cancel_qty = orderLeg:getTotalQty()-orderLeg:getExecQty()
        end

        local match_qty = orderLeg:getExecQty()
        table.insert (orderItem, {'match_vol', match_qty})

        local tick_factor = 1
        local matched_value = 0
        if (match_qty ~= 0 ) then
          -- Use value day for tickfactor for matched value.
          if (cdate ~= nil) then
            tick_factor = easygetter.EvenAmountToDouble(orderLeg:getContract():getTickFactor(nil,cdate));
          end
          local match_avg_price =  orderLeg:getAvgExecPrice()
          table.insert (orderItem, {'match_price', match_avg_price})
          table.insert (orderItem, {'multiplier', tick_factor})
          
          
          local cal_avg_price = (match_qty * match_avg_price)
           table.insert (orderItem,{'avg_price',cal_avg_price})
        end

        
        
        -- total qty = matched qty + open/cancel qty
        table.insert (orderItem, {'vol', match_qty + open_qty + cancel_qty})

        local comm_vat = 0
        for _,op in pairs( order:getOrderOperations() ) do
          if op:getTransactionType() == "Match" then
            local oplegs = op:getOrderOperationLegs()
            if (#oplegs ~= 1) then
              confirmreport.announceGenerationFailure("One order operation should have only one order operation leg!")
              print("One order operation should have only one order operation leg!")
              os.exit(1)
            elseif(oplegs[1]:getContract():getContractCode() == orderLeg:getContract():getContractCode()) then
              local opleg = oplegs[1]
              if (opleg:hasTransaction()) then
                local ta = opleg:getEffectiveTransaction()
                local posting = fo.Posting(ta,1)
                -- if there is no value of maps.NameToFee("Custodian") then the comm+vat will be '0',maybe it should be maps.NameToFee("Settlement") or others , but I am not sure (george guo)
                -- if (posting:hasFeeValue(nil,maps.NameToFee("Custodian")) ) then
                local comm = easygetter.EvenAmountToDouble(posting:getFeeAccountCurr(nil,maps.NameToFee("Custodian")))
                local vat = easygetter.EvenAmountToDouble(posting:getFeeAccountCurr(nil,maps.NameToFee("Settlement")))
                local exch_fee_settle_curr = easygetter.EvenAmountToDouble(posting:getFeeAccountCurr(nil,maps.NameToFee("Exchange")))
                -- confirm with BA that there are two methods to get comm+vat. The value of comm+vat should be the value of TotalCostSettleCurr in Transactions. reference the doc of FeeClarification (george guo)
                comm_vat = comm_vat + comm + vat + exch_fee_settle_curr
                -- end
                -- print("1["..cont_size)
              end
            end
          end
        end

        table.insert (orderItem, {'comm_vat', comm_vat})
        total_comm_vat = total_comm_vat + comm_vat
        table.insert (orderList, orderItem)
      end
    end
  end

  --if not have any match transaction above
  --[[if(have_get_trade_settlement_day == false) then
  local fromTimeStampObj = tim.msecsSince1970ToTimeStamp( tonumber(entryFromMillSec))
  -- with 7*3600 second's UTC offset
  local fromThaiDate  = fromTimeStampObj:getDateInUtcOffset(common.offsetTimeZoneSecs)
  table.insert (depositItem, {'trade_date', fromThaiDate:toString("%Y%m%d")})
  end--]]

  local p="(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  local year,month,day,hour,min,sec=entryFrom:match(p)

  --local fromTimeStampObj = tim.msecsSince1970ToTimeStamp( tonumber(entryFromMillSec))
  -- with 7*3600 second's UTC offset
  --local fromThaiDate  = fromTimeStampObj:getDateInUtcOffset(common.offsetTimeZoneSecs)
  --table.insert (depositItem, {'trade_date', year..month..day})


  table.insert (depositItem, {'total_comm_vat', total_comm_vat})
  table.insert (depositList, depositItem)

  common.InsertRecords(db_file, log_file, table_name_deposit, depositList, debug_mode)
  common.InsertRecords(db_file, log_file, table_name_order, orderList, debug_mode)

  local orderList2 = {}
  local from = tim.TimeStamp( entryFrom )
  local to = tim.TimeStamp( entryTo )

  local position_list = DECIDE_deposit_obj:getAccPositions()   -- get a list of positions
  for _,position in pairs ( position_list ) do
    local data = accpos.getPositionValues( position, from , to, DECIDE_deposit_obj:getGeneralLedgerCurrencyType() )
    local data_effective_status = data.effective
    --if ( data_effective_status == "Yes" ) then
      local orderItem2 = {}

      local contract = position:getContract()
      table.insert (orderItem2, {'series', contract:getContractCode()})


      table.insert (orderItem2, {'quantity', position:getAvailableQuantity()})


      local ok, pe = pcall( fo.PositionEvaluation, { position=position, plview="latest" } )

        table.insert(orderItem2,{'cost',pe:getAvgePrice()})

        
      local mark_average = easygetter.EvenAmountToDouble(data.lastUnchecked)
      table.insert (orderItem2, {'mkt', mark_average})

      local position_short_long = position:getShortLong()
      table.insert (orderItem2, {'side', position_short_long})


       local orders_unmat = 0
        if ( position_short_long == "Long" ) then
            table.insert(orderItem2,{'orders_unmat',position:getOrdersBuy()})
        end
        if ( position_short_long == "Short" ) then
            
        table.insert(orderItem2,{'orders_unmat',position:getOrdersSell()})
        end

        
        
      local realized = easygetter.EvenAmountToDouble(data.startToEndRPL)
      table.insert (orderItem2, {'realized_pl', realized})
      local unrealized = easygetter.EvenAmountToDouble(data.endUPL)
      table.insert (orderItem2, {'unrealized_pl', unrealized})

      table.insert (orderList2, orderItem2)
    --end
  end
  
  local marginList = {}
  
   local mrg_org = mrg.limitStatus(DECIDE_deposit_obj:getClient():getMarginTasks()[1]:getOrderVolumeLimits()[1])

       for _,spanSim_ob in pairs(mrg_org.details) do
         local  marginItem = {}
         if ( spanSim_ob.cbcomgroup:getCode() ~= nil ) then 
         table.insert(marginItem,{'margin_code',spanSim_ob.cbcom:getCode()})
         --table.insert(marginItem,{'margin_code2',mrg_org.details[2].cbcomgroup:getCode()})
         end
         if (spanSim_ob.margin ~= nil) then 
          table.insert(marginItem,{'margin_num',spanSim_ob.margin})
         end
       table.insert(marginList,marginItem)
       end
  
  
  common.InsertRecords(db_file, log_file, table_name_margin, marginList, debug_mode)
  common.InsertRecords(db_file, log_file, table_name_order2, orderList2, debug_mode)
end
local inst = os.getenv( "OCSINST" )
local mand = mandator.Mandator( inst )
mandator.changeTo( mand, process )