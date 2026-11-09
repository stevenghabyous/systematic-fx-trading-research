//+------------------------------------------------------------------+
//|                                           SG_IchimokuCross.mq5   |
//|                                                                  |
//|  Candidate 18 from the SG rule search, as a native MT5 Expert     |
//|  Advisor. Same rule as Live_EURUSD_4H_SG_IchimokuCross.py, but    |
//|  runs inside the terminal so it needs no Python and can be        |
//|  hosted on the MT5 VPS.                                           |
//|                                                                  |
//|  READ THIS FIRST                                                 |
//|  This strategy did NOT pass validation. Across 400 Monte Carlo    |
//|  paths it sat at the 79th percentile of what the same rule earns  |
//|  on structureless noise, when the best of 20 screened candidates  |
//|  should reach the 95th percentile by chance alone. Noise turns a  |
//|  profit about half the time on this instrument. Run on DEMO.      |
//|                                                                  |
//|  THE RULE                                                        |
//|    Long  : Tenkan-sen crosses ABOVE Kijun-sen on a closed bar     |
//|    Short : Tenkan-sen crosses BELOW Kijun-sen                     |
//|    Exit  : take profit or stop loss only. No time exit, and an    |
//|            opposite cross does NOT close the position.            |
//|    TP    : 1.1029%   SL : 0.9159%                                 |
//+------------------------------------------------------------------+
#property copyright "SG"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- inputs
input int    InpTenkan      = 9;         // Tenkan-sen period (Conversion)
input int    InpKijun       = 26;        // Kijun-sen period (Base)
input int    InpSenkouB     = 52;        // Senkou Span B period (unused by the rule)
input double InpTpPercent   = 1.1029;    // Take profit, percent of entry
input double InpSlPercent   = 0.9159;    // Stop loss, percent of entry
input double InpLot         = 0.01;      // Lot size
input ulong  InpMagic       = 18;        // Magic number, identifies our positions
input ulong  InpSlippage    = 20;        // Max deviation in points

//--- globals
int      g_ichimoku = INVALID_HANDLE;
datetime g_last_bar = 0;
CTrade   g_trade;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_ichimoku = iIchimoku(_Symbol, _Period, InpTenkan, InpKijun, InpSenkouB);
   if(g_ichimoku == INVALID_HANDLE)
     {
      Print("ERROR: could not create Ichimoku handle");
      return(INIT_FAILED);
     }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   PrintFormat("SG Ichimoku Cross started | %s %s | lot %.2f | TP %.4f%% SL %.4f%%",
               _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period),
               InpLot, InpTpPercent, InpSlPercent);
   Print("DEMO PLUMBING TEST. This strategy failed its noise comparison.");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_ichimoku != INVALID_HANDLE)
      IndicatorRelease(g_ichimoku);
  }

//+------------------------------------------------------------------+
//| Only act once per bar, at the moment a new one opens.            |
//| This mirrors the backtest: the signal comes from the bar that     |
//| just CLOSED, and the fill happens at the new bar's open.          |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime t = iTime(_Symbol, _Period, 0);
   if(t == 0)
      return(false);          // history not ready yet
   if(t == g_last_bar)
      return(false);
   g_last_bar = t;
   return(true);
  }

//+------------------------------------------------------------------+
//| Do we already hold a position opened by THIS EA?                 |
//| Checked by magic number and symbol, so other strategies running   |
//| on the same account are ignored.                                  |
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(!IsNewBar())
      return;

   if(HasOpenPosition())
     {
      Print("already in a position, holding");
      return;
     }

   //--- Read Tenkan (buffer 0) and Kijun (buffer 1).
   //    Shift 0 is the bar now forming, so shift 1 is the bar that just closed
   //    and shift 2 is the one before it. Using shift 0 would read a bar with
   //    almost no data in it and would not match the backtest.
   double tenkan[], kijun[];
   ArraySetAsSeries(tenkan, true);
   ArraySetAsSeries(kijun,  true);

   if(CopyBuffer(g_ichimoku, 0, 1, 2, tenkan) < 2 ||
      CopyBuffer(g_ichimoku, 1, 1, 2, kijun)  < 2)
     {
      Print("WARNING: not enough Ichimoku data yet");
      return;
     }

   double conv_now  = tenkan[0], base_now  = kijun[0];   // last closed bar
   double conv_prev = tenkan[1], base_prev = kijun[1];   // the bar before it

   //--- A cross is a CHANGE of state, not merely being above or below.
   bool buy  = (conv_prev <= base_prev) && (conv_now > base_now);
   bool sell = (conv_prev >= base_prev) && (conv_now < base_now);

   PrintFormat("bar check | conv %.5f base %.5f (prev %.5f / %.5f) -> buy=%s sell=%s",
               conv_now, base_now, conv_prev, base_prev,
               buy ? "true" : "false", sell ? "true" : "false");

   if(!buy && !sell)
      return;

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double tp = 0.0, sl = 0.0;

   if(buy)
     {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      tp = NormalizeDouble(price * (1.0 + InpTpPercent / 100.0), digits);
      sl = NormalizeDouble(price * (1.0 - InpSlPercent / 100.0), digits);

      if(g_trade.Buy(InpLot, _Symbol, 0.0, sl, tp, "SG IchimokuCross"))
         PrintFormat("BUY %.2f at %.5f  TP %.5f  SL %.5f", InpLot, price, tp, sl);
      else
         PrintFormat("BUY FAILED retcode=%d  %s",
                     g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
     }
   else if(sell)
     {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      tp = NormalizeDouble(price * (1.0 - InpTpPercent / 100.0), digits);
      sl = NormalizeDouble(price * (1.0 + InpSlPercent / 100.0), digits);

      if(g_trade.Sell(InpLot, _Symbol, 0.0, sl, tp, "SG IchimokuCross"))
         PrintFormat("SELL %.2f at %.5f  TP %.5f  SL %.5f", InpLot, price, tp, sl);
      else
         PrintFormat("SELL FAILED retcode=%d  %s",
                     g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
     }
  }
//+------------------------------------------------------------------+
