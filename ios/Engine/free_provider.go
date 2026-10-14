// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
package engine

import (
 "bytes"
 "encoding/json"
 "errors"
 "io"
 "net/http"
 "strings"
 "time"
)

var providerEndpoints = map[string][2]string{
 "login":{"POST","https://api.accounts.firefox.com/v1/account/login"},
 "verify":{"POST","https://api.accounts.firefox.com/v1/session/verify_code"},
 "oauth":{"POST","https://api.accounts.firefox.com/v1/oauth/token"},
 "servers":{"GET","https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/vpn-serverlist/records"},
 "status":{"GET","https://vpn.mozilla.org/api/v1/fpn/status"},
 "activate":{"POST","https://vpn.mozilla.org/api/v1/fpn/activate"},
 "token":{"GET","https://vpn.mozilla.org/api/v1/fpn/token"},
}

func providerRequest(raw json.RawMessage)(any,error) {
 mu.RLock();s:=server;mu.RUnlock()
 cl:=client(s,"",15*time.Second)
 defer cl.CloseIdleConnections()
 // Never forward authentication across a redirect or retain clearance cookies.
 cl.CheckRedirect=func(*http.Request,[]*http.Request)error{return http.ErrUseLastResponse}
 return providerRequestWithClient(raw,cl)
}

func providerRequestWithClient(raw json.RawMessage,cl *http.Client)(any,error) {
 var args struct{Endpoint string `json:"endpoint"`;Body string `json:"body"`;Authorization string `json:"authorization"`}
 if json.Unmarshal(raw,&args)!=nil{return nil,errors.New("err.action")}
 endpoint,ok:=providerEndpoints[args.Endpoint]
 if !ok||len(args.Body)>32768||len(args.Authorization)>32768||strings.ContainsAny(args.Authorization,"\r\n"){return nil,errors.New("err.action")}
 request,err:=http.NewRequest(endpoint[0],endpoint[1],bytes.NewBufferString(args.Body))
 if err!=nil{return nil,errors.New("err.action")}
 request.Header.Set("Content-Type","application/json")
 request.Header.Set("Accept","application/json")
 request.Header.Set("User-Agent","Vyrax Firefox-compatible client")
 if args.Authorization!=""{request.Header.Set("Authorization",args.Authorization)}
 response,err:=cl.Do(request)
 if err!=nil{return nil,errors.New("err.freeNetwork")}
 defer response.Body.Close()
 body,err:=io.ReadAll(io.LimitReader(response.Body,1048577))
 if err!=nil{return nil,errors.New("err.freeNetwork")}
 if len(body)>1048576{return nil,errors.New("err.tooBig")}
 headers:=map[string]string{}
 for _,name:=range []string{"x-quota-limit","x-quota-remaining","x-quota-reset"}{headers[name]=response.Header.Get(name)}
 return map[string]any{"status":response.StatusCode,"body":string(body),"headers":headers},nil
}
