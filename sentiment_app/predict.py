#!/usr/bin/env python
"""Prediction functions for the sentiment model."""

import os
import sys
from functools import lru_cache
from pathlib import Path
from typing import Literal, TypedDict, cast

import joblib
from sklearn.pipeline import Pipeline

RACINE = Path(__file__).resolve().parent


def chemin_modele() -> Path:
    """Return the configured model path, defaulting to this project's model."""
    return Path(os.environ.get("SENTIMENT_MODELE") or RACINE / "models" / "sentiment.joblib")


MODELE = chemin_modele()
ModelSentiment = Literal["positive", "negative"]


class PredictionResult(TypedDict):
    label: ModelSentiment
    score: float


@lru_cache(maxsize=1)
def charger_modele() -> Pipeline:
    """Load the model once per process."""
    if not MODELE.exists():
        raise FileNotFoundError(
            f"Modèle introuvable : {MODELE}. "
            "Lancez python src/train.py ou indiquez son chemin dans SENTIMENT_MODELE."
        )
    return cast(Pipeline, joblib.load(MODELE))


def predict(texte: str) -> PredictionResult:
    """Return the positive/negative label and confidence."""
    if not isinstance(texte, str) or not texte.strip():
        raise ValueError("texte vide")

    pipeline = charger_modele()
    prediction = pipeline.predict([texte])[0]
    if prediction not in {"positive", "negative"}:
        raise RuntimeError(f"Classe de sentiment inattendue : {prediction!r}")
    etiquette = cast(ModelSentiment, prediction)
    score = float(pipeline.predict_proba([texte]).max())

    return {"label": etiquette, "score": round(score, 4)}


def main(argv: list[str] | None = None) -> int:
    """Run the legacy one-text prediction command."""
    arguments = sys.argv[1:] if argv is None else argv
    if not arguments:
        print(__doc__)
        return 2

    resultat = predict(" ".join(arguments))
    print(f"{resultat['label']} (confiance {resultat['score']:.0%})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
