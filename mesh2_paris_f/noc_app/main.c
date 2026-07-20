#include <stdio.h>
#include <stdlib.h>
#include <generated/csr.h>
#include <libbase/uart.h>

static void delay(int cycles) {
    for (volatile int i = 0; i < cycles; i++);
}

static void send_packet(uint8_t dest_x, uint8_t dest_y, uint32_t data) {
    while (noc_tx_busy_read() == 1); 
    uint8_t endereco = (dest_y << 2) | dest_x;
    noc_tx_dest_write(endereco);
    noc_tx_data_write(data);
    noc_tx_send_write(1); 
}

int main(void) {
#ifdef CSR_UART_BASE
    uart_init();
#endif

    uint8_t my_x = main_noc_coords_read() & 0x0F;
    uint8_t my_y = (main_noc_coords_read() >> 4) & 0x0F;
    uint32_t msg_count = 1;

    // Tempo para todo mundo ligar junto
    delay(100000);

    uint8_t target_x = 0;
    uint8_t target_y = 0;

    while (1) {
        // --- 1. TODOS OS NÓS GERAM PACOTES ---
        // Pula o envio se o alvo for o próprio nó
        if (target_x == my_x && target_y == my_y) {
            target_x++;
            if (target_x > 1) { target_x = 0; target_y = (target_y + 1) % 2; }
        }

        // Payload: [Assinatura 0xAA] [X_Origem] [Y_Origem] [Contador]
        uint32_t payload = 0xAA000000 | (my_x << 20) | (my_y << 16) | msg_count;
        send_packet(target_x, target_y, payload);
        msg_count++;

        // Atualiza próximo alvo (Round-Robin entre os nós da malha 2x2)
        target_x++;
        if (target_x > 1) { 
            target_x = 0; 
            target_y = (target_y + 1) % 2; 
        }
        
        delay(50000); // Pequeno atraso para não engarrafar a rede imediatamente

        // --- 2. TODOS OS NÓS RECEBEM PACOTES ---
        // Processa todos os pacotes que chegaram na FIFO de recepção
        while (noc_rx_valid_read() == 1) {
            uint32_t dado = noc_rx_data_read();
            noc_rx_ack_write(1); 
            
            // Apenas o nó [0,0] imprime no terminal (pois é o único com UART mapeada na simulação)
            if (my_x == 0 && my_y == 0) {
                uint8_t remetente_x = (dado >> 20) & 0x0F;
                uint8_t remetente_y = (dado >> 16) & 0x0F;
                uint16_t msg_num = dado & 0xFFFF;
                printf("-> [0,0] Recebeu pacote de [%d,%d] | Msg nº: %d (Hex: 0x%lx)\n", 
                       remetente_x, remetente_y, msg_num, dado);
            }
        }
    }
    return 0;
}
