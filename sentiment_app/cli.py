"""Command-line interface for sentiment-app."""

import argparse
import json
import subprocess
import sys
from pathlib import Path

from sentiment_app import __version__


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sentiment")
    parser.add_argument("--version", action="version", version=f"sentiment-app {__version__}")
    commands = parser.add_subparsers(dest="command", required=True)

    prediction = commands.add_parser("predict", help="classify a French review")
    prediction.add_argument("text", nargs="+", help="review text")
    commands.add_parser("serve", help="start the REST API")
    commands.add_parser("ui", help="start the Streamlit interface")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)

    if args.command == "predict":
        from api.model import SentimentClassifier

        try:
            result = SentimentClassifier().predict(" ".join(args.text))
        except FileNotFoundError as error:
            print(error, file=sys.stderr)
            return 1
        print(json.dumps(result, ensure_ascii=False))
        return 0

    if args.command == "serve":
        import uvicorn

        uvicorn.run("api.main:app", host="127.0.0.1", port=8000)
        return 0

    app = Path(__file__).resolve().parents[1] / "ui" / "app.py"
    return subprocess.call([sys.executable, "-m", "streamlit", "run", str(app)])
