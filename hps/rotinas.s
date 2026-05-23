.syntax unified
.arm
.text
.align 4

@ --- Funções exportadas ---
.global init_hw_asm
.global exit_hw_asm
.global reset_hw_asm
.global carregar_img_asm
.global carregar_w_asm
.global carregar_bias_asm
.global carregar_beta_asm
.global start_asm
.global status_asm

.type init_hw_asm,     %function
.type exit_hw_asm,     %function
.type reset_hw_asm,    %function
.type carregar_img_asm, %function
.type carregar_w_asm,   %function
.type carregar_bias_asm,%function
.type carregar_beta_asm,%function
.type start_asm,       %function
.type status_asm,      %function

@ --- Offsets dos registradores de I/O no Lightweight Bridge ---
.equ PIO_READ_OFFSET, 0x00   @ leitura de status do hardware
.equ PIO_CTRL_OFFSET, 0x10   @ controle de clock e reset
.equ PIO_INST_OFFSET, 0x20   @ envio de instruções

@ --- Bits de controle em pio_hpswrite ---
.equ CTRL_CLK_BIT,   2       @ bit do clock manual
.equ CTRL_RESET_BIT, 1       @ bit de reset

@ --- Códigos de syscall Linux (ARM) ---
.equ SYS_OPEN,   5
.equ SYS_MMAP2,  192
.equ SYS_MUNMAP, 91
.equ SYS_CLOSE,  6

@ --- Quantidade de elementos de cada dado do modelo ---
.equ LIM_IMG,   784
.equ LIM_W,  100352
.equ LIM_BETA, 1280
.equ LIM_BIAS,  128

 
@ Variáveis globais (BSS)
.section .bss
.align 4
hw_fd:   .space 4   @ file descriptor de /dev/mem
hw_base: .space 4   @ endereço virtual mapeado do LW bridge


@ Macro setup_hw
@ Carrega hw_base em r8 e deriva os três ponteiros de registrador:
@   r1  = pio_instrucao  (envio de instruções)
@   r2  = pio_hpswrite   (clock e reset)
@   r12 = pio_readdata   (leitura de status)
@ Se hw_base for zero (não inicializado), salta para err_ret.
.macro setup_hw
    ldr     r8, =hw_base
    ldr     r8, [r8]
    cmp     r8, #0
    beq     err_ret
    add     r1,  r8, #PIO_INST_OFFSET
    add     r2,  r8, #PIO_CTRL_OFFSET
    add     r12, r8, #PIO_READ_OFFSET
.endm


@ init_hw_asm — Inicializa o acesso ao hardware.
@ Abre /dev/mem e mapeia o Lightweight Bridge (0xFF200000, 4 KB).
@ Retorno: 0 = sucesso, -1 = falha.
.section .text
init_hw_asm:
    push    {r4-r7, lr}

    @ Abre /dev/mem com flags leitura/escrita + sincronizado
    ldr     r0, =dev_mem_path
    ldr     r1, =0x101002
    mov     r7, #SYS_OPEN
    svc     #0
    cmp     r0, #0
    blt     init_fail

    @ Salva o file descriptor
    ldr     r1, =hw_fd
    str     r0, [r1]
    mov     r4, r0

    @ Mapeia 4 KB a partir do endereço físico 0xFF200 (página)
    mov     r0, #0           @ endereço virtual: kernel escolhe
    mov     r1, #0x1000      @ tamanho: 4 KB
    mov     r2, #3           @ proteção: PROT_READ | PROT_WRITE
    mov     r3, #1           @ flags: MAP_SHARED
    ldr     r5, =0xff200     @ endereço físico (em páginas para mmap2)
    mov     r7, #SYS_MMAP2
    svc     #0

    @ Verifica erro (mmap retorna endereço próximo de -1 em falha)
    cmn     r0, #4096
    bhi     init_fail_close

    @ Salva o ponteiro base mapeado
    ldr     r1, =hw_base
    str     r0, [r1]

    mov     r0, #0           @ retorna sucesso
    pop     {r4-r7, pc}

init_fail_close:
    @ Fecha o arquivo antes de retornar erro
    ldr     r0, =hw_fd
    ldr     r0, [r0]
    mov     r7, #SYS_CLOSE
    svc     #0
init_fail:
    mov     r0, #-1
    pop     {r4-r7, pc}


@ exit_hw_asm — Libera os recursos do hardware.
@ Desfaz o mmap e fecha /dev/mem. Seguro chamar várias vezes.
exit_hw_asm:
    push    {r4-r7, lr}

    ldr     r4, =hw_base
    ldr     r0, [r4]
    cmp     r0, #0
    beq     exit_done        @ já foi liberado, nada a fazer

    @ Desfaz o mapeamento de memória
    mov     r1, #0x1000
    mov     r7, #SYS_MUNMAP
    svc     #0
    mov     r0, #0
    str     r0, [r4]         @ zera hw_base

    @ Fecha /dev/mem
    ldr     r4, =hw_fd
    ldr     r0, [r4]
    mov     r7, #SYS_CLOSE
    svc     #0
    mov     r0, #-1
    str     r0, [r4]         @ marca fd como inválido

exit_done:
    pop     {r4-r7, pc}


@ reset_hw_asm — Reinicia a FSM do hardware.
@ Aplica um pulso no bit de reset de pio_hpswrite.
reset_hw_asm:
    push    {r0-r3, lr}

    ldr     r0, =hw_base
    ldr     r0, [r0]
    add     r0, r0, #PIO_CTRL_OFFSET

    mov     r1, #CTRL_RESET_BIT
    str     r1, [r0]         @ ativa reset

    mov     r1, #0
    str     r1, [r0]         @ libera reset

    pop     {r0-r3, pc}


@ carregar_img_asm — Envia a imagem de entrada (opcode 1).
@ Protótipo C: void carregar_img_asm(void *buffer)
@
@ Envia 784 pixels (uint8). Formato da instrução por elemento i:
@   [31:28] = 1  (opcode IMG)
@   [27:16] = i  (índice)
@   [15:0]  = pixel
carregar_img_asm:
    push    {r4-r12, lr}
    mov     r10, r0             @ ponteiro para o buffer de pixels
    mov     r9,  #LIM_IMG
    mov     r5,  #0
    setup_hw

    mov     r4, #0
img_loop:
    cmp     r4, r9
    bge     proc_done

    ldrb    r3, [r10], #1       @ lê 1 byte (uint8) e avança ponteiro

    @ Monta instrução: opcode=1, índice=r4, valor=r3
    mov     r7, #1
    lsl     r7, r7, #28
    orr     r7, r7, r4, lsl #16
    uxth    r3, r3
    orr     r7, r7, r3
    str     r7, [r1]
    bl      pulse_hw

    add     r4, r4, #1
    b       img_loop


@ carregar_bias_asm — Envia os bias da camada densa (opcode 3).
@ Protótipo C: void carregar_bias_asm(void *buffer)
@
@ Envia 128 valores (uint16). Formato da instrução por elemento i:
@   [31:28] = 3  (opcode BIAS)
@   [27:16] = i
@   [15:0]  = valor
carregar_bias_asm:
    push    {r4-r12, lr}
    mov     r10, r0
    mov     r9,  #LIM_BIAS
    mov     r5,  #0
    setup_hw

    mov     r4, #0
bias_loop:
    cmp     r4, r9
    bge     proc_done

    ldrh    r3, [r10], #2       @ lê 2 bytes (uint16) e avança ponteiro

    @ Monta instrução: opcode=3, índice=r4, valor=r3
    mov     r7, #3
    lsl     r7, r7, #28
    orr     r7, r7, r4, lsl #16
    uxth    r3, r3
    orr     r7, r7, r3
    str     r7, [r1]
    bl      pulse_hw

    add     r4, r4, #1
    b       bias_loop


@ carregar_beta_asm — Envia os parâmetros beta (BatchNorm) (opcode 4).
@ Protótipo C: void carregar_beta_asm(void *buffer)
@
@ Envia 1280 valores (uint16). Formato da instrução por elemento i:
@   [31:28] = 4  (opcode BETA)
@   [27:16] = i
@   [15:0]  = valor
carregar_beta_asm:
    push    {r4-r12, lr}
    mov     r10, r0
    mov     r9,  #LIM_BETA
    mov     r5,  #0
    setup_hw

    mov     r4, #0
beta_loop:
    cmp     r4, r9
    bge     proc_done

    ldrh    r3, [r10], #2       @ lê 2 bytes (uint16) e avança ponteiro

    @ Monta instrução: opcode=4, índice=r4, valor=r3
    mov     r7, #4
    lsl     r7, r7, #28
    orr     r7, r7, r4, lsl #16
    uxth    r3, r3
    orr     r7, r7, r3
    str     r7, [r1]
    bl      pulse_hw

    add     r4, r4, #1
    b       beta_loop


@ carregar_w_asm — Envia os pesos da rede neural (opcodes 6 e 2).
@ Protótipo C: void carregar_w_asm(void *buffer)
@
@ Envia 100352 pesos (uint16) em duas etapas por elemento:
@   Etapa 1 (endereço): opcode=6, [16:0] = índice & 0x1FFFF
@   Etapa 2 (dado):     opcode=2, [15:0] = valor
carregar_w_asm:
    push    {r4-r12, lr}
    mov     r10, r0
    mov     r9,  #LIM_W
    mov     r5,  #0
    setup_hw

    mov     r4, #0
w_loop:
    cmp     r4, r9
    bge     proc_done

    ldrh    r3, [r10], #2       @ lê 2 bytes (uint16) e avança ponteiro

    @ Etapa 1: envia o endereço do peso
    mov     r7, #6
    lsl     r7, r7, #28
    ldr     r6, =0x1FFFF
    and     r6, r4, r6
    orr     r7, r7, r6
    str     r7, [r1]
    bl      pulse_hw

    @ Etapa 2: envia o valor do peso
    mov     r7, #2
    lsl     r7, r7, #28
    uxth    r3, r3
    orr     r7, r7, r3
    str     r7, [r1]
    bl      pulse_hw

    add     r4, r4, #1
    b       w_loop


@ start_asm — Dispara a inferência e aguarda o resultado (opcode 5).
@ Protótipo C: void start_asm(void)
@ Inicia polling com a subida do bit busy
@ E faz polling em status até o bit busy (bit 0) decer.
start_asm:
    push    {r4-r12, lr}
    mov     r5, #0
    setup_hw

    @ Envia instrução de início (opcode 5)
    mov     r7, #5
    lsl     r7, r7, #28
    str     r7, [r1]
    bl      pulse_hw

    @ Polling: aguarda o hardware enquanto sinalizar busy (bit 0 = 1)
wait_end_busy:
    mov     r7, #0              @ opcode STATUS
    str     r7, [r1]
    bl      pulse_hw
    ldr     r7, [r12]           @ lê o registrador de status
    ubfx    r3, r7, #0, #1      @ extrai bit 0 (busy)
    cmp     r3, #1
    beq     wait_end_busy           @ ainda não terminou, continua polling

    @ Salva o valor bruto final para retorno
    mov     r5, r7
    b       proc_done



@ status_asm — Lê o status do hardware e preenche um array (opcode 0).
@ Protótipo C: uint32_t status_asm(uint32_t *dados)
@ Campos extraídos de pio_readdata:
@   dados[0] = busy   (bit  0)
@   dados[1] = done   (bit  1)
@   dados[2] = error  (bit  2)
@   dados[3] = digito (bits 7:4)
@   dados[4] = ciclos (bits 31:8)
@ Retorno: valor bruto de 32 bits lido do hardware.
status_asm:
    push    {r4-r12, lr}
    mov     r10, r0             @ ponteiro para o array de saída
    mov     r5,  #0
    setup_hw

    @ Envia instrução de leitura de status (opcode 0)
    mov     r7, #0
    str     r7, [r1]
    bl      pulse_hw

    @ Lê o valor bruto e extrai cada campo por bit
    ldr     r7, [r12]
    mov     r5, r7              @ salva para retorno

    ubfx    r3, r7, #0, #1
    str     r3, [r10, #0]       @ dados[0] = busy

    ubfx    r3, r7, #1, #1
    str     r3, [r10, #4]       @ dados[1] = done

    ubfx    r3, r7, #2, #1
    str     r3, [r10, #8]       @ dados[2] = error

    ubfx    r3, r7, #4, #4
    str     r3, [r10, #12]      @ dados[3] = dígito predito

    ubfx    r3, r7, #8, #24
    str     r3, [r10, #16]      @ dados[4] = contagem de ciclos

    b       proc_done


@ Saída comum de todas as funções de carga e controle.
@ r5 carrega o valor de retorno (0 ou valor bruto de status).
proc_done:
    mov     r0, r5
err_ret:
    pop     {r4-r12, pc}

@ pulse_hw — Gera um pulso de clock manual no hardware.
@ Ativa o bit de clock em pio_hpswrite e desativa.
@ Convenção: r2 deve apontar para pio_hpswrite antes do BL.
pulse_hw:
    push    {r3}
    mov     r3, #CTRL_CLK_BIT
    str     r3, [r2]            @ ativa clock

    mov     r3, #0
    str     r3, [r2]            @ desativa clock
    pop     {r3}
    bx      lr

.section .rodata
dev_mem_path: .asciz "/dev/mem"
