package core

import (
	"os"
	"path/filepath"
	"testing"
)

func TestMozillaMarkerSurvivesRawConfig(t *testing.T) {
	path := filepath.Join(t.TempDir(), "mozilla.yaml")
	if err := os.WriteFile(path, []byte("proxies:\n  - name: example\n    type: http\n    server: example.fastly-masque.net\n    port: 443\n    tls: true\n    network: h2\n    x-flclash-mozilla: true\n"), 0600); err != nil {
		t.Fatal(err)
	}
	raw, err := handleGetConfig(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(raw.Proxy) != 1 || raw.Proxy[0]["x-flclash-mozilla"] != true || raw.Proxy[0]["network"] != "h2" {
		t.Fatalf("runtime marker was lost: %#v", raw.Proxy)
	}
}
