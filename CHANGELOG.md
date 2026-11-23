# Journal des versions

Chaque version suit le numéro du TP correspondant et est publiée avec une étiquette Git `v0.N.0`.

## 1.0.0 : installateur Windows

- Ajout d'un installateur Windows autonome avec son propre Python embarqué et le modèle inclus dans la roue.
- Ajout d'un lanceur `sentiment.cmd`, d'un raccourci Démarrer et d'une option pour ajouter la commande au PATH utilisateur.
- L'installation ne nécessite pas qu'un environnement Python soit présent sur le poste client.

## 0.6.0 (TP6) : le paquet installable

- Ajout du paquet `sentiment_app`, de la commande `sentiment` et de la version unique `0.6.0`.
- Déplacement de la prédiction dans le paquet, avec `SENTIMENT_MODELE` pour configurer le modèle séparément.
- Raccordement de l'API au paquet et maintien de la compatibilité avec `python src/predict.py`.
- Ajout de la construction de roue et de son essai hors du dépôt dans la CI.

## 0.5.0 (TP5) : l'interface

- Page Streamlit : un avis ou un fichier d'avis ; le client HTTP traduit chaque réponse de l'API.

## 0.4.0 (TP4) : tests et qualité

- Contrat d'entrée testé, abstention `INDETERMINE`, jeu d'or, tests d'intégration, contrat typé, ruff, mypy et pre-commit.

## 0.3.0 (TP3) : l'API

- FastAPI : `/health`, `/predict` et contrat Pydantic ; la CI entraîne le modèle avant les tests.

## 0.2.0 (TP2) : le modèle

- TF-IDF et régression logistique ; les métriques sont versionnées, le modèle ne l'est pas.

## 0.1.0 (TP1) : le cadrage

- Environnement Python 3.11, structure du dépôt, fiches de cadrage et dépôt GitHub collaboratif.
