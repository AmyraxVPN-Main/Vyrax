package engine

import (
 "encoding/json"
 "io"
 "net/http"
 "strings"
 "testing"
)
type roundTripFunc func(*http.Request)(*http.Response,error)
func (f roundTripFunc) RoundTrip(r *http.Request)(*http.Response,error){return f(r)}
func TestProviderTransportIsFixedBoundedAndKeepsProtectionStatus(t *testing.T){
 calls:=0
 cl:=&http.Client{Transport:roundTripFunc(func(r *http.Request)(*http.Response,error){
  calls++
  if r.URL.String()!=providerEndpoints["login"][1]||r.Method!="POST"{t.Fatal("unexpected endpoint")}
  return &http.Response{StatusCode:406,Header:http.Header{},Body:io.NopCloser(strings.NewReader("<html>challenge</html>")),Request:r},nil
 })}
 raw:=json.RawMessage(`{"endpoint":"login","body":"{}"}`)
 result,err:=providerRequestWithClient(raw,cl)
 if err!=nil||result.(map[string]any)["status"]!=406||calls!=1{t.Fatal("protection must not cause credential retries")}
 for _,bad:=range []string{`{"endpoint":"https://example.test"}`,`{"endpoint":"login","authorization":"Bearer secret\r\nX-Injected: true"}`} {
  if _,err:=providerRequestWithClient(json.RawMessage(bad),cl);err==nil{t.Fatal("unsafe request accepted")}
 }
 if calls!=1{t.Fatal("invalid requests reached transport")}
 cl.Transport=roundTripFunc(func(r *http.Request)(*http.Response,error){return &http.Response{StatusCode:200,Header:http.Header{},Body:io.NopCloser(strings.NewReader(strings.Repeat("x",1048577))),Request:r},nil})
 if _,err:=providerRequestWithClient(raw,cl);err==nil||err.Error()!="err.tooBig"{t.Fatal("unbounded provider response")}
}
