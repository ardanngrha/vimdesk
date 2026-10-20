"""Bound the lifetime of Neovim processes owned by these UI tests."""
import subprocess
import threading
import pynvim


def attach_child(argv, timeout=90):
    nvim = pynvim.attach('child', argv=argv)
    loop = nvim._session._async_session._msgpack_stream.loop
    process = next((transport.get_extra_info('subprocess')
                    for transport in loop._to_close
                    if transport.get_extra_info('subprocess') is not None), None)
    if process is None:
        nvim.close()
        raise RuntimeError('Cannot establish ownership of the test child process')
    expired = threading.Event()

    def watchdog():
        if process.poll() is None:
            expired.set()
            try:
                process.kill()
            except ProcessLookupError:
                pass

    timer = threading.Timer(timeout, watchdog)
    timer.daemon = True
    timer.start()
    nvim._test_process = (process, timer, expired)
    return nvim


def close_child(nvim):
    process, timer, expired = nvim._test_process
    try:
        if process.poll() is None:
            try:
                nvim.command('qa!', async_=True)
            except (EOFError, OSError):
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=0.5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
    finally:
        timer.cancel()
        nvim.close()
    if expired.is_set():
        raise TimeoutError('Neovim UI test timed out; its owned child was killed')
