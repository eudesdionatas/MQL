//+------------------------------------------------------------------+
//|                                          volatilidade_rsi_ma.mq5 |
//|                                                            Lucas |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Lucas, Eudes e Alexandre"
#property link      "https://www.mql5.com"
#property version   "1.02"

//+------------------------------------------------------------------+
//| Includes                                                       |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include "..\\CSV\\FileCSV.mqh"

//+------------------------------------------------------------------+
//| Resources                                                        |
//+------------------------------------------------------------------+
#resource "\\Indicators\\MQL_IA\\Estrategia01\\AlexessSavitzkyGolayMA.ex5"

//+------------------------------------------------------------------+
//| Defines                                                          |
//+------------------------------------------------------------------+
#define PATH(path) "CSV/"+path+".csv"
#define N_CANDLES_TO_PYTHON 15

#define SEND_ARCHIVE    "send"
#define SEND_OK_ARCHIVE "send_predict"
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

//--- csv
CFileCSV fileCSV;
MqlRates rates[];
datetime lastCandleTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
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
   IndicatorRelease(mainHandler);
}

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
   bool result = false;
   
   if(CopyRates(_Symbol, _Period, 0, N_CANDLES_TO_PYTHON, rates) < N_CANDLES_TO_PYTHON)
      return(false);
   
   string h[6] = {"open", "high", "low", "close", "tick", "volume"};
   string d[N_CANDLES_TO_PYTHON][6];
   
   for(int i = N_CANDLES_TO_PYTHON-1; i >= 0; i--)
   {
      //d[i][0] = IntegerToString(i);
      d[i][0] = DoubleToString(NormalizeDouble(rates[i].open       , _Digits), _Digits);
      d[i][1] = DoubleToString(NormalizeDouble(rates[i].high       , _Digits), _Digits);
      d[i][2] = DoubleToString(NormalizeDouble(rates[i].low        , _Digits), _Digits);
      d[i][3] = DoubleToString(NormalizeDouble(rates[i].close      , _Digits), _Digits);
      d[i][4] = DoubleToString(NormalizeDouble(rates[i].tick_volume, _Digits), _Digits);
      d[i][5] = DoubleToString(NormalizeDouble(rates[i].real_volume, _Digits), _Digits);
   }
   
   ResetLastError();
   fileCSV.Open(PATH(SEND_ARCHIVE), FILE_WRITE|FILE_SHARE_READ|FILE_ANSI, 44);
      
   if((fileCSV.WriteHeader(h) < 1 & fileCSV.WriteLine(d) < 1) != 0)
      Print("Error : ", GetLastError());
   
   fileCSV.Close();

   while(!fileCSV.IsExist(PATH(SEND_OK_ARCHIVE)))
   {
      //waiting for startup
      Comment("waiting for startup");
   }
   
   int fileHandle = fileCSV.Open(PATH(SEND_OK_ARCHIVE), FILE_READ | FILE_CSV | FILE_ANSI);
   if(fileHandle != INVALID_HANDLE)
      result = StringToInteger(fileCSV.Read()) == 1;
   fileCSV.Close();
   
   fileCSV.Delete(PATH(SEND_ARCHIVE));
   fileCSV.Delete(PATH(SEND_OK_ARCHIVE));
   
   return(result);
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
