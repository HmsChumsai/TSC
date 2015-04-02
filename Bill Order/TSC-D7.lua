require "ocs"

local cmdln = require "cmdline"
fo = require "fo"
M = require "customOrderData"
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
  local M = require "customOrderData" 
  local dubi = require "dubi"
  local common = require "common"
  local easygetter = require "easygetter"
  local confirmreport = require "confirmreport"
  local debug_mode = false
  local orderMatchStatusToMLMapping = {[true]="M", [false]="P"}
  local TSCReportUtil= require "TSCReportUtil"
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
	--orderList,totalList = getOrderList(orders)
  orderList,totalList = TSCReportUtil.getOrderList(orders,1)
	portList = getPortList()
	database_tables = CreateSchema()
	print('orderList : ',dump(orderList ))
	common.CreateTables(db_file, log_file,  database_tables, debug_mode)
	common.InsertRecords(db_file, log_file, table_name_total, totalList, debug_mode)
	common.InsertRecords(db_file, log_file, table_name_deposit, depositList, debug_mode)
	common.InsertRecords(db_file, log_file, table_name_order, orderList, debug_mode)
	
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
  'buy_limit' .. sql_column_real,
  'credit_limit' .. sql_column_real,
  'credit_type' .. sql_column_text
	}},
  {table_name_order,{
  'side' .. sql_column_text,
  'stock' .. sql_column_text,
  'vol' .. sql_column_integer,
  'price' .. sql_column_real,
  'matched' .. sql_column_integer,
  'st'  ..  sql_column_text,
  'match_qty' .. sql_column_integer,
  'match_price' .. sql_column_real,
  'time' .. sql_column_text,
  'entry' .. sql_column_text,
  'publish' .. sql_column_text,
  'condition' .. sql_column_text,
  'gross_amt' .. sql_column_real,
  'comm_fee' .. sql_column_real,
  'vat' .. sql_column_real,
  'amount_due' .. sql_column_real,
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
