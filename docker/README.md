# Guía de Despliegue y Prueba de Motores de Inferencia (Docker)

Esta carpeta contiene las configuraciones de **Docker Compose** para desplegar y comparar distintos motores de inferencia local (**Ollama**, **vLLM** y **SGLang**) junto con la interfaz web **Open WebUI**.

> [!IMPORTANT]
> **Un único motor activo a la vez en GPU:**  
> Todos los motores reservan entre el **80% y el 93% de la VRAM** de la tarjeta gráfica (ej. 16 GB en la NVIDIA RTX 5070 Ti). **Antes de levantar un motor nuevo, asegúrate siempre de detener el anterior** para evitar errores de memoria (`CUDA Out of Memory`) o bloqueos en el arranque.

---

## 1. Configuración Previa (`HF_TOKEN`)

Algunos modelos alojados en Hugging Face (como la familia *Gemma* o *Llama*) requieren aceptar su licencia y autenticarse mediante un token.

1. Copia el archivo de plantilla en la raíz del proyecto:
   ```bash
   cp ../.env.example ../.env
   ```
2. Edita el archivo `.env` y añade tu token de Hugging Face:
   ```env
   HF_TOKEN=hf_tu_token_real_aqui
   ```
*(Todos los archivos `docker-compose.yml` cargan automáticamente este `.env` centralizado).*

---

## 2. Resumen de Despliegues Disponibles

| Carpeta | Motor | Modelo por Defecto | Puerto API (Host) | Puerto Open WebUI | Caché en Host |
| :--- | :--- | :--- | :---: | :---: | :--- |
| [`Ollama/`](./Ollama) | **Ollama** | Gestión dinámica (`GGUF`) | `11434` | `3000` | `/srv/ai-models/ollama` |
| [`vLLM/`](./vLLM) | **vLLM** | `Qwen/Qwen2.5-7B-Instruct-AWQ` | `8000` | `3000` | `/srv/ai-models/huggingface` |
| [`sglang/`](./sglang) | **SGLang** | `Qwen/Qwen2.5-7B-Instruct-AWQ` | `30000` | `3001` | `/srv/ai-models/huggingface` |
| [`Qwen2.5-7B/`](./Qwen2.5-7B) | **vLLM** | `Qwen/Qwen2.5-VL-7B-Instruct-AWQ` | `8000` | `3000` | `/srv/ai-models/huggingface` |
| [`Gemma4-e4b-it/`](./Gemma4-e4b-it) | **vLLM** | `google/gemma-4-e4b-it` | `8000` | `3000` | `/srv/ai-models/huggingface` |

---

## 3. Cómo Levantar y Parar cada Motor

### A) Ollama (`docker/Ollama`)
Ideal para pruebas rápidas de modelos cuantizados en formato `GGUF`.

* **Levantar:**
  ```bash
  cd docker/Ollama
  sudo docker compose up -d
  ```
* **Ver modelos descargados o descargar uno nuevo:**
  ```bash
  # Listar modelos instalados
  sudo docker exec -it ollama-backend ollama list

  # Descargar un modelo (ej. Qwen 2.5 7B)
  sudo docker exec -it ollama-backend ollama pull qwen2.5:7b
  ```
* **Ver logs en tiempo real:**
  ```bash
  sudo docker logs -f ollama-backend
  ```
* **Parar:**
  ```bash
  cd docker/Ollama
  sudo docker compose down
  ```

---

### B) vLLM (`docker/vLLM`, `docker/Qwen2.5-7B`, `docker/Gemma4-e4b-it`)
Motor orientado a producción y alta concurrencia mediante *PagedAttention*.

* **Levantar:**
  ```bash
  cd docker/vLLM   # (o Qwen2.5-7B / Gemma4-e4b-it)
  sudo docker compose up -d
  ```
* **Verificar que el modelo ha terminado de cargar:**
  ```bash
  sudo docker logs -f vllm-backend
  ```
  *(Espera hasta ver la línea `Application startup complete.` antes de lanzar peticiones).*
* **Parar:**
  ```bash
  cd docker/vLLM
  sudo docker compose down
  ```

---

### C) SGLang (`docker/sglang`)
Alternativa de alto rendimiento a vLLM que incorpora **RadixAttention** (reutilización automática de la caché KV entre peticiones que comparten prompt de sistema o historial).

* **Levantar:**
  ```bash
  cd docker/sglang
  sudo docker compose up -d
  ```
  *(Nota: La primera vez descargará la imagen `lmsysorg/sglang:latest` de ~15 GB).*
* **Verificar que el servidor está listo:**
  ```bash
  sudo docker logs -f sglang-backend
  ```
  *(Espera hasta ver `The server is fired up and ready to roll!`).*
* **Parar:**
  ```bash
  cd docker/sglang
  sudo docker compose down
  ```

---

## 4. Comandos de Diagnóstico y Verificación

Antes de ejecutar un benchmark, puedes comprobar el estado de la GPU y de la API con estos comandos:

1. **Comprobar qué proceso ocupa la VRAM de la GPU:**
   ```bash
   nvidia-smi
   ```
2. **Listar qué contenedores están encendidos actualmente:**
   ```bash
   sudo docker ps
   ```
3. **Consultar a la API qué modelo exacto está cargado (estándar OpenAI):**
   * En **vLLM** (puerto `8000`):
     ```bash
     curl -s http://localhost:8000/v1/models | python3 -m json.tool
     ```
   * En **SGLang** (puerto `30000`):
     ```bash
     curl -s http://localhost:30000/v1/models | python3 -m json.tool
     ```
   * En **Ollama** (puerto `11434`):
     ```bash
     curl -s http://localhost:11434/v1/models | python3 -m json.tool
     ```

---

## 5. Cómo Probar el Rendimiento (`benchmark.sh`)

El script [`../benchmark/benchmark.sh`](../benchmark/benchmark.sh) envía un prompt técnico complejo en modo *streaming* (SSE) y mide:
* **TTFT (*Time To First Token*):** Tiempo de prefill / latencia hasta recibir el primer token.
* **ITL (*Inter-Token Latency*):** Latencia media entre tokens consecutivos (ms).
* **TPS (*Tokens Per Second*):** Velocidad neta de generación (tokens/s).

> [!NOTE]
> El nombre del modelo que pases como segundo argumento **debe coincidir exactamente** con el identificador `"id"` que devuelve el endpoint `/v1/models` de cada motor.

### Ejemplos de ejecución según el motor activo:

* **Probar vLLM:**
  ```bash
  ./benchmark/benchmark.sh http://localhost:8000/v1 Qwen/Qwen2.5-7B-Instruct-AWQ
  ```

* **Probar SGLang:**
  ```bash
  ./benchmark/benchmark.sh http://localhost:30000/v1 Qwen/Qwen2.5-7B-Instruct-AWQ
  ```
  *(Tip: Ejecútalo dos veces seguidas en SGLang para observar cómo disminuye el **TTFT** en la segunda ejecución gracias a la caché de prefijos de RadixAttention).*

* **Probar Ollama:**
  ```bash
  ./benchmark/benchmark.sh http://localhost:11434/v1 qwen2.5:7b
  ```

