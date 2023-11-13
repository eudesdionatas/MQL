//+------------------------------------------------------------------+
//|                                    Volatilidade_RSI_2_EMA_11.mq5 |
//|                                         Lucas, Eudes e Alexandre |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Lucas, Eudes e Alexandre"
#property link      "https://www.mql5.com"
#property version   "1.04"

#include <Trade/Trade.mqh>
#include <Math/Stat/Math.mqh>

CTrade trade;

MqlDateTime DateTimeStructure;

enum ENUM_TARGET
{
   ET40     =  40,  // R$ 40,00
   ET50     =  50,  // R$ 50,00
   ET60     =  60,  // R$ 60,00
   ET70     =  70,  // R$ 70,00
   ET80     =  80,  // R$ 80,00
   ET90     =  90,  // R$ 90,00
   ET100    =  100, // R$ 100,00
   ET110    =  110, // R$ 110,00
   ET120    =  120, // R$ 120,00
   ET130    =  130, // R$ 130,00
   ET140    =  140, // R$ 140,00
   ET150    =  150, // R$ 150,00
};

input string        inpStartHour      = "9:15";            // Horário de Início
input string        inpEndHour        = "14:00";           // Horário de encerramento
input int           inpRSI_Period     = 2;                 // Período do RSI
input int           inpEMA            = 11;                // Período da média
input int           inpRSI_BuyLevel   = 10;                // Mínima do RSI
input int           inpRSI_SellLevel  = 90;                // Máxima do RSI
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
   double lresult = 0.0;
   
   ObjectSetString(0, "result",  OBJPROP_TEXT, "Resultado: R$ " + DoubleToString(dailyResult, 2));
   
   TimeCurrent(DateTimeStructure);
   if((DateTimeStructure.day_of_week == MONDAY     && !monday)    || 
      (DateTimeStructure.day_of_week == TUESDAY    && !tuesday)   || 
      (DateTimeStructure.day_of_week == WEDNESDAY  && !wednesday) || 
      (DateTimeStructure.day_of_week == THURSDAY   && !thursday)  || 
      (DateTimeStructure.day_of_week == FRIDAY     && !friday))
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
            SendMail("Meta Trader: Resultado diário","O total de trades de hoje resultou em R$ "+DoubleToString(dailyResult)+",00 bruto.");
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
            lresult = getResult(currentTime);
            buy = false;
         }
         if(sell)
         {
            lresult = getResult(currentTime);
            sell = false;
         }
      }
      
      else
      
      //buy: the rsi is below the lowest level
      if(rsi[0] < inpRSI_BuyLevel)
      {
         trade.Buy(inpVolume,_Symbol,lastTick.ask, lastTick.ask - pointsSL, lastTick.ask + pointsTP);
         lastTradeTime  = TimeCurrent();
         closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
         buy = true;
      }
      else
      //sell: the rsi is above the highest level
      if(rsi[0] > inpRSI_SellLevel)
      {
         trade.Sell(inpVolume,_Symbol,lastTick.bid, lastTick.bid + pointsSL, lastTick.bid - pointsTP);
         lastTradeTime  = TimeCurrent();
         closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
         sell = true;
      }
   }
   
   else
   
   // when the candle closes above the average
   if(TimeCurrent() > closeTradeTime)
   {
      if(buy && closePrice >= ma[0])
      {
         trade.PositionClose(_Symbol);
         buy = false;   
         lresult = getResult(currentTime);
      } 
      // when the candle closes below the average
      if(sell && closePrice <= ma[0])
      {
         trade.PositionClose(_Symbol);
         sell = false;   
         lresult = getResult(currentTime);
      }
   }
   if(lresult != 0)
   {
      dailyResult += lresult;
      
      if(dailyResult < 0 )  ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrRed);
      else                  ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrGreen);
   }
}
 
//+------------------------------------------------------------------+

double getResult(datetime currentTime)
{
   HistorySelect(TimeCurrent()-currentTime,TimeCurrent());
   int lastDealIndex       = HistoryDealsTotal() - 1;
   ulong ticket            = HistoryDealGetTicket(lastDealIndex);
   double lastDealProfit   = HistoryDealGetDouble(ticket, DEAL_PROFIT);
   ticket                  = HistoryDealGetTicket(lastDealIndex - 1);
   double firstDealProfit  = HistoryDealGetDouble(ticket, DEAL_PROFIT);
   return lastDealProfit - firstDealProfit;
}