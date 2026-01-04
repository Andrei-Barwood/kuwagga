#!/usr/bin/env python3
"""
Script educativo para visualizar la unión de conjuntos
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

# UNIVERSO: elementos del 1 al 9
universo = set(range(1, 10))

# Elegir aleatoriamente entre 2 o 3 conjuntos
n_sets = random.choice([2, 3])

# Generar los conjuntos
tamano_A = random.randint(2, 6)
tamano_B = random.randint(2, 6)
A = set(random.sample(list(universo), tamano_A))
B = set(random.sample(list(universo), tamano_B))

if n_sets == 3:
    tamano_C = random.randint(2, 6)
    C = set(random.sample(list(universo), tamano_C))

# Calcular la unión
if n_sets == 2:
    union = A | B
    conjuntos = {'A': A, 'B': B}
    simbolo_union = 'A ∪ B'
else:
    union = A | B | C
    conjuntos = {'A': A, 'B': B, 'C': C}
    simbolo_union = 'A ∪ B ∪ C'

# Imprimir datos
print("Universo U =", universo)
for nombre, conj in conjuntos.items():
    print(f"Conjunto {nombre} = {conj}")
print(f"\nEjercicio: Encuentra la unión de los conjuntos ({simbolo_union})")
print(f"{simbolo_union} = {sorted(union)}")

# Explicación en lenguaje común
msg = (
    f"La unión de los conjuntos incluye todos los elementos que "
    f"pertenecen a al menos uno de los conjuntos indicados. "
    f"En este caso, incluye todos los que se encuentran en "
    + (", ".join([f"{nombre}" for nombre in conjuntos]))
    + f". Es decir: {sorted(union)}"
)
print("\nExplicación:")
print(msg)

# Diagrama de Venn
plt.figure(figsize=(6,6))
if n_sets == 2:
    venn = venn2(subsets=(A, B), set_labels=('A', 'B'),
                 set_colors=('#63627C', '#A7B7CF'), alpha=0.8)
    venn.get_label_by_id('10').set_text('\n'.join(map(str, sorted(A - B))))
    venn.get_label_by_id('01').set_text('\n'.join(map(str, sorted(B - A))))
    venn.get_label_by_id('11').set_text('\n'.join(map(str, sorted(A & B))))
else:
    venn = venn3(subsets=(A, B, C), set_labels=('A', 'B', 'C'),
                 set_colors=('#63627C', '#A6A4D7', '#485199'), alpha=0.8)
    venn.get_label_by_id('100').set_text('\n'.join(map(str, sorted(A - B - C))))
    venn.get_label_by_id('010').set_text('\n'.join(map(str, sorted(B - A - C))))
    venn.get_label_by_id('001').set_text('\n'.join(map(str, sorted(C - A - B))))
    venn.get_label_by_id('110').set_text('\n'.join(map(str, sorted(A & B - C))))
    venn.get_label_by_id('101').set_text('\n'.join(map(str, sorted(A & C - B))))
    venn.get_label_by_id('011').set_text('\n'.join(map(str, sorted(B & C - A))))
    venn.get_label_by_id('111').set_text('\n'.join(map(str, sorted(A & B & C))))

plt.title("Diagrama de Venn: Unión de conjuntos")
plt.show()