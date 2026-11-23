# Build the Windows installer

The wheel, model, and Python dependency versions must come from the same
Python 3.11 environment used to train the model. Python 3.11.9 is a supported
choice for the embeddable distribution.

From the project root in PowerShell:

```powershell
py -3.11 -m venv .venv311
.\.venv311\Scripts\Activate.ps1
python -m pip install -e . build
python src\train.py
New-Item -ItemType Directory -Force sentiment_app\models
Copy-Item models\sentiment.joblib sentiment_app\models\sentiment.joblib
python -m build --wheel
powershell -ExecutionPolicy Bypass -File installateur\build_installateur.ps1 -PythonVersion 3.11.9
```

Install Inno Setup 6 once with:

```powershell
winget install JRSoftware.InnoSetup
```

The build script checks the wheel and Python versions, downloads the matching
official embeddable Python ZIP, installs the wheel and its locked dependencies,
and runs a version and prediction smoke test. To prepare and test `build\app`
without compiling the installer, pass `-SansCompilation`.

To select a specific wheel:

```powershell
powershell -ExecutionPolicy Bypass -File installateur\build_installateur.ps1 `
  -Roue dist\sentiment_app-1.0.0-py3-none-any.whl -PythonVersion 3.11.9
```

The compiled installer is written to `installateur\Output`. Do not commit the
installer or the staged embedded runtime; publish the setup executable as a
GitHub Release asset.
