-- Last Modified Date: 20140612-01
require "ocs"

local cmdln = require "cmdline"
local fo = require "fo"
local tim = require "tim"
local maps = require "maps"
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
--cmdln.add{ name="--format", descr="", func=function(x) format=x end }
cmdln.add{ name="--from", descr="", func=function(x) entryFrom=x end }
cmdln.add{ name="--to", descr="",  func=function(x) entryTo=x end }

cmdln.parse( arg, true )
print("depositId: "..depositId, "|entryFrom: "..entryFrom, "|entryTo: "..entryTo, "|log_file: "..log_file, "|log_file: "..log_file, "|db_file: "..db_file, "|format: "..format)

ocs.createInstance( "LUA" )
local function process()
  local dubi = require "dubi"
  --self defined common module
  local common = require "common"
  local easygetter = require "easygetter"
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

    {table_name_order, { 'cdate'..sql_column_text,
              'series'..sql_column_text,
              'long_short'..sql_column_text,
              'pos'..sql_column_text,
              'vol'..sql_column_integer,
              'price'..sql_column_real,
              'total_value'..sql_column_real,
              'match_vol'..sql_column_integer,
              'match_price'..sql_column_real,
              'matched_value'..sql_column_real,
              'open_vol'..sql_column_integer,
              'open_value'..sql_column_real,
              'cancel_qty'..sql_column_integer,
              'cancel_value'..sql_column_real,
              'multiplier'..sql_column_integer,
              'cont_size'..sql_column_real,
              'amount'..sql_column_real,
              'comm_vat'..sql_column_real,
              'net'..sql_column_real}}

  }

  common.CreateTables(db_file, log_file,  database_tables, debug_mode)

  local DECIDE_deposit_obj = fo.Deposit( tonumber(depositId) )

  if ( DECIDE_deposit_obj == nil ) then
    confirmreport.announceGenerationFailure("Deposit "..depositId.." is not exist in DEICDE. Please contact Customer Service Team for information.")
    print("Deposit "..depositId.." is not exist in DEICDE. Please contact Customer Service Team for information.")
    -- exit with 100 will not send email to notify user
    os.exit(100)
  end

  local depositItem = {}
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


  local client_obj = DECIDE_deposit_obj:getClient()
  table.insert (depositItem, {'client_name', client_obj:getName()})

  if( client_obj:hasAccountManager() ) then
    local account_manager = client_obj:getAccountManager()
    local trader_id = dubi.getSETTraderId( account_manager:getShortName())
    if( trader_id ~= nil) then
      -- ** pending to dev for multiple exchange
      table.insert (depositItem, {'trader_id', trader_id })
    end
    table.insert (depositItem, {'trader_name', account_manager:getName()})
  end

  if( client_obj:hasClientType() ) then
    table.insert (depositItem, {'cust_type', client_obj:getClientType():getName()})
  end

  local clientFeeCategories = client_obj:getClientFeeCategories()
  for _, category in pairs(clientFeeCategories) do
    local categoryName = category:getName()
    local whtPos = string.find( categoryName, "WHT" )
    if ( whtPos ~= nil) then
      table.insert (depositItem, {'withholding_tax', string.sub(categoryName, whtPos+4, -2) })
      -- should be only configured one WHT, so if founded, should quit loop
      break
    end
  end

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
    table.insert (depositItem, {'unreal_pl_prev', easygetter.EvenAmountToDouble(orderVolLimit:getPreviousFutureUPL())+ easygetter.EvenAmountToDouble(orderVolLimit:getPreviousOptionM2M())})
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
    table.insert (depositItem, {'unreal_pl_expected', easygetter.EvenAmountToDouble(orderVolumeRisk:getTotalFutureUPLGross())+easygetter.EvenAmountToDouble(orderVolumeRisk:getTotalOptionM2M())})
    table.insert (depositItem, {'unreal_pl_port', easygetter.EvenAmountToDouble(orderVolumeRisk:getTotalFutureUPLGross())+easygetter.EvenAmountToDouble(orderVolumeRisk:getTotalOptionM2M())})
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

  local orders = easygetter.GetOrders( depositId, entryFrom, entryTo )

  local orderList = {}
  local seriesNumberList = {}
  local hasOpenOrder = false
  local hasCloseOrder = false

  for _,no in pairs( orders ) do
    local order = fo.Order( no )


    local orderHandlingType = order:getHandlingType()
    if (orderHandlingType == 'TradingOrder' or orderHandlingType == 'BlockTrade') then
      local orderlegs = order:getOrderLegs()
      for _,orderLeg in pairs(orderlegs) do
        local orderItem = {}
        
            
    local positions = order:getDeposit():getPortfolio():getPositions()
      for _,po in ipairs(positions) do 
          local pe = fo.PositionEvaluation { position=po }
                 table.insert(orderItem,{'amount',pe:getAvgePrice()})
                 end

        
        
        
        local cdate = common.GetSettlementDateFromOrder(order)
        local series = orderLeg:getContract():getContractCode()
        seriesNumberList[series] = series
        table.insert (orderItem, {'series', series})

        local LongShort = common.BuySellToLSMapping[orderLeg:getOrderKind()] or ''
        table.insert (orderItem, {'long_short', LongShort})

        local position_obj = orderLeg:getOpenClose()
        table.insert (orderItem, {'pos', position_obj})

        local total_qty = orderLeg:getTotalQty()

        ---------------------------------------------------------------------------

        ---------------------------------------------------------------------------
        -- **pending pdv to solve the bug in found in CNS-3, drop copy order doesn't have validation quote
        local validation_quote = easygetter.EvenAmountToDouble(orderLeg:getValidationQuote())

        -- Use current day for tickfactor for open, total value.
        local tick_factor = easygetter.EvenAmountToDouble(orderLeg:getContract():getTickFactor(nil,tim.Date.current()))

        local open_qty = orderLeg:getOpenQty()
        table.insert (orderItem, {'open_vol', orderLeg:getOpenQty()})
        local open_value = open_qty*validation_quote*tick_factor
        table.insert (orderItem, {'open_value', open_value })

        local cancel_value = 0
        local cancel_qty = 0
        -- BA to confirm whether need to include the expire order as cancel qty
        if(order:getStatus() == "Closed" and
          (order:getOrderClosedBy()=="PartExecCancel" or order:getOrderClosedBy()=="NoExecCancel" ) ) then
          cancel_qty = orderLeg:getTotalQty()-orderLeg:getExecQty()
          table.insert (orderItem, {'cancel_qty', cancel_qty})
          cancel_value = cancel_qty*validation_quote*tick_factor
          table.insert (orderItem, {'cancel_value', cancel_value})
        end

        local match_qty = orderLeg:getExecQty()
        table.insert (orderItem, {'match_vol', match_qty})

        tick_factor = 1
        local match_avg_price = 0
        local matched_value = 0
        if (match_qty ~= 0) then
          -- Use value day for tickfactor for matched value.
          if ( cdate ~= nil ) then
            tick_factor = easygetter.EvenAmountToDouble(orderLeg:getContract():getTickFactor(nil,cdate))
          end
          match_avg_price = orderLeg:getAvgExecPrice()
          matched_value = match_qty*match_avg_price*tick_factor
        end
        table.insert (orderItem, {'match_price', match_avg_price })
        table.insert (orderItem, {'matched_value', matched_value})
        table.insert (orderItem, {'multiplier', tick_factor})

        -- total qty = matched qty + open/cancel qty
        -- total value = matched value + open/cancel value
        table.insert (orderItem, {'vol', match_qty + open_qty + cancel_qty})
        table.insert (orderItem, {'total_value', matched_value + open_value + cancel_value})

        local cont_size = 0
        local comm_vat = 0
        local net = 0
        for _,op in pairs( order:getOrderOperations() ) do
          if op:getTransactionType() == "Match" then
            local oplegs = op:getOrderOperationLegs()
            if (#oplegs ~= 1) then
              confirmreport.announceGenerationFailure("One order operation should and only should have one order opeation legs!")
              print("One order operation should and only should have one order opeation legs!")
              os.exit(1)
            elseif(oplegs[1]:getContract():getContractCode() == orderLeg:getContract():getContractCode()) then
              local price = 0;
              opleg = oplegs[1]
              price = opleg:getPrice();
              table.insert (orderItem, {'price', price})
              if (opleg:hasTransaction()) then
                local ta = opleg:getEffectiveTransaction()
                local posting = fo.Posting(ta,1)
                cdate = ta:getBusinessDate()
                table.insert (orderItem, {'cdate', cdate:toString("%d/%m/%Y")})
                cont_size = cont_size + easygetter.EvenAmountToDouble(posting:getTurnoverAccountCurrGross())
                if (posting:hasFeeValue(nil,maps.NameToFee("Custodian")) ) then
                  local comm = easygetter.EvenAmountToDouble(posting:getFeeAccountCurr(nil,maps.NameToFee("Custodian")))
                  local vat = easygetter.EvenAmountToDouble(posting:getFeeAccountCurr(nil,maps.NameToFee("Settlement")))
                  comm_vat = comm_vat + comm + vat
                end
                net = net + easygetter.EvenAmountToDouble(posting:getTurnoverAccountCurrNet())
              end
            end
          end
        end

        table.insert (orderItem, {'cont_size', cont_size})
        table.insert (orderItem, {'comm_vat', comm_vat})
        table.insert (orderItem, {'net', net})

        if (position == "Open") then
          hasOpenOrder = true
        elseif (position == "Close") then
          hasCloseOrder = true
        end

        table.insert (orderList, orderItem)
      end

    end
  end

  common.InsertRecords(db_file, log_file, table_name_order, orderList, debug_mode)

end
local inst = os.getenv( "OCSINST" )
local mand = mandator.Mandator( inst )
mandator.changeTo( mand, process )