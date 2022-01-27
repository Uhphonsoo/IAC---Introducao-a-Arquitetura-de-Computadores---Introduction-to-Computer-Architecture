; Projeto IAC - Parte 2 - 23/11/2019
; Joao Afonso Silva, 90398 e Jean Leitao, 96977, grupo 10
; versao final

STACKBASE       EQU     8000h
                
INT_MASK        EQU     FFFAh
INT_MASK_VALUE  EQU     8000h ; ligar a interrupcao do timer

POS_CURSOR      EQU     FFFCh ; definir posicao do cursor
END_DUR_TICK    EQU     FFF6h ; endereco para definir a duracao da contagem
TIMER_CONTROL   EQU     FFF7h ; iniciar/parar timer
LER_ACELERO_X   EQU     FFEBh ; ler valor do acelerometro do eixo x
ESCREVER_TERM   EQU     FFFEh ; escrever carater no terminal

DURACAO_TICK    EQU     1     ; (100ms)
g_sobre_255     EQU     000Ah ; (0.0390625m/s^2) (Q8)
                
                ORIG    0000h

pos_atual       WORD    0200h  ; (=2m)     (Q8)
; nota: a posicao inicial nao pode ser 1 porque faz com seja
; invertida a velocidade logo no inicio da simulacao

vel_atual       WORD    0A00h  ; (=10m/s)  (Q8)
t               WORD    0020h  ; (=0.125s) (Q8)
bateu_flag      WORD    0
acel_x          TAB     1

; ------------------------------------------------------------------
; rotina de tratamento de interrupcoes do temporizador
; ------------------------------------------------------------------
                ORIG    7FF0h
int_timer:      
                JMP     int_timer_cont      

                ORIG    6000h 
int_timer_cont: 
                DEC     R6
                STOR    M[R6], R1 ; PUSH R1
                DEC     R6
                STOR    M[R6], R2 ; PUSH R2
                DEC     R6
                STOR    M[R6], R3 ; PUSH R3
                DEC     R6
                STOR    M[R6], R4 ; PUSH R4
                
                ; fazer update da aceleracao
                JAL     update_acel_x
                
                ; fazer update velocidade e posicao
                MVI     R4, vel_atual
                LOAD    R1, M[R4] ; R1 = vel_atual
                MVI     R4, acel_x
                LOAD    R2, M[R4] ; R2 = acel_x
                
                ; R1 = vel_atual, R2 = acel_x
                JAL     calc_vel_atual ; R3 = vel_atual
                
                ; guardo o vel_atualizado na pilha porque nao
                ; o quero usar atualizado no calculo da pos_atualizada
                DEC     R6        ; PUSH R3 !
                STOR    M[R6], R3 ; R3 = vel_atual
                
                ; se bateu_flag = 1 nao calculo a posicao
                MVI     R1, bateu_flag
                LOAD    R1, M[R1] ; R1 = bateu_flag
                CMP     R1, R0
                BR.P    .salta
                
                ; else:
                MVI     R4, pos_atual
                LOAD    R1, M[R4] ; R1 = pos_atual
                MVI     R4, vel_atual
                LOAD    R2, M[R4] ; R2 = vel_atual
                
                ; R1 = pos_atual, R2 = vel_atual
                ; nao uso o vel_atualizado que vem de cima!
                JAL     calc_pos_atual ; R3 = pos_atual
                
                ; preparar proxima iteracao
                MVI     R4, pos_atual
                STOR    M[R4], R3 ; pos_atual(memoria) = pos_atual(nova) 
                
.salta:         
                ; recuperar vel_atualizado para 
                ; poder preparar proxima iteracao
                LOAD    R3, M[R6] ; R3 = vel_atual
                INC     R6        ; POP R3 !
                
                ; preparar proxima iteracao
                MVI     R4, vel_atual
                STOR    M[R4], R3 ; vel_atual(memoria) = vel_atual(nova)
                
                ; limpar impressao anterior da bola
                JAL     limpar_bola
                
                ; imprimir posicao nova da bola
                JAL     imprimir_bola
                
                LOAD    R4, M[R6] ; POP R4
                INC     R6
                LOAD    R3, M[R6] ; POP R3
                INC     R6
                LOAD    R2, M[R6] ; POP R2
                INC     R6
                LOAD    R1, M[R6] ; POP R1
                INC     R6
                RTI
                
; ------------------------------------------------------------------
; main
; ------------------------------------------------------------------
                ORIG    0000h  
                MVI     R6, STACKBASE
                
                ; INICIO-TESTAR -----------------------------
                MVI     R1, INT_MASK
                MVI     R2, INT_MASK_VALUE
                STOR    M[R1], R2               ; set interrupt mask
                ENI                             ; enable interrupts
                
                ; imprimir caixa
                JAL     imprimir_caixa
                
                ; imprimir posicao inicial da bola
                JAL     imprimir_bola
                
                ; chamar as interrupcoes do timer
CLOCK:          
                ; reset de bateu_flag
                MVI     R1, bateu_flag
                STOR    M[R1], R0
                
                MVI     R1, END_DUR_TICK
                MVI     R2, DURACAO_TICK
                STOR    M[R1], R2 ; definir duração de contagem
                
                MVI     R1, TIMER_CONTROL
                MVI     R2, 1
                STOR    M[R1], R2 ; iniciar contagem
                
                BR      CLOCK
                ; FIM-TESTAR -----------------------------
                
FIM:            BR      FIM
                
; v = ax * t + v0
; R1 = vel_atual, R2 = acel_x
calc_vel_atual: 
                DEC     R6
                STOR    M[R6], R4 ; PUSH R4
                DEC     R6
                STOR    M[R6], R7 ; PUSH R7
                
                ; acel_x * t -> 3xSHRA de acel_x (t=0.125)
                SHRA    R2
                SHRA    R2
                SHRA    R2
                ; R2 = acel_x * t
                
                ; Soma tendo em conta o formato Q
                ; R1 = vel_atual(Q8), R2 = acel_x * t(Q8)
                ADD     R3, R2, R1 ; R3 = acel_x * t + vel_atual (Q8)
                
                ; testar se x <= 1
                MVI     R1, pos_atual
                LOAD    R1, M[R1] ; R1 = pos_atual
                MVI     R2, 0100h
                CMP     R1, R2
                BR.NP   .bateu_esq
                
                ; testar se x >= 78
                MVI     R2, 4e00h ; R2 = 78 (Q8)
                CMP     R1, R2
                BR.NN   .bateu_dir
                BR      .return
                
.bateu_esq:     
                CMP     R3, R0 ; so inverto a velocidade se for negativa
                BR.P    .salta
                NEG     R3 ; vel_atual = - vel_atual
.salta:         MVI     R1, pos_atual
                MVI     R2, 0200h
                STOR    M[R1], R2
                ; flag para o programa saber que bateu
                ; que vai evitar calcular de novo a posicao:
                MVI     R1, bateu_flag
                MVI     R2, 1
                STOR    M[R1], R2
                BR      .return
                
.bateu_dir:     
                CMP     R3, R0 ; so inverto a velocidade se for positiva
                BR.N    .salta2
                NEG     R3 ; vel_atual = - vel_atual
.salta2:        MVI     R1, pos_atual
                MVI     R2, 4d00h
                STOR    M[R1], R2
                ; flag para o programa saber que bateu
                ; que vai evitar calcular de novo a posicao:
                MVI     R1, bateu_flag
                MVI     R2, 1
                STOR    M[R1], R2
                
.return:        
                LOAD    R7, M[R6] ; POP R7
                INC     R6
                LOAD    R4, M[R6] ; POP R4
                INC     R6
                JMP     R7

; x = x0 + v0*t + 1/2*ax*t^2
; R1 = pos_atual, R2 = vel_atual
calc_pos_atual: 
                ; vel_atual * t -> 3xSHRA de vel_atual (t=0.125)
                DEC     R6
                STOR    M[R6], R4 ; PUSH R4
                DEC     R6
                STOR    M[R6], R5 ; PUSH R5
                DEC     R6
                STOR    M[R6], R7 ; PUSH R7
                
                SHRA    R2
                SHRA    R2
                SHRA    R2
                ; R2 = vel_atual * t
                
                ; Soma tendo em conta o formato Q
                ; R1 = pos_atual(Q8) R2 = vel_atual * t(Q8)
                ADD     R3, R1, R2 ; R3 = pos_atual + vel_atual * t (Q8)
                
                MVI     R4, acel_x
                LOAD    R5, M[R4] ; R5 = acel_x (Q8)
                
                ; acel_x * t * t -> 6xSHRA de acel_x (t=0.125=2^-3)
                SHRA    R5
                SHRA    R5
                SHRA    R5
                SHRA    R5
                SHRA    R5
                SHRA    R5
                ; R5 = acel_x * t^2 (Q8)
                
                ; acel_x * t^2 * 0.5 -> 1xSHRA de acel_x * t^2 (0.5=2^-1)
                SHRA    R5
                ; R5 = 1/2 * acel_x * t^2 (Q8)
                
                ; Soma tendo em conta o formato Q
                ; R3 = pos_atual + vel_atual * t(Q8), R5 = 1/2 * acel_x * t^2(Q8)
                ADD     R3, R3, R5 ; R3 = pos_atual+vel_atual*t + 1/2 * acel_x * t^2 (Q8)
                
.return:        LOAD    R7, M[R6] ; POP R7
                INC     R6
                LOAD    R5, M[R6] ; POP R5
                INC     R6
                LOAD    R4, M[R6] ; POP R4
                INC     R6
                JMP     R7
                
; a = x*g / 255                 
update_acel_x:  
                DEC     R6
                STOR    M[R6], R1 ; PUSH R1
                DEC     R6
                STOR    M[R6], R2 ; PUSH R2
                DEC     R6
                STOR    M[R6], R3 ; PUSH R3
                DEC     R6
                STOR    M[R6], R7 ; PUSH R7
                
                MVI     R1, LER_ACELERO_X ; endereco de leitura do acelerometro_x
                LOAD    R1, M[R1] ; R1 = valor_acelerometro_x
                
                MVI     R2, g_sobre_255
                
                ; R1 = x, R2 = g/255
                JAL     produto
                ; R3 = x*g -> Q0 * Q8 = Q8
                
                MOV     R1, R3 ; R1 = x*g/255
                MVI     R2, acel_x
                STOR    M[R2], R1 ; acel_x = a = x*g/255
                
                LOAD    R7, M[R6] ; POP R7
                INC     R6
                LOAD    R3, M[R6] ; POP R3
                INC     R6
                LOAD    R2, M[R6] ; POP R2
                INC     R6
                LOAD    R1, M[R6] ; POP R1
                INC     R6
                JMP     R7
                
imprimir_caixa: 
                DEC     R6
                STOR    M[R6], R1 ; PUSH R1
                DEC     R6
                STOR    M[R6], R2 ; PUSH R2
                DEC     R6
                STOR    M[R6], R4 ; PUSH R4
                DEC     R6
                STOR    M[R6], R5 ; PUSH R5
                DEC     R6
                STOR    M[R6], R7 ; PUSH R7
                
                ; imprimir teto (l1)
                MVI     R5, 80
                MVI     R4, 0000h
                
.loop:          
                CMP     R5, R0
                BR.Z    .imprimir_l2
                
                MVI     R1, POS_CURSOR
                STOR    M[R1], R4 ; cursor esta em (l,c) = (0,0)
                
                MVI     R1, ESCREVER_TERM
                MVI     R2, '*'
                STOR    M[R1], R2
                
                INC     R4
                DEC     R5
                BR      .loop
                
.imprimir_l2:   ; imprimir linha 2 (l2)
                ; imprimir 1a parede
                MVI     R1, POS_CURSOR
                MVI     R4, 0100h
                STOR    M[R1], R4 ; cursor esta em (l,c) = (1,0)
                
                MVI     R1, ESCREVER_TERM
                MVI     R2, '*'
                STOR    M[R1], R2
                
                ; imprimir 2a parede
                MVI     R1, POS_CURSOR
                MVI     R4, 014fh
                STOR    M[R1], R4 ; cursor esta em (l,c) = (1,80)
                
                MVI     R1, ESCREVER_TERM
                MVI     R2, '*'
                STOR    M[R1], R2
                
                ; imprimir chao (l3)
                MVI     R5, 80
                MVI     R4, 0200h
                
.loop2:         CMP     R5, R0
                BR.Z    .return
                
                MVI     R1, POS_CURSOR
                STOR    M[R1], R4 ; cursor esta em (l,c) = (2,0)
                
                MVI     R1, ESCREVER_TERM
                MVI     R2, '*'
                STOR    M[R1], R2
                
                INC     R4
                DEC     R5
                BR      .loop2
.return:        
                LOAD    R7, M[R6] ; POP R7
                INC     R6
                LOAD    R5, M[R6] ; POP R5
                INC     R6
                LOAD    R4, M[R6] ; POP R4
                INC     R6
                LOAD    R2, M[R6] ; POP R2
                INC     R6
                LOAD    R1, M[R6] ; POP R1
                INC     R6
                JMP     R7
                
imprimir_bola:  
                DEC     R6
                STOR    M[R6], R1 ; PUSH R1
                DEC     R6
                STOR    M[R6], R2 ; PUSH R2
                DEC     R6
                STOR    M[R6], R4 ; PUSH R4
                DEC     R6
                STOR    M[R6], R7 ; PUSH R7
                
                MVI     R1, pos_atual
                LOAD    R1, M[R1] ; R1 = pos_atual
                        
                ; converter pos_atual de Q8 para decimal (Q0)
                SHR     R1
                SHR     R1 
                SHR     R1
                SHR     R1
                SHR     R1
                SHR     R1
                SHR     R1
                SHR     R1 ; R1 = pos_atual_convertida (Q0)
                
                ; se R1 > 78 nao imprime a bola
                MVI     R4, 78
                CMP     R1, R4
                BR.P    .return
                
                ; para nao escrever em cima da parede da esquerda:
                CMP     R1, R0
                BR.NZ   .salta
                INC     R1
                
.salta:
                ; para nao escrever em cima da parede da direita:
                MVI     R4, 79
                CMP     R4, R1
                BR.NZ   .salta2
                DEC     R1
                         
.salta2:        
                MVI     R2, 0100h ; primeira posicao da caixa
                
                MVI     R4, POS_CURSOR ; definir posicao do cursor
                ADD     R2, R2, R1 ; R2 = 0100h + pos_atual_convertida
                STOR    M[R4], R2 ; coluna = pos_atual_convertida
                
                MVI     R1, ESCREVER_TERM
                MVI     R2, 'o'
                STOR    M[R1], R2
                
.return:        LOAD    R7, M[R6] ; POP R7
                INC     R6
                LOAD    R4, M[R6] ; POP R4
                INC     R6
                LOAD    R2, M[R6] ; POP R2
                INC     R6
                LOAD    R1, M[R6] ; POP R1
                INC     R6
                JMP     R7
                
limpar_bola:    
                DEC     R6
                STOR    M[R6], R1 ; PUSH R1
                DEC     R6
                STOR    M[R6], R2 ; PUSH R2
                DEC     R6
                STOR    M[R6], R3 ; PUSH R3
                DEC     R6
                STOR    M[R6], R4 ; PUSH R4
                DEC     R6
                STOR    M[R6], R7 ; PUSH R7
                
                MVI     R4, 78
                MVI     R2, 0100h
                ; varrer as posicoes dos cursor de 1 a 78
.loop:          
                CMP     R4, R0
                BR.Z    .return
                
                MVI     R1, POS_CURSOR
                ADD     R3, R2, R4 ; R3 = coluna0 + R4
                STOR    M[R1], R3 ; definir posicao do cursor
                
                MVI     R1, ESCREVER_TERM
                MVI     R3, 32 ; ASCII para espaco
                STOR    M[R1], R3
                DEC     R4
                BR      .loop
                
.return:        
                LOAD    R7, M[R6] ; POP R7
                INC     R6
                LOAD    R4, M[R6] ; POP R4
                INC     R6
                LOAD    R3, M[R6] ; POP R3
                INC     R6
                LOAD    R2, M[R6] ; POP R2
                INC     R6
                LOAD    R1, M[R6] ; POP R1
                INC     R6
                JMP     R7

produto:        
                DEC     R6
                STOR    M[R6], R7 ; PUSH R7
                
                MVI     R3, 0
                CMP     R2, R0
                BR.Z    .Fim
.Loop:          ADD     R3, R3, R1
                DEC     R2
                BR.NZ   .Loop
.Fim:           
                LOAD    R7, M[R6] ; POP R7
                INC     R6
                JMP     R7