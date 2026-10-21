package core

import (
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
)

type selectionProbe struct {
	C.Proxy
	name  string
	alive bool
	delay uint16
}

func (p *selectionProbe) Name() string                { return p.name }
func (p *selectionProbe) AliveForTestUrl(string) bool { return p.alive }
func (p *selectionProbe) LastDelayForTestUrl(string) uint16 {
	if !p.alive {
		return 65535
	}
	return p.delay
}

type selectionProvider struct {
	P.ProxyProvider
	nodes []C.Proxy
}

func (p *selectionProvider) Proxies() []C.Proxy { return p.nodes }
func (p *selectionProvider) Version() uint32    { return 1 }
func (p *selectionProvider) Touch()             {}

func TestFastestSelectionRefreshIsOptIn(t *testing.T) {
	for _, interval := range []uint{0, 200} {
		first := &selectionProbe{name: "First", alive: true, delay: 50}
		second := &selectionProbe{name: "Second", alive: true, delay: 10}
		group, err := outboundgroup.NewURLTest(
			outboundgroup.GroupCommonOption{Name: "Fastest", URL: "http://example.com/health"},
			outboundgroup.URLTestOption{SelectionInterval: interval},
			first, []P.ProxyProvider{&selectionProvider{nodes: []C.Proxy{first, second}}},
		)
		if err != nil {
			t.Fatal(err)
		}
		if group.Now() != "Second" {
			t.Fatal("lowest latency node not selected")
		}
		second.alive = false
		time.Sleep(250 * time.Millisecond)
		want := "Second"
		if interval > 0 {
			want = "First"
		}
		if group.Now() != want {
			t.Fatalf("interval %d: unexpected selection", interval)
		}
		second.alive = true
		time.Sleep(250 * time.Millisecond)
		if group.Now() != "Second" {
			t.Fatal("recovered fastest node not selected")
		}
		group.ForceSet("First")
		time.Sleep(250 * time.Millisecond)
		if group.Now() != "First" {
			t.Fatal("explicit selection was overwritten")
		}
	}
}
