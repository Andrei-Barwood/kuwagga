#!/usr/bin/env python3
"""
Script educativo para visualizar la intersección de conjuntos
Requiere: matplotlib, matplotlib-venn
"""

import sys
import random

try:
    import matplotlib.pyplot as plt
    from matplotlib_venn import venn2, venn3
except ImportError as e:
    print(f"Error: Falta la dependencia requerida: {e}", file=sys.stderr)
    print("Instala con: pip install matplotlib matplotlib-venn", file=sys.stderr)
    sys.exit(1)

# UNIVERSO: elementos del 1 al 10
universo = set(range(1, 11))

# Aleatoriamente decide usar 2 o 3 conjuntos
n_sets = random.choice([2, 3])

# Generar conjuntos aleatorios
tamano_A = random.randint(2, 7)
tamano_B = random.randint(2, 7)
A = set(random.sample(list(universo), tamano_A))
B = set(random.sample(list(universo), tamano_B))

if n_sets == 3:
    tamano_C = random.randint(2, 7)
    C = set(random.sample(list(universo), tamano_C))

# Calcular intersección
if n_sets == 2:
    inter = A & B
    conjuntos = {'A': A, 'B': B}
    simbolo = 'A ∩ B'
else:
    inter = A & B & C
    conjuntos = {'A': A, 'B': B, 'C': C}
    simbolo = 'A ∩ B ∩ C'

# Imprimir datos
print("Universo U =", universo)
for nombre, conj in conjuntos.items():
    print(f"Conjunto {nombre} = {conj}")

print(f"\nEjercicio: Encuentra la intersección {simbolo}")
print(f"{simbolo} = {sorted(inter)}")

# Explicación en lenguaje común
msg = (
    f"La intersección {simbolo} contiene los elementos que "
    f"pertenecen a " + ("ambos" if n_sets==2 else "los tres") +
    " conjuntos a la vez. En este caso son: " + str(sorted(inter))
)
print("\nExplicación:")
print(msg)

# Gráfico
plt.figure(figsize=(6,6))
if n_sets == 2:
    venn = venn2(subsets=(A, B), set_labels=('A', 'B'),
                 set_colors=('#63627C', '#A6A4D7'), alpha=0.8)
    label_10 = venn.get_label_by_id('10')
    if label_10: label_10.set_text('\n'.join(map(str, sorted(A - B))))
    label_01 = venn.get_label_by_id('01')
    if label_01: label_01.set_text('\n'.join(map(str, sorted(B - A))))
    label_11 = venn.get_label_by_id('11')
    if label_11: label_11.set_text('\n'.join(map(str, sorted(A & B))))
else:
    venn = venn3(subsets=(A, B, C), set_labels=('A', 'B', 'C'),
                 set_colors=('#63627C', '#A6A4D7', '#485199'), alpha=0.8)

    def set_venn_label(venn_obj, label_id, data_set):
        label = venn_obj.get_label_by_id(label_id)
        if label:
            label.set_text('\n'.join(map(str, sorted(data_set))))

    set_venn_label(venn, '100', A - B - C)
    set_venn_label(venn, '010', B - A - C)
    set_venn_label(venn, '001', C - A - B)
    set_venn_label(venn, '110', A & B - C)
    set_venn_label(venn, '101', A & C - B)
    set_venn_label(venn, '011', B & C - A)
    set_venn_label(venn, '111', A & B & C)

plt.title("Diagrama de Venn: Intersección de conjuntos")
plt.show()