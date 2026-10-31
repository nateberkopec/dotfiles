import base64
import hashlib
import http.server
import json
import os
import pathlib
import selectors
import shutil
import subprocess
import tarfile
import tempfile
import threading
import time
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
NAME = '@example/pi-startup-fixture'
SPEC = f'npm:{NAME}@1.0.0'


def readiness(pi, agent, entry, directory):
    args = [pi, '--mode', 'rpc', '--no-session', '--offline', '--no-extensions',
            '--no-context-files', '--no-skills', '--no-prompt-templates', '--no-themes',
            '--model', 'openai/gpt-6.1-sol', '--api-key', 'synthetic-no-generation', '-e', str(entry)]
    env = {**os.environ, 'PI_CODING_AGENT_DIR': str(agent), 'PI_SKIP_VERSION_CHECK': '1'}
    child = subprocess.Popen(args, cwd=directory, env=env, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    selector = selectors.DefaultSelector()
    buffers = {child.stdout: b'', child.stderr: b''}
    started = time.monotonic()
    try:
        child.stdin.write(b'{"id":"sdk-layout","type":"get_commands"}\n')
        child.stdin.flush()
        for stream in buffers:
            selector.register(stream, selectors.EVENT_READ)
        while time.monotonic() - started < 15:
            for key, _ in selector.select(.1):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                buffers[key.fileobj] += chunk
                if key.fileobj is child.stdout:
                    while b'\n' in buffers[child.stdout]:
                        line, buffers[child.stdout] = buffers[child.stdout].split(b'\n', 1)
                        response = json.loads(line)
                        if response.get('id') == 'sdk-layout':
                            assert response['success'], response
                            commands = response['data']['commands']
                            return next(c['description'] for c in commands if c['name'] == 'startup-host-proof')
            if child.poll() is not None:
                raise RuntimeError(f'Pi exited before readiness: {buffers[child.stderr].decode()}')
        raise TimeoutError(f'Pi readiness timed out: {buffers[child.stderr].decode()}')
    finally:
        selector.close()
        child.kill()
        child.wait()


def complete(home):
    source = '''require ARGV[0] + "/lib/dotfiles"
step = Dotfiles::Step::InstallPiPackagesStep.new(debug: false, dotfiles_dir: ARGV[0], home: ARGV[1])
puts JSON.generate(complete: step.complete?)'''
    result = subprocess.run(['ruby', '-e', source, str(ROOT), str(home)], cwd=ROOT,
                            capture_output=True, text=True, check=True, timeout=15)
    return json.loads(result.stdout)['complete']


with tempfile.TemporaryDirectory(prefix='pi-package-isolation-') as directory:
    root = pathlib.Path(directory)
    package = root / 'fixture/package'
    package.mkdir(parents=True)
    manifest = {'name': NAME, 'version': '1.0.0', 'type': 'module', 'license': 'MIT',
                'peerDependencies': {'@earendil-works/pi-coding-agent': '*'},
                'peerDependenciesMeta': {'@earendil-works/pi-coding-agent': {'optional': True}},
                'pi': {'extensions': ['index.js']}}
    (package / 'package.json').write_text(json.dumps(manifest))
    (package / 'index.js').write_text('''import { getAgentDir } from "@earendil-works/pi-coding-agent";
export default function(pi) {
  pi.registerCommand("startup-host-proof", {
    description: getAgentDir() === process.env.PI_CODING_AGENT_DIR ? "HOST" : "FOREIGN",
    handler: async () => {}
  });
}
''')
    archive = root / 'fixture.tgz'
    with tarfile.open(archive, 'w:gz') as tar:
        tar.add(package, arcname='package')
    archive_bytes = archive.read_bytes()
    integrity = 'sha512-' + base64.b64encode(hashlib.sha512(archive_bytes).digest()).decode()

    class Registry(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            path = urllib.parse.unquote(self.path.split('?')[0])
            if path == '/fixture.tgz':
                body = archive_bytes
            elif path == '/' + NAME:
                version = {**manifest, 'dist': {'tarball': registry_url + '/fixture.tgz', 'integrity': integrity}}
                timestamp = '2000-01-01T00:00:00Z'
                body = json.dumps({'name': NAME, 'dist-tags': {'latest': '1.0.0'},
                                   'time': {'created': timestamp, 'modified': timestamp, '1.0.0': timestamp},
                                   'versions': {'1.0.0': version}}).encode()
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream' if path == '/fixture.tgz' else 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Registry)
    registry_url = f'http://127.0.0.1:{server.server_port}'
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        aube = subprocess.check_output(['mise', '-C', str(pathlib.Path.home()), 'which', 'aube'], text=True).strip()
        pi = subprocess.check_output(['mise', '-C', str(pathlib.Path.home()), 'which', 'pi'], text=True).strip()
        cache = root / 'cache'
        home = root / 'home'
        agent = home / '.pi/agent'
        workspace = agent / 'npm'
        workspace.mkdir(parents=True)
        (workspace / 'package.json').write_text('{"name":"pi-layout-probe","version":"1.0.0","private":true}')
        (agent / 'settings.json').write_text(json.dumps({'lastChangelogVersion': '9999.0.0', 'packages': [SPEC]}))
        for mode in ['shared', 'isolated']:
            flags = ['--config.auto-install-peers=false', '--config.strict-peer-dependencies=false']
            if mode == 'shared':
                flags.append('--config.enable-global-virtual-store=true')
            else:
                shutil.copyfile(ROOT / 'files/home/.pi/agent/npm/.npmrc', workspace / '.npmrc')
            result = subprocess.run([aube, '__aube-shim', 'npm', 'install', NAME + '@1.0.0',
                                     '--registry', registry_url, '--prefix', str(workspace), *flags],
                                    env={**os.environ, 'AUBE_CACHE_DIR': str(cache)},
                                    capture_output=True, text=True, timeout=30)
            assert result.returncode == 0, result.stdout + result.stderr
            sdk = cache / 'virtual-store/v1/node_modules/@earendil-works/pi-coding-agent'
            sdk.mkdir(parents=True, exist_ok=True)
            (sdk / 'package.json').write_text('{"name":"@earendil-works/pi-coding-agent","version":"0.0.0","type":"module","exports":"./index.js"}')
            (sdk / 'index.js').write_text('export const getAgentDir = () => "FOREIGN";\n')
            entry = workspace / 'node_modules' / NAME / 'index.js'
            sdk_identity = readiness(pi, agent, entry, root)
            converged = complete(home)
            assert sdk_identity == ('FOREIGN' if mode == 'shared' else 'HOST'), sdk_identity
            assert converged == (mode == 'isolated'), f'{mode} package-state check: {converged}'
            print(json.dumps({'layout': mode, 'sdk': sdk_identity, 'converged': converged}), flush=True)
        print(json.dumps({'pass': True, 'generationCalls': 0}))
    finally:
        server.shutdown()
        server.server_close()
