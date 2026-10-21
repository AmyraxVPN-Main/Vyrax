package outbound

import (
	"context"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	C "github.com/metacubex/mihomo/constant"
)

func TestHTTP2ConnectDuplexAndDialContextLifetime(t *testing.T) {
	seen := make(chan string, 1)
	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen <- r.Method + " " + r.Host + " " + r.Header.Get("Proxy-Authorization")
		if r.ProtoMajor != 2 {
			t.Errorf("expected HTTP/2, got %s", r.Proto)
		}
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		buffer := make([]byte, 4)
		if _, err := io.ReadFull(r.Body, buffer); err != nil {
			return
		}
		_, _ = w.Write(buffer)
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	}))
	server.EnableHTTP2 = true
	server.StartTLS()
	defer server.Close()
	host, portString, _ := net.SplitHostPort(server.Listener.Addr().String())
	port, _ := strconv.Atoi(portString)
	proxy, err := NewHttp(HttpOption{Name: "h2-test", Server: host, Port: port, TLS: true,
		Network: "h2", SkipCertVerify: true, Headers: map[string]string{"Proxy-Authorization": "Bearer synthetic-pass"}})
	if err != nil {
		t.Fatal(err)
	}
	raw, err := net.Dial("tcp", server.Listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := proxy.StreamConnContext(ctx, raw, &C.Metadata{Host: "example.com", DstPort: 443})
	if err != nil {
		_ = raw.Close()
		t.Fatal(err)
	}
	defer conn.Close()
	cancel()
	_ = conn.SetDeadline(time.Now().Add(5 * time.Second))
	if _, err := conn.Write([]byte("ping")); err != nil {
		t.Fatal(err)
	}
	buffer := make([]byte, 4)
	if _, err := io.ReadFull(conn, buffer); err != nil {
		t.Fatal(err)
	}
	if string(buffer) != "ping" {
		t.Fatalf("unexpected response %q", buffer)
	}
	if value := <-seen; value != "CONNECT example.com:443 Bearer synthetic-pass" {
		t.Fatal(value)
	}
	if err := conn.Close(); err != nil {
		t.Fatal(err)
	}
}

func TestHTTP2ConnectRejectsBadStatusAndProtocol(t *testing.T) {
	for _, h2 := range []bool{true, false} {
		t.Run(strconv.FormatBool(h2), func(t *testing.T) {
			server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusProxyAuthRequired)
			}))
			server.EnableHTTP2 = h2
			server.StartTLS()
			defer server.Close()
			host, portString, _ := net.SplitHostPort(server.Listener.Addr().String())
			port, _ := strconv.Atoi(portString)
			proxy, err := NewHttp(HttpOption{Name: "h2-test", Server: host, Port: port, TLS: true, Network: "h2", SkipCertVerify: true})
			if err != nil {
				t.Fatal(err)
			}
			raw, err := net.Dial("tcp", server.Listener.Addr().String())
			if err != nil {
				t.Fatal(err)
			}
			defer raw.Close()
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_, err = proxy.StreamConnContext(ctx, raw, &C.Metadata{Host: "example.com", DstPort: 443})
			if err == nil {
				t.Fatal("expected refusal")
			}
			if h2 && !strings.Contains(err.Error(), "407") {
				t.Fatal(err)
			}
		})
	}
}

func TestHTTP2ConnectRequiresTLS(t *testing.T) {
	_, err := NewHttp(HttpOption{Name: "h2-test", Server: "example.com", Port: 80, Network: "h2"})
	if err == nil {
		t.Fatal("cleartext HTTP/2 must not be accepted")
	}
}
