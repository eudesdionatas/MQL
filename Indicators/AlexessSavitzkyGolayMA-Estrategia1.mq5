//+------------------------------------------------------------------+
//|                                         AlexessSavitzkyGolay.mq5 |
//|                                            Alexandre Silva Sousa |
//|                                                alexess@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Alexandre Silva Sousa"
#property link      "alexess@gmail.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   4

//--- plot SavitzkyGolay
#property indicator_label1 "SavitzkyGolay"
#property indicator_type1  DRAW_LINE
#property indicator_color1 clrBlue
#property indicator_style1 STYLE_DOT
#property indicator_width1 1
//--- plot MA
#property indicator_label2 "MA"
#property indicator_type2  DRAW_LINE
#property indicator_color2 clrRed
#property indicator_style2 STYLE_DOT
#property indicator_width2 1
//--- plot Middle
#property indicator_label3 "Middle"
#property indicator_type3  DRAW_LINE
#property indicator_color3 clrBrown
#property indicator_style3 STYLE_SOLID
#property indicator_width3 1

//---- plot candle
#property indicator_label4 "SGOpen;SGHigh;SGLow;SGClose"
#property indicator_type4  DRAW_COLOR_CANDLES
#property indicator_color4 clrNONE, clrLime, clrLightCoral, clrMediumSeaGreen, clrCrimson, clrGray, clrDarkGray

//--- defines
#define DAY_SECONDS 86400

//--- enumerators
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

//--- input parameters
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

//--- indicator buffers
double SavitzkyGolayB[];
double maB[];
double middleB[];

double openB [];
double highB [];
double lowB  [];
double closeB[];
double colorB[];

//--- Handles
int maHandle;

//--- constants
datetime cStartTime;
//--- vars
int day;
int dayLastColor;
int workedIndex;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, SavitzkyGolayB, INDICATOR_DATA);
   SetIndexBuffer(1, maB,     INDICATOR_DATA);
   SetIndexBuffer(2, middleB, INDICATOR_DATA);
   //---  candles
   SetIndexBuffer(3, openB,  INDICATOR_DATA);
   SetIndexBuffer(4, highB,  INDICATOR_DATA);
   SetIndexBuffer(5, lowB,   INDICATOR_DATA);
   SetIndexBuffer(6, closeB, INDICATOR_DATA);
   SetIndexBuffer(7, colorB, INDICATOR_COLOR_INDEX);
   
   // SavitzkyGolay line
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, iNP);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   //int shift = (int) MathFloor(iNP / 2);
   //PlotIndexSetInteger(0, PLOT_SHIFT, shift);
   //PlotIndexSetInteger(0, PLOT_SHIFT, 1);
   
   //ArraySetAsSeries(maB, false);
   ArrayInitialize(colorB, 0.0);
   
   maHandle = iMA(NULL, 0, iMAPeriod, iMAShift, iMAMethod, iAppliedPrice);
   if(maHandle == INVALID_HANDLE)
   {
      PrintFormat("iMA failed. Error code: %d", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- constants
   cStartTime = iStartTime % DAY_SECONDS;
   //--- vars
   day = 0;
   dayLastColor = 0;
   workedIndex = -1;
   
   //---
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //---
   if(rates_total < iNP)
      return(0);
   
   int start = prev_calculated - 1;
   int toCopy = rates_total - start;
   if(start < iNP)
   {
      start = iNP;
      toCopy = rates_total;
   }
   
   if(toCopy <= 0)
      toCopy = 1;
   if(CopyBuffer(maHandle, 0, (prev_calculated == 0 ? 0 : 0), toCopy, maB) <= 0)
   {
      Print("CopyBuffer MA handle faield! Error", GetLastError());
      return(rates_total);
   }
   
   
   
   int np;
   int today;
   datetime dayTime;
   int j;
   for(int i = start; i < rates_total && !IsStopped(); i++)
   {
      SavitzkyGolayB[i] = 0.0;
      
      openB [i] = open [i];
      highB [i] = high [i];
      lowB  [i] = low  [i];
      closeB[i] = close[i];
      colorB[i] = 0.0;
      
      np = i - (int) MathFloor(iNP / 2);
      if(iNP == NP_5)
         SavitzkyGolayB[ i] = (- 3*open[np-2]
                               +12*open[np-1]
                               +17*open[np]
                               +12*open[np+1]
                               -3*open[np+2]
                              )/35;
      /*else
      if(iNP == NP_7)
         SavitzkyGolayB[np] = (-2*open[np-3]
                               +3*open[np-2]
                               +6*open[np-1]
                               +7*open[np]
                               +6*open[np+1]
                               +3*open[np+2]
                               -2*open[np+3]
                              )/21;
      else
      if(iNP == NP_9)
         SavitzkyGolayB[np] = (-21*open[np-4]
                               +14*open[np-3]
                               +39*open[np-2]
                               +54*open[np-1]
                               +59*open[np]
                               +54*open[np+1]
                               +39*open[np+2]
                               +14*open[np+3]
                               -21*open[np+4]
                              )/231;
      else
      if(iNP == NP_11)
         SavitzkyGolayB[np] = (-36*open[np-5]
                               + 9*open[np-4]
                               +44*open[np-3]
                               +69*open[np-2]
                               +84*open[np-1]
                               +89*open[np]
                               +84*open[np+1]
                               +69*open[np+2]
                               +44*open[np+3]
                               + 9*open[np+4]
                               -36*open[np+5]
                              )/429;
      else
      if(iNP == NP_13)
         SavitzkyGolayB[np] = (-11*open[np-6]
                               + 0*open[np-5]
                               + 9*open[np-4]
                               +16*open[np-3]
                               +21*open[np-2]
                               +24*open[np-1]
                               +25*open[np]
                               +24*open[np+1]
                               +21*open[np+2]
                               +16*open[np+3]
                               + 9*open[np+4]
                               + 0*open[np+5]
                               -11*open[np+6]
                              )/143;
      */if(iNP == NP_15)
         SavitzkyGolayB[ i] = (- 78*open[np-7]
                               - 13*open[np-6]
                               + 42*open[np-5]
                               + 87*open[np-4]
                               +122*open[np-3]
                               +147*open[np-2]
                               +162*open[np-1]
                               +167*open[np]
                               +162*open[np+1]
                               +147*open[np+2]
                               +122*open[np+3]
                               + 87*open[np+4]
                               + 42*open[np+5]
                               - 13*open[np+6]
                               - 78*open[np+7]
                              )/1105;
      if(iNP == NP_25)
         SavitzkyGolayB[ i] = (-253*open[np-12]
                               -138*open[np-11]
                               - 33*open[np-10]
                               + 62*open[np-9]
                               +147*open[np-8]
                               +222*open[np-7]
                               +287*open[np-6]
                               +343*open[np-5]
                               +387*open[np-4]
                               +422*open[np-3]
                               +447*open[np-2]
                               +462*open[np-1]
                               +467*open[np]
                               +462*open[np+1]
                               +447*open[np+2]
                               +422*open[np+3]
                               +387*open[np+4]
                               +343*open[np+5]
                               +287*open[np+6]
                               +222*open[np+7]
                               +147*open[np+8]
                               + 62*open[np+9]
                               - 33*open[np+10]
                               -138*open[np+11]
                               -253*open[np+12]
                              )/5177.0;//)/5175;
      
      middleB[i] = MathMin(SavitzkyGolayB[i], maB[i]) + MathAbs(SavitzkyGolayB[i] - maB[i])/2;
      
      //--- candle
      today = (int) MathFloor(time[i] / DAY_SECONDS);
      
      dayTime = time[i] % DAY_SECONDS;
      if(/*i > workedIndex &&*/ iShowCandles && cStartTime < dayTime)
      {
         colorB[i] = colorB[i-1];
         
         /*
         if(iFilterInit && today != day)
         {
            day = today;
            
            dayLastColor = (int) colorB[i-1];
            if(dayLastColor > 2)
               dayLastColor -= 2;
            
            colorB[i] = 0.0;
            
            workedIndex = i;
         }
         /**/
         /*
         if(SavitzkyGolayB[ i-1] > 0.0)
         {
            //if(close[i-1] > SavitzkyGolayB[ i-1] && dayLastColor != 1)
            if(dayLastColor != 1 && (open[i] > SavitzkyGolayB[ i]))
            {
               colorB[i] = 1.0;
               dayLastColor = 0;
            }
            else
            //if(close[i-1] < SavitzkyGolayB[ i-1] && dayLastColor != 1)
            if(dayLastColor != 2 && (open[i] < SavitzkyGolayB[ i]))
            {
               colorB[i] = 2.0;
               dayLastColor = 0;
            }
            
         }
         /**/
         
         j = i-1;
         /*
         if((close[j] > middleB[j] && SavitzkyGolayB[j] > maB[i]) )//|| (close[j] > maB[j] && close[j] > SavitzkyGolayB[j]))
            colorB[i] = 1.0;
         else
         if((close[j] < middleB[j] && SavitzkyGolayB[j] < maB[j]) )//|| (close[j] < maB[j] && close[j] < SavitzkyGolayB[j]))
            colorB[i] = 2.0;
         /**/
         //if(MathAbs(SavitzkyGolayB[i] - maB[i]) < 50*Point())
         //   colorB[i] = 0.0;
         
         /*
         if((SavitzkyGolayB[j] < maB[j]) )//|| (close[j] > maB[j] && close[j] > SavitzkyGolayB[j]))
            colorB[i] = 1.0;
         else
         if((SavitzkyGolayB[j] > maB[j]) )//|| (close[j] < maB[j] && close[j] < SavitzkyGolayB[j]))
            colorB[i] = 2.0;
         else
            colorB[i] = 0.0;
         /**/
         /*
         if(middleB[j] > middleB[j-1] && close[j] > SavitzkyGolayB[j] && close[j] > maB[j])
            colorB[i] = 1.0;
         else
         if(middleB[j] < middleB[j-1] && close[j] < SavitzkyGolayB[j] && close[j] < maB[j])
            colorB[i] = 2.0;
         else
         {
            //if(middleB[j] > middleB[j-1] && close[j] > SavitzkyGolayB[j] && close[j] > maB[j])
            //   colorB[i] = 1.0;
            //else
            //if(middleB[j] < middleB[j-1] && close[j] < SavitzkyGolayB[j] && close[j] < maB[j])
            //   colorB[i] = 2.0;
            //else
            //   colorB[i] = 0.0;
         }
         /**/
         
         if(colorB[j] > 0)
            colorB[i] = colorB[j];
         
         if(colorB[i] == 0)
         {
            if(close[j] > SavitzkyGolayB[j] && (open[j] <= SavitzkyGolayB[j] ||close[j-1] <= SavitzkyGolayB[j-1]))
               colorB[i] = 1.0;
            else
            if(close[j] < SavitzkyGolayB[j] && (open[j] >= SavitzkyGolayB[j] ||close[j-1] >= SavitzkyGolayB[j-1]))
               colorB[i] = 2.0;
         }
         else
         if((colorB[j] == 1.0 || colorB[j] == 3.0) && close[j] < SavitzkyGolayB[j] && close[j] < maB[j])
            colorB[i] = 2.0;
         else
         if((colorB[j] == 2.0 || colorB[j] == 4.0) && close[j] > SavitzkyGolayB[j] && close[j] > maB[j])
            colorB[i] = 1.0;
         
         /*
         if(close[j] > SavitzkyGolayB[j])
            colorB[i] = 1.0;
         else
         if(close[j] < SavitzkyGolayB[j])
            colorB[i] = 2.0;
         */
         
         if(colorB[i] > 2)
            colorB[i] -= 2;
         if((colorB[i] == 1 || colorB[i] == 2) && close[i] < open[i])
            colorB[i] += 2;
      }
   }
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}