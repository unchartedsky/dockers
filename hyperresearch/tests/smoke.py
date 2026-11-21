"""Container smoke test. Run only with a fresh test-only /vault and --network none."""

import asyncio
import json
import os
import secrets
import subprocess
import sys
import tempfile
from contextlib import AsyncExitStack, asynccontextmanager
from dataclasses import replace
from importlib.metadata import version
from pathlib import Path
from urllib.parse import urlsplit

import httpx
from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client

VAULT = Path('/vault')
ENTRYPOINT = '/usr/local/bin/hyperresearch-entrypoint'
BASE = 'http://127.0.0.1:8080'
TOKEN = secrets.token_urlsafe(32)
ENV = {**os.environ, 'MCP_PROXY_AUTH_TOKEN': TOKEN, 'HYPERRESEARCH_MCP_HOST': 'mcp.example.test'}
HEADERS = {'Host': ENV['HYPERRESEARCH_MCP_HOST'], 'Authorization': f'Bearer {TOKEN}'}


def fail_start(env, expected):
    result = subprocess.run([ENTRYPOINT], env=env, capture_output=True, timeout=15)
    assert result.returncode != 0 and expected in result.stderr, expected.decode()


@asynccontextmanager
async def server():
    process = await asyncio.create_subprocess_exec(ENTRYPOINT, env=ENV)
    try:
        async with httpx.AsyncClient(timeout=2, trust_env=False) as http:
            for _ in range(150):
                assert process.returncode is None, 'entrypoint stopped before becoming ready'
                try:
                    response = await http.get(f'{BASE}/healthz', headers=HEADERS)
                except httpx.ConnectError:
                    await asyncio.sleep(0.1)
                    continue
                assert response.status_code == 204, 'authenticated health check failed'
                break
            else:
                raise AssertionError('entrypoint readiness timed out')
            for method, path in [('GET', '/healthz'), ('POST', '/mcp')]:
                for headers, expected in [({'Host': HEADERS['Host']}, 401),
                                          ({**HEADERS, 'Authorization': 'Bearer wrong'}, 401),
                                          ({**HEADERS, 'Host': 'invalid.example.test'}, 421)]:
                    response = await http.request(method, f'{BASE}{path}', headers=headers)
                    assert response.status_code == expected, f'{path}: unexpected rejection status'
        children = Path(f'/proc/{process.pid}/task/{process.pid}/children').read_text().split()
        assert len(children) == 1, 'expected a single stdio child'
        child_env = Path(f'/proc/{children[0]}/environ').read_bytes().split(b'\0')
        assert not any(value.startswith(b'MCP_PROXY_AUTH_TOKEN=') for value in child_env), 'token reached stdio child'
        yield
    finally:
        if process.returncode is None:
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), 10)
            except TimeoutError:
                process.kill()
                await process.wait()
                raise


@asynccontextmanager
async def connect():
    async with httpx.AsyncClient(headers=HEADERS, timeout=15, trust_env=False) as http:
        async with streamable_http_client(f'{BASE}/mcp', http_client=http) as (read, write, _):
            async with ClientSession(read, write) as session:
                await session.initialize()
                yield session


async def tool(session, name, **args):
    message = await session.call_tool(name, args)
    assert not message.isError, f'{name} returned a protocol error'
    return json.loads(message.content[0].text)


async def data(session, name, **args):
    result = await tool(session, name, **args)
    assert result.get('ok') is True, f'{name} failed: {result.get("error_code", "unknown")}'
    return result['data']


async def indexed(session, note_id, **filters):
    results = await tool(session, 'search_notes', **filters)
    assert note_id in {note['id'] for note in results}, 'note missing from search index'


async def simultaneous(a, b):
    barrier = asyncio.Barrier(2)

    async def start(operation):
        await barrier.wait()
        return await operation

    return await asyncio.gather(start(a), start(b))


async def concurrent_notes(a, b):
    async def create(session, title):
        return (await data(session, 'create_note', title=title, body='A smokecheck note.'))['note_id']

    first, second = await simultaneous(create(a, 'Smokecheck one'), create(b, 'Smokecheck two'))
    duplicate_a, duplicate_b = await simultaneous(create(a, 'Smokecheck duplicate'), create(b, 'Smokecheck duplicate'))
    assert len({first, second, duplicate_a, duplicate_b}) == 4
    for note_id in (first, second, duplicate_a, duplicate_b):
        await indexed(a, note_id, query='smokecheck')

    await simultaneous(data(a, 'update_note', note_id=first, status='review'),
                       data(b, 'update_note', note_id=first, add_tags='concurrent'))
    note = await tool(a, 'read_note', note_id=first)
    assert note['status'] == 'review' and 'concurrent' in note['tags']
    await indexed(a, first, status='review', tag='concurrent')

    # The update which removed the other marker ran second, irrespective of response delivery order.
    async def revise(session, own, other):
        return own, other, await data(session, 'update_note', note_id=first, summary=own,
                                      add_tags=own, remove_tags=other)

    applied = await simultaneous(revise(a, 'revision-a', 'revision-b'), revise(b, 'revision-b', 'revision-a'))
    winners = [own for own, other, result in applied if f'-tag:{other}' in result['changes']]
    assert len(winners) == 1, 'could not identify server apply order'
    note = await tool(a, 'read_note', note_id=first)
    assert note['summary'] == winners[0] and set(note['tags']) & {'revision-a', 'revision-b'} == set(winners)
    assert f'summary: {winners[0]}' in (VAULT / note['path']).read_text()
    await indexed(a, first, tag=winners[0])
    return first


async def overlap_fetch(a, b, observer):
    reached, release = asyncio.Event(), asyncio.Event()
    body = ('<html><title>Smokecheck source</title><main><h1>Smokecheck source</h1><p>'
            + 'Research source material for an isolated integration test. ' * 20 + '</p></main></html>').encode()

    async def fixture(reader, writer):
        try:
            await reader.readuntil(b'\r\n\r\n')
            reached.set()
            await asyncio.wait_for(release.wait(), 10)
            writer.write(b'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\nContent-Length: '
                         + str(len(body)).encode() + b'\r\n\r\n' + body)
            await writer.drain()
        finally:
            writer.close()
            await writer.wait_closed()

    async with await asyncio.start_server(fixture, '127.0.0.1', 0) as http:
        url = f'http://127.0.0.1:{http.sockets[0].getsockname()[1]}/source'
        async with asyncio.TaskGroup() as group:
            fetch = group.create_task(data(a, 'fetch_url', url=url))
            try:
                await asyncio.wait_for(reached.wait(), 10)
                note = await data(b, 'create_note', title='Smokecheck while fetching', body='A smokecheck note.')
                assert (await tool(observer, 'read_note', note_id=note['note_id']))['id'] == note['note_id']
                await indexed(observer, note['note_id'], query='smokecheck')
                assert not fetch.done(), 'the delayed fetch was not pending during the write and read'
            finally:
                release.set()
        assert fetch.result().get('note_id'), 'fetch result is missing its note ID'
        rejection = await tool(a, 'fetch_url', url=url)
        assert rejection.get('ok') is False, 'duplicate fetch should return an explicit failure'


async def rejected_child():
    with tempfile.TemporaryDirectory() as directory:
        stub = Path(directory) / 'hyperresearch'
        stub.touch(mode=0o700)
        env = {**ENV, 'PATH': directory + ':' + ENV['PATH']}
        for command, minimum, limit in [('exit 23', 0, 10), ('exec sleep 60', 18, 35)]:
            stub.write_text(f'#!/bin/sh\n{command}\n')
            started = asyncio.get_running_loop().time()
            process = await asyncio.create_subprocess_exec(ENTRYPOINT, env=env,
                                                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                async with asyncio.timeout(limit), httpx.AsyncClient(timeout=2, trust_env=False) as http:
                    while process.returncode is None:
                        try:
                            await http.get(f'{BASE}/healthz', headers=HEADERS)
                        except httpx.ConnectError:
                            await asyncio.sleep(0.1)
                            continue
                        raise AssertionError('proxy listened before the child initialized')
                assert process.returncode != 0 and asyncio.get_running_loop().time() - started >= minimum
            finally:
                if process.returncode is None:
                    process.kill()
                    await process.wait()


async def public_fetch():
    assert not list(VAULT.iterdir()), 'test requires an empty disposable /vault'
    url = os.environ['HYPERRESEARCH_SMOKE_PUBLIC_URL']
    target = urlsplit(url)
    assert target.scheme == 'https' and target.hostname and target.username is None and target.password is None
    async with server(), connect() as session:
        note = await data(session, 'fetch_url', url=url)
        assert note.get('note_id'), 'public fetch did not create a vault note'
        rejected = await tool(session, 'fetch_url', url=url)
        assert rejected.get('ok') is False, 'duplicate public fetch should fail explicitly'
    print('Hyperresearch public HTTPS fetch test passed')


async def main():
    assert list(VAULT.iterdir()) == [], 'test requires an empty disposable /vault'
    assert sys.version_info[:2] == (3, 13)
    for package, expected in {'mcp-proxy': '0.15.0', 'hyperresearch': '0.13.3', 'mcp': '1.30.0',
                              'exa-py': None, 'tavily-python': None, 'crawl4ai': None, 'watchdog': None}.items():
        assert version(package) and (expected is None or version(package) == expected), package
    subprocess.run([sys.executable, '-m', 'pip', 'check'], check=True)
    for token in (None, ''):
        fail_start({key: value for key, value in ENV.items() if key != 'MCP_PROXY_AUTH_TOKEN'}
                   | ({} if token is None else {'MCP_PROXY_AUTH_TOKEN': token}), b'MCP_PROXY_AUTH_TOKEN')
    assert not list(VAULT.iterdir()), 'invalid credentials modified the vault'
    partial = VAULT / '.hyperresearch'
    partial.mkdir()
    fail_start(ENV, b'incomplete vault')
    assert list(VAULT.iterdir()) == [partial] and not list(partial.iterdir())
    partial.rmdir()
    unknown = VAULT / '.unrelated'
    unknown.write_text('unchanged')
    fail_start(ENV, b'incomplete vault')
    assert unknown.read_text() == 'unchanged' and not partial.exists()
    unknown.unlink()
    for mode in (0o300, 0o500):
        VAULT.chmod(mode)
        try:
            fail_start(ENV, b'/vault must be readable and writable')
        finally:
            VAULT.chmod(0o700)
    (VAULT / 'lost+found').mkdir()
    async with server(), connect() as session:
        names = {item.name for item in (await session.list_tools()).tools}
        assert {'create_note', 'update_note', 'fetch_url', 'vault_status'} <= names
        assert (await tool(session, 'vault_status'))['total_notes'] == 0

    db = partial / 'hyperresearch.db'
    real_db = db.with_suffix('.original')
    db.rename(real_db)
    db.mkdir()
    fail_start(ENV, b'incomplete vault')
    db.rmdir()
    db.symlink_to(real_db)
    fail_start(ENV, b'incomplete vault')
    db.unlink()
    real_db.rename(db)
    await rejected_child()

    # Permit only the synthetic fixture in this disposable offline vault; never on a deployment.
    from hyperresearch.core.config import VaultConfig

    config_path = VAULT / '.hyperresearch/config.toml'
    config = VaultConfig.load(config_path)
    replace(config, fetch=replace(config.fetch, allow_private_hosts=('127.0.0.1',))).save(config_path)
    async with server(), AsyncExitStack() as stack:
        a, b, observer = [await stack.enter_async_context(connect()) for _ in range(3)]
        note_id = await concurrent_notes(a, b)
        await overlap_fetch(a, b, observer)
    async with server(), connect() as session:
        await indexed(session, note_id, query='smokecheck')
    assert VaultConfig.load(config_path).fetch.allow_private_hosts == ('127.0.0.1',)
    print('Hyperresearch MCP smoke test passed')


if __name__ == '__main__':
    if sys.argv[1:] == ['--public-fetch']:
        asyncio.run(public_fetch())
    else:
        assert not sys.argv[1:], 'unexpected smoke test arguments'
        asyncio.run(main())
