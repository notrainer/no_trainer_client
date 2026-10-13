"""Run without containers: python3 tests/check_training.py."""
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRAINING = ROOT / "etc/nmap-training"


def main():
    with tempfile.TemporaryDirectory() as directory:
        scratch = Path(directory)
        container_env = scratch / "container_environment"
        container_env.mkdir()
        profile = scratch / "profile.sh"
        profile.write_text(
            (ROOT / "etc/profile.d/nmap-training.sh").read_text()
            .replace("/run/s6/container_environment", str(container_env))
            .replace("/opt/nmap-training", str(TRAINING))
        )
        mock_ip = scratch / "ip"
        mock_ip.write_text('''#!/bin/bash
if [ "$1" = "-o" ]; then
    if [ -n "$TEST_INTERFACE" ]; then
        echo "$SCAN_NETWORK dev $TEST_INTERFACE proto kernel scope link src 172.28.50.101"
    fi
else
    printf '%s\\n' "$*" >> "$TEST_ROUTES"
fi
''')
        mock_ip.chmod(0o755)
        env = dict(os.environ, PATH=f"{scratch}:{os.environ['PATH']}",
                   HOME=str(scratch / "participant"), TEST_INTERFACE="eth7",
                   TEST_ROUTES=str(scratch / "routes.log"))
        for name in ("SCAN_NETWORK", "SCAN_INTERFACE", "LAB_IF", "LAB_DNS", "LAB_DOMAIN", "NMAP_SAGE_API_KEY"):
            env.pop(name, None)

        def run_shell(source, overrides=None, check=True):
            return subprocess.run(
                ["bash", "-eu", "-c", source.replace("/etc/profile.d/nmap-training.sh", str(profile))],
                env=env | (overrides or {}), capture_output=True, text=True, check=check,
            )

        output = run_shell(f'. "{profile}"; printf "%s %s %s" "$SCAN_INTERFACE" "$LAB_IF" "$LAB_NET"')
        assert output.stdout == "eth7 eth7 172.28.50.0/24", output.stdout
        (container_env / "SCAN_NETWORK").write_text("172.28.50.0/24")
        (container_env / "SCAN_INTERFACE").write_text("eth7")
        (container_env / "LAB_DNS").write_text("172.28.50.11")
        output = run_shell(f'. "{profile}"; printf "%s %s" "$LAB_DNS" "$SCAN_INTERFACE"')
        assert output.stdout == "172.28.50.11 eth7", output.stdout
        output = run_shell(f'. "{profile}"; printf "%s" "$SCAN_INTERFACE"', {"SCAN_INTERFACE": "eth9"})
        assert output.stdout == "eth9", output.stdout
        (container_env / "NMAP_SAGE_API_KEY").write_text("test-sage-key")
        output = run_shell(f'. "{profile}"; printf "%s" "$NMAP_SAGE_API_KEY"')
        assert output.stdout == "test-sage-key"
        output = run_shell(f'. "{profile}"; printf "%s" "$NMAP_SAGE_API_KEY"', {"NMAP_SAGE_API_KEY": "override-key"})
        assert output.stdout == "override-key"

        setup = (TRAINING / "scripts/setup-training.sh").read_text()
        run_shell(setup)
        sage = Path(env["HOME"]) / "nmap-sage"
        assert sage.read_bytes() == (TRAINING / "scripts/nmap-sage").read_bytes()
        assert os.access(sage, os.X_OK)
        results = Path(env["HOME"]) / "nmap-training-results"
        for name in (
            "targets.txt",
            "excluded.txt",
            "http.args",
            "dns-brute.args",
            "ldap.args",
            "capture-discovery.sh",
            "read-nmap-xml.py",
            "hello.lua",
            "status-check.lua",
            "inventory.lua",
        ):
            assert (results / name).is_file(), name
        (results / "http.args").write_text("participant edits\n")
        (results / "inventory.lua").write_text("-- participant Lua edits\n")
        nse_copy = Path(env["HOME"]) / "http-shop-policy.nse"
        nse_copy.write_text("participant NSE edits\n")
        sage.write_text("participant helper edits\n")
        (results / "targets.txt").unlink()
        (results / "targets.txt").symlink_to(scratch / "participant-targets.txt")
        run_shell(setup)
        assert (results / "http.args").read_text() == "participant edits\n"
        assert (results / "inventory.lua").read_text() == "-- participant Lua edits\n"
        assert nse_copy.read_text() == "participant NSE edits\n"
        assert sage.read_text() == "participant helper edits\n"
        sage.unlink()
        sage.symlink_to(scratch / "participant-sage")
        run_shell(setup)
        assert sage.is_symlink(), "Keep participant helper links, even when their target is missing"
        assert (results / "targets.txt").is_symlink()

        # Exercise password initialization without changing the machine account.
        for name, body in {
            "chpasswd": '#!/bin/bash\ncat > "$TEST_PASSWORD_INPUT"\n',
            "passwd": '#!/bin/bash\nprintf "%s\\n" "$*" > "$TEST_PASSWORD_LOCK"\n',
            "s6-setuidgid": "#!/bin/bash\nexit 0\n",
        }.items():
            mock = scratch / name
            mock.write_text(body)
            mock.chmod(0o755)
        password_input = scratch / "password-input"
        password_lock = scratch / "password-lock"
        initialization = (
            (TRAINING / "init-training.sh")
            .read_text()
            .replace('"$NMAP_TRAINING/scripts/multicast-routes.sh"', "/usr/bin/true")
        )
        run_shell(
            initialization,
            {
                "SSH_PASSWORD": "generated-test-password",
                "TEST_PASSWORD_INPUT": str(password_input),
                "TEST_PASSWORD_LOCK": str(password_lock),
            },
        )
        assert password_input.read_text() == "abc:generated-test-password\n"
        assert not password_lock.exists(), "Configured password must stay unlocked"
        password_input.unlink()
        run_shell(initialization, {"SSH_PASSWORD": "", "TEST_PASSWORD_INPUT": str(password_input), "TEST_PASSWORD_LOCK": str(password_lock)})
        assert not password_input.exists(), "An unset SSH password must not set a password"
        assert password_lock.read_text() == "-l abc\n", "An unset SSH password must lock the account"
        Path(env["TEST_ROUTES"]).unlink(missing_ok=True)

        routes = (TRAINING / "scripts/multicast-routes.sh").read_text()
        run_shell(routes)
        route_log = Path(env["TEST_ROUTES"])
        assert route_log.read_text().splitlines() == [
            "route replace 224.0.0.251/32 dev eth7",
            "route replace 239.255.255.250/32 dev eth7",
        ]
        route_log.unlink()
        assert run_shell(routes, {"SCAN_INTERFACE": "management0"}, check=False).returncode == 1
        assert not route_log.exists(), "Wrong interface must not install routes"
        (container_env / "SCAN_INTERFACE").unlink()
        assert run_shell(routes, {"TEST_INTERFACE": ""}, check=False).returncode != 0
        assert not route_log.exists(), "Missing network must not install routes"

        xml = scratch / "scan.xml"
        xml.write_text('''<nmaprun><prescript><script id="broadcast" output="offer"/></prescript>
<host><ports><port><script id="http" output="status"/></port></ports>
<hostscript><script id="smb" output="dialect"/></hostscript></host></nmaprun>''')
        parsed = subprocess.run(["python3", str(TRAINING / "scripts/read-nmap-xml.py"), str(xml)],
                                check=True, capture_output=True, text=True)
        assert all(line in parsed.stdout for line in ("broadcast offer", "http status", "smb dialect"))

    print("Training checks passed: environment, interface selection, working copies, SSH initialization, routes and XML.")


if __name__ == "__main__":
    main()
