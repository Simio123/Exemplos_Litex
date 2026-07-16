#include <stdio.h>
#include <stdlib.h>
#include <generated/csr.h> // A "mágica" do LiteX: traz os registradores do Migen para o C

// Variáveis globais para simular a identidade do nó atual
// (Na prática, poderíamos ler isso de um registrador de hardware)
int MY_X = 0;
int MY_Y = 0;

// Função para criar um atraso (já que não temos 'sleep' do Linux)
void delay(int cycles) {
    for (volatile int i = 0; i < cycles; i++);
}

// Função de envio adaptada para o nosso hardware
void send_packet(uint8_t dest_x, uint8_t dest_y, uint32_t data) {
    // 1. Aguarda o roteador estar livre
    while (noc_tx_busy_read() == 1);
    
    // 2. Escreve o destino (Y nos bits [3:2], X nos bits [1:0])
    uint8_t endereco = (dest_y << 2) | dest_x;
    noc_tx_dest_write(endereco);
    
    // 3. Escreve a carga útil de 32 bits
    noc_tx_data_write(data);
    
    // 4. Pulso para enviar!
    noc_tx_send_write(1);
}

// Função de recepção adaptada
void check_network(void) {
    // Verifica se há algo esperando na porta Local
    if (noc_rx_valid_read() == 1) {
        uint32_t dado = noc_rx_data_read();
        
        // Confirma o recebimento para liberar o roteador
        noc_rx_ack_write(1);
        
        printf(">>> RECEBI MENSAGEM: 0x%lx\n", dado);
    }
}

int main(void) {
    printf("\n--- Nó da Malha Inicializado! ---\n");
    
    // Um contador simples para criar mensagens únicas
    uint32_t mensagem_id = 0xAABB0000; 

    while (1) {
        // Envia uma mensagem para o Nó 3 (X=1, Y=1) a cada iteração
        // Para evitar enviar para si mesmo, fazemos uma checagem
        if (MY_X != 1 || MY_Y != 1) {
            printf("Enviando pacote para Node(1,1)...\n");
            send_packet(1, 1, mensagem_id);
            mensagem_id++;
        }

        // Verifica se recebemos alguma coisa
        check_network();

        // Pausa antes de repetir
        delay(500000);
    }
    
    return 0;
}
