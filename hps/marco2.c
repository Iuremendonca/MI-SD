#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "api.h"

// Libera o hardware ao encerrar o programa 
static void cleanup(void) { exit_hw_asm(); }

// Configuração de cada tipo de dado carregado no hardware 
typedef struct {
    const char *arquivo;
    size_t      elem_bytes;  // tamanho de cada elemento em bytes 
    uint32_t    limite;      // quantidade de elementos           
} dado_t;

static const dado_t dados_cfg[] = {
    { "nove.bin", 1, 784    },  // imagem de entrada: 784 pixels uint8  
    { "pesos.bin",  2, 100352 },  // pesos da rede: 100352 valores uint16 
    { "bias.bin",   2, 128    },  // bias da camada densa: 128 uint16     
    { "beta.bin",   2, 1280   },  // parâmetros beta (BatchNorm): 1280    
};

int main(void) {
    if (init_hw_asm() != 0) {
        fprintf(stderr, "Erro: falha ao mapear /dev/mem.\n");
        return 1;
    }
    atexit(cleanup);

    // Lê todos os arquivos binários para memória uma única vez 
    void *bufs[4] = {NULL};
    for (int j = 0; j < 4; j++) {
        const dado_t *cfg = &dados_cfg[j];

        FILE *f = fopen(cfg->arquivo, "rb");
        if (!f) { perror(cfg->arquivo); return 1; }

        bufs[j] = malloc(cfg->limite * cfg->elem_bytes);
        if (!bufs[j]) { fclose(f); fprintf(stderr, "Sem memória.\n"); return 1; }

        fread(bufs[j], cfg->elem_bytes, cfg->limite, f);
        fclose(f);
    }

    int cont = 0;

    // Executa 100 inferências reutilizando os mesmos dados 
    for (int i = 0; i < 100; i++) {
        reset_hw_asm();
        printf("\n=== Inferência %d ===\n", i + 1);

        // Carrega todos os dados no hardware 
        carregar_img_asm (bufs[0]);
        carregar_w_asm   (bufs[1]);
        carregar_bias_asm(bufs[2]);
        carregar_beta_asm(bufs[3]);

        // Lê status antes de iniciar (deve estar idle) 
        uint32_t status[5] = {0};
        status_asm(status);

        printf("Busy       : %u\n", status[0]);
        printf("Done       : %u\n", status[1]);
        printf("Error      : %u\n", status[2]);
        printf("Resultado  : %u\n", status[3]);
        printf("Ciclos     : %u\n\n", status[4]);

        // Dispara a inferência e aguarda conclusão
        start_asm();

        // Lê status final com o resultado 
        status_asm(status);

        printf("Busy       : %u\n", status[0]);
        printf("Done       : %u\n", status[1]);
        printf("Error      : %u\n", status[2]);
        printf("Resultado  : %u\n", status[3]);
        printf("Ciclos     : %u\n", status[4]);

        // Contabiliza acertos (dígito esperado = 9)
        if (status[3] == 9) cont++;
    }

    printf("Acertos: %d\n", cont);

    // Libera buffers
    for (int j = 0; j < 4; j++)
        free(bufs[j]);

    return 0;
}
