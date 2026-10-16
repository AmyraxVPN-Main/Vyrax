package http

import (
	"context"
	"testing"

	"github.com/xtls/xray-core/common/session"
)

func TestVyraxLiteralHeaderWithoutInbound(t *testing.T) {
	headers := []*Header{{Key: "Proxy-Authorization", Value: "Bearer synthetic-only"}}
	ctx := session.ContextWithOutbounds(context.Background(), []*session.Outbound{{}})
	got, err := fillRequestHeader(ctx, headers)
	if err != nil {
		t.Fatalf("internal probe rejected literal header: %v", err)
	}
	if len(got) != 1 || got[0].Value != headers[0].Value {
		t.Fatal("literal header changed")
	}
}

func TestVyraxTemplateHeaderRequiresInbound(t *testing.T) {
	headers := []*Header{{Key: "X-Test", Value: "{{.Source}}"}}
	ctx := session.ContextWithOutbounds(context.Background(), []*session.Outbound{{}})
	if _, err := fillRequestHeader(ctx, headers); err == nil {
		t.Fatal("dynamic header accepted without required context")
	}
}

func TestVyraxEmptyHeaderWithoutInbound(t *testing.T) {
	got, err := fillRequestHeader(context.Background(), nil)
	if err != nil || len(got) != 0 {
		t.Fatal("empty headers changed")
	}
}
