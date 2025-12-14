#!/usr/bin/env python3
"""
Script para gerar ficheiro manifest.json com lista de CSV disponíveis
Executa: python3 generate_manifest.py
"""

import os
import json
from pathlib import Path

# Diretório atual (pasta TEST-DATA-CSV)
current_dir = Path(__file__).parent
csv_files = sorted(
    [f.name for f in current_dir.glob('*.csv')],
    reverse=True  # Mais recentes primeiro
)

manifest = {
    "files": csv_files,
    "count": len(csv_files),
    "generated": True
}

# Escrever ficheiro JSON
output_file = current_dir / 'files.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(manifest, f, indent=2)

print(f"✅ Ficheiro 'files.json' gerado com {len(csv_files)} ficheiros CSV")
print(f"Ficheiros encontrados: {csv_files}")
