//+------------------------------------------------------------------+
//|                                    Volatilidade_RSI_2_EMA_11.mq5 |
//|                                         Lucas, Eudes e Alexandre |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Lucas, Eudes e Alexandre"
#property link      "https://www.mql5.com"
#property version   "1.05"

#include <Trade/Trade.mqh>
#include <Math/Stat/Math.mqh>

CTrade trade;

MqlDateTime dateTimeStructure;

enum ENUM_TARGET
{
   ET20     =  20,      // R$ 20,00
   ET30     =  30,      // R$ 30,00
   ET40     =  40,      // R$ 40,00
   ET50     =  50,      // R$ 50,00
   ET60     =  60,      // R$ 60,00
   ET70     =  70,      // R$ 70,00
   ET80     =  80,      // R$ 80,00
   ET90     =  90,      // R$ 90,00
   ET100    =  100,     // R$ 100,00
   ET110    =  110,     // R$ 110,00
   ET120    =  120,     // R$ 120,00
   ET130    =  130,     // R$ 130,00
   ET140    =  140,     // R$ 140,00
   ET150    =  150,     // R$ 150,00
   ET160    =  160,     // R$ 160,00
   ET170    =  170,     // R$ 170,00
   ET180    =  180,     // R$ 180,00
   ET190    =  190,     // R$ 190,00
   ET200    =  200,     // R$ 200,00
   ET300    =  300,     // R$ 300,00
   ET400    =  400,     // R$ 400,00
   ET500    =  500,     // R$ 500,00
   ETMax    =  100000,  // R$ 100.000,00
};

input string        inpStartHour      = "9:15";            // Horário de Início
input string        inpEndHour        = "14:00";           // Horário de encerramento
input int           inpRSI_Period     = 2;                 // Período do RSI
input int           inpEMA            = 11;                // Período da média
input int           inpRSI_BuyLevel   = 5;                 // Mínima do RSI
input int           inpRSI_SellLevel  = 95;                // Máxima do RSI
input int           inpVolume         = 1;                 // Volume
input ENUM_TARGET   inpDailyTarget    = ET50;              // Alvo diário por papel      
input double        inpTP             = 700;               // Take Profit
input double        inpSL             = 500;               // Stop Loss
input bool          monday            = true;              // Operar segunda-feira
input bool          tuesday           = true;              // Operar terça-feira
input bool          wednesday         = true;              // Operar quarta-feira
input bool          thursday          = true;              // Operar quinta-feira
input bool          friday            = true;              // Operar sexta-feira


datetime       lastTradeTime     = 0;
bool           buy               = false;
bool           sell              = false;
bool           mailSent          = false;  
datetime       closeTradeTime    = 0;
datetime       startTime         = StringToTime(inpStartHour)  %  86400;
datetime       endTime           = StringToTime(inpEndHour)    %  86400;
int            hndRSI            = 0;
int            hndMA             = 0;
int            customMA          = 0;
double         dailyResult       = 0;
double         rsi[];
double         ma[];
double         openTradePoint;
int            lDelta = 1;
double         pointsSL;
double         pointsTP;
double         pointsTarget;
datetime       lastCandleTime;
long           expertAdvisorID = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   pointsSL     = inpSL * Point();
   pointsTP     = inpTP * Point();
   pointsTarget = inpDailyTarget * Point();
   
   ArraySetAsSeries(rsi,true);
   ArraySetAsSeries(ma, true);

//---
   hndRSI = iRSI(_Symbol, _Period, inpRSI_Period, PRICE_CLOSE);
   hndMA  = iMA (_Symbol, _Period, inpEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   if(hndMA == INVALID_HANDLE || hndRSI == INVALID_HANDLE)
   {
      Print("iRSI / iMA failed! Error: ", GetLastError());
      return(INIT_FAILED);
   }
   
   
   ObjectCreate      (0,"target_",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"target_",OBJPROP_TEXT, "R$ " + IntegerToString(inpDailyTarget) + 
                        " x " + IntegerToString(inpVolume) + (inpVolume > 1 ? " papéis" : " papel") );
   ObjectSetInteger  (0,"target_",OBJPROP_COLOR, clrBlue);
   ObjectSetInteger  (0,"target_",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"target_",OBJPROP_YDISTANCE, 20);
   ObjectSetInteger  (0,"target_",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"target_",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);   

   ObjectCreate      (0,"target",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"target",OBJPROP_TEXT, "Alvo: R$ " + IntegerToString(inpVolume * inpDailyTarget));
   ObjectSetInteger  (0,"target",OBJPROP_COLOR, clrBlue);
   ObjectSetInteger  (0,"target",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"target",OBJPROP_YDISTANCE, 40);
   ObjectSetInteger  (0,"target",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"target",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   

   ObjectCreate      (0,"result",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"result",OBJPROP_TEXT, "Resultado: R$" + DoubleToString(dailyResult,2));
   ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"result",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"result",OBJPROP_YDISTANCE, 5);
   ObjectSetInteger  (0,"result",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger  (0,"result",OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);   

   lastCandleTime = 0;

  //---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---

   ObjectDelete(0,"target");
   ObjectDelete(0,"result");
   
   IndicatorRelease(hndMA);
   IndicatorRelease(hndRSI);
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   datetime currentTime = TimeCurrent() % 86400;
   double lresult       = 0.0;
   
   ObjectSetString(0, "result",  OBJPROP_TEXT, "Resultado: R$ " + DoubleToString(dailyResult, 2));
   
   TimeCurrent(dateTimeStructure);
   if((dateTimeStructure.day_of_week == MONDAY     && !monday)    || 
      (dateTimeStructure.day_of_week == TUESDAY    && !tuesday)   || 
      (dateTimeStructure.day_of_week == WEDNESDAY  && !wednesday) || 
      (dateTimeStructure.day_of_week == THURSDAY   && !thursday)  || 
      (dateTimeStructure.day_of_week == FRIDAY     && !friday))
   {    
      return;
   }
   
   // current time is less than or equal to the start time
   if( currentTime <= startTime )
   {
      dailyResult = 0;
      ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrBlack);
      return;
   }
   
   int positions = PositionsTotal();

   // current time is greater than or equal to the closing time or the gain is greater than or equal to the daily target 
   if(currentTime >= endTime || dailyResult >= (inpDailyTarget * inpVolume))
   {
        if(positions > 0)
            trade.PositionClose(_Symbol);
        if (!mailSent)
        {
            SendMail("Meta Trader: Resultado diário","O total de trades de hoje resultou em R$ "+DoubleToString(dailyResult,2)+" bruto.");
            mailSent = true;
        }

        buy = false;
        sell = false;

        return;
   }
   
   // if can't copy the RSI buffer
   if (CopyBuffer(hndRSI,0,0,2,rsi) < 0 || CopyBuffer(hndMA,0,0,2,ma) < 0)
   {
      Print("Erro ao tentar copiar os buffers RSI / MA: ", GetLastError());
      return;
   }
   
   // iClose returns the Close price of the bar (indicated by the 'shift' parameter) on the corresponding chart.
   double closePrice = iClose(_Symbol,_Period,1);

   MqlTick lastTick;
   if(!SymbolInfoTick(_Symbol,lastTick)) 
   {
      Print("Erro ao tentar o último tick: ", GetLastError());
      return;
   }

   if(positions == 0)
   {
      // when the stop was executed or the position was closed manually
      if(buy || sell)
      {
         if(buy)
         {
            buy = false;
         }
         if(sell)
         {
            sell = false;
         }
         IsNewCandle();
         lresult = result(currentTime,expertAdvisorID);
      }
      
      else
      {
         //buy: the rsi is below the lowest level
         if(rsi[0] < inpRSI_BuyLevel)
         {
            if(IsNewCandle())
            {
               trade.Buy(inpVolume,_Symbol,lastTick.ask, lastTick.ask - pointsSL, lastTick.ask + pointsTP);
               expertAdvisorID = HistoryDealGetInteger(HistoryDealsTotal() - 1, DEAL_MAGIC);
               lastTradeTime  = TimeCurrent();
               closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
               buy = true;
            }
         }
         else
         //sell: the rsi is above the highest level
         if(rsi[0] > inpRSI_SellLevel)
         {
            if(IsNewCandle())
            {
               trade.Sell(inpVolume,_Symbol,lastTick.bid, lastTick.bid + pointsSL, lastTick.bid - pointsTP);
               expertAdvisorID = HistoryDealGetInteger(HistoryDealsTotal() - 1, DEAL_MAGIC);
               lastTradeTime  = TimeCurrent();
               closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
               sell = true;
            }
         }
      }
   }
      
   else
   {
   // when the candle closes above the average
      if(TimeCurrent() > closeTradeTime)
      {
         if(buy && closePrice >= ma[1])
         {
            trade.PositionClose(_Symbol);
            buy = false;   
            lresult = result(currentTime,expertAdvisorID);
         } 
         // when the candle closes below the average
         if(sell && closePrice <= ma[1])
         {
            trade.PositionClose(_Symbol);
            sell = false;   
            lresult = result(currentTime,expertAdvisorID);
         }
      }
   }
   
   if(lresult != 0)
   {
      dailyResult = lresult;
      
      if(dailyResult < 0 )  ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrRed);
      else                  ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrGreen);
   }
}
 
//+------------------------------------------------------------------+
bool IsNewCandle()
{
   datetime time[];
   
   if(CopyTime(Symbol(), Period(), 0, 1, time) < 1)
      return false;
   
   if(time[0] == lastCandleTime)
      return false;
   
   lastCandleTime = time[0];

   return true;
}

// Return the result at the day
double result(datetime currentTime, long xpAdvID)
{
 double res       = 0;
 datetime today   = TimeCurrent() - currentTime;

 if (HistorySelect(today, TimeCurrent())){
   int totalDeals = HistoryDealsTotal() - 1;
   for (int i = totalDeals; i >= 0; i--)
   {
     const ulong ticket = HistoryDealGetTicket(i);
     
     if((HistoryDealGetInteger(ticket, DEAL_MAGIC) == xpAdvID) && (HistoryDealGetString(ticket, DEAL_SYMBOL) == Symbol()))
       res += HistoryDealGetDouble(ticket, DEAL_PROFIT);
   }
 }
     
  return(res);
}