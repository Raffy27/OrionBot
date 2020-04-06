object Net: TNet
  OldCreateOrder = False
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 359
  Width = 407
  object HTTPClient: TIdHTTP
    IOHandler = IOHandler
    AllowCookies = True
    ProxyParams.BasicAuthentication = False
    ProxyParams.ProxyPort = 0
    Request.ContentLength = -1
    Request.ContentRangeEnd = -1
    Request.ContentRangeStart = -1
    Request.ContentRangeInstanceLength = -1
    Request.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    Request.BasicAuthentication = False
    Request.UserAgent = 
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:68.0) Gecko/2010010' +
      '1 Firefox/68.0'
    Request.Username = 'aa'
    Request.Ranges.Units = 'bytes'
    Request.Ranges = <>
    HTTPOptions = [hoForceEncodeParams]
    Left = 152
    Top = 104
  end
  object TorInfo: TIdSocksInfo
    Host = '127.0.0.1'
    Port = 9050
    Version = svSocks5
    Left = 152
    Top = 152
  end
  object IOHandler: TIdSSLIOHandlerSocketOpenSSL
    MaxLineAction = maException
    Port = 0
    DefaultPort = 0
    SSLOptions.Method = sslvSSLv23
    SSLOptions.SSLVersions = [sslvSSLv2, sslvSSLv3, sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2]
    SSLOptions.Mode = sslmClient
    SSLOptions.VerifyMode = []
    SSLOptions.VerifyDepth = 0
    Left = 72
    Top = 104
  end
  object XMLDoc: TXMLDocument
    NodeIndentStr = #9
    Left = 72
    Top = 152
  end
end
