#!/usr/bin/env python3
"""Real HTTP queue -> child dedicated -> four ENet peers -> per-account history.

All accounts and matches are ephemeral local test fixtures. No production host,
credentials, arbitrary RPCs, or client-supplied scores are used.
"""
import json
import hashlib
import hmac
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def main():
    repo = Path(__file__).resolve().parents[2]
    output = repo / "build/social-match"
    output.mkdir(parents=True, exist_ok=True)
    binary = os.environ.get("GODOT_BIN", "godot")
    processes, logs = [], []
    with tempfile.TemporaryDirectory(prefix="deadfall-social-match-") as temporary:
        directory = Path(temporary)

        def start(name, arguments):
            log = (output / f"{name}.log").open("a" if name == "control" and len(processes) > 0 else "w")
            logs.append(log)
            process = subprocess.Popen(
                [binary, "--headless", "--path", str(repo), "--script",
                 "scripts/ci/social_match_peer.gd", "--", f"--test-dir={directory}", *arguments],
                cwd=repo, env=dict(os.environ, XDG_DATA_HOME=str(directory / name)),
                stdout=log, stderr=subprocess.STDOUT,
            )
            processes.append(process)
            return process

        def api(path, token="", payload=None):
            request = urllib.request.Request(
                "http://127.0.0.1:24865/v1" + path,
                data=json.dumps(payload).encode() if payload is not None else None,
                headers={"Content-Type": "application/json", "Authorization": "Bearer " + token},
            )
            with urllib.request.urlopen(request, timeout=3) as response:
                value = json.load(response)
            assert value.get("ok"), (path, value.get("reason"))
            return value

        try:
            control = start("control", ["--control-test"])
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                assert control.poll() is None, "Control process exited"
                if "DEADFALL_SOCIAL_CONTROL_READY" in (output / "control.log").read_text(): break
                time.sleep(0.1)
            else:
                raise AssertionError("Control API did not start")
            tokens = []
            for index in range(4):
                account = api("/guest/register", payload={
                    "guest_id": "gst_" + str(index) * 32, "username": f"SocialE2E{index}",
                    "secret_verifier": "a" * 64, "selected_character": "operator_01",
                })
                tokens.append(account["session_token"])
            # An existing duo remains together; two single players in duo mode
            # fill the opposing team. All three parties voluntarily queue.
            party = api("/party/create", tokens[0], {"capacity": 2})["party"]
            api("/party/join", tokens[1], {"code": party["code"]})
            for index in (2, 3): api("/party/create", tokens[index], {"capacity": 2})
            for index in (0, 2, 3):
                api("/match/start", tokens[index], {"game_mode": "pvp_duo", "mission_id": "mission_01_first_signal"})
            deadline = time.monotonic() + 25
            while time.monotonic() < deadline:
                assignments = [api("/party/current", token)["party"].get("match", {}) for token in tokens]
                if all(value.get("status") == "READY" for value in assignments): break
                for token in tokens: api("/presence", token, {"ping_ms": 0})
                time.sleep(1.2)
            else:
                raise AssertionError("Matched child did not publish READY")
            assert len({value["match_id"] for value in assignments}) == 1
            assert len({value["join_ticket"] for value in assignments}) == 4
            assert all(value["game_mode"] == "pvp_duo" for value in assignments)
            clients = []
            for index, assignment in enumerate(assignments):
                path = directory / f"assignment-{index}.json"
                path.write_text(json.dumps(assignment))
                clients.append(start(f"client-{index}", [
                    f"--assignment={path}", f"--name=SocialE2E{index}",
                    f"--result={directory / f'result-{index}.json'}",
                    *(["--attacker"] if index == 0 else []),
                ]))
            deadline = time.monotonic() + 115
            while time.monotonic() < deadline and any(p.poll() is None for p in clients):
                assert control.poll() is None, "Control died during match"
                for log_path in output.glob("*.log"):
                    assert "SCRIPT ERROR:" not in log_path.read_text(), f"Script error in {log_path}"
                time.sleep(0.2)
            assert all(p.poll() == 0 for p in clients), "Match peer failed/timed out; inspect build/social-match"
            results = [json.loads((directory / f"result-{i}.json").read_text()) for i in range(4)]
            assert [r["outcome"] for r in results] == ["VICTORY", "VICTORY", "DEFEAT", "DEFEAT"]
            assert results[0]["observed_automatic_reload"]
            histories = [api("/history", token) for token in tokens]
            assert all(len(h["matches"]) == 1 for h in histories)
            assert [h["matches"][0]["outcome"] for h in histories] == [r["outcome"] for r in results]
            assert histories[0]["matches"][0]["kills"] == 10
            assert histories[0]["stats"]["wins"] == 1
            assert histories[2]["stats"]["wins"] == 0
            assert all(h["matches"][0]["mode"] == "pvp_duo" for h in histories)
            # On-disk state survives a restart (sessions intentionally do not).
            state_path = next((directory / "control").rglob("social_state.dat"))
            saved = json.loads(state_path.read_text())
            assert len(saved["match_history"]) == 4
            (directory / "stop").touch()
            assert control.wait(timeout=5) == 0
            (directory / "stop").unlink()
            control = start("control", ["--control-test"])
            deadline = time.monotonic() + 15
            while (output / "control.log").read_text().count("DEADFALL_SOCIAL_CONTROL_READY") < 2:
                assert control.poll() is None and time.monotonic() < deadline, "Restart failed"
                time.sleep(0.1)
            for index in range(4):
                guest = "gst_" + str(index) * 32
                nonce = api("/guest/challenge", payload={"guest_id": guest})["nonce"]
                proof = hmac.new(bytes.fromhex("a" * 64), nonce.encode(), hashlib.sha256).hexdigest()
                token = api("/guest/verify", payload={"guest_id": guest, "nonce": nonce, "proof": proof})["session_token"]
                assert api("/history", token)["matches"] == histories[index]["matches"], "History lost on restart"
            report = {"scope": "local HTTP + dedicated child + ENet", "players": 4,
                      "teams": [2, 2], "outcomes": [r["outcome"] for r in results],
                      "automatic_reload_observed": True, "history_accounts_persisted": 4,
                      "winner_kills": histories[0]["matches"][0]["kills"]}
            (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        finally:
            (directory / "stop").touch()
            for process in processes:
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    try: process.wait(timeout=5)
                    except subprocess.TimeoutExpired: process.kill(); process.wait()
            for log in logs: log.close()
        for path in output.glob("*.log"):
            text = path.read_text()
            assert "SCRIPT ERROR:" not in text and "ERROR:" not in text, f"Error in {path}"
        print(json.dumps(report, indent=2))
        print("NEXORA: DEADFALL social matchmaking and PvP end-to-end smoke passed")


if __name__ == "__main__":
    main()
