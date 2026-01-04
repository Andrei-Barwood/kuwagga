#!/usr/bin/env python3
"""
Script educativo para visualizar disyunción, diferencia y diferencia simétrica
Requiere: matplotlib, matplotlib-venn
"""

import sys
import random

try:
    import matplotlib.pyplot as plt
    from matplotlib_venn import venn2
except ImportError as e:
    print(f"Error: Falta la dependencia requerida: {e}", file=sys.stderr)
    print("Instala con: pip install matplotlib matplotlib-venn", file=sys.stderr)
    sys.exit(1)

# UNIVERSO: elementos del 1 al 10
universo = set(range(1, 11))

ejercicios = [
    ('disjuntos', 'Conjuntos disjuntos'),
    ('diferencia', 'Diferencia'),
    ('diferencia_simetrica', 'Diferencia simétrica')
]

for opcion, operacion in ejercicios:
    # Generar conjuntos aleatorios diferentes para cada ejercicio
    tamano_A = random.randint(2, 7)
    tamano_B = random.randint(2, 7)
    A = set(random.sample(sorted(universo), tamano_A))
    B = set(random.sample(sorted(universo), tamano_B))
    
    # Determinar operación y explicación
    if opcion == 'diferencia_simetrica':
        simbolo = 'A △ B'
        resultado = (A - B) | (B - A)
        explicacion = (
            f"La diferencia simétrica {simbolo} incluye los elementos que están "
            f"en A o en B, pero no en ambos. "
            f"{simbolo} = {sorted(resultado)}"
        )
        titulo = "A △ B: Diferencia Simétrica"
    elif opcion == 'disjuntos':
        simbolo = 'A ∩ B'
        resultado = A & B
        if len(resultado) == 0:
            explicacion = (
                f"Los conjuntos son disjuntos si no tienen elementos en común. "
                f"En este caso, A ∩ B = {set()} (conjunto vacío), por lo tanto, son disjuntos."
            )
        else:
            explicacion = (
                f"Los conjuntos NO son disjuntos porque comparten estos elementos: {sorted(resultado)}"
            )
        titulo = "¿Son disjuntos? (Intersección)"
    elif opcion == 'diferencia':
        simbolo = 'A - B'
        resultado = A - B
        explicacion = (
            f"La diferencia {simbolo} está formada por los elementos de A que no están en B. "
            f"{simbolo} = {sorted(resultado)}"
        )
        titulo = "A - B: Elementos solo en A"
    
    # Imprimir
    print("="*55)
    print("Universo U =", universo)
    print(f"Conjunto A = {A}")
    print(f"Conjunto B = {B}")
    print(f"\nEjercicio: {operacion}")
    print(f"Operación: {simbolo}")
    print("Resultado:", sorted(resultado) if not (opcion=='disjuntos' and len(resultado)==0) else set())
    print("\nExplicación:")
    print(explicacion)
    
    # Diagrama de Venn
    plt.figure(figsize=(6,6))
    venn = venn2(subsets = (A, B), set_labels = ('A', 'B'), set_colors=('#63627C', '#A6A4D7'), alpha=0.8)
    label_10 = venn.get_label_by_id('10')
    if label_10 is not None:
        label_10.set_text('\n'.join(map(str, sorted(A - B))))
    label_01 = venn.get_label_by_id('01')
    if label_01 is not None:
        label_01.set_text('\n'.join(map(str, sorted(B - A))))
    label_11 = venn.get_label_by_id('11')
    if label_11 is not None:
        label_11.set_text('\n'.join(map(str, sorted(A & B))))
    plt.title(titulo)
    plt.show()
