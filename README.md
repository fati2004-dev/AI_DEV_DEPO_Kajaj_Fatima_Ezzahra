# sentiment-app

Application de classification de sentiment des avis clients, développée pour le cours
*Développement et déploiement d'applications intelligentes*.

## Utiliser l'application

La version Windows est distribuée sous forme d'installateur autonome :
`installateur/Output/sentiment-app-1.0.0-setup.exe`. Elle installe son propre Python et le
modèle, sans nécessiter Python sur le poste client. Après installation, ouvrez un nouveau
terminal :

```powershell
sentiment --version
sentiment predict "Livraison rapide, produit conforme, très satisfait"
```

Le paquet fournit aussi une API FastAPI (`sentiment serve`). L'interface Streamlit est
optionnelle et s'installe avec `pip install ".[ui]"`.

## Développer et tester

Avec Python 3.11 :

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-dev.txt
python src\train.py
python -m pytest -q
```

Le jeu d'or conserve six cas connus en `xfail`; ils signalent les limites actuelles du modèle.

## Construire la roue

Le modèle doit être placé dans `sentiment_app/models/sentiment.joblib` avant la construction :

```powershell
New-Item -ItemType Directory -Force sentiment_app\models
Copy-Item models\sentiment.joblib sentiment_app\models\sentiment.joblib
python -m build --wheel
```

## Construire l'installateur Windows

Activez l'environnement Python 3.11 ayant servi à produire le modèle, installez Inno Setup 6,
puis lancez depuis la racine :

```powershell
powershell -ExecutionPolicy Bypass -File installateur\build_installateur.ps1 -PythonVersion 3.11.9
```

Voir [installateur/README.md](installateur/README.md) pour les options. L'installateur final
est un artefact de publication; ne l'ajoutez pas au dépôt Git.
