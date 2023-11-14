# -*- coding: utf-8 -*-

import socket, numpy as np
import pickle
import pandas as pd
import pandas_ta as ta
from scipy.signal import savgol_filter
import json
from datetime import datetime



class socketserver:
    def __init__(self, address = '', port = 9091):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.address = address
        self.port = port
        self.sock.bind((self.address, self.port))
        self.msg = ''
        self.loaded_model = pickle.load(open('xgb_modelo_svg_ma.pkl', 'rb'))
        
    def recvmsg(self):
        self.sock.listen(1)
        self.conn, self.addr = self.sock.accept()
        print('connected to', self.addr)
        self.msg = ''

        while True:
            data = self.conn.recv(30000)
            self.msg = data.decode("utf-8")
            if not data:
                break   
            print(self.msg)
            self.conn.send(predict(self.msg, self.loaded_model).encode())
            return self.msg
            
    def __del__(self):
        self.sock.close()
        
def predict(msg, model):
    df= pd.DataFrame()
    try:
        dic = eval(str(msg).replace("'", "\""))
        df = pd.DataFrame.from_dict(dic.values())
        # df = pd.read_json(msg)
    except Exception as e:
        print("erro no json: ",e)
        return "False"

    df_f = pd.DataFrame()
    df_f = pd.concat([df[['volume']],df_f], axis=1)
    df_f = pd.concat([df.ta.rsi(length=6),df_f], axis=1)
    df_f = pd.concat([df.ta.rsi(length=2),df_f], axis=1)
    df_f = pd.concat([df.ta.true_range(),df_f], axis=1)
    df_f = pd.concat([df.ta.willr(),df_f], axis=1)
    df_f = pd.concat([df.ta.adx(),df_f], axis=1)
    df_f = pd.concat([df.ta.stochrsi(),df_f], axis=1)
    df_f['SAVGOL'] = df['close'] - savgol_filter(df['close'],13,3)
    df_f = pd.concat([df.ta.obv(),df_f], axis=1)
    df_f = pd.concat([df.ta.slope(),df_f], axis=1)
    df_f = pd.concat([df.ta.ohlc4(),df_f], axis=1)
    result_proba = model.predict_proba(df_f.iloc[-1].values.reshape(1, -1))
    Y_pred= (result_proba[:,1] > 0.55)
    print(datetime.now().strftime("%m/%d/%Y, %H:%M:%S") +" - "+ str(Y_pred[0]))
    return str(Y_pred[0])
    
serv = socketserver('127.0.0.1', 9091)

while True:  
    msg = serv.recvmsg()

        
        

    
