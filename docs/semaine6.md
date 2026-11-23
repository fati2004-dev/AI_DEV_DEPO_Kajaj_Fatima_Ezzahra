# Compte rendu TP6

1. **Pourquoi le modèle est-il séparé du paquet ?** Le modèle a son propre cycle de vie : on peut le réentraîner ou le remplacer sans reconstruire ni republier le code. `SENTIMENT_MODELE` indique son emplacement au paquet.
2. **Que fournit le paquet installé ?** Il fournit le code de prédiction, l'API et la commande `sentiment`, dont la version `0.6.0` est définie une seule fois dans `sentiment_app/__init__.py`. Les tests, les données et le modèle ne sont pas inclus dans la roue.
3. **Comment vérifie-t-on que le paquet fonctionne hors du dépôt ?** La CI construit la roue, l'installe dans un nouvel environnement, puis lance la prédiction depuis un autre répertoire en donnant le chemin du modèle avec `SENTIMENT_MODELE`.
