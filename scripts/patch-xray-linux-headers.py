#!/usr/bin/env python3
"""Allow literal HTTP proxy headers in Xray's internal latency probes.

The normal template path retains its requirement for inbound/outbound metadata.
Apply to the SHA-256-pinned v26.3.27 source before building the Linux core.
"""
import argparse
import difflib
from pathlib import Path


def patch(source):
    file = source / 'proxy/http/client.go'
    before = file.read_text()
    marker = '// Vyrax: literal headers do not need an inbound context.'
    if marker in before:
        return ''
    target = '\tinbound := session.InboundFromContext(ctx)'
    assert before.count(target) == 1, 'Unexpected Xray header implementation'
    assert before.count('\t"sync"\n') == 1
    after = before.replace('\t"sync"\n', '\t"sync"\n\t"strings"\n')
    after = after.replace(target, '''\t// Vyrax: literal headers do not need an inbound context.
\t// Observatory probes originate internally, without an inbound socket.
\tneedsContext := false
\tfor _, h := range header {
\t\tif strings.Contains(h.Value, "{{") {
\t\t\tneedsContext = true
\t\t\tbreak
\t\t}
\t}
\tif !needsContext {
\t\treturn header, nil
\t}

''' + target)
    file.write_text(after)
    return ''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
                                       fromfile='a/proxy/http/client.go',tofile='b/proxy/http/client.go'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('--diff',type=Path)
    args = parser.parse_args()
    diff = patch(args.source)
    if args.diff and diff:
        args.diff.write_text(diff)
    print('Xray literal-header fix applied; dynamic header validation preserved.')
