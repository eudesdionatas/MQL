//+------------------------------------------------------------------+
//|                                              Scalper_RSI_EMA.mq5 |
//|                                         Lucas, Eudes e Alexandre |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Lucas, Eudes e Alexandre"
#property link      "https://www.mql5.com"
#property version   "1.5"

#include <Trade/Trade.mqh>
#include <Math/Stat/Math.mqh>
#include "..\\Socket\\ClientSocket.mqh"
#include "..\\Socket\\JAson.mqh"

CTrade trade;

MqlDateTime dateTimeStructure;

enum ticker {
   WIN   = 1,  // Mini índice
   WDO   = 2   // Mini dólar
};

input ticker   inpTicker             = WIN;        // Papel
input string   inpStartHour          = "9:15";     // Horário de Início
input string   inpEndHour            = "17:45";    // Horário de encerramento
input int      inpRSI_Period         = 2;          // Período do RSI
input int      inpEMA_Period         = 11;         // Período da média
input int      inpLowerLevel         = 10;         // Mínima do RSI
input int      inpHigherLevel        = 90;         // Máxima do RSI
input int      inpVolume             = 1;          // Número de papéis
input int      inpPointsDailyTarget  = 670;        // Alvo diário em pontos
input int      inpPointsDailyLoss    = 550;        // Loss diário em pontos            
input double   inpTP                 = 200;        // Take Profit
input bool     inpWithSL             = true;       // Lançar ordem com Stop Loss
input double   inpSL                 = 170;        // Stop Loss
input ulong    expertAdvisorID       = 564791;     // Número mágico (Identificador deste robô)
input bool     monday                = true;       // Operar segunda-feira
input bool     tuesday               = true;       // Operar terça-feira
input bool     wednesday             = true;       // Operar quarta-feira
input bool     thursday              = true;       // Operar quinta-feira
input bool     friday                = true;       // Operar sexta-feira


datetime       lastTradeTime     = 0;
bool           buy               = false;
bool           sell              = false;
bool           mailSent          = false;  
bool           buyLose           = false;
bool           sellLose          = false;
datetime       closeTradeTime    = 0;
datetime       startTime         = StringToTime(inpStartHour)  %  86400;
datetime       endTime           = StringToTime(inpEndHour)    %  86400;
int            hndRSI            = 0;
int            hndMA             = 0;
int            customMA          = 0;
int            contOperations    = 0;
double         cashDailyResult   = 0;
double         pointsDailyResult = 0;
int            volume            = inpVolume;
int            tradeVolume       = inpVolume;
ENUM_DEAL_TYPE lastDealType;
double         rsi[];
double         ma[];
double         openTradePoint;
int            lDelta = 1;
double         pointsSL;
double         pointsTP;
double         pointsTarget;
datetime       lastCandleTime;
string         daysToOperate;


CClientSocket* Socket;
int nCandlesToSocket;
MqlRates rates[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  
   pointsSL                = inpSL * Point();
   pointsTP                = inpTP * Point();
   pointsTarget            = inpPointsDailyTarget * Point();
   datetime timeCurrent    = TimeCurrent();
   datetime dayTimeCurrent = timeCurrent % 86400;
   datetime today          = timeCurrent - dayTimeCurrent;

   
   ArraySetAsSeries(rsi,true);
   ArraySetAsSeries(ma, true);

//---
   hndRSI = iRSI(_Symbol, _Period, inpRSI_Period, PRICE_CLOSE);
   hndMA  = iMA (_Symbol, _Period, inpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   if(hndMA == INVALID_HANDLE || hndRSI == INVALID_HANDLE)
   {
      Print("iRSI / iMA failed! Error: ", GetLastError());
      return(INIT_FAILED);
   }

   daysToOperate = DaysToOperate();

   // Socket=CClientSocket::Socket();
   // Socket.Config("localhost", 9092);

   // nCandlesToSocket = 15;   
   
   AssignLabels();

   lastCandleTime = 0;

   UpdateResults(today);
   Comments(today,timeCurrent);

  //---
   return(INIT_SUCCEEDED);
}

string DaysToOperate()
{
   string out   = "[";
   int contDays    = 0;
   
   if(monday) 
   {
      out += " Seg ";
      contDays++;
   }
   if(tuesday)
   {
      if (contDays > 0) out    += "Ter ";
      else out    += " Ter ";
      contDays++;
   } 
   if(wednesday) 
   {
      if (contDays > 0) out    += "Qua ";
      else out    += " Qua ";
      contDays++;
   } 
   if(thursday)
   {
      if (contDays > 0) out    += "Qui ";
      else out    += " Qui ";
      contDays++;
   } 
   if(friday)
   {
      if (contDays > 0) out    += "Sex ";
      else out    += " Sex ";
      contDays++;
   } 

   out   += "]";
   if (contDays == 5) out = "Todos";

   return out;

}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   ObjectDelete(0,"target");
   ObjectDelete(0,"targetPoints");
   ObjectDelete(0,"targetCash");
   ObjectDelete(0,"stopLoss");
   ObjectDelete(0,"stopLossPoints");
   ObjectDelete(0,"stopLossCash");
   ObjectDelete(0,"takeProfit");
   ObjectDelete(0,"takeProfitPoints");
   ObjectDelete(0,"takeProfitCash");
   ObjectDelete(0,"loss");
   ObjectDelete(0,"lossPoints");
   ObjectDelete(0,"lossCash");
   ObjectDelete(0,"result");
   ObjectDelete(0,"resultPoints");
   ObjectDelete(0,"resultCash");
   
   IndicatorRelease(hndMA);
   IndicatorRelease(hndRSI);

   Comment("");

   //---
   // CClientSocket::DeleteSocket();
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   datetime timeCurrent    = TimeCurrent();
   datetime dayTimeCurrent = timeCurrent % 86400;
   datetime today          = timeCurrent - dayTimeCurrent;
   bool lose_              = false;
   bool isNewCandle        = IsNewCandle();

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
   if( dayTimeCurrent <= startTime )
   {
      pointsDailyResult = 0;
      cashDailyResult = 0;
      UpdateResults(today);
      return;
   }
   
   int positions = GetNumberOfOpenOrders(expertAdvisorID, Symbol());

   // current time is greater than or equal to the closing time or the gain is greater than or equal to the daily target 
   if(dayTimeCurrent >= endTime || pointsDailyResult >= inpPointsDailyTarget || pointsDailyResult <= (inpPointsDailyLoss) * -1)
   {
         UpdateResults(today);
        if(positions > 0)
            trade.PositionClose(_Symbol);
        if (!mailSent)
        {
            string asset;
            if (inpTicker == WIN) asset = "Mini índice";
               else 
            if (inpTicker == WDO) asset = "Mini dólar";

            string content = "O total de trades no " + asset + " hoje, resultou em R$ " + DoubleToString(cashDailyResult,0) +" bruto, " + DoubleToString(pointsDailyResult,0) + " pontos." + 
                              "\n\nInício das negociações: " + inpStartHour + "h" +
                              "\nHora da última negociação: " + TimeToString(timeCurrent, TIME_MINUTES) + "h" +
                              "\n\nRSI(Períodos / Nível inferior / Nível superior): " + inpRSI_Period + " / "+ inpLowerLevel + " / " + inpHigherLevel +
                              "\nMédia aritmética exponencial: " + inpEMA_Period + " períodos" +
                              "\n\nTake Profit: "  + inpTP + 
                              "\nStop Loss: " + inpSL +
                              "\nAlvo diário em pontos: " + inpPointsDailyTarget +
                              "\nLoss diário em pontos: " + inpPointsDailyTarget + 
                              "\n\nNúmero de operações: " + contOperations +
                              "\nVariação média de pontos por candle: " + DoubleToString(Comments(today, timeCurrent),2);

            SendMail("Robô Scalper: Resultado diário", content );            
            mailSent = true;
        }

        buy  = false;
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
   
   if(rsi[0] > inpLowerLevel && buyLose){
      if(closePrice > ma[0])
      {
         // volume   = inpVolume;
         buyLose  = false;
      }
   }
   
   if(rsi[0] < inpHigherLevel && sellLose)
   {
      if(closePrice < ma[0])
      {
         // volume   = inpVolume;
         sellLose = false;
      }
   }

   if(positions == 0)
   {
      // when the Stop Loss(SL)/Take Profit(TP) was executed or the position was closed manually
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

         lose_ = lose(expertAdvisorID,today,timeCurrent);

         UpdateResults(today);

         if(lose_)
         {
            volume *= 2;
            tradeVolume = volume;
            if(lastDealType == DEAL_TYPE_SELL && rsi[0] < inpLowerLevel)
            {
               buyLose = true;
            }
            if(lastDealType == DEAL_TYPE_BUY && rsi[0] > inpHigherLevel)
            {
               sellLose = true;
            }
         }
         else 
         {
            volume = inpVolume;
         }

      }
      
      else
      {
         //buy: the rsi is below the lowest level
         if(rsi[0] < inpLowerLevel)
         {
            if(isNewCandle || true)
            {
               if(IsToOperate())
               {
                  if (buyLose)
                  {
                     trade.SetExpertMagicNumber(expertAdvisorID);
                     tradeVolume = volume;
                     if(inpWithSL)
                        trade.Sell(volume,_Symbol,lastTick.bid, lastTick.bid + pointsSL, lastTick.bid - pointsTP, expertAdvisorID);
                     else
                        trade.Sell(volume,_Symbol,lastTick.bid, 0, lastTick.bid - pointsTP, expertAdvisorID);
                     lastTradeTime  = timeCurrent;
                     closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
                     sell = true;
                  }
                  else
                  {
                     tradeVolume = volume;
                     trade.SetExpertMagicNumber(expertAdvisorID);
                     if(inpWithSL)
                        trade.Buy(volume,_Symbol,lastTick.ask, lastTick.ask - pointsSL, lastTick.ask + pointsTP, expertAdvisorID);
                     else
                        trade.Buy(volume,_Symbol,lastTick.ask, 0, lastTick.ask + pointsTP, expertAdvisorID);
                     lastTradeTime  = timeCurrent;
                     closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
                     buy = true;
                  }
                  
               }
            }
         }
         else
         //sell: the rsi is above the highest level
         if(rsi[0] > inpHigherLevel)
         {
            if(isNewCandle || true)
            {
               if(IsToOperate())
               {
                  if(sellLose)
                  {
                     trade.SetExpertMagicNumber(expertAdvisorID);
                     if(inpWithSL)
                        trade.Buy(volume,_Symbol,lastTick.ask, lastTick.ask - pointsSL, lastTick.ask + pointsTP, expertAdvisorID);
                     else
                        trade.Buy(volume,_Symbol,lastTick.ask, 0, lastTick.ask + pointsTP, expertAdvisorID);
                     lastTradeTime  = timeCurrent;
                     closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
                     buy = true;
                  }
                  else
                  {
                     trade.SetExpertMagicNumber(expertAdvisorID);
                     if(inpWithSL)
                        trade.Sell(volume,_Symbol,lastTick.bid, lastTick.bid + pointsSL, lastTick.bid - pointsTP, expertAdvisorID);
                     else
                        trade.Sell(volume,_Symbol,lastTick.bid, 0, lastTick.bid - pointsTP, expertAdvisorID);
                     lastTradeTime  = timeCurrent;
                     closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
                     sell = true;
                  }
               }
            }
         }
      }
   }
      
   else
   {
   // when the candle closes above the average
      if(timeCurrent > closeTradeTime)
      {
         if(buy && closePrice >= ma[1] && !sellLose)
         {
            trade.PositionClose(_Symbol);
            buy = false;
            UpdateResults(today);
            lose_ = lose(expertAdvisorID,today,timeCurrent);
            if (lose_)
            {
               volume *= 2;
               tradeVolume = volume;   
            }
            else
            {
               tradeVolume = volume;
               volume = inpVolume;   
            } 
         } 
         // when the candle closes below the average
         if(sell && closePrice <= ma[1] && !buyLose)
         {
            trade.PositionClose(_Symbol);
            sell = false;
            UpdateResults(today);
            lose_ = lose(expertAdvisorID,today,timeCurrent);
            if (lose_)
            {
               volume *= 2;
               tradeVolume = volume;   
            }
            else
            {
               tradeVolume = volume;
               volume = inpVolume;   
            }
         }
      }
   }
   Comments(today,timeCurrent);
}

void UpdateResults (datetime today)
{
   pointsDailyResult = result(expertAdvisorID, today);
   cashDailyResult   = (pointsDailyResult/5) * inpVolume;
   if(pointsDailyResult == 0)
   {
      ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrBlack);
      ObjectSetInteger  (0,"resultPoints",OBJPROP_COLOR, clrBlack);
      ObjectSetInteger  (0,"resultCash",OBJPROP_COLOR, clrBlack);
   }
   else if(pointsDailyResult < 0 )
   {
      ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrRed);
      ObjectSetInteger  (0,"resultPoints",OBJPROP_COLOR, clrRed);
      ObjectSetInteger  (0,"resultCash",OBJPROP_COLOR, clrRed);
   }  
   else 
   {
      ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrGreen);
      ObjectSetInteger  (0,"resultPoints",OBJPROP_COLOR, clrGreen);
      ObjectSetInteger  (0,"resultCash",OBJPROP_COLOR, clrGreen);
   }

   ObjectSetString(0, "resultPoints",  OBJPROP_TEXT, DoubleToString(pointsDailyResult, 0) + " pontos");
   ObjectSetString(0, "resultCash",  OBJPROP_TEXT, "R$ " + DoubleToString(cashDailyResult, 2));

}
 
// Return the result at the day at points
double result(ulong xpAdvID, datetime today)
{
   double res           = 0;
   bool manuallyClosed  = false;

 if (HistorySelect(today, TimeCurrent())){
   int totalDeals = HistoryDealsTotal()-1;
   for (int i = 1; i <= totalDeals; i++)
   {
      ulong ticket          = HistoryDealGetTicket(i);
      ulong magicNumber     = HistoryDealGetInteger(ticket, DEAL_MAGIC);

      if(HistoryDealGetInteger(ticket, DEAL_REASON) == DEAL_REASON_CLIENT || HistoryDealGetInteger(ticket, DEAL_REASON) == DEAL_REASON_MOBILE)
      {
         for(int x = totalDeals - 1; x >= 1 ; x--)
         {
            ulong previousTicket  = HistoryDealGetTicket(x);
            
            if (HistoryDealGetInteger(previousTicket, DEAL_MAGIC) == xpAdvID)
            {
               manuallyClosed = true;
               break;
            }
         }
      }

     if(((magicNumber == xpAdvID) && (HistoryDealGetString(ticket, DEAL_SYMBOL) == Symbol())) || manuallyClosed)
       res += HistoryDealGetDouble(ticket, DEAL_PROFIT);
   }
   contOperations = (totalDeals+1)/2;
 }
  res = (res/inpVolume) * 5;
  return res;
}


int GetNumberOfOpenOrders(ulong xpAdvID, string symbol)
{
   int openTrades = 0;
   bool manuallyClosed = false;

   for (int i = 0; i <  PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
      if(HistoryDealGetInteger(ticket, DEAL_REASON) == DEAL_REASON_CLIENT)      
      {
         for(int x = HistoryDealsTotal() - 2; x >= 1 ; x--)
         {
            ulong previousTicket  = HistoryDealGetTicket(x-2);
         
            if (HistoryDealGetInteger(previousTicket, DEAL_MAGIC) == xpAdvID)
            {
               manuallyClosed = true;
               break;
            }
         }
      }

      // Successfully select the position
      if(PositionGetInteger(POSITION_MAGIC) == xpAdvID || manuallyClosed) 
      {
         // Open trade is from the Expert with our magicNumber
         if(PositionGetString(POSITION_SYMBOL) == symbol)
            openTrades++;
      }
      }
   }
   return openTrades;
}

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

bool IsToOperate()
{

   /***********************************************************************************/
   return true;
   
   /***********************************************************************************/

   if(CopyRates(_Symbol, _Period, 0, nCandlesToSocket, rates) < nCandlesToSocket)
      return(false);
   
   CJAVal data;
   CJAVal item;
   for(int i = nCandlesToSocket-1; i >= 0; i--)
   {
      //item["time"  ] = datetime(rates[i].time       );
      item["open"  ] = int(rates[i].open       );
      item["high"  ] = int(rates[i].high       );
      item["low"   ] = int(rates[i].low        );
      item["close" ] = int(rates[i].close      );
      item["tick"  ] = int(rates[i].tick_volume);
      item["volume"] = int(rates[i].real_volume);
      
      data[IntegerToString(i)].Set(item);
      
      item.Clear();
   }
   
   string serialized = data.Serialize();
   
   Print("serialized: ", serialized);
   
   if(!Socket.IsConnected())
   {
      Print("Socket.IsConnected() (line ", __LINE__, ") error: ", GetLastError());
      return(false);
   }
   
   //bool send = Socket.SocketSend(serialized);
   //Print("send: ", send);
   //if(send)
   if(Socket.SocketSend(serialized))
   {
      string yhat = Socket.SocketReceive();
      Print("Value of Prediction: ", yhat);
      
      if(yhat == "True" )
      {
         Print("IA mandou operar!");
         return(true);
      }
      else
      {
         Print("IA mandou NÃO operar!");
      }
   }
   
   return(false);
}

void AssignLabels()
{
   
   ObjectCreate      (0,"stopLoss",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"stopLoss",OBJPROP_TEXT, "Stop Loss");
   ObjectSetInteger  (0,"stopLoss",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"stopLoss",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"stopLoss",OBJPROP_YDISTANCE, 30);
   ObjectSetInteger  (0,"stopLoss",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"stopLoss",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);    

   ObjectCreate      (0,"stopLossPoints",OBJ_LABEL,  0, 0, 0);
   if(inpWithSL)
      ObjectSetString   (0,"stopLossPoints",OBJPROP_TEXT, DoubleToString(inpSL,0) + " pontos");
   else
      ObjectSetString   (0,"stopLossPoints",OBJPROP_TEXT, "--");  
   ObjectSetInteger  (0,"stopLossPoints",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"stopLossPoints",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"stopLossPoints",OBJPROP_YDISTANCE, 55);
   ObjectSetInteger  (0,"stopLossPoints",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"stopLossPoints",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);    

   ObjectCreate      (0,"stopLossCash",OBJ_LABEL,  0, 0, 0);
   if(inpWithSL)
      ObjectSetString   (0,"stopLossCash",OBJPROP_TEXT, "R$ " + DoubleToString(inpSL/5,2));
   else
      ObjectSetString   (0,"stopLossCash",OBJPROP_TEXT, "--");  
   ObjectSetInteger  (0,"stopLossCash",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"stopLossCash",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"stopLossCash",OBJPROP_YDISTANCE, 80);
   ObjectSetInteger  (0,"stopLossCash",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"stopLossCash",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); 

   /************************************************************************************/
   
   ObjectCreate      (0,"loss",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"loss",OBJPROP_TEXT, "Loss diário");
   ObjectSetInteger  (0,"loss",OBJPROP_COLOR, clrRed);
   ObjectSetInteger  (0,"loss",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"loss",OBJPROP_YDISTANCE, 115);
   ObjectSetInteger  (0,"loss",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"loss",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);   
   
   ObjectCreate      (0,"lossPoints",OBJ_LABEL,  0, 0, 0);
   if (inpWithSL)
      ObjectSetString   (0,"lossPoints",OBJPROP_TEXT, IntegerToString(inpPointsDailyLoss) + " pontos");
   else 
      ObjectSetString   (0,"lossPoints",OBJPROP_TEXT, "--");
   ObjectSetInteger  (0,"lossPoints",OBJPROP_COLOR, clrRed);
   ObjectSetInteger  (0,"lossPoints",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"lossPoints",OBJPROP_YDISTANCE, 140);
   ObjectSetInteger  (0,"lossPoints",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"lossPoints",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);

   ObjectCreate      (0,"lossCash",OBJ_LABEL,  0, 0, 0);
   if (inpWithSL)
      ObjectSetString   (0,"lossCash",OBJPROP_TEXT, IntegerToString(inpVolume) + " x R$ " + IntegerToString(inpPointsDailyLoss/5));
   else
      ObjectSetString   (0,"lossCash",OBJPROP_TEXT, "--");
   ObjectSetInteger  (0,"lossCash",OBJPROP_COLOR, clrRed);
   ObjectSetInteger  (0,"lossCash",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"lossCash",OBJPROP_YDISTANCE, 165);
   ObjectSetInteger  (0,"lossCash",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"lossCash",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);

   /************************************************************************************/

   ObjectCreate      (0,"takeProfit",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"takeProfit",OBJPROP_TEXT, "Take Profit");
   ObjectSetInteger  (0,"takeProfit",OBJPROP_COLOR, clrGreen);
   ObjectSetInteger  (0,"takeProfit",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"takeProfit",OBJPROP_YDISTANCE, 200);
   ObjectSetInteger  (0,"takeProfit",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"takeProfit",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);    

   ObjectCreate      (0,"takeProfitPoints",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"takeProfitPoints",OBJPROP_TEXT, DoubleToString(inpTP,0) + " pontos");
   ObjectSetInteger  (0,"takeProfitPoints",OBJPROP_COLOR, clrGreen);
   ObjectSetInteger  (0,"takeProfitPoints",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"takeProfitPoints",OBJPROP_YDISTANCE, 225);
   ObjectSetInteger  (0,"takeProfitPoints",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"takeProfitPoints",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);    

   ObjectCreate      (0,"takeProfitCash",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"takeProfitCash",OBJPROP_TEXT, "R$ " + DoubleToString(inpTP/5,2));
   ObjectSetInteger  (0,"takeProfitCash",OBJPROP_COLOR, clrGreen);
   ObjectSetInteger  (0,"takeProfitCash",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"takeProfitCash",OBJPROP_YDISTANCE, 250);
   ObjectSetInteger  (0,"takeProfitCash",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"takeProfitCash",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); 

   /************************************************************************************/

   ObjectCreate      (0,"target",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"target",OBJPROP_TEXT, "Alvo diário");
   ObjectSetInteger  (0,"target",OBJPROP_COLOR, clrBlue);
   ObjectSetInteger  (0,"target",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"target",OBJPROP_YDISTANCE, 140);
   ObjectSetInteger  (0,"target",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger  (0,"target",OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);   
   
   ObjectCreate      (0,"targetPoints",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"targetPoints",OBJPROP_TEXT, IntegerToString(inpPointsDailyTarget) + " pontos");
   ObjectSetInteger  (0,"targetPoints",OBJPROP_COLOR, clrBlue);
   ObjectSetInteger  (0,"targetPoints",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"targetPoints",OBJPROP_YDISTANCE, 115);
   ObjectSetInteger  (0,"targetPoints",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger  (0,"targetPoints",OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);

   ObjectCreate      (0,"targetCash",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"targetCash",OBJPROP_TEXT, IntegerToString(inpVolume) + " x R$ " + IntegerToString(inpPointsDailyTarget/5));
   ObjectSetInteger  (0,"targetCash",OBJPROP_COLOR, clrBlue);
   ObjectSetInteger  (0,"targetCash",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"targetCash",OBJPROP_YDISTANCE, 90);
   ObjectSetInteger  (0,"targetCash",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger  (0,"targetCash",OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);

   /*****************************************************************************************************************/

   ObjectCreate      (0,"result",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"result",OBJPROP_TEXT, "Resultado");
   ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"result",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"result",OBJPROP_YDISTANCE, 55);
   ObjectSetInteger  (0,"result",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger  (0,"result",OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);    

   ObjectCreate      (0,"resultPoints",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"resultPoints",OBJPROP_TEXT, DoubleToString(pointsDailyResult,0) + " pontos");
   ObjectSetInteger  (0,"resultPoints",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"resultPoints",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"resultPoints",OBJPROP_YDISTANCE, 30);
   ObjectSetInteger  (0,"resultPoints",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger  (0,"resultPoints",OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);    

   ObjectCreate      (0,"resultCash",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"resultCash",OBJPROP_TEXT, "R$ " + DoubleToString(cashDailyResult,2));
   ObjectSetInteger  (0,"resultCash",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"resultCash",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"resultCash",OBJPROP_YDISTANCE, 5);
   ObjectSetInteger  (0,"resultCash",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger  (0,"resultCash",OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER); 

}

double Comments(datetime today, datetime timeCurrent)
{
   double mid              = 0;
   int numberOfCandles     = Bars(_Symbol, _Period,today,timeCurrent);

   double variation = 0;
   double x = 0;
   for(x; x <= numberOfCandles; x++)
   {
      variation += iHigh(_Symbol,_Period,x) - iLow(_Symbol,_Period,x);
   }
   mid = variation/x;

   Comment( "Nº de candles do dia: " + numberOfCandles + 
            "      AVG (pontos por candle): " + DoubleToString(mid,2) +         
            "      RSI ( Período / Mínima / Máxima ): " + inpRSI_Period + " / " + inpLowerLevel + " / " + inpHigherLevel +
            "      EMA (Período): " + inpEMA_Period +                           
            "      Volume inicial / negociado: " + inpVolume + " / " + tradeVolume +
            "      Dias de operação: " + daysToOperate + 
            "      Início: " + inpStartHour + "h" +
            "      Encerramento: " + inpEndHour + "h" +
            "      Nº de operações: " + contOperations + 
            "      Nº mágico: " + expertAdvisorID); 
   return mid;
}

double lastOperationInformations(ulong xpAdvID, datetime today, datetime timeCurrent)
{   
   double res           = 0;
   bool manuallyClosed  = false;
   if (HistorySelect(today, timeCurrent))
   {
      int totalDeals = HistoryDealsTotal()-1;
      
         ulong ticket          = HistoryDealGetTicket(totalDeals);
         ulong magicNumber     = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         lastDealType          = HistoryDealGetInteger(ticket, DEAL_TYPE);

         if(HistoryDealGetInteger(ticket, DEAL_REASON) == DEAL_REASON_CLIENT)      
         {
            
            for(int x = totalDeals - 1; x >= 1 ; x--)
            {
               ulong previousTicket  = HistoryDealGetTicket(x);
               
               if (HistoryDealGetInteger(previousTicket, DEAL_MAGIC) == xpAdvID)
               {
                  manuallyClosed = true;
                  break;
               }
            }
         }

         if(((magicNumber == xpAdvID) && (HistoryDealGetString(ticket, DEAL_SYMBOL) == Symbol())) || manuallyClosed)
            res = HistoryDealGetDouble(ticket, DEAL_PROFIT);
 }
  return res;
}

bool lose(ulong xpAdvID, datetime today, datetime timeCurrent)
{
   return lastOperationInformations(xpAdvID, today, timeCurrent) < 0;
}