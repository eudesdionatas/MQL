# -*- coding: utf-8 -*-

#import socket, numpy as np
import pickle
import pandas as pd
import pandas_ta as ta
from scipy.signal import savgol_filter
#import json
from datetime import datetime
import xgboost as xgb

import csv
import os
import time

def predict(df, model):
    df_f = pd.DataFrame()
    df_f = pd.concat([df[['volume']],      df_f], axis=1)
    df_f = pd.concat([df.ta.rsi(length=6), df_f], axis=1)
    df_f = pd.concat([df.ta.rsi(length=2), df_f], axis=1)
    df_f = pd.concat([df.ta.true_range(),  df_f], axis=1)
    df_f = pd.concat([df.ta.willr(),       df_f], axis=1)
    df_f = pd.concat([df.ta.adx(),         df_f], axis=1)
    df_f = pd.concat([df.ta.stochrsi(),    df_f], axis=1)
    df_f['SAVGOL'] = df['close'] - savgol_filter(df['close'],13,3)
    df_f = pd.concat([df.ta.obv(),         df_f], axis=1)
    df_f = pd.concat([df.ta.slope(),       df_f], axis=1)
    df_f = pd.concat([df.ta.ohlc4(),       df_f], axis=1)
    
    result_proba = model.predict_proba(df_f.iloc[-1].values.reshape(1, -1))
    Y_pred       = (result_proba[:,1] > 0.5)
    
    print(datetime.now().strftime("%m/%d/%Y, %H:%M:%S") +" - "+ str(Y_pred[0]))
    
    return str(Y_pred[0])

# alterar PATH_COMMON para o caminho correto na máquina em que o MT5 está rodando
PATH_COMMON     = r'C:\Users\alexe\AppData\Roaming\MetaQuotes\Tester\7AC693EA680DB1E02A35823334C1322E\Agent-127.0.0.1-3000\MQL5\Files\CSV\{}.csv'
SEND_ARCHIVE      = 'send'
SEND_TEMP_ARCHIVE = 'send_temp'
SEND_OK_ARCHIVE   = 'send_predict'

here = os.path.dirname(os.path.abspath(__file__))
filename = os.path.join(here, 'xgb_modelo_svg_ma.pkl')

#print(xgb.__version__)

try:
    model = pickle.load(open(filename, 'rb'))
except Exception as e:
    print("Erro ao carregar modelo: ", e)
    exit()


while True:
    
    cond1 = os.path.isfile(PATH_COMMON.format(SEND_ARCHIVE))
    cond2 = os.path.isfile(PATH_COMMON.format(SEND_OK_ARCHIVE))

    if cond1 and not cond2:
        try:
            df = pd.read_csv(PATH_COMMON.format(SEND_ARCHIVE), delimiter=',')
            #print(df)

            result = predict(df, model) == 'True'
            #print('result: {}'.format(result))
            #print(type(result))
            
            sendResult = open(PATH_COMMON.format(SEND_TEMP_ARCHIVE), 'w')
            sendResult.write('1' if result else '0')
            sendResult.close()
            
            os.renames(PATH_COMMON.format(SEND_TEMP_ARCHIVE), PATH_COMMON.format(SEND_OK_ARCHIVE));
            
            # tirar o comentário do comando atual quando estiver rodando na real (seja em conta demo ou não)
            #time.sleep(10)
        except Exception as e:
            print(datetime.now().strftime("%m/%d/%Y, %H:%M:%S") + " - erro analisando arquivo: ", e)
            #exit()
        
        #f = open(PATH_COMMON.format(SEND_TEMP_ARCHIVE), "x");
        #print('Create init checket file: {}'.format(f.name))
        #f.close();
        #os.renames(PATH_COMMON.format(SEND_TEMP_ARCHIVE), PATH_COMMON.format(SEND_OK_ARCHIVE));
        