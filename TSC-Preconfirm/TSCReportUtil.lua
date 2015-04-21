TSCReportUtil={}
function TSCReportUtil.getOrderList(orders,isBillOrder)
	print('----------- Start getOrderList--------')
  local orderMatchStatusToMLMapping = {[true]="M", [false]="P"}
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
        print('order_num : ',no)
        print('match_qty : ',match_qty)
        
        if (match_qty~=0 or isBillOrder==1 ) then	
          local orderItem = {}
          local vol=0
          local price=0
          local symbol= fo.getOrderContract(order):getSymbol() 
          local buy_sell = order:getBuySell()
          local execQty = orderleg:getExecQty()
          local status = orderMatchStatusToMLMapping[totalQty == execQty]
          
          if (isBillOrder==1) then
            local entry=order:getEntryUser():getName()
						print(" Entry :" .. entry)
						vol = orderleg:getTotalQty()
            price = orderleg:getPriceLimit()
            time =order:getEntryTime():getClockTimeInUtcOffset(common.offsetTimeZoneSecs):toString("%T") 
            local totalQty = orderleg:getOpenQty()
            if (match_qty~= 0 ) then
              table.insert (orderItem, {'match_price',execQty })
              table.insert(orderItem,{'match_qty',match_qty})
              table.insert(orderItem,{'matched',match_qty})
            end
						table.insert(orderItem,{'entry',entry})
            table.insert(orderItem,{'time',time})
            table.insert(orderItem, {'st', M.getStatus(order:getOrderId())})
          else
            price = orderleg:getAvgExecPrice()
            price = easygetter.EvenAmountToDouble(price)
            vol = execQty
          end

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
          table.insert (orderItem,{'stock',symbol})
          table.insert (orderItem,{'side',buy_sell})
          table.insert (orderItem,{'vol',vol})
          table.insert (orderItem,{'comm_fee',comm_fee})
          table.insert (orderItem,{'vat',vat})
          table.insert (orderItem,{'price',price})
          table.insert (orderItem,{'gross_amt',gross_amt})
          table.insert (orderItem,{'amount_due',amount_due})
          table.insert(orderList,orderItem)
        end
      end
    end
  end
  if (net<0) then
    paid_received = "Paid " 
  else
    paid_received = "Received " 
  end
  table.insert(totalItem,{'net',net})
  table.insert(totalItem,{'paid_received',paid_received})
  --table.insert(totalItem,{'comm',total_comm_fee})
  --table.insert(totalItem,{'vat',vat})
	--table.insert(totalList,{'total_comm_fee',total_comm_fee})
	--table.insert(totalList,{'total_vat',total_vat})
	table.insert(totalList,totalItem)
	--print('totalList : ',dump(totalList))
	print('----------- End getOrderList--------')
	return orderList,totalList
end

local hasLimitValue = function(limittype)
  local list = {
    Limit = true,
    LimitIceberg = true,
    OrMarketOnClose = true,
    OneCancelsOtherL = true,
    OneCancelsOtherM = true
  }
  return list[limittype]
end

return TSCReportUtil
