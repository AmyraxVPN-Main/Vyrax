package core

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

func TestSubscriptionPreservesExtendedTransports(t *testing.T) {
	const id = "00000000-0000-4000-8000-000000000001"
	vmess, _ := json.Marshal(map[string]any{"v": "2", "ps": "Duplicate", "add": "example.com", "port": "8080", "id": id, "aid": "0", "scy": "auto", "net": "httpupgrade", "host": "cdn.example.com", "path": "/test", "tls": ""})
	links := []string{
		"vless://" + id + "@example.com:8080?security=none&type=xhttp&mode=stream-up#Duplicate",
		"vless://" + id + "@example.com:8080?security=none&type=httpupgrade&host=cdn.example.com&path=%2Ftest#Duplicate",
		"vmess://" + base64.StdEncoding.EncodeToString(vmess),
		"trojan://fixture@example.com:8080?security=none&type=httpupgrade&host=cdn.example.com&path=%2Ftest#Duplicate",
		"ss://" + base64.RawStdEncoding.EncodeToString([]byte("aes-256-gcm:fixture")) + "@example.com:8080?plugin=v2ray-plugin%3Bmode%3Dwebsocket%3Bmux%3D0#Duplicate",
	}
	plain := "\ufeff  " + strings.Join(links, "\r\n  ") + "\n"
	for _, content := range []string{plain, base64.StdEncoding.EncodeToString([]byte(plain)), base64.RawURLEncoding.EncodeToString([]byte(plain))} {
		proxies, err := convertSubscriptionLinks([]byte(content))
		if err != nil {
			t.Fatal(err)
		}
		if len(proxies) != len(links) {
			t.Fatalf("got %d nodes, want %d", len(proxies), len(links))
		}
		seen := map[string]bool{}
		for i, p := range proxies {
			want := "Duplicate"
			if i > 0 {
				want = fmt.Sprintf("Duplicate-%02d", i)
			}
			if p["name"] != want || seen[want] {
				t.Fatal("names are not unique and stable")
			}
			seen[want] = true
		}
		if lookupField(proxies[0], "xhttp-opts.mode") != "stream-up" {
			t.Fatal("XHTTP mode lost")
		}
		for _, i := range []int{1, 2, 3} {
			if lookupField(proxies[i], "ws-opts.v2ray-http-upgrade") != true {
				t.Fatal("HTTP Upgrade lost")
			}
		}
		if proxies[3]["skip-tls"] != true || lookupField(proxies[3], "ws-opts.headers.Host") != "cdn.example.com" {
			t.Fatal("Trojan parameters lost")
		}
		if lookupField(proxies[4], "plugin-opts.mux") != false {
			t.Fatal("SS mux flag lost")
		}
		for _, message := range handleValidateProxies(proxies) {
			if message != "" {
				t.Fatalf("native adapter rejected node: %s", message)
			}
		}
	}
}

func TestSubscriptionNeverSilentlySkipsUnreadableLines(t *testing.T) {
	content := "trojan://fixture@example.com:443#First\nunsupported://private-value@example.com:443\n"
	nodes, err := convertSubscriptionLinks([]byte(content))
	if nodes != nil || err == nil || !strings.Contains(err.Error(), "line 2") || strings.Contains(err.Error(), "private-value") {
		t.Fatal("expected atomic rejection with a sanitized line number")
	}
}

func TestSubscriptionNamesAvoidBuiltInsAndExistingSuffixes(t *testing.T) {
	content := "trojan://fixture@example.com:443#DIRECT\ntrojan://fixture@example.com:443#DIRECT-01\n"
	nodes, err := convertSubscriptionLinks([]byte(content))
	if err != nil {
		t.Fatal(err)
	}
	if nodes[0]["name"] == "DIRECT" || nodes[0]["name"] == nodes[1]["name"] {
		t.Fatal("reserved or duplicate name")
	}
}
