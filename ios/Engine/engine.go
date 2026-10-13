// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
package engine

import (
 "context"
 "crypto/sha256"
 "encoding/hex"
 "encoding/json"
 "errors"
 "io"
 "net"
 "net/http"
 "net/url"
 "runtime/debug"
 "strings"
 "sync"
 "time"

 "github.com/xtls/xray-core/common/serial"
 "github.com/xtls/xray-core/common/session"
 xnet "github.com/xtls/xray-core/common/net"
 "github.com/xtls/xray-core/core"
 "github.com/xtls/xray-core/features/outbound"
 "github.com/xtls/xray-core/features/routing"
 "github.com/xtls/xray-core/infra/conf"
 _ "github.com/xtls/xray-core/main/distro/all"
)

const maxBody = 4 * 1024 * 1024
var mu sync.RWMutex
var server *core.Instance
var nodes = map[string]string{}
var probeRefs = map[string]int{}
var probes = make(chan struct{}, 2)
var probeURL = "https://www.gstatic.com/generate_204"

func init() { debug.SetMemoryLimit(32*1024*1024); debug.SetGCPercent(50) }

// The app and extension are separate processes, each with one Go runtime.
// In the extension, every probe uses the live instance; it never starts a
// competing core or changes Xray's process-global DNS resolver.
func Invoke(text string) string {
 var req struct { Method string `json:"method"`; Payload json.RawMessage `json:"payload"` }
 var data any
 var err error
 if len(text)>8*1024*1024 || json.Unmarshal([]byte(text), &req)!=nil { err=errors.New("err.config") } else {
  switch req.Method {
  case "start": err=start(req.Payload); data=true
  case "stop": mu.Lock(); if server!=nil { err=server.Close();server=nil };nodes=map[string]string{};mu.Unlock();data=true
  case "select": err=selectConfig(req.Payload);data=true
  case "delay": data,err=delay(req.Payload)
  case "http": data,err=download(req.Payload)
  default: err=errors.New("err.action")
  }
 }
 result:=map[string]any{"result":data};if err!=nil { result=map[string]any{"error":safeError(err)} }
 out,_:=json.Marshal(result);return string(out)
}

func safeError(err error) string {
 // Core errors can contain credentials, configuration fragments or URLs.
 if strings.HasPrefix(err.Error(),"err.") { return err.Error() }
 return "err.core"
}

func decodeConfig(raw json.RawMessage) (*conf.Config,error) {
 var c conf.Config
 if err:=json.Unmarshal(raw,&c);err!=nil {return nil,errors.New("err.config")}
 if len(c.OutboundConfigs)==0 || len(c.OutboundConfigs)>513 || len(c.InboundConfigs)>1 {return nil,errors.New("err.catalog")}
 for _,in:=range c.InboundConfigs { if in.Protocol!="socks" || in.ListenOn==nil || in.ListenOn.String()!="127.0.0.1" {return nil,errors.New("err.config")} }
 return &c,nil
}
func start(raw json.RawMessage) error {
 mu.Lock();defer mu.Unlock()
 if server!=nil {return errors.New("err.busy")}
 c,err:=decodeConfig(raw);if err!=nil{return err}
 built,err:=c.Build();if err!=nil{return err}
 s,err:=core.New(built);if err!=nil{return err}
 if err=s.Start();err!=nil{s.Close();return err}
 server=s;nodes=map[string]string{}
 for _,o:=range c.OutboundConfigs {b,_:=json.Marshal(o);nodes[o.Tag]=string(b)}
 return nil
}
func selectConfig(raw json.RawMessage) error {
 mu.Lock();defer mu.Unlock()
 if server==nil {return errors.New("err.notConnected")}
 c,err:=decodeConfig(raw);if err!=nil{return err}
 if c.RouterConfig==nil{return errors.New("err.config")}
 route,err:=c.RouterConfig.Build();if err!=nil{return err}
 for _,o:=range c.OutboundConfigs {
  b,_:=json.Marshal(o);if nodes[o.Tag]==string(b){continue}
  if len(nodes)>=513 {return errors.New("err.catalog")}
  built,err:=o.Build();if err!=nil{return err}
  // Tag identity is immutable for the lifetime of this tunnel. A changed node
  // requires reconnecting, rather than closing an existing user's stream.
  if _,exists:=nodes[o.Tag];exists{return errors.New("err.config")}
  if err=core.AddOutboundHandler(server,built);err!=nil{return err}
  nodes[o.Tag]=string(b)
 }
 return server.GetFeature(routing.RouterType()).(routing.Router).AddRule(serial.ToTypedMessage(route),false)
}

func client(s *core.Instance, tag string, timeout time.Duration) *http.Client {
 tr:=&http.Transport{DisableKeepAlives:true,Proxy:nil}
 if s!=nil { tr.DialContext=func(ctx context.Context,network,address string)(net.Conn,error){
  dst,err:=xnet.ParseDestination("tcp:"+address);if err!=nil{return nil,err}
  if tag!="" {ctx=session.SetForcedOutboundTagToContext(ctx,tag)}
  return core.Dial(ctx,s,dst)
 } }
 return &http.Client{Transport:tr,Timeout:timeout,CheckRedirect:func(r *http.Request,via []*http.Request)error{
  if len(via)>=5 || !validURL(r.URL) {return errors.New("err.subFailed")}
  if via[0].URL.Scheme=="https" && r.URL.Scheme!="https" {return errors.New("err.subFailed")}
  return nil
 }}
}
func validURL(u *url.URL)bool {return u!=nil && (u.Scheme=="https"||u.Scheme=="http") && u.Hostname()!="" && u.User==nil}

func delay(raw json.RawMessage)(any,error) {
 probes<-struct{}{};defer func(){<-probes}()
 var o conf.OutboundDetourConfig
 if json.Unmarshal(raw,&o)!=nil{return nil,errors.New("err.config")}
 o.Tag="probe";b,_:=json.Marshal(o);hash:=sha256.Sum256(b);tag:="probe-"+hex.EncodeToString(hash[:12]);o.Tag=tag
 mu.Lock()
 s:=server;temporary:=false
 if s==nil {
  c:=&conf.Config{OutboundConfigs:[]conf.OutboundDetourConfig{o}}
  built,err:=c.Build();if err!=nil{mu.Unlock();return nil,err}
  s,err=core.New(built);if err!=nil{mu.Unlock();return nil,err}
  if err=s.Start();err!=nil{s.Close();mu.Unlock();return nil,err}
  // Disconnected probes run serially, protecting Xray's global DNS state.
  temporary=true
 } else {
  if _,ok:=nodes[tag];!ok {
   built,err:=o.Build();if err!=nil{mu.Unlock();return nil,err}
   if err=core.AddOutboundHandler(s,built);err!=nil{mu.Unlock();return nil,err}
   nodes[tag]=string(b)
  }
  probeRefs[tag]++
  mu.Unlock()
 }
 if temporary {defer func(){s.Close();mu.Unlock()}()} else {defer func(){
  mu.Lock();defer mu.Unlock()
  if server==s {probeRefs[tag]--;if probeRefs[tag]==0 {s.GetFeature(outbound.ManagerType()).(outbound.Manager).RemoveHandler(context.Background(),tag);delete(probeRefs,tag);delete(nodes,tag)}}
 }()}
 cl:=client(s,tag,8*time.Second);defer cl.CloseIdleConnections()
 start:=time.Now();r,err:=cl.Get(probeURL)
 if err!=nil{return map[string]any{"latency":nil},nil};defer r.Body.Close()
 if r.StatusCode!=204{return map[string]any{"latency":nil},nil}
 return map[string]any{"latency":max(int64(1),time.Since(start).Milliseconds())},nil
}

func download(raw json.RawMessage)(any,error) {
 var req struct{URL string `json:"url"`;Update bool `json:"update"`}
 if json.Unmarshal(raw,&req)!=nil{return nil,errors.New("err.subFailed")}
 u,err:=url.Parse(req.URL);if err!=nil||!validURL(u){return nil,errors.New("err.subFailed")}
 mu.RLock();s:=server;mu.RUnlock()
 tags:=[]string{"direct"};if s!=nil{tags=append(tags,"")}
 for _,tag:=range tags{
  cl:=client(s,tag,10*time.Second)
  r,err:=cl.Get(req.URL)
  if err!=nil{cl.CloseIdleConnections();continue}
  if req.Update&&r.StatusCode==404{r.Body.Close();cl.CloseIdleConnections();return map[string]any{"release":nil},nil}
  if r.StatusCode!=200{r.Body.Close();cl.CloseIdleConnections();continue}
  body,err:=io.ReadAll(io.LimitReader(r.Body,maxBody+1));r.Body.Close();cl.CloseIdleConnections()
  if err!=nil||len(body)>maxBody{continue}
  if req.Update{
   if len(body)>262144{return nil,errors.New("err.subFailed")}
   var release any;if json.Unmarshal(body,&release)!=nil{return nil,errors.New("err.subFailed")};return map[string]any{"release":release},nil
  }
  return map[string]any{"text":string(body),"title":r.Header.Get("profile-title"),"disposition":r.Header.Get("content-disposition"),"userInfo":r.Header.Get("subscription-userinfo")},nil
 }
 return nil,errors.New("err.subFailed")
}
