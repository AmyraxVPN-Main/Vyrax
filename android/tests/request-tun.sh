#!/system/bin/sh
printf 'GET /generate_204 HTTP/1.1\r\nHost: vyrax-fixture.example\r\nConnection: close\r\n\r\n' | toybox nc -w 5 -W 5 203.0.113.1 80
