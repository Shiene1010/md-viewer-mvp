#!/usr/bin/env python3
"""md-viewer 정적 서빙 + OpenCode 동일출처 프록시.

브라우저는 /oc/* 로만 대화하고, service.json 비밀번호는 이 프로세스에만 있다.
"""
import base64
import json
import os
import urllib.error
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
OC = 'http://127.0.0.1:49374'
FREE = {'id': 'muse-spark-1.3-contributor-free', 'providerID': 'opencode'}


def _pw():
    with open(os.path.expanduser('~/.config/opencode/service.json'), encoding='utf-8') as f:
        return json.load(f)['password']


def oc(method, path, body=None):
    data = json.dumps(body).encode('utf-8') if body is not None else None
    req = urllib.request.Request(
        OC + path, data=data, method=method,
        headers={'Content-Type': 'application/json',
                 'Authorization': 'Basic ' + base64.b64encode(
                     ('opencode:' + _pw()).encode()).decode()})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


class H(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def log_message(self, *a):
        pass

    def _send(self, code, obj):
        b = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _read(self):
        try:
            n = int(self.headers.get('Content-Length') or 0)
        except ValueError:
            n = 0
        return json.loads(self.rfile.read(n).decode('utf-8') or '{}') if n else {}

    def do_GET(self):
        u = urlparse(self.path)
        if u.path == '/oc/chat-poll':
            q = parse_qs(u.query)
            sid = q.get('sessionID', [''])[0]
            after = q.get('after', [''])[0] or None
            code, raw = oc('GET', f'/api/session/{sid}/message?limit=10')
            if code != 200:
                return self._send(502, {'error': '세션 무효. 다시 전송하세요.', 'reset': True})
            try:
                items = json.loads(raw)['data']
            except (KeyError, ValueError):
                return self._send(502, {'error': 'upstream'})
            msgs = []
            for m in reversed(items):
                if m.get('type') != 'assistant':
                    continue
                txt = ''.join(p.get('text', '') for p in m.get('content', [])
                              if p.get('type') == 'text')
                err = m.get('error', {}).get('message') if m.get('finish') == 'error' else None
                done = 'completed' in m or m.get('finish') in ('stop', 'error')
                msgs.append({'id': m['id'], 'text': txt, 'done': done, 'error': err})
            if after is not None:
                ids = [m['id'] for m in msgs]
                msgs = msgs[ids.index(after) + 1:] if after in ids else msgs
            return self._send(200, {'messages': msgs})
        return super().do_GET()

    def do_POST(self):
        u = urlparse(self.path)
        if u.path == '/oc/chat-init':
            code, raw = oc('POST', '/api/session', {'title': 'md-chat'})
            if code not in (200, 201):
                return self._send(502, {'error': '세션 생성 실패'})
            sid = json.loads(raw)['data']['id']
            oc('POST', f'/api/session/{sid}/move', {'directory': ROOT})
            oc('POST', f'/api/session/{sid}/model', {'model': FREE})
            return self._send(200, {'sessionID': sid})
        if u.path == '/oc/chat-send':
            b = self._read()
            code, _raw = oc('POST', f"/api/session/{b.get('sessionID', '')}/prompt",
                            {'text': b.get('text', '')})
            if code != 200:
                return self._send(502, {'error': '전송 실패. 다시 전송하세요.', 'reset': True})
            return self._send(200, {'ok': True})
        return self._send(404, {'error': 'unknown'})


if __name__ == '__main__':
    import sys
    host = os.environ.get('HOST', '127.0.0.1')
    port = int(os.environ.get('PORT', '8123'))
    # python3 server.py [host] [port]  (예: python3 server.py 0.0.0.0 8123)
    if len(sys.argv) > 1:
        host = sys.argv[1]
    if len(sys.argv) > 2:
        port = int(sys.argv[2])
    print(f'md-viewer: http://{host}:{port}', flush=True)
    ThreadingHTTPServer((host, port), H).serve_forever()
