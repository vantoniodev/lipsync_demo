# LatentSync 1.6 VPS demo

Template simples de lipsync com LatentSync 1.6. Coloque a midia localmente em:

- Video: `materiais_teste/kobori_sem_audio.mp4`
- Audio: `materiais_teste/kobori_audio_separado.wav`

## Midia

Os arquivos de video/audio nao ficam versionados no git. Antes de rodar na VPS, copie seus arquivos para `materiais_teste/` com os nomes acima, ou informe caminhos customizados:

```bash
VIDEO_PATH=/caminho/video.mp4 AUDIO_PATH=/caminho/audio.wav bash scripts/preflight_media.sh
```

O script de preflight gera uma copia limpa apenas com o stream de video antes de chamar o LatentSync.

## Requisitos da VPS

Use uma VPS Linux com GPU NVIDIA/CUDA. O LatentSync 1.6 oficial exige aproximadamente 18 GB de VRAM para inferencia.

Recomendado:

- Ubuntu 22.04 ou 24.04
- Driver NVIDIA funcionando (`nvidia-smi`)
- GPU com 18 GB+ de VRAM
- `git`
- `conda` ou Miniconda/Mambaforge
- `apt-get` com permissao para instalar pacotes de sistema, ou compiladores ja instalados

## Uso rapido na VPS

```bash
git clone https://github.com/vantoniodev/lipsync_demo.git
cd lipsync_demo

bash scripts/setup_latentsync_1_6.sh
bash scripts/preflight_media.sh
bash scripts/run_latentsync_1_6.sh
```

O resultado principal sera criado em:

```text
outputs/kobori_latentsync_1_6.mp4
```

## Smoke test primeiro

Para validar instalacao e CUDA com um trecho curto:

```bash
bash scripts/make_smoke_test_clip.sh 15
VIDEO_PATH=work/smoke/kobori_video_15s.mp4 \
AUDIO_PATH=work/smoke/kobori_audio_15s.wav \
OUT_PATH=outputs/kobori_latentsync_1_6_smoke_15s.mp4 \
bash scripts/run_latentsync_1_6.sh
```

## Parametros uteis

O script aceita variaveis de ambiente:

```bash
STEPS=20 GUIDANCE=1.5 bash scripts/run_latentsync_1_6.sh
```

- `STEPS`: normalmente 20 a 50. Mais passos melhoram qualidade e deixam mais lento.
- `GUIDANCE`: normalmente 1.0 a 3.0. Valores altos podem melhorar sync, mas podem gerar jitter/distorcao.
- `ENABLE_DEEPCACHE=0`: desliga DeepCache se houver instabilidade.
- `USE_16K_AUDIO=1`: usa o WAV mono/16 kHz gerado no preflight para depuracao. Para resultado final, prefira o audio original.

## Estimativa de custo/performance

Baseline real medido em Vast.ai:

- GPU: NVIDIA A40
- Video: 2m30s
- Tempo de processamento: cerca de 40 min
- Preco: US$ 0.357/h
- Custo observado: cerca de US$ 0.095 por minuto de video processado

Formula:

```text
custo por minuto de video = preco_hora * minutos_processando / 150
```

Tabela estimada com precos informados em Vast.ai:

| GPU | Preco/h | Tempo estimado p/ 2m30s | US$/min video |
| --- | ---: | ---: | ---: |
| 4090 | 0.397 | 17-24 min | 0.045-0.064 |
| RTX PRO 6000 WS | 0.950 | 7-12 min | 0.044-0.076 |
| RTX 5880 Ada | 0.381 | 21-29 min | 0.053-0.074 |
| L40 | 0.434 | 18-25 min | 0.052-0.072 |
| RTX 6000 Ada | 0.541 | 16-23 min | 0.058-0.083 |
| A100 SXM4 | 0.542 | 18-25 min | 0.065-0.090 |
| A40 | 0.357 | 40 min real | 0.095 |

Leitura pratica:

- A 4090 tende a ser a melhor em custo por minuto, se a VRAM for suficiente e o host for confiavel.
- A RTX 5880 Ada parece uma boa alternativa com 48 GB.
- L40 e RTX 6000 Ada sao boas opcoes estaveis, mas precisam vencer pelo tempo real.
- RTX PRO 6000 WS pode ser a mais rapida, mas so compensa se ficar perto do limite baixo da estimativa.
- A100 SXM4 e A40 nao parecem as melhores opcoes para custo por minuto neste pipeline.
- Se o item `RTX 6000` for a antiga Quadro RTX 6000/Turing, evitar; se for Ada, usar a linha `RTX 6000 Ada`.

Para comparar provedores/GPU, rode sempre o mesmo clipe:

```bash
time bash scripts/run_latentsync_1_6.sh
```

## Arquivos gerados

Pastas ignoradas pelo git:

- `external/`: clone local do LatentSync
- `work/`: midia preparada e smoke clips
- `outputs/`: videos finais

## Troubleshooting

### `error: command 'g++' failed: No such file or directory`

O pacote `insightface` precisa compilar uma extensao nativa. Atualize o repo e rode o setup novamente:

```bash
git pull
bash scripts/setup_latentsync_1_6.sh
```

Em Ubuntu, o script instala `build-essential`, `gcc`, `g++`, `libgl1` e `libglib2.0-0`. Se a VPS nao tiver `apt-get` ou `sudo`, instale um compilador C++ manualmente antes do setup.

### `Missing required command: ffmpeg`

Atualize o repo. Os scripts recentes ativam o ambiente `latentsync` automaticamente quando o `ffmpeg` estiver instalado apenas dentro do conda:

```bash
git pull
bash scripts/preflight_media.sh
```

Tambem funciona ativar o ambiente manualmente:

```bash
conda activate latentsync
bash scripts/preflight_media.sh
```

### ONNXRuntime `libnvrtc.so.12` / `Applied providers: ['CPUExecutionProvider']`

Se o run mostrar mensagens como `Failed to load library libonnxruntime_providers_cuda.so with error: libnvrtc.so.12`, o PyTorch ainda pode estar usando a GPU, mas o InsightFace/ONNXRuntime caiu para CPU na etapa de deteccao de face. Atualize o repo e rode o setup uma vez para instalar/expor a lib CUDA NVRTC:

```bash
git pull
bash scripts/setup_latentsync_1_6.sh
bash scripts/run_latentsync_1_6.sh
```

O `run_latentsync_1_6.sh` exporta automaticamente os diretorios `site-packages/nvidia/*/lib` para `LD_LIBRARY_PATH`.
