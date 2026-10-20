# 27401GT076 - Implantación de un Servidor de IA Local para los CCFF de Informática

Repositorio oficial del **Grupo de Trabajo 27401GT076** del departamento de Informática del **IES Celia Viñas** (Almería), en colaboración con el Centro del Profesorado (CEP) de Almería para el curso 2026/2027.

## Propósito del Proyecto

Desplegar, securizar y documentar una infraestructura de **Inteligencia Artificial local y autogestionada** en el centro educativo para los ciclos formativos de la familia de Informática y Comunicaciones (**SMR, ASIR, DAM, DAW**) y el **Curso de Especialización en Ciberseguridad**.

### ¿Por qué IA local en el centro?

* **Privacidad y RGPD:** Consultas, código y datos quedan confinados en la red local del centro.

* **Equidad y Sostenibilidad:** Acceso sin suscripciones de pago ni coste por token para todo el alumnado.

* **Perfil Técnico Profesional:** El alumnado pasa de ser usuario pasivo de un chatbot a utilizar servicios de inferencia y consumir APIs locales estandarizadas.

## Stack Tecnológico y Arquitectura

* **SO Host:** Linux (Ubuntu Server / Debian) con drivers NVIDIA + CUDA 12.6.

* **Motores de Inferencia:** `vLLM`, `Ollama` y `llama.cpp`.

* **Orquestación:** Docker y Docker Compose (`nvidia-container-toolkit`).

* **Interfaz de Usuario / RAG:** [OpenWebUI](https://github.com/open-webui/open-webui) con base de conocimiento integrada.

* **Modelos Evaluados:** Familias abiertas y multimodales  en versiones densas y cuantizadas (AWQ 4-bit, GGUF).

* **APIs:** Interfaz compatible con OpenAI y Hugging Face p.

## Estructura del Repositorio

```
├── docker/
│   ├── ollama/                  # Docker compose para levantar OpenWebUI + Ollama (para la prueba de motores)
│   └── vLLM/                    # Docker compose para levantar OpenWebUI + vLLM
├── benchmarks/
│   ├── benchmark.sh             # Script de estrés para medir latencia (TTFT) y tokens/s
│   └── resultados/              # Logs comparativos de rendimiento y consumo de VRAM
├── docs/
│   ├── guia_instalacion.md      # Puesta en producción y configuración de drivers/Docker
│   ├── securizacion_backups.md  # Políticas de acceso, red local, firewall y copias
│   └── catalogo_modelos.md      # Evaluación crítica (precisión en Bash/SQL/código vs alucinaciones)
├── practicas_aula/
│   ├── asir_smr/                # Monitorización (nvidia-smi), logs, cuellos de botella y Docker
│   ├── dam_daw/                 # Integración de API local en Python/Java/PHP y consultas SQL
│   └── ciberseguridad/          # Auditoría, prompts estructurados y análisis de seguridad
└── prompts/                     # Banco de prompts técnicos y pruebas para RAG

```
## Aplicación Didáctica en Ciclos Formativos

| Ciclo | Enfoque Principal en el Aula | 
| ----- | ----- | 
| **SMR / ASIR** | Despliegue de contenedores, logs, monitorización de GPU/VRAM con `nvidia-smi`, reglas de cortafuegos  | 
| **DAM / DAW** | Consumo de la API local desde código (Python, Java, PHP), optimización de consultas SQL complejas y depuración guiada sin conexión externa. | 
| **Ciberseguridad** | Consumo de la API local desde código (Python, Java, PHP) | 

* **Asesoría de Referencia:** Centro del Profesorado (CEP) de Almería.

## Licencias

* **Código fuente y scripts** (`docker-compose.yml`, scripts `.sh`, código de clientes): Licencia [MIT](LICENSE-CODE).

* **Materiales educativos y documentación** (guías, situaciones de aprendizaje, catálogos): Licencia [Creative Commons Reconocimiento-CompartirIgual 4.0 Internacional (CC BY-SA 4.0)](LICENSE-DOCS).
