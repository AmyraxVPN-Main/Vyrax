package engine
import (
 "encoding/json"
 "fmt"
 "net/http"
 "net/http/httptest"
 "strings"
 "sync"
 "testing"
)
func invokeTest(t *testing.T,method string,payload any)map[string]any{
 t.Helper();request,_:=json.Marshal(map[string]any{"method":method,"payload":payload});var result map[string]any
 if err:=json.Unmarshal([]byte(Invoke(string(request))),&result);err!=nil{t.Fatal(err)}
 return result
}
func TestSubscriptionsAndLiveProbes(t *testing.T){
 endpoint:=httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter,r *http.Request){
  if r.URL.Path=="/ping"{w.WriteHeader(204);return}
  w.Header().Set("profile-title","base64:VGVzdA==");w.Header().Set("subscription-userinfo","upload=1; download=2; total=3");fmt.Fprint(w,"vless://synthetic-fixture")
 }));defer endpoint.Close()
 oldURL:=probeURL;probeURL=endpoint.URL+"/ping";defer func(){probeURL=oldURL}()
 result:=invokeTest(t,"http",map[string]any{"url":endpoint.URL})
 if result["error"]!=nil||result["result"].(map[string]any)["title"]!="base64:VGVzdA=="{t.Fatal("subscription metadata failed")}
 config:=json.RawMessage(`{"log":{"loglevel":"none"},"outbounds":[{"tag":"direct","protocol":"freedom"}],"routing":{"rules":[{"type":"field","network":"tcp,udp","outboundTag":"direct"}]}}`)
 if r:=invokeTest(t,"start",config);r["error"]!=nil{t.Fatal(r)}
 defer invokeTest(t,"stop",map[string]any{})
 var wg sync.WaitGroup
 for i:=0;i<2;i++{wg.Add(1);go func(){defer wg.Done();r:=invokeTest(t,"delay",map[string]any{"protocol":"freedom"});if r["error"]!=nil||r["result"].(map[string]any)["latency"]==nil{t.Error("live through-core HTTP probe failed")}}()};wg.Wait()
 if len(nodes)!=1||len(probeRefs)!=0{t.Fatal("probe handlers leaked")}
 blocked:=invokeTest(t,"delay",map[string]any{"protocol":"blackhole"})
 if blocked["error"]!=nil||blocked["result"].(map[string]any)["latency"]!=nil{t.Fatal("delay must fail for blocked outbound")}
 // Atomically replace routing while preserving the running instance.
 if r:=invokeTest(t,"select",config);r["error"]!=nil{t.Fatal(r)}
 result=invokeTest(t,"http",map[string]any{"url":endpoint.URL})
 if result["error"]!=nil{t.Fatal("subscription failed while core active")}
}
func TestErrorsNeverExposePayload(t *testing.T){
 r:=Invoke(`{"method":"start","payload":{"outbounds":[{"protocol":"unknown","settings":{"password":"PRIVATE_FIXTURE"}}]}}`)
 if !strings.Contains(r,"err.core")||strings.Contains(r,"PRIVATE_FIXTURE"){t.Fatal("unsanitized error")}
 r=Invoke(`{"method":"http","payload":{"url":"file:///private"}}`)
 if !strings.Contains(r,"err.subFailed"){t.Fatal("unsafe URL accepted")}
}
