package outbound

import (
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"sync"

	"github.com/metacubex/http"
	"github.com/metacubex/mihomo/common/contextutils"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/tls"
)

type httpH2Conn struct {
	net.Conn
	reader io.ReadCloser
	writer *io.PipeWriter
	cancel context.CancelFunc
	client *http.ClientConn
	once   sync.Once
}

func (c *httpH2Conn) Read(b []byte) (int, error)  { return c.reader.Read(b) }
func (c *httpH2Conn) Write(b []byte) (int, error) { return c.writer.Write(b) }
func (c *httpH2Conn) Close() error {
	c.once.Do(func() {
		c.cancel()
		_ = c.writer.Close()
		_ = c.reader.Close()
		_ = c.client.Close()
		_ = c.Conn.Close()
	})
	return nil
}

func (h *Http) streamH2(ctx context.Context, conn net.Conn, metadata *C.Metadata) (net.Conn, error) {
	if tc, ok := conn.(*tls.Conn); !ok || tc.ConnectionState().NegotiatedProtocol != "h2" {
		return nil, fmt.Errorf("HTTP/2 CONNECT: server did not negotiate h2")
	}
	protocols := new(http.Protocols)
	protocols.SetUnencryptedHTTP2(true)
	transport := &http.Transport{
		Protocols:      protocols,
		DialTLSContext: func(context.Context, string, string) (net.Conn, error) { return conn, nil },
	}
	client, err := transport.NewClientConn(ctx, "https", ":0")
	if err != nil {
		return nil, err
	}
	if err = client.Reserve(); err != nil {
		_ = client.Close()
		return nil, err
	}
	// The dialing deadline ends at CONNECT; the stream lives until Close.
	streamCtx, cancel := context.WithCancel(context.Background())
	reader, writer := io.Pipe()
	req, err := http.NewRequestWithContext(streamCtx, http.MethodConnect, "https://"+metadata.RemoteAddress(), reader)
	if err != nil {
		cancel()
		_ = reader.Close()
		_ = writer.Close()
		_ = client.Close()
		return nil, err
	}
	req.Host = metadata.RemoteAddress()
	req.ContentLength = -1
	for key, value := range h.option.Headers {
		req.Header.Set(key, value)
	}
	if h.user != "" && h.pass != "" {
		req.Header.Set("Proxy-Authorization", "Basic "+base64.StdEncoding.EncodeToString([]byte(h.user+":"+h.pass)))
	}
	stop := contextutils.AfterFunc(ctx, cancel)
	response, err := client.RoundTrip(req)
	stop()
	if err != nil || response.StatusCode != http.StatusOK {
		cancel()
		_ = reader.Close()
		_ = writer.Close()
		_ = client.Close()
		if response != nil {
			_ = response.Body.Close()
		}
		if err != nil {
			return nil, fmt.Errorf("HTTP/2 CONNECT failed: %w", err)
		}
		return nil, fmt.Errorf("HTTP/2 CONNECT refused: status %d", response.StatusCode)
	}
	return &httpH2Conn{Conn: conn, reader: response.Body, writer: writer, cancel: cancel, client: client}, nil
}
