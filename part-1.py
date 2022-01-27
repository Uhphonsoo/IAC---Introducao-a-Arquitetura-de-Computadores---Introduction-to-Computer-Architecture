# Projeto IAC - Parte 1 - 26/10/2019
# Joao Afonso Silva, 90398 e Jean Leitao, 96977, grupo 10

import math

def calc_acel_x(ang_plano, g):
    return g * sen(ang_plano)

def calc_vel_atual(vel_ini, acel_x):
    t = 0.125
    return acel_x * t + vel_ini

def calc_pos_atual(pos_ini, vel_ini, acel_x):
    t = 0.125
    return pos_ini + (vel_ini * t) + (0.5 * acel_x * t**2)

def sen(n):
    return math.sin(n*math.pi/180)

ang_plano_main = 60
vel_ini_1 = 7
vel_ini_2 = vel_ini_1
pos_ini_main = 2
g_main = 10
acel_x_main = calc_acel_x(ang_plano_main, g_main)

i = 50
while i > 0:
    vel_ini_1 = calc_vel_atual(vel_ini_1, acel_x_main)
    # de forma a não usar a vel já atualizada uso vel_ini_2
    pos_ini_main = calc_pos_atual(pos_ini_main, vel_ini_2, acel_x_main)
    vel_ini_2 = vel_ini_1
    i -= 1

# a imprimir com 8 casas decimais (Q8)
print(f" vel_final = {vel_ini_1:.8f}")
print(f" pos_final = {pos_ini_main:.8f}")
