; Projeto IAC - Parte 1 - 26/10/2019
; Joao Afonso Silva, 90398 e Jean Leitao, 96977, grupo 10

STACKBASE       EQU     8000h
iteracoes       EQU     50 ; corresponde a 6.25 segundos (t=0.125)

                ORIG    0000h

ang_plano       WORD    60     ; (=60graus)(Q0)           
t               WORD    0020h  ; (=0.125s) (Q8)
vel_ini         WORD    0700h  ; (=7m/s)   (Q8)
pos_ini         WORD    0200h  ; (=2m)     (Q8)
g               WORD    10     ; (10m/s^2) (Q0)
acel_x          TAB     1

SENOS           STR     0000h,0004h,0009h,000Dh,0012h,0016h,001Bh,001Fh,0024h,0028h,002Ch,0031h,0035h,003Ah,003Eh,0042h,0047h,004Bh,004Fh,0053h,0058h,005Ch,0060h,0064h,0068h,006Ch,0070h,0074h,0078h,007Ch,0080h,0084h,0088h,008Bh,008Fh,0093h,0096h,009Ah,009Eh,00A1h,00A5h,00A8h,00ABh,00AFh,00B2h,00B5h,00B8h,00BBh,00BEh,00C1h,00C4h,00C7h,00CAh,00CCh,00CFh,00D2h,00D4h,00D7h,00D9h,00DBh,00DEh,00E0h,00E2h,00E4h,00E6h,00E8h,00EAh,00ECh,00EDh,00EFh,00F1h,00F2h,00F3h,00F5h,00F6h,00F7h,00F8h,00F9h,00FAh,00FBh,00FCh,00FDh,00FEh,00FEh,00FFh,00FFh,00FFh,0100h,00100h,0100h,0100h												
                ; senos estao em formato Q8
                
                ORIG    0000h  
                MVI     R6, STACKBASE
                
                ; INICIO-TESTAR -----------------------------
                MVI     R4, ang_plano
                LOAD    R1, M[R4] ; R1 = ang_plano
                MVI     R4, g
                LOAD    R2, M[R4] ; R2 = g
                
                ; R1 = ang_plano, R2 = g
                JAL     calc_acel_x
                ; R3 = acel_x
                
                MVI     R5, iteracoes
                
loop:           CMP     R5, R0
                BR.Z    FIM
                MVI     R4, vel_ini
                LOAD    R1, M[R4] ; R1 = vel_ini
                MVI     R4, acel_x
                LOAD    R2, M[R4] ; R2 = acel_x
                
                ; R1 = vel_ini(ou vel_atual), R2 = acel_x
                JAL     calc_vel_atual ; R3 = vel_atual
                
                ; guardo o vel_atualizado na pilha porque nao
                ; o quero usar atualizado no calculo da pos_atualizada
                DEC     R6        ; PUSH R3
                STOR    M[R6], R3 ; R3 = vel_atual
                
                MVI     R4, pos_ini
                LOAD    R1, M[R4] ; R1 = pos_ini
                MVI     R4, vel_ini
                LOAD    R2, M[R4] ; R2 = vel_ini
                
                DEC     R6
                STOR    M[R6], R5
                ; R1 = pos_ini, R2 = vel_ini
                ; nao uso o vel_atualizado que vem de cima!
                JAL     calc_pos_atual ; R3 = pos_atual
                LOAD    R5, M[R6]
                INC     R6
                
                ; preparar proxima iteracao
                MVI     R4, pos_ini
                STOR    M[R4], R3 ; pos_ini(memoria) = pos_ini(nova) 
                
                ; recuperar vel_atualizado para 
                ; poder preparar proxima iteracao
                LOAD    R3, M[R6] ; R3 = vel_atual
                INC     R3        ; POP R3
                
                ; preparar proxima iteracao
                MVI     R4, vel_ini
                STOR    M[R4], R3 ; vel_ini(memoria) = vel_ini(nova)
                
                DEC     R5
                BR      loop
                ; FIM-TESTAR -----------------------------
                
FIM:            BR      FIM

; ax = g * sin(ang_plano)
; R1 = ang_plano, R2 = acel_grav = g
calc_acel_x:    DEC     R6
                STOR    M[R6], R7
                ; R1 = ang_plano
                JAL     sin ; R3 = sin(ang_plano)
                
                LOAD    R7, M[R6]
                INC     R6
                
                MOV     R1, R2 ; R1 = g
                MOV     R2, R3 ; R2 = sin(ang_plano)
                
                DEC     R6
                STOR    M[R6], R7
                ; R1 = g, R2 = sin(ang_plano) 
                JAL     produto ; R3 = g * sin(ang_plano) (Q0 * Q8)
                
                ; R3 esta em Q8
                
                LOAD    R7, M[R6]
                INC     R6
                
                MVI     R4, acel_x
                STOR    M[R4], R3
                
                JMP     R7

; v = ax * t + v0
; R1 = vel_ini, R2 = acel_x
calc_vel_atual: ; acel_x * t -> 3xSHRA de acel_x (t=0.125)
                SHRA    R2
                SHRA    R2
                SHRA    R2
                ; R2 = acel_x * t
                
                ; Soma tendo em conta o formato Q
                ; R1 = vel_ini(Q8), R2 = acel_x * t(Q8)
                ADD     R3, R2, R1 ; R3 = acel_x * t + vel_ini (Q8)
                JMP     R7

; x = x0 + v0*t + 1/2*ax*t^2
; R1 = pos_ini, R2 = vel_ini
calc_pos_atual: ; vel_ini * t -> 3xSHRA de vel_ini (t=0.125)
                SHRA    R2
                SHRA    R2
                SHRA    R2
                ; R2 = vel_ini * t
                
                ; Soma tendo em conta o formato Q
                ; R1 = pos_ini(Q8) R2 = vel_ini * t(Q8)
                ADD     R3, R1, R2 ; R3 = pos_ini + vel_ini * t (Q8)
                
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
                ; R3 = pos_ini + vel_ini * t(Q8), R5 = 1/2 * acel_x * t^2(Q8)
                ADD     R3, R3, R5 ; R3 = pos_ini + vel_ini * t + 1/2 * acel_x * t^2 (Q8)
                
                JMP     R7

; R1 = angulo, R3 = sin(angulo)
sin:            MVI     R4, SENOS
                ADD     R4, R4, R1
                LOAD    R3, M[R4]
                JMP     R7
                
produto:        MVI     R3, 0
                CMP     R2, R0
                BR.Z    .Fim
.Loop:          ADD     R3, R3, R1
                DEC     R2
                BR.NZ   .Loop
.Fim:           JMP     R7