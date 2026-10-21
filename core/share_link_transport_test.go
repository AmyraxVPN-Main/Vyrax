package core

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/url"
	"testing"
	"time"

	"github.com/metacubex/http"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/transport/gun"
	"github.com/metacubex/mihomo/transport/trojan"
	"github.com/metacubex/mihomo/transport/vmess"
)

func TestImportedTransportBatch(t *testing.T) {
	const id = "00000000-0000-4000-8000-000000000001"
	cases := []struct{ scheme, network, mode string }{
		{"vless", "xhttp", "stream-up"}, {"vless", "httpupgrade", ""},
		{"vmess", "httpupgrade", ""}, {"vless", "xhttp", "packet-up"},
		{"ss", "ws", ""}, {"vmess", "ws", ""}, {"trojan", "ws", ""},
		{"trojan", "httpupgrade", ""}, {"vmess", "grpc", ""},
		{"trojan", "grpc", ""}, {"vless", "grpc", ""},
	}
	for i, tc := range cases {
		t.Run(fmt.Sprint(i+1), func(t *testing.T) {
			q := url.Values{"security": {"none"}, "type": {tc.network}, "host": {"cdn.example.com"}, "path": {"/test=@fixture"}, "serviceName": {"test=@fixture"}}
			if tc.mode != "" {
				q.Set("mode", tc.mode)
			}
			link := fmt.Sprintf("%s://%s@example.com:8080?%s#Fixture", tc.scheme, id, q.Encode())
			if tc.scheme == "vmess" {
				path := "/test=@fixture"
				if tc.network == "grpc" {
					path = "test=@fixture"
				}
				body, _ := json.Marshal(map[string]any{"v": "2", "ps": "Fixture", "add": "example.com", "port": "8080", "id": id, "aid": "0", "scy": "auto", "net": tc.network, "host": "cdn.example.com", "path": path, "tls": ""})
				link = "vmess://" + base64.StdEncoding.EncodeToString(body)
			}
			if tc.scheme == "ss" {
				link = "ss://" + base64.RawStdEncoding.EncodeToString([]byte("aes-256-gcm:fixture")) + "@example.com:8080?plugin=" + url.QueryEscape("v2ray-plugin;mode=websocket;host=cdn.example.com;path=/test=@fixture;mux=0") + "#Fixture"
			}
			decoded := handleDecodeShareLinks([]string{link})
			if len(decoded[0]) != 1 {
				t.Fatal("link not decoded")
			}
			p := decoded[0][0]
			if tc.scheme == "ss" && lookupField(p, "plugin-opts.mux") != false {
				t.Fatal("disabled plugin mux lost")
			}
			parsed, err := adapter.ParseProxy(p)
			if err != nil {
				t.Fatalf("parse: %v", err)
			}
			defer parsed.Close()
			if tc.network == "httpupgrade" {
				if p["network"] != "ws" || lookupField(p, "ws-opts.v2ray-http-upgrade") != true {
					t.Fatal("upgrade lost")
				}
			}
			if tc.scheme == "trojan" && p["skip-tls"] != true {
				t.Fatal("plaintext lost")
			}
			if tc.network == "xhttp" && lookupField(p, "xhttp-opts.mode") != tc.mode {
				t.Fatal("mode lost")
			}
			if tc.network == "ws" || tc.network == "httpupgrade" {
				pathKey, hostKey := "ws-opts.path", "ws-opts.headers.Host"
				if tc.scheme == "ss" {
					pathKey, hostKey = "plugin-opts.path", "plugin-opts.host"
				}
				if lookupField(p, pathKey) != "/test=@fixture" || lookupField(p, hostKey) != "cdn.example.com" {
					t.Fatal("path or host lost")
				}
			}
		})
	}
}

func TestPlainTrojanLocalTransportExchange(t *testing.T) {
	for _, network := range []string{"tcp", "ws", "httpupgrade", "grpc"} {
		t.Run(network, func(t *testing.T) {
			listener, err := net.Listen("tcp", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			defer listener.Close()
			serverResult := make(chan error, 1)
			handle := func(c net.Conn) {
				defer c.Close()
				_ = c.SetDeadline(time.Now().Add(5 * time.Second))
				key := trojan.Key("fixture")
				expected := append([]byte{}, key[:]...)
				expected = append(expected, '\r', '\n', trojan.CommandTCP, 3, 11)
				expected = append(expected, []byte("example.com")...)
				expected = append(expected, 0, 80, '\r', '\n')
				got := make([]byte, len(expected))
				_, err := io.ReadFull(c, got)
				if err == nil && !bytes.Equal(got, expected) {
					err = fmt.Errorf("wrong Trojan header")
				}
				payload := make([]byte, 4)
				if err == nil {
					_, err = io.ReadFull(c, payload)
				}
				if err == nil && string(payload) != "ping" {
					err = fmt.Errorf("wrong payload")
				}
				if err == nil {
					_, err = c.Write([]byte("pong"))
				}
				serverResult <- err
			}
			var server *http.Server
			if network == "tcp" {
				go func() {
					c, err := listener.Accept()
					if err != nil {
						serverResult <- err
						return
					}
					handle(c)
				}()
			} else {
				handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					if r.Host != "cdn.example.com" || r.URL.Path != "/test" {
						serverResult <- fmt.Errorf("wrong HTTP host/path")
						w.WriteHeader(400)
						return
					}
					c, err := vmess.StreamUpgradedWebsocketConn(w, r)
					if err != nil {
						serverResult <- err
						return
					}
					handle(c)
				})
				var h http.Handler = handler
				protocols := new(http.Protocols)
				protocols.SetHTTP1(true)
				if network == "grpc" {
					protocols.SetUnencryptedHTTP2(true)
					h = gun.NewServerHandler(gun.ServerOption{ServiceName: "test", ConnHandler: handle})
				}
				server = &http.Server{Handler: h, Protocols: protocols, ReadHeaderTimeout: 5 * time.Second}
				go server.Serve(listener)
				defer server.Close()
			}
			port := listener.Addr().(*net.TCPAddr).Port
			opt := outbound.TrojanOption{Name: "fixture", Server: "127.0.0.1", Port: port, Password: "fixture", SkipTLS: true, Network: network, SNI: "cdn.example.com", WSOpts: outbound.WSOptions{Path: "/test", Headers: map[string]string{"Host": "cdn.example.com"}}, GrpcOpts: outbound.GrpcOptions{GrpcServiceName: "test"}}
			if network == "httpupgrade" {
				opt.Network = "ws"
				opt.WSOpts.V2rayHttpUpgrade = true
			}
			proxy, err := outbound.NewTrojan(opt)
			if err != nil {
				t.Fatal(err)
			}
			defer proxy.Close()
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			conn, err := proxy.DialContext(ctx, &C.Metadata{NetWork: C.TCP, Host: "example.com", DstPort: 80})
			if err != nil {
				t.Fatal(err)
			}
			defer conn.Close()
			_ = conn.SetDeadline(time.Now().Add(5 * time.Second))
			if _, err = conn.Write([]byte("ping")); err != nil {
				t.Fatal(err)
			}
			response := make([]byte, 4)
			if _, err = io.ReadFull(conn, response); err != nil {
				t.Fatal(err)
			}
			if string(response) != "pong" {
				t.Fatal("wrong response")
			}
			if err = <-serverResult; err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestTrojanKeepsTLSByDefault(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	first := make(chan byte, 1)
	go func() {
		c, err := listener.Accept()
		if err != nil {
			first <- 0
			return
		}
		defer c.Close()
		_ = c.SetDeadline(time.Now().Add(5 * time.Second))
		var b [1]byte
		_, _ = io.ReadFull(c, b[:])
		first <- b[0]
	}()
	proxy, err := outbound.NewTrojan(outbound.TrojanOption{Name: "fixture", Server: "127.0.0.1", Port: listener.Addr().(*net.TCPAddr).Port, Password: "fixture"})
	if err != nil {
		t.Fatal(err)
	}
	defer proxy.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := proxy.DialContext(ctx, &C.Metadata{NetWork: C.TCP, Host: "example.com", DstPort: 80})
	if conn != nil {
		conn.Close()
	}
	if err == nil {
		t.Fatal("expected an incomplete TLS handshake to fail")
	}
	if <-first != 22 {
		t.Fatal("default connection did not send a TLS handshake")
	}
}
