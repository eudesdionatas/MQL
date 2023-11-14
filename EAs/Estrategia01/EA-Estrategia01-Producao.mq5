//+------------------------------------------------------------------+
//|                                          volatilidade_rsi_ma.mq5 |
//|                                                            Lucas |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Lucas, Eudes e Alexandre"
#property link      "https://www.mql5.com"
#property version   "1.02"

//#include <Math/Stat/Math.mqh>
#include <Trade/Trade.mqh>
#include "..\\Socket\\ClientSocket.mqh"
#include "..\\Socket\\JAson.mqh"

#resource "\\Indicators\\MQL_IA\\Estrategia01\\AlexessSavitzkyGolayMA.ex5"
//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_NP
{
   NP_5  =  5, // 5
   //NP_7  =  7, // 7
   //NP_9  =  9, // 9
   //NP_11 = 11, // 11
   //NP_13 = 13, // 13
   NP_15 = 15, // 15
   NP_25 = 25  // 25
};

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input string iSeparatorEA = "-----| Configurações do EA |-----"; //-----| Configurações do EA |-----
input int      EA_Magic        = 123456789;              // EA Magic Number
input datetime iInitEATime     = D'1970.01.01 09:00:59'; // Horário para começar a operar (só HH:mm é considerado)
input datetime iEndEATime      = D'1970.01.01 17:45:00'; // Horário para terminar de operar (só HH:mm é considerado)
input double   iLots           = 1; // Lot size


input string iSeparatorIndicator = "-----| Configurações do indicador |-----"; //-----| Configurações do indicador |-----
input datetime iStartTime   = D'1970.01.01 09:13:00'; // Candle Start Time (only HH:mm is considered)
input string iSeparatorSG = "---| Savitzky Golay |---"; //---| Savitzky Golay |---
input ENUM_NP  iNP = NP_25;         // SG NP
input bool     iShowCandles = true; // SG Show candles
//input bool     iFilterInit  = true; // SG Filter initial movement
input string iSeparatorMA = "---| Moving Average |---"; //---| Moving Average |---
input int                iMAPeriod     = 8;           // MA Period
input ENUM_MA_METHOD     iMAMethod     = MODE_EMA;    // MA Method
input ENUM_APPLIED_PRICE iAppliedPrice = PRICE_CLOSE; // MA Applied Price
input int                iMAShift      = 0;           // MA Shift


//--- main variables
CTrade trade;
int mainHandler;
double sgB[];
double maB[];
double colorB[];
int colorIndicator;
int lastColorIndicator;
datetime initTime;
datetime endTime;

//--- file handle
//string filename = "validacao_estrategia_1_v2.csv";
//int    fileCtrl;
//datetime tto[];

//--- socket
CClientSocket* Socket;
MqlRates rates[];
datetime lastCandleTime;
int nCandlesToSocket;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // file
   /*
   fileCtrl = FileOpen(filename, FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON);
   if(fileCtrl != INVALID_HANDLE)
   {
      FileReadString(fileCtrl);
      datetime time;
      bool     operate;
      string line[2];
      while(!FileIsEnding(fileCtrl))
      {
         StringSplit(FileReadString(fileCtrl), ',', line);
         
         time    = StringToTime(line[0]);
         operate = StringCompare(line[1], "True") == 0;
         
         if(operate)
         {
            ArrayResize(tto, tto.Size()+1);
            tto[tto.Size()-1] = time;
         }
      }
   }
   else
   {
      Print("Error (line ", __LINE__, "): ", GetLastError());
      return(INIT_FAILED);
   }
   */
   
   // handlers
   mainHandler = iCustom(NULL,
                         0,
                         "::Indicators\\MQL_IA\\Estrategia01\\AlexessSavitzkyGolayMA",
                         iStartTime,
                         iSeparatorSG,
                         iNP,
                         iShowCandles,
                         iSeparatorMA,
                         iMAPeriod,
                         iMAMethod,
                         iAppliedPrice,
                         iMAShift);
   if(mainHandler <= 0)
   {
      Print("Error trying to create handler! Error code: ", GetLastError());
      return(INIT_FAILED);
   }
   
   initTime = iInitEATime % 86400;
   endTime  = iEndEATime  % 86400;
   
   colorIndicator = 0;
   lastColorIndicator = 0;
   
   //---
   Socket=CClientSocket::Socket();
   Socket.Config("localhost", 9091);
   
   //---
   lastCandleTime = 0;
   nCandlesToSocket = 15;
   
   //---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //---
   //FileClose(fileCtrl);
   IndicatorRelease(mainHandler);
   
   //---
   CClientSocket::DeleteSocket();
}

//+------------------------------------------------------------------+
//| Indicator function                                               |
//+------------------------------------------------------------------+
/*
bool timeToOperate(datetime time)
{
   for(int i = ArraySize(tto)-1; i >= 0; i--)
   {
      if(tto[i] == time)
         return(true);
   }
   
   return(false);
}
*/

//+------------------------------------------------------------------+
//| IsNewCandle function                                             |
//+------------------------------------------------------------------+
bool IsNewCandle()
{
   datetime time[];
   
   if(CopyTime(Symbol(), Period(), 0, 1, time) < 1)
      return false;
   
   if(time[0] == lastCandleTime)
      return false;
   
   return bool(lastCandleTime = time[0]);
}

//+------------------------------------------------------------------+
//| IsToOperate function                                             |
//+------------------------------------------------------------------+
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
         Print("IA mandou comprar!");
         return(true);
      }
      else
      {
         Print("IA NÃO mandou comprar!");
      }
   }
   
   return(false);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   int nPositions;
   MqlRates lastRates[1];
   MqlTick  lastTick;
   
   datetime currentTime = TimeCurrent() % 86400;
   
   
   // current time is less than or equal to the start time
   if(currentTime < initTime)
   {
      lastColorIndicator = 0;
      return;
   }
   
   nPositions = PositionsTotal();
   
   // current time is greater than or equal to the closing time or the gain is greater than or equal to the daily target 
   if(currentTime >= endTime)
   {
      if(nPositions > 0)
         trade.PositionClose(_Symbol);
      
      lastColorIndicator = 0;
      
      return;
   }
   
   // if can't copy the RSI buffer
   if(CopyBuffer(mainHandler, 0, 0, 1, sgB) < 0 || CopyBuffer(mainHandler, 1, 0, 1, maB) < 0 || CopyBuffer(mainHandler, 7, 0, 1, colorB) < 0)
   {
      Print("Erro ao tentar copiar buffers: ", GetLastError());
      return;
   }
   
   //--- last tick
   if(!SymbolInfoTick(_Symbol, lastTick))
   {
      Print("Erro ao tentar o último tick: ", GetLastError());
      return;
   }
   //--- last rates
   if(!CopyRates(_Symbol, _Period, 0, 1, lastRates))
   {
      Print("Erro ao tentar o últimos candles: ", GetLastError());
      return;
   }
   
   switch((int)colorB[0])
   {
      case 1:
      case 3:
         colorIndicator = 1;
         break;
      case 2:
      case 4:
         colorIndicator = -1;
         break;
      default:
         colorIndicator = 0;
         break;
   }
   
   if(nPositions == 0)
   {
      if(colorIndicator > 0 && colorIndicator != lastColorIndicator)
      {
         lastColorIndicator = colorIndicator;
         
         //if(timeToOperate(lastRates[0].time))
         if(IsToOperate())
            trade.Buy(iLots, _Symbol);
      }
      else
      if(colorIndicator < 0 && colorIndicator != lastColorIndicator)
      {
         lastColorIndicator = colorIndicator;
         
         //if(timeToOperate(lastRates[0].time))
         if(IsToOperate())
            trade.Sell(iLots, _Symbol);
      }
      
   }
   
   else // if(positions == 0)
   {
      PositionSelect(_Symbol);
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         if(colorIndicator < 0)
         {
            if(colorIndicator != lastColorIndicator && IsToOperate()) //timeToOperate(lastRates[0].time))
            {
               trade.Sell(2*iLots, _Symbol);
            }
            else
               trade.PositionClose(_Symbol);
            
            lastColorIndicator = colorIndicator;
         }
      }
      
      else
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         if(colorIndicator > 0)
         {
            if(colorIndicator != lastColorIndicator && IsToOperate()) //timeToOperate(lastRates[0].time))
            {
               trade.Buy(2*iLots, _Symbol);
            }
            else
               trade.PositionClose(_Symbol);
            
            lastColorIndicator = colorIndicator;
         }
      }
   }
}
 
//+------------------------------------------------------------------+
