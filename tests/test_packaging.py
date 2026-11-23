"""Tests for the installable package and command."""

import json
import re
import subprocess
import sys
import tomllib
from pathlib import Path
from types import SimpleNamespace

import pytest

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "models" / "sentiment.joblib"


def read_pyproject() -> dict:
    return tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))


def test_package_metadata():
    project = read_pyproject()["project"]
    assert project["name"] == "sentiment-app"
    assert project["scripts"]["sentiment"] == "sentiment_app.cli:main"
    assert any(dependency.startswith("scikit-learn") for dependency in project["dependencies"])


def test_only_runtime_packages_are_included():
    packages = read_pyproject()["tool"]["setuptools"]["packages"]
    assert packages == ["sentiment_app", "sentiment_app.models", "api", "ui"]
    assert "tests" not in packages and "src" not in packages


def test_ui_dependencies_are_optional():
    project = read_pyproject()["project"]
    assert "streamlit" not in project["dependencies"]
    assert any(
        dependency.startswith("streamlit")
        for dependency in project["optional-dependencies"]["ui"]
    )


def test_version_has_one_source():
    import sentiment_app

    assert re.fullmatch(r"\d+\.\d+\.\d+", sentiment_app.__version__)
    assert read_pyproject()["tool"]["setuptools"]["dynamic"]["version"]["attr"] == (
        "sentiment_app.__version__"
    )


def test_api_does_not_modify_python_path():
    for file in sorted((ROOT / "api").glob("*.py")):
        assert "sys.path" not in file.read_text(encoding="utf-8"), f"{file.name} modifies sys.path"


def test_model_path_can_be_configured(monkeypatch, tmp_path):
    from sentiment_app import predict

    model_path = tmp_path / "elsewhere.joblib"
    monkeypatch.setenv("SENTIMENT_MODELE", str(model_path))
    assert predict.chemin_modele() == model_path
    monkeypatch.delenv("SENTIMENT_MODELE")
    assert predict.chemin_modele() == ROOT / "sentiment_app" / "models" / "sentiment.joblib"


def test_version_command(capsys):
    from sentiment_app import __version__, cli

    with pytest.raises(SystemExit) as exit_info:
        cli.main(["--version"])
    assert exit_info.value.code == 0
    assert capsys.readouterr().out.strip() == f"sentiment-app {__version__}"


def test_module_entrypoint_displays_version():
    result = subprocess.run(
        [sys.executable, "-m", "sentiment_app", "--version"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    assert result.stdout.strip() == "sentiment-app 1.0.0"


def test_command_requires_a_subcommand():
    from sentiment_app import cli

    with pytest.raises(SystemExit) as exit_info:
        cli.main([])
    assert exit_info.value.code == 2


def test_missing_model_reports_configuration_help(monkeypatch, tmp_path, capsys):
    from sentiment_app import cli, predict

    monkeypatch.setattr(predict, "MODELE", tmp_path / "missing.joblib")
    predict.charger_modele.cache_clear()
    try:
        assert cli.main(["predict", "Un avis quelconque"]) == 1
        assert "SENTIMENT_MODELE" in capsys.readouterr().err
    finally:
        predict.charger_modele.cache_clear()


def test_serve_command_starts_api(monkeypatch):
    from sentiment_app import cli

    appels = []
    monkeypatch.setitem(
        sys.modules,
        "uvicorn",
        SimpleNamespace(run=lambda *args, **kwargs: appels.append((args, kwargs))),
    )
    assert cli.main(["serve"]) == 0
    assert appels == [
        (("api.main:app",), {"host": "127.0.0.1", "port": 8000})
    ]


def test_ui_command_starts_streamlit(monkeypatch):
    from sentiment_app import cli

    appels = []
    monkeypatch.setattr(cli.subprocess, "call", lambda command: appels.append(command) or 0)
    assert cli.main(["ui"]) == 0
    assert appels == [
        [sys.executable, "-m", "streamlit", "run", str(ROOT / "ui" / "app.py")]
    ]


@pytest.mark.skipif(not MODEL.exists(), reason="model not produced: run python src/train.py")
def test_predict_command(capsys):
    from sentiment_app import cli

    assert cli.main(["predict", "Livraison rapide, produit conforme, très satisfait"]) == 0
    result = json.loads(capsys.readouterr().out)
    assert result["label"] == "POSITIVE" and 0.5 <= result["score"] <= 1
