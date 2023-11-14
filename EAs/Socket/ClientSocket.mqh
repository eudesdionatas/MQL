//+------------------------------------------------------------------+
//|                                                CClientSocket.mqh |
//|                                     Copyright 2021, Lethan Corp. |
//|                           https://www.mql5.com/pt/users/14134597 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Lethan Corp."
#property link      "https://www.mql5.com/pt/users/14134597"
#property version   "1.00"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CClientSocket
  {
private:
   static CClientSocket*  m_socket;
   int                    m_handler_socket;
   int                    m_port;
   string                 m_host;
   int                    m_time_out;
                     CClientSocket(void);
                    ~CClientSocket(void);
public:
   static bool           DeleteSocket(void);
   bool                  SocketSend(string payload);
   string                SocketReceive(void);
   bool                  IsConnected(void);
   static CClientSocket *Socket(void);
   bool                  Config(string host, int port);
   bool                  Close(void);
  };

CClientSocket *CClientSocket::m_socket;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CClientSocket::CClientSocket(void) : m_host("localhost"), m_port(9090), m_time_out(1000), m_handler_socket(INVALID_HANDLE)
  {

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CClientSocket::~CClientSocket(void)
  {
   ::SocketClose(m_handler_socket);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static CClientSocket *CClientSocket::Socket(void)
  {
   if(CheckPointer(m_socket)==POINTER_INVALID)
      m_socket=new CClientSocket();
   return m_socket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CClientSocket::DeleteSocket(void)
  {
   bool res=CheckPointer(m_socket)!=POINTER_INVALID;
   if(res)
      delete m_socket;
   return res;
  }
//+------------------------------------------------------------------+
bool CClientSocket::SocketSend(string payload)
  {
   char req[];
   int  len=::StringToCharArray(payload,req)-1;
   if(len<0)
      return(false);
   return(::SocketSend(m_handler_socket,req,len)==len);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CClientSocket::SocketReceive(void)
  {
   char rsp[];
   string result = "";
   uint len;
   uint timeout_check=::GetTickCount()+m_time_out;
   do
     {
      len=::SocketIsReadable(m_handler_socket);
      if(len)
        {
         int rsp_len;
         rsp_len = ::SocketRead(m_handler_socket,rsp,len,m_time_out);
         if(rsp_len>0)
           {
            result+=::CharArrayToString(rsp,0,rsp_len);
           }
        }
     }
   while((::GetTickCount()<timeout_check) && !::IsStopped());
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CClientSocket::IsConnected(void)
  {
   ResetLastError();
   bool res=true;

   m_handler_socket=SocketCreate();
   if(m_handler_socket==INVALID_HANDLE)
      res=false;

   if(!::SocketConnect(m_handler_socket,m_host,m_port,m_time_out))
      res=false;

   return res;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CClientSocket::Config(string host,int port)
  {
   bool res=true;

   m_host=host;
   m_port=port;

   if((m_host!=host&m_port!=port)!=0)
      res ^=true;

   return res;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CClientSocket::Close(void)
  {
   bool res=false;
   if(SocketClose(m_handler_socket))
     {
      res=true;
      m_handler_socket=INVALID_HANDLE;
     }
   return res;
  }
//+------------------------------------------------------------------+
