require "ocs"

local cmdln = require "cmdline"
local fo = require "fo"
local tim = require "tim"
local maps = require "maps"
local accpos = require "accpos"
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
print("depositId: " .. depositId)
print("entryFrom: " .. entryFrom)
print("entryTo: " .. entryTo)
print("log_file: " .. log_file)
print("db_file: " .. db_file)
print("format: " .. format)

ocs.createInstance( "LUA" )

function process()
  
  local dubi = require "dubi"
  local common = require "common"
  local easygetter = require "easygetter"
  local confirmreport = require "confirmreport"
  local debug_mode = false
  local orderMatchStatusToMLMapping = {[true]="M", [false]="P"}

  --local table_name_deposit = "deposit"
  --local table_name_order = "DECIDE_order"

  common.CheckValidTimeRange(entryFrom, entryTo)

  local database_tables = {}
	
  table_name_deposit = "deposit"
  table_name_order = "DECIDE_order"
  table_name_total = "DECIDE_total"
	table_name_port = "DECIDE_port"
	local depositList = {}
	local orderList = {}
	local totalList = {}
	local portList = {}
	local orders = easygetter.GetOrders( depositId, entryFrom, entryTo )
	
  DECIDE_deposit_obj = fo.Deposit( tonumber(depositId) )
	depositList = getDeposit(depositId)
	orderList,totalList = getOrderList(orders)
	portList = getPortList()
	database_tables = CreateSchema()
	print('orderList : ',dump(orderList ))
	common.CreateTables(db_file, log_file,  database_tables, debug_mode)
	common.InsertRecords(db_file, log_file, table_name_total, totalList, debug_mode)
	common.InsertRecords(db_file, log_file, table_name_deposit, depositList, debug_mode)
	common.InsertRecords(db_file, log_file, table_name_order, orderList, debug_mode)
	common.InsertRecords(db_file, log_file, table_name_port, portList, debug_mode)
	
end

function CreateSchema()
	print('--------------Start CreateSchema() -------------- ')
  print('test local val' .. table_name_deposit)
	local sql_column_text = ' TEXT DEFAULT "" '
  local sql_column_integer = ' INTEGER DEFAULT 0'
  local sql_column_real = ' REAL DEFAULT 0.0'
--  local table_name_deposit = "deposit"
--  local table_name_order = "DECIDE_order"
--  local table_name_total = "DECIDE_total"
  local database_tables = {
  {table_name_deposit,{'account_no' .. sql_column_text,
	'account_name' .. sql_column_text,
	'account_type' .. sql_column_text,
  'trader_name' .. sql_column_text,
  

	}},
  {table_name_order,{
  'side' .. sql_column_text,
  'stock' .. sql_column_text,
  'vol' .. sql_column_integer,
  'price' .. sql_column_real,
  'gross_amt' .. sql_column_real,
  'comm_fee' .. sql_column_real,
  'vat' .. sql_column_real,
  'amount_due' .. sql_column_real,
  }},
	{table_name_port,{
  'stock' .. sql_column_text,
	'tff' .. sql_column_text,
	'pos' .. sql_column_integer,
	'avg_price' .. sql_column_real,
	'mkt_price' .. sql_column_real,
	'amount' .. sql_column_real,
	'mkt_value' .. sql_column_real,
	'pl' .. sql_column_real,
	}},
  {table_name_total,{'comm' ..sql_column_real,
  'net' .. sql_column_real,
  }}
	}
	print ('database_tables : '  ,dump(database_tables))
	print ('----------------- End CreateSchema ---------------') 
  return database_tables
end

function getDeposit(depositId)
	print('----------- Start getDeposit --------')
	local depositItem = {}
	local depositList={}
  table.insert (depositItem, {'account_no', DECIDE_deposit_obj:getNumber()})
  table.insert (depositItem, {'account_name', DECIDE_deposit_obj:getName()})
  if (DECIDE_deposit_obj:hasAccountType()) then
  	table.insert (depositItem, {'account_type', DECIDE_deposit_obj:getAccountType():getName() })
	end
  local client = DECIDE_deposit_obj:getClient()
  if (client:hasAccountManager()) then
    local user = client:getAccountManager()
    local person = user:getPerson()
    local trader_name = person:getName()
    print('trader_name : ' .. trader_name)
    table.insert(depositItem,{'trader_name',trader_name})    
  end
  
	table.insert(depositList,depositItem)


  print('depositList : ',dump(depositList))
	
  print('----------- End getDeposit ---------')
	return depositList
end


function getOrderList(orders)
	print('----------- Start getOrderList--------')
	local orderList= {}
	local totalList={}
	local totalItem={}
  local net=0
	for _,no in pairs(orders) do 
		local order = fo.Order( no )
		local orderHandlingType = order:getHandlingType()
		if (orderHandlingType == 'TradingOrder' or orderHandlingType == 'BlockTrade') then
			local orderlegs = order:getOrderLegs()
			for _,orderleg in pairs(orderlegs) do
				local match_qty = orderleg:getExecQty()
				if (match_qty~=0) then	
					local orderItem = {}
          local symbol= fo.getOrderContract(order):getSymbol() 
					table.insert (orderItem , {'stock',symbol})
					local buy_sell = orderleg:getOrderKind()
					print('buy_sell : ' .. buy_sell)
					table.insert (orderItem,{'side',buy_sell})
          
					local vol = orderleg:getExecQty()
					table.insert (orderItem,{'vol',vol})

					local price = orderleg:getAvgExecPrice()
          price = easygetter.EvenAmountToDouble(price)
					print('price : ',price)
          table.insert (orderItem,{'price',price})

					local comm_fee  = getFee(order,orderleg)
					local vat=0.07*comm_fee
					local gross_amt=vol*price
          local amount_due=0.0

          if (buy_sell=='Buy') then
            amount_due=gross_amt+comm_fee+vat
            net = net-amount_due
          else
            amount_due=gross_amt-comm_fee-vat
            net = net + amount_due
          end
					table.insert (orderItem,{'comm_fee',comm_fee})
					table.insert (orderItem,{'vat',vat})
					table.insert (orderItem,{'gross_amt',gross_amt})
					table.insert (orderItem,{'amount_due',amount_due})

					table.insert(orderList,orderItem)
				end
			end
		end
	end
  if (net<0) then
    net = "Paid"
  else
    net = Received
  end
  table.insert(totalItem,{'net',net})
  --table.insert(totalItem,{'comm',total_comm_fee})
  --table.insert(totalItem,{'vat',vat})
	--table.insert(totalList,{'total_comm_fee',total_comm_fee})
	--table.insert(totalList,{'total_vat',total_vat})
	table.insert(totalList,totalItem)
	print('totalList : ',dump(totalList))
	print('----------- End getOrderList--------')
	return orderList,totalList
end

function getPortList()
	print("----------------- Start getPortList ------------------")
	local portList = {}
	local position_list = DECIDE_deposit_obj:getAccPositions()
	for _,position in pairs ( position_list ) do
		local data = accpos.getPositionValues( position, tim.TimeStamp.current() , tim.TimeStamp.current(), DECIDE_deposit_obj:getGeneralLedgerCurrencyType() )
		
		if ( data.effective == "Yes" ) then
    	--local pos = fo.Position(position)
      local portItem = {}
      local ok, pe = pcall(fo.PositionEvaluation, {
        position = position,
        plview = plview,plrefdate = plref
        })
      local ce = pe:getContractEvaluation()  
      local symbol=ce:getContract():getSymbol() 
      --fo.getOrderContract(order):getSymbol() 
      local contract = position:getContract()
			local stock = contract:getContractCode()
			--local ce = fo.ContractEvaluation{ contract=contract }
			local mkt_price = ce:getLastUnchecked()
			local pos = pe:getQuantity() 
			local avg_price = pe:getAvgePriceNet() 
			local amount=pe:getPosBookValue()
			local mkt_value = pe:getLiqMarketValue()
      local pl = amount-mkt_value
			
			
			---------------------------- Get UPL-------------------
			
--			local orderVolLimit = easygetter.GetFirstActiveOVL(depositId)
--			local orderVolumeRisk = nil
--			if (orderVolLimit ~= nil) then
--				orderVolumeRisk = orderVolLimit:getUniqueRisk()
--				if(orderVolumeRisk ~= nil) then
--					local pl =easygetter.EvenAmountToDouble(orderVolumeRisk:getTotalFutureUPLGross())
--					table.insert(portItem,{'pl',pl})
--				end
--			end
			--------------------------- End UPL--------------------
			table.insert(portItem,{'pos',pos})
      table.insert(portItem,{'stock',symbol})
			table.insert(portItem,{'amount',amount})
			table.insert(portItem,{'mkt_price',mkt_price})
      table.insert(portItem,{'mkt_value',mkt_value})
      table.insert(portItem,{'avg_price',avg_price})
      table.insert(portItem,{'pl',pl})
			table.insert(portList,portItem)
		end
	end
  print("portList : ",dump(portList))
	print("----------------- End getPortList ------------------")
  return portList
end

function getFee(order, orderLeg, ut)
  local fee = 0
	for _, execution in ipairs(order:getEffectiveExecutions(ut)) do
    local leg = execution:getOrderLeg(ut)
    if leg:getOrder() == order and leg:getLegIndex() == orderLeg:getLegIndex() then
      local data = execution:getData(ut)
      fee = fee + math.abs(data.amountp:asDouble() - data.netAmountP:asDouble())
		end
  end
  return fee
end

function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end
local inst = os.getenv( "OCSINST" )
local mand = mandator.Mandator( inst )
mandator.changeTo( mand, process )
