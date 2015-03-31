require "ocs"

local cmdln = require "cmdline"
local fo = require "fo"
local tim = require "tim"
local maps = require "maps"
local easygetter = require "easygetter"
local mandator = require "mandator"

local depositId = ""
local entryFrom = ""
local entryTo = ""
local log_file = ""
local db_file = ""
local format = "PDF"

cmdln.add{ name="--logFile", descr="", func=function(x) log_file=x end }
cmdln.add{ name="--dbFile", descr="", func=function(x) db_file=x end }
cmdln.add{ name="--depositid", descr="", func=function(x) depositId=x end }
cmdln.add{ name="--from", descr="", func=function(x) entryFrom=x end }
cmdln.add{ name="--to", descr="",  func=function(x) entryTo=x end }

cmdln.parse( arg, true )
print("depositId: " .. depositId)
print("entryFrom: " .. entryFrom)
print("entryTo: " .. entryTo)
print("log_file: " .. log_file)
print("db_file: " .. db_file)
print("format: " .. format)

ocs.createInstance( "LUA" )
local function process()
  local dubi = require "dubi"
  --self defined common module
  local common = require "common"
  local M = require "customOrderData"
  local confirmreport = require "confirmreport"

  common.CheckValidTimeRange(entryFrom, entryTo)

  local CallForceMapping = {["Call"]="Call", ["Force"]="Force", ["None"]=""}
  local debug_mode = false

  local sql_column_text = ' TEXT DEFAULT "" '
  local sql_column_integer = ' INTEGER DEFAULT 0'
  local sql_column_real = ' REAL DEFAULT 0.0'
  local table_name_deposit = "deposit"
  local table_name_order = "DECIDE_order"
  local database_tables = {
    {table_name_deposit, {'client_name'..sql_column_text,
              'account_no'..sql_column_text,
              'magin_type'..sql_column_text,
              'account_name'..sql_column_text,
              'trader_id'..sql_column_text,
              'trader_name'..sql_column_text,
              'TCH_account'..sql_column_text,
              'cust_flag'..sql_column_text,
              'cust_type'..sql_column_text,
              'account_type'..sql_column_text,
              'credit_type'..sql_column_text,
              'cannot_over_credit'..sql_column_text,
              'cash_checking'..sql_column_text,
              'mark_to_market'..sql_column_text,
              'auto_net_pos'..sql_column_text,
              'margin_method'..sql_column_text,
              'position_limit'..sql_column_real,
              'report_level_F'..sql_column_text,
              'report_level_O'..sql_column_text,
              'commission'..sql_column_real,
              'expected_commission'..sql_column_real,
              'withholding_tax'..sql_column_real,
              'cash_balance_prev'..sql_column_real,
              'excess_equity'..sql_column_real,
              'liquid_lvalue_curr'..sql_column_real,
              'credit_line'..sql_column_real,
              'buy_limit'..sql_column_real,
              'equity_balance_pre'..sql_column_real,
              'equity_balance_expected'..sql_column_real,
              'equity_balance_port'..sql_column_real,
              'excess_equity_bal_prev'..sql_column_real,
              'excess_equity_bal_expected'..sql_column_real,
              'excess_equity_bal_port'..sql_column_real,
              'unreal_pl_prev'..sql_column_real,
              'unreal_pl_expected'..sql_column_real,
              'unreal_pl_port'..sql_column_real,
              'magin_bal_prev'..sql_column_real,
              'magin_bal_expected'..sql_column_real,
              'magin_bal_port'..sql_column_real,
              'call_force_flag_prev'..sql_column_text,
              'call_force_flag_expected'..sql_column_text,
              'call_force_flag_port'..sql_column_text,
              'call_force_amount_prev'..sql_column_real,
              'call_force_amount_expected'..sql_column_real,
              'call_force_amount_port'..sql_column_real,
              'withdrawal_port'..sql_column_real}},

    {table_name_order, { 'order_no'..sql_column_text,
        'order_entry_username'..sql_column_text,
        'order_entry_time'..sql_column_text,
        'trade_date'..sql_column_text,
        'settlement_date'..sql_column_text,
        'INSTRUMENT'..sql_column_text,
        'buy_sell'..sql_column_text,
        'pos'..sql_column_text,
        'vol'..sql_column_integer,
        'price'..sql_column_text,
        'match_price'..sql_column_real,
        'match_vol'..sql_column_integer,
        'unmatched_qty'..sql_column_integer,
        'Status'..sql_column_real,
        'service_type'..sql_column_real,
        'published'..sql_column_real}}
  }


  common.CreateTables(db_file, log_file,  database_tables, debug_mode)

  local DECIDE_deposit_obj = fo.Deposit( tonumber(depositId) )

  --local depositList = {}
  local depositItem = {}
  local client_obj = DECIDE_deposit_obj:getClient()
  table.insert (depositItem, {'client_name', client_obj:getName()})
  table.insert (depositItem, {'account_no', DECIDE_deposit_obj:getNumber()})
  table.insert (depositItem, {'account_name', DECIDE_deposit_obj:getNumber()})
  table.insert (depositItem, {'TCH_account', DECIDE_deposit_obj:getDefClearingAccount():getName()})
  
  
    if(DECIDE_deposit_obj:hasTradingProfile()) then
    local profile = DECIDE_deposit_obj:getTradingProfile()
    local profilePreFix = ""
    if( profile ~= nil) then
      profilePreFix = string.sub(profile:getName(), 1, 2)
      if( string.find("F=;O=;A=;N=;G=;E=;X=;", profilePreFix) ~= nil) then
        table.insert (depositItem, {'cust_flag', string.sub(profilePreFix, 1, 1)})
      else
        table.insert (depositItem, {'cust_flag', "Unexpected Value"})
      end
    end
  end
  
  if (DECIDE_deposit_obj:hasAccountType()) then
    table.insert (depositItem, {'account_type', DECIDE_deposit_obj:getAccountType():getName() })
  end

  table.insert (depositItem, {'auto_net_pos', common.BoolleanToYesNoMapping[DECIDE_deposit_obj:hasShortLongNetting()] })
  
  
  
  if( client_obj:hasAccountManager() ) then
    local account_manager = client_obj:getAccountManager()
    local trader_id = dubi.getSETTraderId( account_manager:getShortName())
    if( trader_id ~= nill) then
      table.insert (depositItem, {'trader_id', trader_id })
    end
    table.insert (depositItem, {'trader_name', account_manager:getName()})
  end
  if( client_obj:hasClientType() ) then
    table.insert (depositItem, {'cust_type', client_obj:getClientType():getName()})
  end
--------------------------------------------------------------------------- New 


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

  if (margCalcSettings ~= nil) then
    table.insert (depositItem, {'magin_type', margCalcSettings:getName()})
      table.insert (depositItem, {'margin_method', margCalcSettings:getName()})
  end

  if (orderVolLimit ~= nil) then
    table.insert (depositItem, {'credit_type',  '1'})
  end

  local cannot_over_credit = ""
  if	(orderVolLimit == nil) then
    cannot_over_credit = "Y"
  else
    local cannot_over_creditMap = {["Rejected"]="N", ["NotApproved"]="A"}
    cannot_over_credit = cannot_over_creditMap[orderVolLimit:getRejectAction()]
  end
  table.insert (depositItem, {'cannot_over_credit', cannot_over_credit})

  local cash_checking = "N"
  if	(orderVolLimit == nil) then
    cash_checking = "N"
  elseif (orderVolLimit:getCalculationMethod() == "CashBalance") then
    cash_checking = "Y"
  end
  table.insert (depositItem, {'cash_checking', cash_checking})

  --**table.insert (depositItem, {'position_limit', ''}) -- not available for now in Account Setting
  --**table.insert (depositItem, {'cash_balance_prev', }) -- not available for now in limit and risk

  if ( orderVolLimit ~= nil ) then
    table.insert (depositItem, {'mark_to_market', common.BoolleanToYNMapping[orderVolLimit:includeUPL()] })
    table.insert (depositItem, {'credit_line', easygetter.EvenAmountToDouble(orderVolLimit:getCreditLine())})
  --	table.insert (depositItem, {'buy_limit', easygetter.EvenAmountToDouble(orderVolLimit:getLimitAmount())})
    table.insert (depositItem, {'equity_balance_pre', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousEquityBalance()) })
    table.insert (depositItem, {'excess_equity_bal_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousExcessEquityBalance())})
    table.insert (depositItem, {'unreal_pl_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousFutureUPL())+ easygetter.EvenAmountToDouble(orderVolLimit:getPreviousOptionUPLGross())})
    table.insert (depositItem, {'magin_bal_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousInitialMargin())})
    table.insert (depositItem, {'call_force_flag_prev', CallForceMapping[orderVolLimit:getPreviousCallForce()]})
    table.insert (depositItem, {'call_force_amount_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousForceMargin())})
    table.insert (depositItem, {'withdrawal_port', easygetter.EvenAmountToDouble(orderVolLimit:getDepositWithdrawal())})
  end

  if(orderVolumeRisk ~= nil) then
    table.insert (depositItem, {'commission', easygetter.EvenAmountToDouble(orderVolumeRisk:getTurnoverFee()) })
    table.insert (depositItem, {'expected_commission', easygetter.EvenAmountToDouble(orderVolumeRisk:getTurnoverFee()) + easygetter.EvenAmountToDouble(orderVolumeRisk:getOrderFee())})
    table.insert (depositItem, {'liquid_lvalue_curr',  easygetter.EvenAmountToDouble(orderVolumeRisk:getLiquidationValue())})
    table.insert (depositItem, {'equity_balance_expected', easygetter.EvenAmountToDouble(orderVolumeRisk:getExpectedEquityBalance())})
    table.insert (depositItem, {'equity_balance_port', easygetter.EvenAmountToDouble(orderVolumeRisk:getEquityBalance())})
    table.insert (depositItem, {'buy_limit', easygetter.EvenAmountToDouble(orderVolumeRisk:getCreditLimit())})
    table.insert (depositItem, {'cash_balance_prev', easygetter.EvenAmountToDouble(orderVolumeRisk:getCashBalance()) })
    table.insert (depositItem, {'excess_equity_bal_expected', easygetter.EvenAmountToDouble(orderVolumeRisk:getExpectedExcessEquityBalance())})
    table.insert (depositItem, {'excess_equity',easygetter.EvenAmountToDouble(orderVolumeRisk:getExcessEquityBalance()) })
    table.insert (depositItem, {'excess_equity_bal_port',easygetter.EvenAmountToDouble(orderVolumeRisk:getExcessEquityBalance()) })
    table.insert (depositItem, {'unreal_pl_port', easygetter.EvenAmountToDouble(orderVolumeRisk:getTotalFutureUPLGross())+easygetter.EvenAmountToDouble(orderVolumeRisk:getTotalOptionUPLGross())})
    table.insert (depositItem, {'magin_bal_expected', easygetter.EvenAmountToDouble(orderVolumeRisk:getExpectedMargin())})
    table.insert (depositItem, {'magin_bal_port', easygetter.EvenAmountToDouble(orderVolumeRisk:getExpectedMargin())-easygetter.EvenAmountToDouble(orderVolumeRisk:getOrderMargin())})
    table.insert (depositItem, {'call_force_flag_expected', CallForceMapping[orderVolumeRisk:getCallForce()]})
    table.insert (depositItem, {'call_force_flag_port',CallForceMapping[orderVolumeRisk:getCallForce()] })
    table.insert (depositItem, {'call_force_amount_expected', easygetter.EvenAmountToDouble(orderVolumeRisk:getForceMargin())+easygetter.EvenAmountToDouble(orderVolumeRisk:getOrderMargin())})
    table.insert (depositItem, {'call_force_amount_port',easygetter.EvenAmountToDouble(orderVolumeRisk:getForceMargin()) })
  end

  local depositList = {}
  table.insert (depositList, depositItem)

  --common.print_table(depositList)
  common.InsertRecords(db_file, log_file, table_name_deposit, depositList, debug_mode)

-------------------------------------------------------------------------------------
  local orders = easygetter.GetOrders( depositId, entryFrom, entryTo )

  local orderList = {}
  local orderItem = {}

  local have_get_trade_settlement_day = false

  for _,no in pairs( orders ) do
    local order = fo.Order( no )

    local orderHandlingType = order:getHandlingType()
    if (orderHandlingType == 'TradingOrder' or orderHandlingType == 'BlockTrade') then
      local orderlegs = order:getOrderLegs()

      local service_type = order:hasTradingChannel()
      if (service_type == true ) then
        table.insert (orderItem, {'service_type',order:getTradingChannel():getName()})
      end

      for i = 1, order:getNumberLegs() do
        orderItem = {}
        local orderLeg = orderlegs[i]

        local order_entry_username = order:getEntryUser():getName()    -- User Role Name in DECIDE GUI. Will be a name in Thai
        table.insert (orderItem, {'order_entry_username', order_entry_username})

        local order_entry_time = tostring(order:getEntryTime())   -- YYYY-MM-DDTHH:mm:ss
        local idx_start = string.find(order_entry_time,"T") + 1
        local idx_end = string.len(order_entry_time)
        order_entry_time = string.sub(order_entry_time, idx_start, idx_end)
        table.insert (orderItem, {'order_entry_time', order_entry_time})

        local order_id = order:getOrderId()
        table.insert (orderItem, {'order_no', order_id})

        local instrument = orderLeg:getContract():getContractCode()
        table.insert (orderItem, {'INSTRUMENT', instrument})

        local buy_sell = common.BuySellToBSMapping[orderLeg:getOrderKind()]
        table.insert (orderItem, {'buy_sell', buy_sell})

        local position = orderLeg:getOpenClose()
        table.insert (orderItem, {'pos', position})

        local order_price_limit = tostring(orderLeg:getPriceLimit())
        local order_limit_type = tostring(order:getOrderLimitType())
        if (order_limit_type == "Limit") then
          table.insert (orderItem, {'price', order_price_limit})
        else
          table.insert (orderItem, {'price', order_limit_type})
        end

        table.insert (orderItem, {'status', M.getStatus(order:getOrderId())})

        table.insert (orderItem, {'published', orderLeg:getPeakQty()})

        local qty = orderLeg:getTotalQty()      -- Total Quantity
        table.insert (orderItem, {'vol', qty})

        local match_qty = orderLeg:getExecQty()     -- Matched Quantity
        table.insert (orderItem, {'match_vol', match_qty})
        if (match_qty ~= 0 ) then
          local match_avg_price =  orderLeg:getAvgExecPrice()
          table.insert (orderItem, {'match_price', match_avg_price })
        end

---------------------------------- TO BE REMOVED ------------------------------------------------------------------------------------------------

        table.insert (orderItem, {'unmatched_qty', qty - match_qty })

        local tradeDate = order:getEntryTime():getDateInUtcOffset(offsetTimeZoneSecs):toString("%d/%m/%Y")
        table.insert (orderItem, {'trade_date', tradeDate})

        local cdate = common.GetSettlementDateFromOrder(order);
        if( cdate ~= nil) then
          table.insert (orderItem, {'settlement_date', cdate:toString("%d/%m/%Y")})
          if( have_get_trade_settlement_day == false) then
            table.insert (depositItem, {'trade_date', tradeDate})
            have_get_trade_settlement_day = true
          end
        end

--------------------------------------------------------------------------------------------------------------------------------------------------------

        table.insert (orderList, orderItem)
      end
    end
  end

  table.insert (depositList, depositItem)

  common.InsertRecords(db_file, log_file, table_name_order, orderList, debug_mode)
  --common.InsertRecords(db_file, log_file, table_name_deposit, depositList, debug_mode)
  --common.InsertRecords(db_file, log_file, table_name_order, orderList, debug_mode)
end
local inst = os.getenv( "OCSINST" )
local mand = mandator.Mandator( inst )
mandator.changeTo( mand, process )