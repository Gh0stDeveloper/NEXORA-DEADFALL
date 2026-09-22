#!/usr/bin/env python3
"""Four real ENet clients, authoritative city/AI, loopback RTT and process metrics."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time


def cpu_seconds(pid):
    fields = Path(f"/proc/{pid}/stat").read_text().split(")", 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")


def main():
    repo = Path(__file__).resolve().parents[2]
    output = repo / "build/server-load"
    output.mkdir(parents=True, exist_ok=True)
    binary = os.environ.get("GODOT_BIN", "godot")
    port = int(os.environ.get("DEADFALL_LOAD_TEST_PORT", "24870"))
    processes, logs, readers = [], [], []
    with tempfile.TemporaryDirectory(prefix="deadfall-load-") as profile:
        def start(name, arguments):
            log = (output / f"{name}.log").open("w")
            logs.append(log)
            process = subprocess.Popen(
                [binary, "--headless", "--path", str(repo), "--script",
                 "scripts/ci/match_load_peer.gd", "--", "--campaign", *arguments],
                cwd=repo, env=dict(os.environ, XDG_DATA_HOME=str(Path(profile) / name)),
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            )

            # Drain complete process output before checking final success markers.
            def capture():
                for line in process.stdout:
                    log.write(line)
                    log.flush()

            reader = threading.Thread(target=capture, daemon=True)
            reader.start()
            readers.append(reader)
            processes.append(process)
            return process

        try:
            server = start("server", ["--server", f"--port={port}", f"--directory-port={port + 1}", "--public-host=127.0.0.1", "--room=LOAD42"])
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                assert server.poll() is None, "Server exited during startup"
                if "DEADFALL_CITY_NAV_READY" in (output / "server.log").read_text():
                    break
                time.sleep(0.1)
            else:
                raise AssertionError("Server navigation did not become ready")
            clients = [start(f"client-{i}", [f"--connect=127.0.0.1:{port}", f"--name=Load{i}"]) for i in range(4)]
            started, cpu_started = time.monotonic(), cpu_seconds(server.pid)
            deadline = started + 40
            while time.monotonic() < deadline and any(p.poll() is None for p in clients):
                time.sleep(0.1)
            assert all(p.poll() == 0 for p in clients), "A load client failed/timed out; inspect build/server-load"
            seconds = time.monotonic() - started
            cpu_percent = (cpu_seconds(server.pid) - cpu_started) * 100.0 / seconds
            rss = next(line.split()[1] for line in Path(f"/proc/{server.pid}/status").read_text().splitlines() if line.startswith("VmHWM:"))
            # Let the dedicated process handle all departures and subsequent AI
            # ticks. Errors after the final client exits must fail this gate too.
            assert server.wait(timeout=12) == 0, "Dedicated failed after clients disconnected"
            for reader in readers:
                reader.join(timeout=3)
                assert not reader.is_alive(), "Process output did not finish draining"
            results = []
            for index in range(4):
                text = (output / f"client-{index}.log").read_text()
                assert "SCRIPT ERROR:" not in text and "ERROR:" not in text
                row = next(line.split("DEADFALL_LOAD_CLIENT_RESULT ", 1)[1] for line in text.splitlines() if line.startswith("DEADFALL_LOAD_CLIENT_RESULT "))
                results.append(json.loads(row))
            text = (output / "server.log").read_text()
            assert "presentation_nodes=0" in text and "ERROR:" not in text
            metrics = [json.loads(line.split("DEADFALL_SERVER_PERF ", 1)[1]) for line in text.splitlines() if line.startswith("DEADFALL_SERVER_PERF ")]
            assert metrics and max(m["players"] for m in metrics) == 4
            report = {"scope": "local loopback, not WAN/VPS measurement", "seconds": round(seconds, 2), "server_cpu_one_core_percent": round(cpu_percent, 2), "server_peak_rss_mb": round(int(rss) / 1024, 2), "clients": results, "server": metrics}
            (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report, indent=2))
            print("NEXORA: DEADFALL four-peer city load smoke passed")
        finally:
            for process in processes:
                if process.poll() is None: process.terminate()
            for process in processes:
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
            for reader in readers: reader.join(timeout=3)
            for log in logs: log.close()


if __name__ == "__main__":
    main()
