//+------------------------------------------------------------------+
//|                                                           ax.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#define EXPERT_MAGIC 20211003
//--- input
input ENUM_TIMEFRAMES TRADE_TF = PERIOD_H1;
input int RSI_PERIOD           = 14;
input int MA_PERIOD            = 50;
ulong TICKETS[];
int iRSI_HANDLE;
int iMA_HANDLE;

//+------------------------------------------------------------------+
//| Opening Buy position                                             |
//+------------------------------------------------------------------+
ulong OpeningBuy(string symbol, double volume, ulong magic) {	
	MqlTradeRequest request = {};
	MqlTradeResult  result  = {};
	//--- zeroing the request and result values
   ZeroMemory(request);
   ZeroMemory(result);
	request.action    = TRADE_ACTION_DEAL;
	request.symbol    = symbol;
	request.volume    = volume;
	request.type      = ORDER_TYPE_BUY;
	request.price     = SymbolInfoDouble(symbol, SYMBOL_ASK);
	request.deviation = 5;
	request.magic     = magic;
	//--- send the request
	if(!OrderSend(request,result)) { 
		PrintFormat("OrderSend error %d",GetLastError());
		return 0;
	}
	//--- information about the operation
   PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   return result.order;
}
//+------------------------------------------------------------------+
//| Opening Sell position                                            |
//+------------------------------------------------------------------+
ulong OpeningSell(string symbol, double volume, ulong magic) {
	MqlTradeRequest request = {};
	MqlTradeResult  result  = {};
	//--- zeroing the request and result values
   ZeroMemory(request);
   ZeroMemory(result);
   request.action    = TRADE_ACTION_DEAL;
	request.symbol    = symbol;
	request.volume    = volume;
	request.type      = ORDER_TYPE_SELL;
	request.price     = SymbolInfoDouble(symbol, SYMBOL_BID);
	request.deviation = 5;
	request.magic     = magic;
	//--- send the request
	if(!OrderSend(request,result)) { 
		PrintFormat("OrderSend error %d",GetLastError());
		return 0;
	}
	//--- information about the operation
   PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   return result.order;
}
//+------------------------------------------------------------------+
//| Closing Buy position                                             |
//+------------------------------------------------------------------+
ulong ClosingByTicket(ulong ticket) {
	MqlTradeRequest request = {};
	MqlTradeResult  result  = {};
	//--- zeroing the request and result values
   ZeroMemory(request);
   ZeroMemory(result);
	string position_symbol = PositionGetString(POSITION_SYMBOL);
	if(PositionSelectByTicket(ticket)) {
		request.action          = TRADE_ACTION_DEAL;
		request.position        = ticket;
		request.symbol          = position_symbol;
		request.volume          = PositionGetDouble(POSITION_VOLUME);
		request.deviation       = 5;
		request.magic           = PositionGetInteger(POSITION_MAGIC);
		ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
		if(type == POSITION_TYPE_BUY) {
			request.price        = SymbolInfoDouble(position_symbol, SYMBOL_BID);
			request.type         = ORDER_TYPE_SELL;
		}else {
			request.price        = SymbolInfoDouble(position_symbol, SYMBOL_ASK);
			request.type         = ORDER_TYPE_BUY;
		}
		if(!OrderSend(request,result)) {
			PrintFormat("OrderSend error %d",GetLastError());
			return 0;
		}   
      //--- information about the operation   
      PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
      return result.order;
	}
	return 0;
}
//+------------------------------------------------------------------+
//| get order ticket function                                        |
//+------------------------------------------------------------------+
bool GetOrderTickets(ulong& tickets[]) { return(GetOrderTickets(tickets, _Symbol, EXPERT_MAGIC)); }
bool GetOrderTickets(ulong& tickets[], string symbol) {
   uint counter = 0;
   uint ticket_counter = 0;
   int total = PositionsTotal();
   for(int i = 0;i < total;i++) {
      if(PositionSelect(symbol)) {
         counter++;
         ArrayResize(tickets, counter);
         tickets[ticket_counter] = PositionGetInteger(POSITION_TICKET);     
         ticket_counter++;
      }
   }
	if(ArraySize(tickets) > 0) { return true; }
   return false;
}
bool GetOrderTickets(ulong& tickets[], string symbol, int magic_number) {
   uint counter = 0;
   uint ticket_counter = 0;   
   int total = PositionsTotal();
   for(int i = 0;i < total;i++) {
      if(PositionSelect(symbol)) {         
         if(PositionGetInteger(POSITION_MAGIC)) {            
            counter++;
            ArrayResize(tickets, counter);
            tickets[ticket_counter] = PositionGetInteger(POSITION_TICKET);     
            ticket_counter++;
         }
      }
   }
   if(ArraySize(tickets) > 0) { return true; }
   return false;
}
//+------------------------------------------------------------------+
//| get ma info function                                             |
//+------------------------------------------------------------------+
bool GetMAInfo(double& iMA_buffer[], int buffer_num, int start_pos, int count) {
	if(CopyBuffer(iMA_HANDLE, buffer_num, start_pos, count, iMA_buffer) != count) {
		Print("CopyBuffer from iMA failed, no data");
		return false;
	}
	return true;
}
//+------------------------------------------------------------------+
//| get rsi info function                                            |
//+------------------------------------------------------------------+
bool GetRSIInfo(double& iRSI_buffer[], int buffer_num, int start_pos, int count) {
	if(CopyBuffer(iRSI_HANDLE, buffer_num, start_pos, count, iRSI_buffer) != count) {
      Print("CopyBuffer from iRSI failed, no data");
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+
//| get rates info function                                          |
//+------------------------------------------------------------------+
bool GetRatesInfo(MqlRates& rates[], ENUM_TIMEFRAMES period, string symbol, int start_pos, int count) {	
	if(CopyRates(symbol, period, start_pos, count, rates) != count) {
      Print("CopyRates of ", symbol," failed, no history");
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+
//| Doji identify function                                           |
//+------------------------------------------------------------------+
int Doji(double open, double high, double low, double close) { return(Doji(open, high, low, close, _Symbol, 0.40)); }
int Doji(double open, double high, double low, double close, string symbol, double dojiBodyPercentage) {
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double dojiBody = ((high - low) / tick_size) * dojiBodyPercentage;
   //--- Dragonfly Doji return 0
   if(((high - close) / tick_size) <= dojiBody && ((high - open) / tick_size) <= dojiBody) return 0;
   //--- Gravestone Doji return 1
   if(((close - low) / tick_size) <= dojiBody && ((open - low) / tick_size) <= dojiBody) return 1;
   return -1;
}
//+------------------------------------------------------------------+
//| Big Black bar identify function                                  |
//+------------------------------------------------------------------+
bool IsBigBlackBar(double open, double high, double low, double close) { return(IsBigBlackBar(open, high, low, close, _Symbol, 0.20)); }
bool IsBigBlackBar(double open, double high, double low, double close, string symbol, double candleWickPercentage) {
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double candleWick = ((high - low) / tick_size) * candleWickPercentage;   
   if(((high - close) / tick_size) <= candleWick && ((open - low) / tick_size) <= candleWick){
      return true;
   }else if(((close - low) / tick_size) <= candleWick && ((high - open) / tick_size) <= candleWick){
      return true;
   }
   return false;   
}
//+------------------------------------------------------------------+
//| Check for open order                                             |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE CheckForOpen(double ma, double rsi, double open, double high, double low, double close, int overbought, int oversold) {
   if(IsBigBlackBar(open, high, low, close)) {
      if(open > ma && close > open && rsi <= overbought) {         
         return ORDER_TYPE_BUY;
      }else if(open < ma && close < open && rsi >= oversold) {
         return ORDER_TYPE_SELL;
      }
   }else {
   	int doji = Doji(open, high, low, close);
      if(doji == 0 && low > ma && rsi < overbought) {         
         return ORDER_TYPE_BUY;
      }else if(doji == 1 && high < ma && rsi > oversold) {         
         return ORDER_TYPE_SELL;
      }
   }
   return -1;
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
	//--- RSI indicator
	iRSI_HANDLE = iRSI(_Symbol, TRADE_TF, RSI_PERIOD, PRICE_CLOSE);   
   if(iRSI_HANDLE==INVALID_HANDLE) {
      printf("Error creating iRSI indicator");
      return(INIT_FAILED);
   }
   //--- MA indicator
   iMA_HANDLE = iMA(_Symbol, TRADE_TF, MA_PERIOD, 0, MODE_SMA, PRICE_CLOSE);
   if(iMA_HANDLE == INVALID_HANDLE) {
   	printf("Error creating iMA indicator");
   	return(INIT_FAILED);
   }
	//GetOrderTickets(TICKETS, _Symbol);
	//printf("%d", TICKETS[0]);
	//if(ArraySize(TICKETS) > 0) {
	//	ulong close_ticket = ClosingByTicket(TICKETS[0]);
	//	if(close_ticket > 0) {
	//		printf("Closed : %d", close_ticket);
	//	}
	//}
	//ulong open_ticket = OpeningBuy(_Symbol, 0.01, EXPERT_MAGIC);
	//if(open_ticket > 0) {
	//	printf("[Buy] : %d", open_ticket);
	//}else {
	//	printf("Opening error: ");
	//}		
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
	//---
   MqlRates rt[];
	double   rsi[];
	double   ma[];
	ArraySetAsSeries(rt, true);
	ArraySetAsSeries(rsi, true);
	ArraySetAsSeries(ma, true);
	
	GetRatesInfo(rt, TRADE_TF, _Symbol, 0, 2);
	//--- go trading only for first ticks of new bar   
   if(rt[0].tick_volume > 1) { return; }
      
   GetRSIInfo(rsi, 0, 0, 2);
   GetMAInfo(ma, 0, 0, 2);
   //printf("rsi: %.2f ma: %.3f volume: %d", rsi[2],ma[0], rt[2].tick_volume);
   ENUM_ORDER_TYPE ot_open = CheckForOpen(ma[1], rsi[1], rt[1].open, rt[1].high, rt[1].low, rt[1].close, 70, 30);
   if(ot_open == ORDER_TYPE_BUY) {
   	OpeningBuy(_Symbol, 0.01, EXPERT_MAGIC);
   }else if(ot_open == ORDER_TYPE_SELL) {
   	OpeningSell(_Symbol, 0.01, EXPERT_MAGIC);
   }
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
