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

-------------------------------------------------------------------------------------
  --local orders = easygetter.GetOrders( depositId, entryFrom, entryTo )

  local options = {}
  options.status = {"A", "B", "C", "E"}
  local orders = dubi.getOrders(options)
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

        local order_entry_username = order:getEntryUser():getName()    -- User Role Name in DECIDE GUI. Will be a name in Thai
        table.insert (orderItem, {'order_entry_username', order_entry_username})

        local order_entry_time = tostring(order:getEntryTime())   -- YYYY-MM-DDTHH:mm:ss
        local idx_start = string.find(order_entry_time,"T") + 1
        local idx_end = string.len(order_entry_time)
        order_entry_time = string.sub(order_entry_time, idx_start, idx_end)
        table.insert (orderItem, {'order_entry_time', order_entry_time})

        local order_id = order:getOrderId()
        table.insert (orderItem, {'order_no', order_id})-------------------------------------------------------------------------------------------------------------------------

        table.insert (orderList, orderItem)
      end
    end
  end

  --table.insert (depositList, depositItem)

  common.InsertRecords(db_file, log_file, table_name_order, orderList, debug_mode)
  --common.InsertRecords(db_file, log_file, table_name_deposit, depositList, debug_mode)
  --common.InsertRecords(db_file, log_file, table_name_order, orderList, debug_mode)
end
local inst = os.getenv( "OCSINST" )
local mand = mandator.Mandator( inst )
mandator.changeTo( mand, process )