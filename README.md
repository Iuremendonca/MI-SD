# 🧠 ELM Acelerador — TEC 499 MI Sistemas Digitais 2026.1

> **Marco 1 — Co-processador ELM em FPGA + Simulação**
> Universidade Estadual de Feira de Santana · Departamento de Tecnologia

<div align="center">

[![Simulation](https://img.shields.io/badge/simulação-Icarus%20Verilog-blue)](#simulação)
[![Target](https://img.shields.io/badge/alvo-DE1--SoC%20(Cyclone%20V)-orange)](#hardware)
[![Format](https://img.shields.io/badge/ponto%20fixo-Q4.12-green)](#formato-numérico)
[![License](https://img.shields.io/badge/disciplina-TEC%20499-purple)](#)
[![UEFS](https://img.shields.io/badge/UEFS-DEXA-red)](#)

</div>

---

## 📋 Sumário

### Marco 1 — Co-processador ELM em FPGA + Simulação
1. [Visão Geral do Projeto](#1-visão-geral-do-projeto)
2. [Levantamento de Requisitos](#2-levantamento-de-requisitos)
3. [Arquitetura do Hardware](#3-arquitetura-do-hardware)
4. [Formato Numérico Q4.12](#4-formato-numérico-q412)
5. [Descrição dos Módulos RTL](#5-descrição-dos-módulos-rtl)
6. [Mapa de Registradores / ISA](#6-mapa-de-registradores--isa)
7. [Uso de Recursos FPGA](#7-uso-de-recursos-fpga)
8. [Ambiente de Desenvolvimento](#8-ambiente-de-desenvolvimento)
9. [Instalação e Configuração](#9-instalação-e-configuração)
10. [Processo de Desenvolvimento](#10-processo-de-desenvolvimento)
11. [Simulação e Testes](#11-simulação-e-testes)
12. [Análise dos Resultados](#12-análise-dos-resultados)
13. [Estrutura do Repositório](#13-estrutura-do-repositório)
14. [Equipe](#14-equipe)
15. [Referências](#15-referências)

### Marco 2 — Integração HW↔Linux via Driver Assembly
16. [Levantamento de Requisitos — Marco 2](#16-levantamento-de-requisitos--marco-2)
17. [Visão Geral do Marco 2](#17-visão-geral-do-marco-2)
18. [Configuração do Platform Designer](#18-configuração-do-platform-designer)
19. [Geração do Cabeçalho de Endereços](#19-geração-do-cabeçalho-de-endereços)
20. [Driver Assembly — API Pública](#20-driver-assembly--api-pública)
21. [Mapa de Registradores MMIO](#21-mapa-de-registradores-mmio)
22. [Formato das Instruções ISA (32 bits)](#22-formato-das-instruções-isa-32-bits)
23. [Fluxo Completo de Inferência](#23-fluxo-completo-de-inferência)
24. [Compilação e Execução — Marco 2](#24-compilação-e-execução--marco-2)
25. [Teste de Estabilidade — Marco 2](#25-teste-de-estabilidade--marco-2)


---

## 1. Visão Geral do Projeto

Este repositório contém a implementação RTL (Register-Transfer Level) em **Verilog** de um co-processador dedicado à inferência de dígitos manuscritos (0–9) utilizando uma **Extreme Learning Machine (ELM)** [[3]](#15-referências) sobre a plataforma **DE1-SoC** (Intel Cyclone V SoC) [[1]](#15-referências).

O sistema classifica imagens 28×28 pixels (MNIST) em escala de cinza, executando os seguintes estágios sequenciais:

<img width="665" height="294" alt="image" src="https://github.com/user-attachments/assets/206e8c31-1b12-4c8d-b218-a92a96730bfc" />

---

### 1.1 Entrada de Dados

O processo inicia com a leitura do vetor de entrada que representa a imagem.

* **Tamanho:** 784 bytes (ex: matriz $28 \times 28$).
* **Ação:** Os dados são carregados para a memória interna do acelerador.

---

### 1.2 Camada Oculta (Hidden Layer)

Processamento da transformação não-linear dos dados de entrada [[3]](#15-referências)[[4]](#15-referências).

* **Equação:** $$h = \sigma(W_n \cdot x + b)$$
* **Onde:**
  * $W_n$: Matriz de pesos.
  * $x$: Pixel.
  * $b$: Vetor de bias.
  * $\sigma$: Função de ativação.

---

### 1.3 Camada de Saída (Output Layer)

Cálculo da combinação linear dos neurônios ocultos com os pesos de saída [[3]](#15-referências).

* **Equação:** $$y = \beta \cdot h$$
* **Onde:**
  * $\beta$: Matriz de pesos de saída (obtida no pré-treino).

---

### 1.4 Cômputo da Predição

Fase final onde a rede decide qual classe o dado pertence.

* **Lógica:** $$\text{pred} = \text{argmax}(y)$$
* **Resultado:** O sistema retorna um valor no intervalo **0..9**, indicando o dígito identificado.

---

**Parâmetros do modelo:**

| Parâmetro | Dimensão | Memória |
|-----------|----------|---------|
| W (pesos oculta) | 128 × 784 | ~200 KB (Q4.12) |
| b (bias oculta) | 128 × 1 | 256 B |
| β (pesos saída) | 10 × 128 | ~2,5 KB (Q4.12) |

---

## 2. Levantamento de Requisitos

### 2.1 Requisitos Funcionais

| ID | Requisito |
|----|-----------|
| RF-01 | O co-processador deve aceitar uma imagem 28×28 pixels, 8 bits por pixel (0–255) |
| RF-02 | Deve implementar a camada oculta: `h = sigmoid(W · x + b)` com 128 neurônios |
| RF-03 | Deve implementar a camada de saída: `y = β · h` com 10 neurônios (classes) |
| RF-04 | Deve retornar a predição `pred = argmax(y)` no intervalo [0, 9] |
| RF-05 | Todos os valores internos devem ser representados em ponto fixo Q4.12 |
| RF-06 | A arquitetura deve ser sequencial com FSM de controle |
| RF-07 | Deve haver um datapath MAC (Multiply-Accumulate) |
| RF-08 | A ativação da camada oculta deve ser approximada (piecewise linear) |
| RF-09 | Deve possuir memórias para imagem, pesos W, bias b e pesos β |
| RF-10 | A ISA deve incluir: STORE_IMG, STORE_WEIGHTS, STORE_BIAS, START, STATUS |

### 2.2 Requisitos Não-Funcionais

| ID | Requisito |
|----|-----------|
| RNF-01 | Sintetizável para DE1-SoC (Cyclone V — 5CSEMA5F31C6) |
| RNF-02 | Clock alvo: 50 MHz |
| RNF-03 | Testbench com ao menos K vetores de teste comparando com golden model |
| RNF-04 | Código Verilog com comentários e estilo consistente |

### 2.3 Restrições

- Representação exclusiva em ponto fixo Q4.12 (sem ponto flutuante)
- Pesos devem residir em blocos RAM/ROM inicializados (arquivos `.mif`)
- Arquitetura estritamente sequencial (sem paralelismo entre camadas)

---

## 3. Arquitetura do Hardware

### 3.1 Diagrama de Blocos (Datapath + FSM)

A arquitetura segue os princípios de co-processadores para aceleração de redes neurais em FPGA [[2]](#15-referências)[[7]](#15-referências).

<img width="591" height="940" alt="image" src="https://github.com/user-attachments/assets/adea536d-085e-491e-bc11-897d8a7fea6b" />


### 3.2 Estados da FSM

<img width="419" height="512" alt="image" src="https://github.com/user-attachments/assets/63d76b3d-a681-4fe9-89ca-9a10e4b5651c" />

---

## 4. Formato Numérico Q4.12

Todos os valores internos utilizam ponto fixo **Q4.12** (signed, 16 bits):

```
  Bit 15   │  Bits 14–12  │  Bits 11–0
  ─────────┼──────────────┼────────────
  Sinal    │  Parte int.  │  Parte frac.
  (1 bit)  │   (3 bits)   │  (12 bits)
```

- **Resolução:** `1/4096 ≈ 0.000244`
- **Faixa representável:** `[-8.0, +7.999756...]`
- **Conversão:** valor_real = valor_inteiro / 4096

### Saturação no MAC

O acumulador interno usa 40 bits para evitar overflow durante a soma. O resultado final é saturado para a faixa Q4.12:

```verilog
if (resultado > 40'sd32767) saida <= 16'h7FFF;  // +7.999...
else if (resultado < -40'sd32768) saida <= 16'h8000;  // -8.0
else saida <= resultado [15:0];
```

---

## 5. Descrição dos Módulos RTL

| Arquivo | Módulo | Função |
| :--- | :--- | :--- |
| `elm_accel.v` | `elm_accel` | **Top-level;** integra todos os submódulos e gerencia o barramento global. |
| **Controle e Decodificação** | | |
| `fsm_elm.v` | `fsm_elm` | FSM de 4 estados; coordena o fluxo de dados e sinais de controle. |
| `decodificador_isa.v` | `decodificador_isa` | Decodifica instruções de 32 bits, extraindo Opcode, ADDR e DATA. |
| **Datapath (Cálculo)** | | |
| `camada_oculta.v` | `camada_oculta` | Gerencia o processamento da primeira camada ($784 \times 128$). |
| `camada_saida.v` | `camada_saida` | Gerencia o processamento da camada de saída ($128 \times 10$). |
| `mac.v` | `mac` | Unidade Multiply-Accumulate de 40 bits com saturação em **Q4.12**. |
| `ativacao_sigmoid.v` | `ativacao_sigmoid` | Implementa a função Sigmóide via aproximação linear (4 segmentos). |
| `argmax.v` | `argmax` | Compara os 10 resultados finais e identifica o índice da classe vencedora. |
| **Memórias (RAM)** | | |
| `ram_img.v` | `ram_img` | Armazena o vetor da imagem de entrada (784 bytes). |
| `ram_pesos.v` | `ram_pesos` | Armazena a matriz de pesos $W$ (100K x 16 bits). |
| `ram_bias.v` | `ram_bias` | Armazena o vetor de bias $b$ (128 x 16 bits). |
| `ram_neuroniosativos.v` | `ram_neuroniosativos` | RAM para armazenar os resultados ativados ($h$) da camada oculta. |
| `ram_beta.v` | `ram_beta` | Armazena a matriz de pesos de saída $\beta$ (1280 x 16 bits). |
| **Interface e Visualização** | | |
| `decodificador_7seg.v` | `decodificador_7seg` | Converte a predição para os displays de 7 segmentos da DE1-SoC. |
| `instrucoes.v` | `instrucoes` | Interface para mapear chaves e botões físicos em instruções ISA. |

---
### 5.1 `decodificador_isa.v` — decodificador de instruções

Faz a ponte entre o processador ARM (HPS) e o hardware de inferência. O HPS envia um barramento de 32 bits (`instrucao`) junto com um pulso de escrita (`hps_write`), e o módulo ISA decodifica o opcode para determinar a operação:

- **Escrita nas RAMs** — distribui o dado (`data_to_mem`) e o endereço correto (`w_addr`, `img_addr`, `bias_addr`, `beta_addr`) para cada memória, ativando o sinal de escrita correspondente (`wren_w`, `wren_img`, `wren_bias`, `wren_beta`).
- **Início da inferência** — gera o pulso `start_pulse` que coloca a FSM em movimento.
- **Leitura do resultado** — disponibiliza o dígito predito pelo argmax em `hps_readdata`, com informações de status (busy/done) para que o HPS saiba quando o resultado é válido.

O módulo também monitora os sinais `fsm_busy` e `fsm_done` para evitar que o HPS inicie uma nova inferência enquanto a anterior ainda está em execução.

---

### 5.2 `fsm_elm.v` — máquina de estados

Controla o sequenciamento das duas fases de cálculo. Possui quatro estados:

| Estado | Descrição |
|---|---|
| `REPOUSO` | Aguarda o pulso `start`. |
| `CALC_OCULTO` | Habilita `calcular`, ativando a camada oculta. Permanece neste estado até que o sinal `ultimo_neuronio` indique que todos os 128 neurônios foram processados. |
| `CALC_SAIDA` | Habilita `calcula_saida`, ativando a camada de saída. Permanece até `ultimo_neuronio_saida`, que sinaliza o fim das 10 classes. |
| `FIM` | Pulsa `pronto` por um ciclo, notificando o ISA de que o resultado está disponível, e retorna ao `REPOUSO`. |

A FSM utiliza registradores auxiliares (`foi_ultimo_oculto`, `foi_ultimo_saida`) para capturar as bordas dos sinais de fim de camada e evitar transições espúrias.

---

### 5.3 `mac.v` — multiply-accumulate

Núcleo aritmético reutilizado pelas duas camadas. Opera em **ponto fixo Q4.12** (12 bits fracionários) e segue o seguinte protocolo:

1. A cada ciclo em que `dado_valido` está ativo, calcula `mult_atual = valor × peso` (resultado de 32 bits) e acumula em um registrador de **40 bits** com sinal.
2. Quando `fim_neuronio` é assinalado (último pixel do neurônio atual), soma o `bias` alinhado ao ponto fixo (`bias << 12`) e aplica um **shift aritmético de 12 bits à direita** para converter de volta à representação Q4.12.
3. O resultado é **saturado** para o intervalo `[−32768, 32767]` (int16) antes de ser registrado em `saida`.
4. O sinal `ativacao` é pulsado por um ciclo para indicar que `saida` é válido.

O acumulador de 40 bits garante que produtos intermediários não transbordem, mesmo com 784 multiplicações acumuladas.

---

### 5.4 `camada_oculta.v` — camada oculta (128 neurônios)

Gerencia os contadores de endereço e alimenta o MAC com os dados corretos para calcular a saída dos 128 neurônios ocultos.

**Normalização do pixel:** antes de entrar no MAC, cada pixel `uint8` é convertido para Q4.12 com um shift de 4 bits à esquerda (`pixel << 4`), mapeando o intervalo `[0, 255]` para `[0.0, ~1.0]` em ponto fixo.

**Endereçamento:** dois contadores controlam o acesso às RAMs:
- `cnt_pixel` (0–783): percorre os 784 pixels de uma imagem para cada neurônio.
- `cnt_neuronio` (0–127): avança para o próximo neurônio após todos os pixels serem processados.
- `cnt_peso` (0–100351): avança continuamente sem reset parcial, apontando diretamente para o peso `W[neurônio][pixel]` na `ram_pesos`.

Um pipeline de 1 ciclo (`calcular_d`, `fim_pixel_d`) sincroniza os dados lidos da RAM com o MAC, compensando a latência de leitura das memórias síncronas.

---

### 5.5 Otimização da Função de Ativação (Sigmoid Piecewise Linear)

Para garantir a eficiência do acelerador na FPGA e evitar o uso de multiplicadores proprietários (blocos aritméticos integrados diretamente na arquitetura física de uma FPGA), a função de ativação foi implementada via aproximação linear por partes (**PWL**). 

Se a entrada for negativa, aplica a simetria da sigmoid: `resultado = 1.0 − sigmoid(|x|)`. As divisões são implementadas como shifts aritméticos à direita, e todas as constantes estão representadas em Q4.12. O módulo também mantém um contador `addr_out` que incrementa a cada ativação, gerando automaticamente o endereço de escrita na `ram_neuroniosativos`

#### Aproximação da Função Sigmóide Logística

| Intervalo de $\|x\|$ | Equação (Aproximação) | Operação RTL (Q4.12) |
| :--- | :--- | :--- |
| $[0, 1.0)$ | $f(x) = 0.25x + 0.5$ | `(abs >> 2) + 16'h0800` |
| $[1.0, 2.5)$ | $f(x) = 0.125x + 0.625$ | `(abs >> 3) + 16'h0A00` |
| $[2.5, 4.5)$ | $f(x) = 0.03125x + 0.859375$ | `(abs >> 5) + 16'h0DC0` |
| $\ge 4.5$ | $f(x) = 1.0$ (Saturação) | `16'h1000` |

> [!TIP]
> De acordo com **Oliveira (2017)** [[7]](#15-referências), essa abordagem minimiza o uso de elementos lógicos e blocos de DSP, permitindo que o sistema atinja maiores frequências de operação ($F_{max}$) ao reduzir o caminho crítico do datapath. O trabalho completo está disponível em: https://repositorio.unifei.edu.br/xmlui/handle/123456789/861

#### Comparativo entre curva da função original e a aproximação

<img width="972" height="504" alt="image" src="https://github.com/user-attachments/assets/d0fd30d1-a618-4aaf-a1c6-d1342768bbfe" />

---

### 5.6 `camada_saida.v` — camada de saída (10 classes)

Calcula os logits das 10 classes do classificador usando o mesmo módulo MAC, mas com duas diferenças importantes em relação à camada oculta:

- **Sem função de ativação:** os logits `y[c]` são passados diretamente para o argmax, sem passar pela sigmoid.
- **Bias zerado:** o campo de bias é fixado em `16'sd0`, pois os pesos `beta` já incorporam o viés da regressão de saída do ELM.

O endereçamento percorre `cnt_h` (0–127) e `cnt_classe` (0–9), com o endereço do peso calculado como `addr_peso_saida = cnt_h × 10 + cnt_classe`, refletindo o layout linha-maior da `ram_beta`. Ao final de cada classe, o sinal `y_valida` é pulsado para notificar o argmax.

---

### 5.7 `argmax.v` — seleção da classe predita

Percorre as 10 classes `y[0..9]` à medida que chegam (um por pulso de `y_valida`) e mantém o valor máximo e seu índice em registradores internos. O contador `current_idx` é incrementado automaticamente a cada logit recebido, eliminando a necessidade de um endereço externo.

Ao receber o pulso `pronto` da FSM, o índice vencedor é transferido para a saída `saida[3:0]`, que representa o dígito predito (0–9). O sinal `clear` (gerado pelo pulso `start`) reinicia o módulo antes de cada inferência, garantindo que o resultado anterior não contamine a próxima predição.

---
## 6. Mapa de Registradores / ISA

### 6.1 Banco de registradores

| Registrador | Largura | Acesso | Módulo | Reset | Descrição |
|---|---|---|---|---|---|
| `save_instrucao` | 32 bits | R/W | `decodificador_isa` | `32'b0` | Captura a instrução vinda do HPS a cada borda de subida do clock. Os campos `opcode[31:28]`, `addr_in[27:16]` e `data_in[15:0]` são extraídos diretamente deste registrador. |
| `data_to_mem` | 16 bits | W | `decodificador_isa` | `16'b0` | Registra o campo de dado (`data_in[15:0]`) da instrução para escrita nas RAMs internas. Compartilhado por `ram_img`, `ram_pesos`, `ram_bias` e `ram_beta`, dependendo do opcode ativo. |
| `temp_w_addr` | 17 bits | R/W | `decodificador_isa` | `17'b0` | Armazena o endereço de 17 bits para escrita na `ram_pesos`. Configurado pelo opcode `0x6` (STORE W ADDR) e utilizado na operação seguinte de opcode `0x2` (STORE W). Necessário pois o campo `addr_in` tem apenas 12 bits. |
| `ciclo_count` | 32 bits | R | `decodificador_isa` | `32'b0` | Contador de ciclos de clock decorridos durante a inferência. Incrementado enquanto a FSM está em `CALC_OCULTO` ou `CALC_SAIDA`. Permite medir latência de execução via HPS. |
| `hps_readdata` | 32 bits | R | `decodificador_isa` | `32'b0` | Dado de retorno ao HPS. Populado pelo opcode `0x0` (STATUS): `[7:4]` resultado argmax · `[2]` error · `[1]` fsm_done · `[0]` fsm_busy. |


A ISA utiliza palavras de 32 bits com o seguinte formato:

```
 31      28     27     16  15       0
 ┌─────────┬──────────┬──────────┐
 │ OPCODE  │  ADDR    │   DATA   │
 │ (4 bits)│ (12 bits)│ (16 bits)│
 └─────────┴──────────┴──────────┘
```

### 6.2 Tabela de Opcodes

| Instrução | Opcode | Descrição |
|-----------|--------|-----------|
| `STORE_IMG` | `0x1` | Escreve pixel na `ram_img[ADDR]` = `DATA[7:0]` |
| `STORE_WEIGHTS` | `0x2` | Escreve peso em `ram_pesos[ADDR]` = `DATA` (Q4.12) |
| `STORE_BIAS` | `0x3` | Escreve bias em `ram_bias[ADDR]` = `DATA` (Q4.12) |
| `STORE_BETA` | `0x4` | Escreve peso de saída em `ram_beta[ADDR]` = `DATA` |
| `START` | `0x5` | Dispara pulso `start` para a FSM |
| `STATUS` | `0x6` | Lê estado (`hps_readdata`): `[7:4]` = resultado, `[2:0]` = estado FSM |

### 6.3 Saída STATUS (`hps_readdata`)

```
 31       8   7    4   3    2    1    0
 ┌─────────┬──────┬───┬────┬────┬────┐
 │ reserva │ pred │ ? │ERR │DONE│BUSY│
 └─────────┴──────┴───┴────┴────┴────┘
```

| Bits | Significado |
|------|-------------|
| `[7:4]` | Dígito predito (0–9) em BCD |
| `[2]` | ERROR — erro no processamento |
| `[1]` | DONE — inferência concluída (`pronto`) |
| `[0]` | BUSY — FSM em processamento |

---

## 7. Uso de Recursos FPGA

> Dados obtidos após síntese no Quartus Prime Lite [[5]](#15-referências) para **Cyclone V — 5CSEMA5F31C6** [[1]](#15-referências).

| Recurso | Utilizado | Disponível | % |
|---------|-----------|------------|---|
| ALMs (LUTs) | 655 | 32.070 | 2% |
| Registradores | 691 | 128.280 | 0,005% |
| Pins | 27 | 457 | 5,9% |
| DSP Blocks (18×18) | 2 | 87 | 2% |
| M10K (BRAM) | 203 | 397 | 51% |
| PLLs | 0 | 6 | 0% |

**Estimativa de memória (BRAMs M10K):**

| RAM | Profundidade | Largura | Tamanho | M10K est. |
|-----|-------------|---------|---------|-----------|
| `ram_img` | 1024 | 8 | 8 KB | 1 |
| `ram_pesos` | 131.072 | 16 | 2 MB | ~200 |
| `ram_bias` | 128 | 16 | 256 B | 1 |
| `ram_neuroniosativos` | 128 | 16 | 256 B | 1 |
| `ram_beta` | 1280 | 16 | 2,5 KB | 1 |

---

## 8. Ambiente de Desenvolvimento

### 8.1 Hardware

| Item | Especificação |
|------|--------------|
| Placa FPGA | Terasic DE1-SoC [[1]](#15-referências) |
| FPGA | Intel Cyclone V SoC — 5CSEMA5F31C6 |
| HPS | ARM Cortex-A9 Dual-Core, 800 MHz |
| Memória HPS | 1 GB DDR3 |
| Clock FPGA | 50 MHz (onboard) |

### 8.2 Software

| Ferramenta | Versão | Uso |
|------------|--------|-----|
| Quartus Prime Lite [[5]](#15-referências) | 21.1 | Síntese e place & route |
| ModelSim-Intel | 10.5b | Simulação RTL |
| Icarus Verilog [[6]](#15-referências) | 11.0 | Verificação saída esperada |
| GTKWave | 3.3.x | Visualização de formas de onda |
| Python | 3.10+ | Scripts de geração de vetores de teste e MIF |
| NumPy | 1.24+ | Golden model e geração de dados |
| Git | 2.x | Controle de versão |

---

## 9. Instalação e Configuração

### 9.1 Pré-requisitos

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install iverilog gtkwave python3 python3-pip git

pip3 install numpy
```

> Para síntese e programação da placa: **Quartus Prime Lite 21.1** [[5]](#15-referências) (Windows ou Linux), disponível em [intel.com/content/www/us/en/software/programmable/quartus-prime](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/download.html).

### 9.2 Clonar o repositório

```bash
git clone https://github.com/<org>/MI-SD.git
cd MI-SD
```

Após clonar, a estrutura já estará pronta para uso:

- Os **arquivos MIF** dos pesos (W\_in, bias e β) estão em `quartus/mif/` — não é necessário gerá-los;
- As **imagens de teste** PNG estão em `assets/images_png/` e suas versões MIF em `assets/images_mif/`.

### 9.3 Executar simulação (ModelSim / Icarus Verilog)

**ModelSim (Quartus):**

```
1. Abrir Quartus Prime Lite
2. File → Open Project → quartus/<projeto>.qpf
3. Tools → Run Simulation Tool → RTL Simulation
4. No ModelSim: adicionar os sinais de interesse e rodar
```

**Icarus Verilog [[6]](#15-referências) (linha de comando):**

```bash
# Compilar todos os módulos RTL + testbench desejado
iverilog -g2012 -o simulation/elm_sim \
    rtl/*.v testbenches/<modulo>_tb.v

# Executar
vvp simulation/elm_sim

# Visualizar formas de onda
gtkwave simulation/dump.vcd &
```

### 9.4 Sintetizar e gravar na DE1-SoC

```
1. Abrir Quartus Prime Lite
2. File → Open Project → quartus/<projeto>.qpf
3. Processing → Start Compilation
4. Tools → Programmer → selecionar pbl1.sof → Start
```

> Os arquivos MIF em `quartus/mif/` são carregados automaticamente pelo Quartus [[5]](#15-referências) durante a compilação para inicializar as RAMs com os pesos do modelo.

### 9.5 Teste Python (elm_model)

Para testar a inferência em python utilize o seguinte comando juntamente com os arquivos txt, disponiveis em `scripts/txt`.

As imagens de teste disponíveis em `assets/images_png/` podem ser usadas diretamente com os scripts em `scripts/` para gerar vetores de simulação ou para validação na placa via a ISA do co-processador.

O arquivo `label.txt` deve conter uma linha com o digito a ser inferido.

```bash
# Exemplo: rodar golden model Python contra uma imagem
 python elm_model.py \\
        --weights weights.txt \\
        --beta    beta.txt    \\
        --bias    bias.txt    \\
        --image   image.txt   \\
        --label   label.txt
```

---

## 10. Processo de Desenvolvimento

Esta seção descreve a trajetória real da equipe — as decisões tomadas, os problemas encontrados e como cada um foi resolvido. O objetivo é registrar não apenas *o que* foi construído, mas *como* se chegou até aqui.

### 10.1 Fase 1 — Entendimento do problema e elaboração dos diagramas

O ponto de partida foi o estudo da teoria da ELM [[3]](#15-referências)[[4]](#15-referências) e a compreensão das etapas matemáticas envolvidas na inferência: produto matricial da camada oculta, aplicação da ativação não-linear e produto matricial da camada de saída. Antes de escrever qualquer linha de Verilog, a equipe elaborou diagramas de fluxo detalhando cada etapa de cálculo — o que permitiu mapear com clareza quais operações seriam necessárias, quais dados precisariam ser armazenados e em que ordem cada resultado dependia do anterior.

Em retrospecto, percebeu-se que o foco inicial foi direcionado à **corretude da inferência** (os cálculos matemáticos em hardware) antes de consolidar a **arquitetura completa** (ISA, banco de registradores, interface HPS–FPGA). Embora esse caminho tenha gerado um aprendizado sólido sobre a operação do datapath, a ordem ideal seria definir primeiro a arquitetura e depois implementar a inferência dentro dela — lição incorporada nas iterações seguintes.

### 10.2 Fase 2 — Implementação e validação módulo a módulo

Com os diagramas em mãos, a implementação seguiu uma estratégia **bottom-up**: cada módulo foi escrito e validado individualmente antes de ser integrado ao sistema.

Os módulos foram testados na seguinte ordem:

1. `mac.v` — verificação da aritmética Q4.12, saturação e acumulação de 40 bits;
2. `ativacao_sigmoid.v` — validação dos quatro segmentos lineares contra valores esperados em Python;
3. `argmax.v` — verificação do registro correto do máximo entre 10 entradas sequenciais;
4. `camada_saida.v` — validação dos contadores e da sequência de endereçamento;
5. `fsm_elm.v` — verificação das transições de estado e dos sinais de controle gerados.

Cada módulo foi simulado com **testbenches individuais no Icarus Verilog** [[6]](#15-referências) (via playground online) e também no **ModelSim do Quartus** [[5]](#15-referências), onde a visualização das formas de onda permitiu inspecionar ciclo a ciclo o comportamento dos sinais. As saídas foram sistematicamente comparadas com scripts Python que executavam a mesma operação em ponto flutuante de dupla precisão, servindo como golden reference.

### 10.3 Fase 3 — Integração no top-level e sincronização de sinais

Após a validação individual, os módulos foram integrados no top-level `ondeamagicaacontece.v`. Essa etapa revelou a principal dificuldade técnica do projeto: **a sincronização de sinais em presença de latência de acesso às RAMs**.

As memórias inferidas pelo Quartus [[5]](#15-referências) introduzem um ciclo de latência entre a apresentação do endereço e a disponibilização do dado na saída. Isso exigiu que vários sinais de controle fossem **atrasados por registros de pipeline** para garantir que os dados lidos de cada RAM chegassem ao MAC exatamente no ciclo correto — especialmente o sinal `dado_valido` e os pulsos `fim_neuronio` e `ultimo_neuronio`, cujo alinhamento temporal com os dados é crítico para a operação correta do acumulador.

A depuração foi realizada em camadas: primeiro validando a camada oculta isoladamente (comparando `h_saida` ciclo a ciclo com o Python), depois a camada de saída. Em ambos os casos, os resultados intermediários do hardware coincidiam com os do modelo de referência.

### 10.4 Fase 4 — Diagnóstico do erro de inferência e correção do mapeamento dos pesos β

Após a sincronização estar aparentemente correta, a inferência final continuava produzindo resultados incorretos. Um dado relevante foi que **o hardware e o golden model em Python erravam para a mesma classe** — o que indicou que o erro não era de aritmética ou sincronismo, mas de **lógica no acesso aos dados**.

Iniciou-se então um processo de descarte sistemático de hipóteses. Testes específicos foram realizados para verificar:

- Conservação de sinal no formato Q4.12 (complemento de dois) — **passou**;
- Aritmética do MAC com vetores de entrada controlados — **passou**;
- Sincronismo dos pulsos de controle — **passou**;
- Valores intermediários de `h_saida` e `h_ativado` — **corretos**;
- Valores de `y_saida` para cada classe — **incorretos em relação à referência**.

A causa raiz foi identificada ao comparar a **convenção de linearização** das duas matrizes de pesos:

| Matriz | Convenção | Acesso sequencial |
|--------|-----------|-------------------|
| W\_in (oculta) | Linha = neurônio; coluna = pixel | neurônio 0: pesos 0–783, neurônio 1: pesos 784–1567, ... |
| β (saída) | **Linha = pixel de entrada (h); coluna = classe** | os **primeiros pesos de cada neurônio** estão nas primeiras posições — ou seja, cada coluna é uma classe |

A RAM `ram_beta` havia sido populada seguindo a mesma lógica de W\_in (linha a linha), mas o hardware a endereçava como se cada bloco de 128 posições correspondesse a uma classe. Na prática, o hardware estava lendo os pesos da **coluna** quando deveria ler os da **linha**, e vice-versa — equivalente a usar β transposta no lugar de β.

A correção foi feita no script `gen_mif.py`: a matriz β passou a ser transposta antes de ser linearizada para o arquivo `.mif`, alinhando a convenção de armazenamento ao padrão de acesso do hardware. Após essa correção, a inferência passou a produzir os resultados corretos.

### 10.5 Fase 5 — Integração da ISA e testes na placa

Com a inferência validada por simulação, a ISA e o decodificador de instruções (desenvolvidos em paralelo) foram acoplados ao datapath no módulo `ondeamagicaacontece.v`. Os testes finais foram realizados **diretamente na placa DE1-SoC** [[1]](#15-referências), verificando que:

- A validação individual de cada módulo foi preservada após a integração completa;
- A validação da inferência por simulação se manteve no hardware real;
- A comunicação via instruções (STORE\_IMG, START, STATUS) operou corretamente, com o resultado exibido no display de 7 segmentos da placa.

---

## 11. Simulação e Testes

### 11.1 Estratégia de Verificação

A estratégia de verificação baseou-se na simulação funcional e temporal em múltiplos níveis, com comparação sistemática dos resultados contra um **Golden Model** em Python. As ferramentas utilizadas foram o **ModelSim** [[5]](#15-referências) para análises complexas de integração e o **EDA Playground** para validações rápidas de módulos individuais.

Os arquivos de teste estão localizados na pasta `/testbenchs` e seguem o padrão de nomenclatura `tb_nome_do_modulo.v` para testes de modulos individuais e `tb_camada_nome.v` para testes de integrações.

---

### 11.2 Plataformas de Teste e Passo a Passo

#### A. EDA Playground (Testes Individuais de Módulos)

Utilizado para validação unitária de componentes lógicos (MAC, Sigmoid, Argmax) devido à agilidade de execução via web.

1. Acesse o [EDA Playground](https://www.edaplayground.com/).
2. Faça o upload do arquivo do módulo (ex: `mac.v`) e seu respectivo testbench localizado em `/testbenchs/tb_mac.v`.
3. Selecione o simulador **Icarus Verilog** [[6]](#15-referências) ou **Questa Sim**.
4. Marque a opção "Open EPWave after run" para visualizar os sinais.
5. Clique em **Run** para validar a lógica aritmética e de estados.

#### B. ModelSim (Integração, Acesso à Memória e Barramento)

Plataforma principal para validar a integração entre dois ou mais módulos, fluxos de acesso às memórias RAM e avaliação detalhada de sinais temporais críticos.

1. Abra o **ModelSim** e crie um novo projeto (`File -> New -> Project`).
2. Adicione todos os arquivos `.v` da pasta `/rtl` e o testbench de integração desejado da pasta `/testbenchs` (ex: `tb_camada_oculta.v`).
3. Compile todos os arquivos (`Compile -> Compile All`).
4. Inicie a simulação (`Simulate -> Start Simulation`) e selecione o módulo de testbench na aba *Work*.
5. Adicione os sinais desejados à janela **Wave** (`Add Wave`).
6. Execute o comando `run -all` no console para processar o fluxo completo de dados e verificar a sincronização dos sinais `h_saida`, `y_saida` e os endereçamentos de memória.

---

### 11.3 Casos de Teste

| Caso | Descrição | Ambiente | Resultado |
|------|-----------|----------|-----------|
| TC-01 | Validação individual do MAC (aritmética Q4.12) | EDA Playground | ✅ Passou |
| TC-02 | Validação do sigmoid piecewise (4 segmentos) | EDA Playground | ✅ Passou |
| TC-03 | Validação do argmax (10 entradas sequenciais) | EDA Playground | ✅ Passou |
| TC-04 | Sincronização da camada oculta (h_saida × referência Python) | ModelSim | ✅ Passou |
| TC-05 | Sincronização da camada de saída (y_saida × referência Python) | ModelSim | ✅ Passou |
| TC-06 | Saturação do MAC (overflow e underflow) | EDA Playground | ✅ Passou |
| TC-07 | Reset durante processamento (FSM → REPOUSO) | ModelSim | ✅ Passou |
| TC-08 | Inferência completa — K vetores MNIST | ModelSim | ✅ Passou |
| TC-09 | Dois START consecutivos sem reset | ModelSim | ✅ Passou |
| TC-10 | Validação na placa DE1-SoC | Hardware Real | ✅ Passou |

### 11.4 Automação via Terminal

Para ambientes Linux/WSL, a execução pode ser automatizada via `Makefile`.

---

## 12. Análise dos Resultados

### 12.1 Latência de Inferência

| Etapa | Ciclos |
|-------|--------|
| Camada oculta (784 × 128 MACs) | ~100.352 |
| Ativação sigmoid (128 neurônios) | 128 |
| Camada de saída (128 × 10 MACs) | ~1.280 |
| Argmax (10 comparações) | 10 |
| **Total** | **~101.770 ciclos** |
| **Latência @ 50 MHz** | **~2,03 ms por inferência** |

### 12.2 Principais dificuldades encontradas e como foram superadas

**Sincronização de sinais com latência de RAM**

As memórias inferidas pelo Quartus [[5]](#15-referências) introduzem 1 ciclo de latência. A solução foi adicionar registros de pipeline para atrasar os sinais de controle (`dado_valido`, `fim_neuronio`, `ultimo_neuronio`) de forma que eles cheguem ao MAC no mesmo ciclo que os dados lidos da RAM.

**Inferência incorreta com hardware e software errando para o mesmo valor**

O fato de ambos errarem para a mesma classe foi o indício que levou a equipe a investigar a camada de dados em vez da aritmética. A causa foi a diferença de convenção de linearização entre W\_in e β: enquanto W\_in é armazenada linha a linha (neurônio por neurônio), a matriz β original tinha sua dimensão de classes nas colunas. O hardware endereçava β esperando os pesos de cada classe contíguos, mas a matriz estava transposta. A correção foi realizar a transposição de β no script de geração do MIF, antes de linearizar.

**Integração da ISA ao datapath validado**

O acoplamento da ISA introduziu multiplexadores nos barramentos de endereço das RAMs (selecionando entre o endereço gerado pela FSM durante inferência e o endereço gerado pela ISA durante escrita). A validação foi feita garantindo que os resultados obtidos na simulação prévia continuavam corretos após a integração.

### 12.3 Observações finais

A ativação sigmoid piecewise linear — cuja abordagem é fundamentada em **Oliveira (2017)** [[7]](#15-referências) — introduz erro máximo de `±0.009` em relação ao sigmoid exato, dentro do tolerável para classificação de dígitos. O acumulador interno de 40 bits garante que não há overflow durante a fase de acumulação do MAC, com saturação aplicada apenas na saída para a faixa Q4.12. A validação em placa confirmou que o comportamento observado em simulação foi preservado no hardware real, corroborando os resultados obtidos em trabalhos similares de aceleração de ELM em FPGA [[2]](#15-referências).

---

## 13. Estrutura do Repositório

```
MI-SD/
├── README.md                   ← Este arquivo
│
├── assets/                     ← Recursos de dados do modelo
│   ├── images_mif/             ← Imagens de teste convertidas para formato MIF
│   └── images_png/             ← Imagens de teste no formato PNG (28×28, grayscale)
│
├── docs/                       ← Documentação complementar
│                               ← Diagramas, especificações e relatórios
│
├── quartus/                    ← Projeto Intel Quartus Prime
│                               ← Arquivos de síntese, pinos e saída (.sof)
│
├── rtl/                        ← Código-fonte Verilog (RTL)
│                               ← Todos os módulos do co-processador ELM
│
├── scripts/                    ← Scripts Python de suporte
│   ├── txt/                    ← Arquivos para uso nos testbenchs e elm_model.py 
│
├── simulation/                 ← Artefatos de simulação (ModelSim / Icarus)
│                               ← Testbenches, formas de onda e relatórios
│
└── testbenchs/                 ← Testbenches individuais por módulo
                                ← Validação unitária de cada submódulo RTL
```

---

## 14. Equipe

> _Iure Rocha Moreira Mendonça._
> _João Pedro da Silva Ferreira._
> _Thaylane da Silva._

---

## 15. Referências

1. **DE1-SoC User Manual** — Terasic Technologies. Disponível em: [fpgacademy.org](https://fpgacademy.org/boards.html)
2. **Accelerating Extreme Learning Machine on FPGA** — UTHM Publisher. Disponível em: [publisher.uthm.edu.my](https://publisher.uthm.edu.my/ojs/index.php/ijie/article/view/4431)
3. **Extreme learning machine: algorithm, theory and applications** — ResearchGate. Disponível em: [researchgate.net](https://www.researchgate.net/publication/257512921)
4. **A máquina de aprendizado extremo (ELM)** — Computação Inteligente. Disponível em: [computacaointeligente.com.br](https://computacaointeligente.com.br/algoritmos/maquina-de-aprendizado-extremo/)
5. **Intel Quartus Prime Lite Design Software** — versão 21.1.
6. **Icarus Verilog** — versão 11.0. Disponível em: [iverilog.icarus.com](http://iverilog.icarus.com/)
7. OLIVEIRA, J. G. M. *Uma arquitetura reconfigurável de Rede Neural Artificial utilizando FPGA*. Dissertação (Mestrado) – UNIFEI, Itajubá, 2017. Disponível em: [repositorio.unifei.edu.br/xmlui/handle/123456789/861](https://repositorio.unifei.edu.br/xmlui/handle/123456789/861)

---

## Marco 2 — Comunicação HPS↔FPGA

---

## 16. Levantamento de Requisitos — Marco 2

### 16.1 Requisitos Funcionais

| ID | Requisito |
|----|-----------|
| RF-M2-01 | O driver deve abrir o dispositivo `/dev/mem` via syscall `SYS_OPEN` com flags `O_RDWR \| O_SYNC` |
| RF-M2-02 | O driver deve mapear 4 KB a partir do endereço físico `0xFF200000` (LW Bridge) via syscall `SYS_MMAP2` |
| RF-M2-03 | O driver deve expor a função `init_hw_asm()` que inicializa o mapeamento e retorna 0 em sucesso ou -1 em falha |
| RF-M2-04 | O driver deve expor a função `exit_hw_asm()` que desfaz o mapeamento e fecha `/dev/mem`; deve ser idempotente |
| RF-M2-05 | O driver deve expor a função `reset_hw_asm()` que aplica um pulso de reset na FSM do co-processador |
| RF-M2-06 | O driver deve expor a função `start_asm()` que dispara a inferência e bloqueia até o hardware sinalizar conclusão via polling |
| RF-M2-07 | O driver deve expor `carregar_img_asm(void*)` que transfere 784 pixels `uint8` para a `ram_img` do co-processador |
| RF-M2-08 | O driver deve expor `carregar_w_asm(void*)` que transfere 100.352 pesos `uint16` (Q4.12) para a `ram_pesos` usando protocolo de duas instruções por elemento (opcodes `0x6` + `0x2`) |
| RF-M2-09 | O driver deve expor `carregar_bias_asm(void*)` que transfere 128 bias `uint16` (Q4.12) para a `ram_bias` |
| RF-M2-10 | O driver deve expor `carregar_beta_asm(void*)` que transfere 1.280 betas `uint16` (Q4.12) para a `ram_beta` |
| RF-M2-11 | O driver deve expor `status_asm(uint32_t*)` que lê `pio_readdata` e preenche o array `dados[0..4]` com: busy, done, error, dígito predito e ciclos de clock |
| RF-M2-12 | Cada instrução enviada ao co-processador deve ser confirmada por um pulso de clock manual em `pio_hpswrite` (sub-rotina `pulse_hw`) |
| RF-M2-13 | A aplicação de teste (`marco2.c`) deve executar 1.000 inferências consecutivas com a mesma imagem e verificar acurácia igual a 100% |
| RF-M2-14 | Todos os protótipos da API devem ser declarados no cabeçalho público `api.h`, sem dependências além de `<stdint.h>` |

### 16.2 Requisitos Não-Funcionais

| ID | Requisito |
|----|-----------|
| RNF-M2-01 | As rotinas críticas de acesso ao hardware (`init`, `exit`, `reset`, `start`, `carregar_*`, `status`) devem ser implementadas exclusivamente em Assembly ARM (ARMv7, modo ARM, sintaxe unificada) |
| RNF-M2-02 | O código Assembly deve usar apenas syscalls Linux (`SYS_OPEN`, `SYS_MMAP2`, `SYS_MUNMAP`, `SYS_CLOSE`) sem dependências de bibliotecas externas para o acesso ao hardware |
| RNF-M2-03 | O driver deve ser compilável diretamente no HPS com `gcc` nativo ou por compilação cruzada com `arm-linux-gnueabihf-gcc`, sem etapas de build adicionais |
| RNF-M2-04 | A função `exit_hw_asm()` deve ser registrada via `atexit()` na aplicação chamadora para garantir liberação de recursos mesmo em saídas inesperadas |
| RNF-M2-05 | O endereço base mapeado (`hw_base`) e o file descriptor (`hw_fd`) devem ser armazenados em variáveis globais na seção `.bss`, isoladas da pilha da aplicação |
| RNF-M2-06 | O pulso de clock (`pulse_hw`) deve aguardar no mínimo 150 ciclos de delay entre a borda de subida e a borda de descida, garantindo setup/hold do co-processador |
| RNF-M2-07 | A execução do driver requer privilégios de superusuário (`sudo`) devido ao acesso a `/dev/mem` |
| RNF-M2-08 | O código Assembly deve ser documentado com comentários descrevendo a função de cada bloco, os registradores utilizados e os efeitos colaterais |

### 16.3 Restrições

| Restrição | Descrição |
|-----------|-----------|
| **Acesso ao hardware** | Exclusivamente via MMIO mapeado em `/dev/mem`; proibido o uso de módulos de kernel ou outros mecanismos de I/O |
| **Linguagem do driver** | As rotinas de acesso ao hardware obrigatoriamente em Assembly ARM puro; a aplicação de controle pode ser em C |
| **Barramento** | Apenas o Lightweight HPS-to-FPGA AXI Bridge (`0xFF200000`, 4 KB) é utilizado; nenhum outro barramento ou periférico é acessado |
| **Largura da instrução** | Todas as instruções enviadas ao co-processador têm 32 bits fixos no formato `[opcode(4)][addr(12)][data(16)]` |
| **Endereçamento de pesos W** | O campo `addr` de 12 bits da ISA é insuficiente para as 100.352 posições da `ram_pesos`; obrigatório o uso de opcode `0x6` para definir os 17 bits de endereço antes de cada escrita com opcode `0x2` |
| **Polling** | A espera pelo término da inferência é feita por polling ativo do bit `busy` em `pio_readdata`; interrupções não são utilizadas |
| **Ordem de carga** | Os dados (imagem, pesos, bias, beta) devem ser carregados completamente antes do `START`; o driver não impede violação dessa ordem |


## 17. Visão Geral do Marco 2

Este marco implementa o lado de software: o código que roda no processador ARM (HPS) da DE1-SoC e se comunica com o co-processador ELM sintetizado na FPGA. A comunicação é feita através do barramento **Lightweight HPS-to-FPGA AXI**, mapeado no endereço físico `0xFF200000`, permitindo ao ARM escrever e ler registradores da FPGA via ponteiros de memória.

### Visão da Stack Completa

```
┌─────────────────────────┐
│   Aplicação C (marco2.c)│  chamadas de função C
├─────────────────────────┤
│  Driver Assembly        │  syscalls Linux + STR/LDR
│     (rotinas.s)         │  diretos no barramento
├─────────────────────────┤
│  LW Bridge 0xFF200000   │  4 KB mapeados via /dev/mem
│  ┌──────┬──────┬──────┐ │
│  │READ  │CTRL  │INSTR │ │  offsets 0x00, 0x10, 0x20
│  └──────┴──────┴──────┘ │
├─────────────────────────┤
│  Co-proc FPGA           │  ELM Inferência (elm_accel)
│  (elm_accel)            │
└─────────────────────────┘
```

### Fluxo de uma Inferência Completa via HPS

1. Carregar pesos W (100.352 elementos) via opcode `STORE_W_ADDR` + `STORE_WEIGHTS`
2. Carregar bias (128 elementos) via opcode `STORE_BIAS`
3. Carregar pesos β (1.280 elementos) via opcode `STORE_BETA`
4. Carregar imagem (784 pixels) via opcode `STORE_IMG`
5. Disparar a FSM com `START`
6. Consultar `STATUS` e ler o dígito predito em `[7:4]`

> A ordem dos passos 1–4 é livre entre si, mas todos devem preceder o `START`. O driver não impede iniciar a inferência sem dados carregados — essa responsabilidade é do código chamador.

---

## 18. Configuração do Platform Designer

Três componentes **PIO (Parallel I/O)** foram adicionados ao `soc_system.qsys` no Platform Designer e conectados à porta `h2f_lw_axi_master` do HPS:

<img width="767" height="660" alt="image" src="https://github.com/user-attachments/assets/6e16c395-be9d-4126-b795-340f37011193" />

Cada PIO foi exportado como `Conduit` e conectado no top-level `ghrd_top.v` (`fio_instrucao`, `fio_hps_write`, `fio_hps_readdata`), que chega às portas do módulo `elm_accel`.

Após configurar os PIOs: **Generate > Generate HDL...** e recompilação do projeto para gravar o novo `.sof` na placa.

---

### 19. Interfaces Externas

#### Interface com o co-processador (MMIO)

| Sinal | Endereço Físico | Tipo | Descrição |
|-------|----------------|------|-----------|
| `pio_readdata` | `0xFF200000` | Entrada (32 bits) | Lê status, dígito predito e ciclos de clock da FPGA |
| `pio_hpswrite` | `0xFF200010` | Saída (2 bits) | Bit 1: pulso de clock · Bit 0: reset da FSM |
| `pio_instrucao` | `0xFF200020` | Saída (32 bits) | Instrução de 32 bits enviada ao co-processador |

#### Interface com a aplicação C (API pública)

```c
/* api.h — contratos da API; erros devolvidos por valor de retorno */
int      init_hw_asm(void);            /* 0 = ok, -1 = falha em open/mmap */
void     exit_hw_asm(void);            /* seguro chamar múltiplas vezes    */
void     reset_hw_asm(void);           /* reinicia FSM; não bloqueia        */
void     start_asm(void);              /* bloqueia até done ou timeout      */
void     carregar_img_asm(void *buf);  /* buf: uint8[784]                   */
void     carregar_w_asm(void *buf);    /* buf: uint16[100352] Q4.12         */
void     carregar_bias_asm(void *buf); /* buf: uint16[128]   Q4.12         */
void     carregar_beta_asm(void *buf); /* buf: uint16[1280]  Q4.12         */
uint32_t status_asm(uint32_t *dados);  /* dados[0..4]; retorna valor bruto  */
```

#### Dados de entrada esperados por função

| Função | Arquivo binário | Elementos | Tipo por elemento | Tamanho total |
|--------|----------------|-----------|-------------------|---------------|
| `carregar_img_asm` | `nove.bin` / imagem PNG decodificada | 784 | `uint8` | 784 B |
| `carregar_w_asm` | `pesos.bin` | 100.352 | `uint16` Q4.12 | ~196 KB |
| `carregar_bias_asm` | `bias.bin` | 128 | `uint16` Q4.12 | 256 B |
| `carregar_beta_asm` | `beta.bin` | 1.280 | `uint16` Q4.12 | 2,5 KB |

#### Array de retorno de `status_asm`

| Índice | Campo | Bits em `pio_readdata` | Descrição |
|--------|-------|------------------------|-----------|
| `dados[0]` | `busy` | bit 0 | 1 enquanto a FSM está processando |
| `dados[1]` | `done` | bit 1 | 1 quando a inferência foi concluída |
| `dados[2]` | `error` | bit 2 | 1 se ocorreu erro de opcode |
| `dados[3]` | `resultado` | bits 7:4 | Dígito predito (0–9) |
| `dados[4]` | `ciclos` | bits 31:8 | Ciclos de clock da inferência |

---


## 20. Geração do Cabeçalho de Endereços

O cabeçalho `hps_0.h` foi gerado a partir do arquivo `.sopcinfo` do projeto para que o software conheça os offsets de cada PIO sem hardcodá-los:

```bash
sopc-create-header-files "./soc_system.sopcinfo" --single hps_0.h --module hps_0
```

O arquivo gerado define constantes como `PIO_INSTRUCAO_BASE`, `PIO_HPSWRITE_BASE` e `PIO_READDATA_BASE` — os offsets que as rotinas Assembly usam para calcular os endereços virtuais após o `mmap`.

---

## 21. Driver Assembly — API Pública

O driver é definido em `api.h` e implementado em `rotinas.s`. Toda a comunicação com o hardware ocorre dentro dessas rotinas, isolando completamente a aplicação C dos detalhes de MMIO e syscalls.

### Descrição de cada função

| Função | Descrição |
|--------|-----------|
| `init_hw_asm` | Abre `/dev/mem` via `SYS_OPEN` e mapeia 4 KB a partir de `0xFF200` via `SYS_MMAP2`. Salva o fd em `hw_fd` e o ponteiro base em `hw_base`. Retorna 0 ou -1. |
| `exit_hw_asm` | Desfaz o mmap (`SYS_MUNMAP`) e fecha o fd (`SYS_CLOSE`). Idempotente: verifica `hw_base ≠ 0` antes de agir. |
| `reset_hw_asm` | Aplica um pulso no bit de reset de `pio_hpswrite` (RESET=1 → aguarda ~150 ciclos → RESET=0). Reinicia a FSM do co-processador. |
| `start_asm` | Envia opcode `0x5`, faz polling em `pio_readdata` bit 0 (`busy`) até a queda do sinal. Bloqueia a thread chamadora até o hardware terminar. |
| `carregar_img_asm` | 784 iterações. `ldrb` lê 1 byte; monta instrução `[opcode=1][índice][pixel]`; STR em `pio_instrucao` + `pulse_hw`. |
| `carregar_w_asm` | 100.352 pesos. 2 instruções por peso: opcode `0x6` (endereço de 17 bits) + opcode `0x2` (valor uint16). |
| `carregar_bias_asm` | 128 bias. `ldrh` lê 2 bytes; opcode `0x3` + `pulse_hw`. |
| `carregar_beta_asm` | 1.280 betas. `ldrh` lê 2 bytes; opcode `0x4` + `pulse_hw`. |
| `status_asm` | Opcode `0x0` + `pulse_hw`. Lê `pio_readdata`. Extrai campos com `ubfx`: `dados[0]` = busy · `dados[1]` = done · `dados[2]` = error · `dados[3]` = dígito predito · `dados[4]` = ciclos. |

### Macro `setup_hw` e sub-rotina `pulse_hw`

A **macro `setup_hw`** é chamada no início de cada função de carga e controle. Ela carrega o endereço base do LW Bridge (salvo em `hw_base`) e deriva três ponteiros de registrador:

| Registrador | Offset | PIO | Direção |
|---|---|---|---|
| `r1` | `+0x20` | `pio_instrucao` | HPS → FPGA |
| `r2` | `+0x10` | `pio_hpswrite` | HPS → FPGA (clock/reset) |
| `r12` | `+0x00` | `pio_readdata` | FPGA → HPS |

A **sub-rotina `pulse_hw`** gera o pulso de clock manual que o `decodificador_isa.v` usa para registrar cada instrução:

```
pulse_hw:
    escreve CTRL_CLK_BIT em pio_hpswrite   → borda de subida
    aguarda ~150 ciclos de delay
    escreve 0 em pio_hpswrite              → borda de descida
    retorna
```

---

## 22. Registradores MMIO

### Campos de `pio_readdata`

```
 Bits [31:8]  │  Bits [7:4]  │  Bit [2]  │  Bit [1]  │  Bit [0]
 ─────────────┼──────────────┼───────────┼───────────┼──────────
 Ciclos       │  Dígito pred │  Error    │  Done     │  Busy
 (contador)   │  (0–9)       │           │           │
```

### Campos de `pio_hpswrite`

| Bit | Nome | Função |
|-----|------|--------|
| 1 | `hpswrite` | Pulso de clock — a FPGA registra a instrução na borda de subida |
| 0 | `reset` | Mantido em 1 reinicia a FSM; retornar a 0 libera o reset |

---

## 23. Formato das Instruções ISA (32 bits)

```
 31      28  27      16  15       0
 ┌──────────┬──────────┬──────────┐
 │  OPCODE  │   ADDR   │   DATA   │
 │  (4 bits)│ (12 bits)│ (16 bits)│
 └──────────┴──────────┴──────────┘
```

| Opcode | Nome | Formato | Descrição |
|--------|------|---------|-----------|
| `0x0` | STATUS | `[31:28]=0` | Lê `pio_readdata` com `ubfx` e preenche `dados[0..4]` |
| `0x1` | STORE_IMG | `[31:28]=1 [27:16]=i [15:0]=pixel` | 1 byte por instrução; 784 iterações |
| `0x2` | STORE_W | `[31:28]=2 [15:0]=valor` | Deve ser precedido por opcode `0x6` |
| `0x3` | STORE_BIAS | `[31:28]=3 [27:16]=i [15:0]=bias` | 2 bytes por instrução; 128 iterações |
| `0x4` | STORE_BETA | `[31:28]=4 [27:16]=i [15:0]=beta` | 2 bytes por instrução; 1280 iterações |
| `0x5` | START | `[31:28]=5` | Dispara inferência; `start_asm` faz polling até `busy=0` |
| `0x6` | STORE_W_ADDR | `[31:28]=6 [16:0]=endereço` | Define os 17 bits de endereço para a próxima escrita em `ram_pesos` |

---

## 24. Fluxo Completo de Inferência

```
 1. init_hw_asm()          → open /dev/mem → mmap2 0xFF200 → salva hw_base
 2. reset_hw_asm()         → bit RESET=1 → aguarda → RESET=0
 3. carregar_img_asm(buf)  → 784× [STR opcode 1 + pulse_hw]
 4. carregar_w_asm(buf)    → 100.352× [STR opcode 6 + pulse_hw + STR opcode 2 + pulse_hw]
 5. carregar_bias_asm(buf) → 128× [STR opcode 3 + pulse_hw]
 6. carregar_beta_asm(buf) → 1.280× [STR opcode 4 + pulse_hw]
 7. start_asm()            → STR opcode 5 + polling busy até 0
 8. status_asm(estado)     → ubfx → estado[3] = dígito predito (0–9)
                                  → estado[4] = ciclos de clock
 9. exit_hw_asm()          → munmap hw_base → close /dev/mem
```

> **Resultado:** `estado[3]` contém o dígito predito (0–9) e `estado[4]` a contagem de ciclos da inferência.

---

## 25. Compilação e Execução — Marco 2

### Compilação no HPS (DE1-SoC)

```bash
# Compilação direta no HPS (ARM nativo)
gcc -O2 -o marco2 marco2.c rotinas.s

# Compilação cruzada (em x86 com toolchain ARM)
arm-linux-gnueabihf-gcc -O2 -o marco2 marco2.c rotinas.s
```

### Execução

```bash
# Requer acesso root para abrir /dev/mem
sudo ./marco2
```

### Arquivos binários necessários

| Arquivo | Conteúdo | Elementos | Tipo |
|---------|----------|-----------|------|
| `nove.bin` | Imagem do dígito 9 | 784 | `uint8` |
| `pesos.bin` | Matriz W | 100.352 | `uint16` (Q4.12) |
| `bias.bin` | Vetor bias | 128 | `uint16` (Q4.12) |
| `beta.bin` | Matriz β | 1.280 | `uint16` (Q4.12) |

---

## 26. Teste de Estabilidade — Marco 2

O `marco2.c` executa **1000 inferências consecutivas** com a mesma imagem (`nove.bin`) para validar a estabilidade do sistema. A cada iteração o hardware é reiniciado com `reset_hw_asm()` e todos os dados são recarregados — o cenário mais exigente para verificar a ausência de estados residuais.

```c
/* marco2.c — loop de estabilidade */
for (int i = 0; i < 1000; i++) {
    reset_hw_asm();
    carregar_img_asm (bufs[0]);
    carregar_w_asm   (bufs[1]);
    carregar_bias_asm(bufs[2]);
    carregar_beta_asm(bufs[3]);
    start_asm();
    status_asm(status);
    if (status[3] == 9) cont++;
}
printf("Acertos: %d\n", cont);  /* Esperado: 1000 */
```

### Resultado

| Métrica | Valor |
|---------|-------|
| Inferências executadas | 1.000 |
| Acertos (pred = 9) | **1.000** |
| Taxa de acerto | **100%** |
| Estabilidade | Comprovada — nenhuma falha ou estado residual |

---

<div align="center">

*Universidade Estadual de Feira de Santana — UEFS · Departamento de Tecnologia · TEC 499 MI Sistemas Digitais 2026.1*

</div>
