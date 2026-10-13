from contextlib import redirect_stderr, redirect_stdout
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

PATH = Path(__file__).resolve().parents[1] / "etc/nmap-training/scripts/nmap-sage"
loader = importlib.machinery.SourceFileLoader("nmap_sage", str(PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
sage = importlib.util.module_from_spec(spec)
loader.exec_module(sage)


class SageClientTests(unittest.TestCase):
    def run_main(self, args, key="test-key", error=None):
        out, err = io.StringIO(), io.StringIO()
        with patch.dict(os.environ, {"NMAP_SAGE_API_KEY": key}), patch("sys.argv", ["nmap-sage", *args]), \
                patch.object(sage, "ask", return_value="nmap -sV TARGET", side_effect=error) as ask, \
                redirect_stdout(out), redirect_stderr(err):
            code = sage.main()
        return code, out.getvalue(), err.getvalue(), ask

    def test_quoted_and_unquoted_arguments_print_only_the_answer(self):
        for args in (["how can I scan FTP"], ["how", "can", "I", "scan", "FTP"]):
            code, out, err, ask = self.run_main(args)
            self.assertEqual((code, out, err), (0, "nmap -sV TARGET\n", ""))
            ask.assert_called_once_with("how can I scan FTP", "test-key")

    def test_missing_key_and_invalid_questions_do_not_send(self):
        for args, key, expected in ((["nmap"], "", 1), ([], "test-key", 2), (["x" * 2001], "test-key", 2)):
            code, out, err, ask = self.run_main(args, key)
            self.assertEqual(code, expected)
            self.assertEqual(out, "")
            self.assertTrue(err)
            ask.assert_not_called()

    def test_network_and_refusal_errors_are_clean(self):
        errors = [URLError("private connection detail"), ValueError("private invalid answer detail"),
                  HTTPError(sage.ENDPOINT, 400, "private", {}, io.BytesIO(b'{"error":{"type":"nmap_only"}}')),
                  HTTPError(sage.ENDPOINT, 500, "private", {}, io.BytesIO(b'private provider failure'))]
        for error in errors:
            code, out, err, ask = self.run_main(["question"], error=error)
            self.assertEqual(code, 1)
            self.assertEqual(out, "")
            self.assertNotIn("private", err)
            self.assertNotIn("test-key", err)

    def test_https_bearer_and_redirect_protection(self):
        response = io.BytesIO(json.dumps({"choices": [{"message": {"content": "nmap -sV TARGET"}}]}).encode())
        with patch.object(sage, "build_opener") as opener:
            opener.return_value.open.return_value = response
            self.assertEqual(sage.ask("scan FTP", "test-key"), "nmap -sV TARGET")
            request = opener.return_value.open.call_args.args[0]
            self.assertEqual(request.full_url, sage.ENDPOINT)
            self.assertEqual(request.get_header("Authorization"), "Bearer test-key")
            self.assertEqual(json.loads(request.data)["messages"][0]["content"], "scan FTP")
            self.assertIsInstance(opener.call_args.args[0], sage.NoRedirect)
        self.assertIsNone(sage.NoRedirect().redirect_request(None, None, 302, "", {}, "https://elsewhere"))

    def test_invalid_response_and_terminal_controls(self):
        for content in ("nmap TARGET\x1b[31m", "nmap TARGET\nsecond line", "x" * 301, None):
            with patch.object(sage, "build_opener") as opener:
                opener.return_value.open.return_value = io.BytesIO(
                    json.dumps({"choices": [{"message": {"content": content}}]}).encode())
                with self.assertRaises(ValueError):
                    sage.ask("scan", "test-key")


if __name__ == "__main__":
    unittest.main()
