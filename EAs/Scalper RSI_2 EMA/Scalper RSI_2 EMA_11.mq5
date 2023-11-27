//+------------------------------------------------------------------+
//|                                    Volatilidade_RSI_2_EMA_11.mq5 |
//|                                         Lucas, Eudes e Alexandre |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Lucas, Eudes e Alexandre"
#property link      "https://www.mql5.com"
#property version   "1.2"

#include <Trade/Trade.mqh>
#include <Math/Stat/Math.mqh>
#include "..\\Socket\\ClientSocket.mqh"
#include "..\\Socket\\JAson.mqh"

CTrade trade;

MqlDateTime dateTimeStructure;


input string   inpStartHour          = "9:15";     // Horário de Início
input string   inpEndHour            = "17:45";    // Horário de encerramento
input int      inpRSI_Period         = 2;          // Período do RSI
input int      inpEMA                = 11;         // Período da média
input int      inpRSI_BuyLevel       = 5;          // Mínima do RSI
input int      inpRSI_SellLevel      = 95;         // Máxima do RSI
input int      inpVolume             = 1;          // Número de papéis
input int      inpPointsDailyTarget  = 200;        // Alvo diário em pontos
input int      inpPointsDailyLoss    = 50;         // Loss diário em pontos            
input double   inpTP                 = 700;        // Take Profit
input double   inpSL                 = 500;        // Stop Loss
input bool     monday                = true;       // Operar segunda-feira
input bool     tuesday               = true;       // Operar terça-feira
input bool     wednesday             = true;       // Operar quarta-feira
input bool     thursday              = true;       // Operar quinta-feira
input bool     friday                = true;       // Operar sexta-feira


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
double         cashDailyResult   = 0;
double         pointsDailyResult = 0;
double         rsi[];
double         ma[];
double         openTradePoint;
int            lDelta = 1;
double         pointsSL;
double         pointsTP;
double         pointsTarget;
datetime       lastCandleTime;
ulong          expertAdvisorID;

CClientSocket* Socket;
int nCandlesToSocket;
MqlRates rates[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  
   pointsSL          = inpSL * Point();
   pointsTP          = inpTP * Point();
   pointsTarget      = inpPointsDailyTarget * Point();
   expertAdvisorID   = 1546;
   
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

   Socket=CClientSocket::Socket();
   Socket.Config("localhost", 9092);

   nCandlesToSocket = 10;   
   
   AssignLabels();

   lastCandleTime = 0;

   UpdateResults(TimeCurrent()% 86400);

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
   ObjectDelete(0,"targetPoints");
   ObjectDelete(0,"targetCash");
   ObjectDelete(0,"loss");
   ObjectDelete(0,"lossPoints");
   ObjectDelete(0,"lossCash");
   ObjectDelete(0,"result");
   ObjectDelete(0,"resultPoints");
   ObjectDelete(0,"resultCash");
   
   IndicatorRelease(hndMA);
   IndicatorRelease(hndRSI);

   //---
   CClientSocket::DeleteSocket();
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   bool     inOperation = false;
   datetime currentTime = TimeCurrent() % 86400;

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
      pointsDailyResult = 0;
      cashDailyResult = 0;
      UpdateResults(currentTime);
      return;
   }
   
   int positions = GetNumberOfOpenOrders(expertAdvisorID, Symbol());

   // current time is greater than or equal to the closing time or the gain is greater than or equal to the daily target 
   if(currentTime >= endTime || pointsDailyResult >= inpPointsDailyTarget || pointsDailyResult <= (inpPointsDailyLoss) * -1)
   {
        if(positions > 0)
            trade.PositionClose(_Symbol);
        if (!mailSent)
        {
            string content = "O total de trades de hoje resultou em R$ ";
            SendMail("Robô Scalper: Resultado diário",
                     content + DoubleToString(cashDailyResult,2)+" bruto.");            
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
         UpdateResults(currentTime);
      }
      
      else
      {
         //buy: the rsi is below the lowest level
         if(rsi[0] < inpRSI_BuyLevel)
         {
            if(IsNewCandle())
            {
               if(IsToOperate())
               {
                  trade.SetExpertMagicNumber(expertAdvisorID);
                  trade.Buy(inpVolume,_Symbol,lastTick.ask, lastTick.ask - pointsSL, lastTick.ask + pointsTP);
                  lastTradeTime  = TimeCurrent();
                  closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
                  buy = true;
               }
            }
         }
         else
         //sell: the rsi is above the highest level
         if(rsi[0] > inpRSI_SellLevel)
         {
            if(IsNewCandle())
            {
               if(IsToOperate())
               {
                  trade.SetExpertMagicNumber(expertAdvisorID);
                  trade.Sell(inpVolume,_Symbol,lastTick.bid, lastTick.bid + pointsSL, lastTick.bid - pointsTP);
                  lastTradeTime  = TimeCurrent();
                  closeTradeTime = lastTradeTime + lDelta + PeriodSeconds(_Period); 
                  sell = true;
               }
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
            UpdateResults(currentTime);
         } 
         // when the candle closes below the average
         if(sell && closePrice <= ma[1])
         {
            trade.PositionClose(_Symbol);
            sell = false;   
            UpdateResults(currentTime);
         }
      }
   }
}

void UpdateResults (datetime current)
{
   pointsDailyResult += result(expertAdvisorID, current);
   cashDailyResult   += (pointsDailyResult/5) * inpVolume;

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
double result(ulong xpAdvID, datetime current)
{
   double res       = 0;
   datetime today   = TimeCurrent() - current;

 if (HistorySelect(today, TimeCurrent())){
   int totalDeals = HistoryDealsTotal()-1;
   for (int i = 1; i <= totalDeals; i++)
   {
     const ulong ticket = HistoryDealGetTicket(i);
     ulong magicNumber  = HistoryDealGetInteger(ticket, DEAL_MAGIC);

     if((magicNumber == xpAdvID) && (HistoryDealGetString(ticket, DEAL_SYMBOL) == Symbol())
         )
       res += HistoryDealGetDouble(ticket, DEAL_PROFIT);
   }
 }
  res = (res/inpVolume) * 5;
  return res;
}

bool IsToOperate()
{
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
   ObjectCreate      (0,"target",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"target",OBJPROP_TEXT, "Alvo diário");
   ObjectSetInteger  (0,"target",OBJPROP_COLOR, clrBlue);
   ObjectSetInteger  (0,"target",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"target",OBJPROP_YDISTANCE, 20);
   ObjectSetInteger  (0,"target",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"target",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);   
   
   ObjectCreate      (0,"targetPoints",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"targetPoints",OBJPROP_TEXT, IntegerToString(inpPointsDailyTarget) + " pontos");
   ObjectSetInteger  (0,"targetPoints",OBJPROP_COLOR, clrBlue);
   ObjectSetInteger  (0,"targetPoints",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"targetPoints",OBJPROP_YDISTANCE, 40);
   ObjectSetInteger  (0,"targetPoints",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"targetPoints",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);

   ObjectCreate      (0,"targetCash",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"targetCash",OBJPROP_TEXT, IntegerToString(inpVolume) + " x R$ " + IntegerToString(inpPointsDailyTarget/5));
   ObjectSetInteger  (0,"targetCash",OBJPROP_COLOR, clrBlue);
   ObjectSetInteger  (0,"targetCash",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"targetCash",OBJPROP_YDISTANCE, 60);
   ObjectSetInteger  (0,"targetCash",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"targetCash",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);

   /************************************************************************************/
   
   ObjectCreate      (0,"loss",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"loss",OBJPROP_TEXT, "Loss diário");
   ObjectSetInteger  (0,"loss",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"loss",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"loss",OBJPROP_YDISTANCE, 100);
   ObjectSetInteger  (0,"loss",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"loss",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);   
   
   ObjectCreate      (0,"lossPoints",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"lossPoints",OBJPROP_TEXT, IntegerToString(inpPointsDailyLoss) + " pontos");
   ObjectSetInteger  (0,"lossPoints",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"lossPoints",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"lossPoints",OBJPROP_YDISTANCE, 120);
   ObjectSetInteger  (0,"lossPoints",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"lossPoints",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);

   ObjectCreate      (0,"lossCash",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"lossCash",OBJPROP_TEXT, IntegerToString(inpVolume) + " x R$ " + IntegerToString(inpPointsDailyLoss/5));
   ObjectSetInteger  (0,"lossCash",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"lossCash",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"lossCash",OBJPROP_YDISTANCE, 140);
   ObjectSetInteger  (0,"lossCash",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger  (0,"lossCash",OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);

   /************************************************************************************/

   ObjectCreate      (0,"result",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"result",OBJPROP_TEXT, "Resultado");
   ObjectSetInteger  (0,"result",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"result",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"result",OBJPROP_YDISTANCE, 45);
   ObjectSetInteger  (0,"result",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger  (0,"result",OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);    

   ObjectCreate      (0,"resultPoints",OBJ_LABEL,  0, 0, 0);
   ObjectSetString   (0,"resultPoints",OBJPROP_TEXT, DoubleToString(pointsDailyResult,0) + " pontos");
   ObjectSetInteger  (0,"resultPoints",OBJPROP_COLOR, clrBlack);
   ObjectSetInteger  (0,"resultPoints",OBJPROP_XDISTANCE, 5);
   ObjectSetInteger  (0,"resultPoints",OBJPROP_YDISTANCE, 25);
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

int GetNumberOfOpenOrders(ulong magicNumber, string symbol)
{
   int openTrades = 0;

   for (int i = 0; i <  PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         // Successfully select the position
         if(PositionGetInteger(POSITION_MAGIC) == magicNumber) 
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