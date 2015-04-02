TSCReportUtil={}
function TSCReportUtil.getOrderList(orders)
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

return TSCReportUtil
