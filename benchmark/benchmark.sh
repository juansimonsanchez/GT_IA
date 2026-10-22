#!/usr/bin/env bash
# ==============================================================================
# Script de benchmarking universal para LLMs (API compatible con OpenAI)
# Compatible con: vLLM, Ollama, LM Studio, TGI, Aphrodite, OpenAI, Groq, DeepSeek, etc.
# Soporta: Modelos Instruct estándar y modelos de razonamiento (DeepSeek-R1, etc.)
#
# Uso:
#   ./benchmark.sh <URL_BASE> <MODEL_NAME> [API_KEY]
# Ejemplos:
#   ./benchmark.sh http://localhost:8000/v1 Qwen/Qwen2.5-7B-Instruct-AWQ
#   ./benchmark.sh http://localhost:11434/v1 deepseek-r1:7b
#   ./benchmark.sh https://api.openai.com/v1 gpt-4o-mini sk-tu-clave
# ==============================================================================

set -euo pipefail

URL="${1:-http://localhost:8000/v1}"
MODEL="${2:-Qwen/Qwen2.5-7B-Instruct-AWQ}"
API_KEY="${3:-dummy_key}"

# Validar dependencias
for cmd in python3 curl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: Se requiere '$cmd' instalado en el sistema." >&2
    exit 1
  fi
done

# Prompt exigente: arquitectura de SO, matemáticas y código
PROMPT=$(cat << 'EOF'
Actúa como un arquitecto sénior de sistemas operativos y sistemas distribuidos.
Realiza un análisis exhaustivo y técnico comparando dos estrategias críticas de memoria virtual:
1. Paginación multinivel tradicional (ej. x86-64 con 4 o 5 niveles) asistida por TLB de múltiples niveles (L1i, L1d, L2/STLB).
2. Tablas de páginas invertidas (Inverted Page Tables / Hashed Page Tables) como las usadas históricamente en arquitecturas PowerPC o IA-64.

Tu respuesta debe incluir obligatoriamente:
- Análisis matemático paso a paso del overhead de memoria de cada enfoque dado un espacio de direcciones de 48 bits, páginas de 4 KiB y 64 GiB de RAM física.
- El ciclo de vida exacto de una traducción (TLB hit, TLB miss, page table walk y page fault) detallando registros de control e interrupciones hardware.
- El impacto del TLB shootdown en sistemas multicore/NUMA bajo alta concurrencia, analizando el rol de las IPIs (Inter-Processor Interrupts).
- Una implementación funcional y robusta en C (con estructuras, manejo de colisiones por encadenamiento y simulación de TLB asociativa de 4 vías con política LRU) que demuestre la resolución de direcciones para una tabla invertida.
EOF
)

echo "======================================================================"
echo "                   BENCHMARK DE RENDIMIENTO LLM                      "
echo "======================================================================"
echo "Endpoint : $URL"
echo "Modelo   : $MODEL"
echo "Max Tok  : 2048"
echo "Modo     : Streaming (SSE)"
echo "======================================================================"
echo "Iniciando stream y registrando telemetría..."

METRICS=$(python3 - <<EOF
import json
import os
import sys
import time
import urllib.error
import urllib.request

url = "${URL}/chat/completions"
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer ${API_KEY}"
}

# Payload base universal
payload = {
    "model": "${MODEL}",
    "messages": [
        {
            "role": "system",
            "content": "Eres un ingeniero de sistemas experto y riguroso. Proporciona explicaciones técnicas profundas y exhaustivas sin omitir detalles de implementación."
        },
        {
            "role": "user",
            "content": """${PROMPT}"""
        }
    ],
    "max_tokens": 2048,
    "temperature": 0.0,
    "stream": True,
    "stream_options": {"include_usage": True}
}

req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers=headers
)

# Fallback si el backend rechaza stream_options (motores o proxies antiguos)
try:
    resp = urllib.request.urlopen(req, timeout=180)
except urllib.error.HTTPError as e:
    if e.code == 400 and "stream_options" in payload:
        payload.pop("stream_options", None)
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers
        )
        resp = urllib.request.urlopen(req, timeout=180)
    else:
        err_msg = e.read().decode("utf-8", errors="ignore")
        sys.stderr.write(f"\n[HTTP Error {e.code}]: {err_msg}\n")
        sys.exit(1)
except Exception as e:
    sys.stderr.write(f"\n[Error de conexión]: {str(e)}\n")
    sys.exit(1)

t_start = time.perf_counter()
t_first_token = None
chunks_count = 0
reasoning_chunks = 0
content_chunks = 0
reported_prompt_tokens = 0
reported_completion_tokens = 0

with resp:
    for line in resp:
        line_str = line.decode("utf-8").strip()
        if not line_str.startswith("data:"):
            continue

        raw_data = line_str[5:].strip()
        if raw_data == "[DONE]":
            break

        try:
            data = json.loads(raw_data)
            choices = data.get("choices", [])
            if choices:
                delta = choices[0].get("delta", {})
                
                # Soporte universal: token normal o token de razonamiento (DeepSeek-R1 / o1 / o3)
                r_token = delta.get("reasoning_content") or ""
                c_token = delta.get("content") or ""
                
                if r_token or c_token:
                    if t_first_token is None:
                        t_first_token = time.perf_counter()
                    if r_token:
                        reasoning_chunks += 1
                    if c_token:
                        content_chunks += 1
                    chunks_count += 1

            usage = data.get("usage")
            if usage:
                reported_prompt_tokens = usage.get("prompt_tokens", 0)
                reported_completion_tokens = usage.get("completion_tokens", 0)

        except json.JSONDecodeError:
            continue

t_end = time.perf_counter()

if t_first_token is None:
    sys.stderr.write("\nError: No se recibió ningún token de salida en la respuesta.\n")
    sys.exit(1)

final_completion_tokens = reported_completion_tokens if reported_completion_tokens > 0 else chunks_count
final_prompt_tokens = reported_prompt_tokens

ttft = t_first_token - t_start
gen_time = t_end - t_first_token
total_time = t_end - t_start
tps = (final_completion_tokens / gen_time) if gen_time > 0 else 0.0
itl_ms = (gen_time / max(1, final_completion_tokens - 1)) * 1000.0 if final_completion_tokens > 1 else 0.0

print(f"{final_prompt_tokens}|{final_completion_tokens}|{ttft:.4f}|{gen_time:.4f}|{total_time:.4f}|{tps:.2f}|{itl_ms:.2f}|{reasoning_chunks}|{content_chunks}")
EOF
)

# Parsear métricas
IFS='|' read -r PROMPT_TOKENS COMPLETION_TOKENS TTFT GEN_TIME TOTAL_TIME TPS ITL_MS REASON_CHUNKS CONTENT_CHUNKS <<< "$METRICS"

echo "----------------------------------------------------------------------"
echo "                       RESULTADOS DE LA PRUEBA                        "
echo "----------------------------------------------------------------------"
printf "%-32s : %s\n" "Tokens de entrada (Prompt)" "$PROMPT_TOKENS"
printf "%-32s : %s\n" "Tokens generados (Salida)" "$COMPLETION_TOKENS"
printf "%-32s : %s (Razonamiento: %s | Contenido: %s)\n" "Chunks recibidos" "$((REASON_CHUNKS + CONTENT_CHUNKS))" "$REASON_CHUNKS" "$CONTENT_CHUNKS"
printf "%-32s : %ss\n" "Latencia al 1er Token (TTFT)" "$TTFT"
printf "%-32s : %ss\n" "Tiempo neto de decodificación" "$GEN_TIME"
printf "%-32s : %ss\n" "Tiempo total de ejecución" "$TOTAL_TIME"
printf "%-32s : %sms\n" "Inter-Token Latency (ITL media)" "$ITL_MS"
echo "----------------------------------------------------------------------"
printf "%-32s : \033[1;32m%s tokens/s\033[0m\n" "Velocidad de generación (TPS)" "$TPS"
echo "======================================================================"
