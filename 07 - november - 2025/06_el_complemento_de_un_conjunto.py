import matplotlib.pyplot as plt
from matplotlib_venn import venn2
import random

# UNIVERSO: elementos del 1 al 8
universo = set(range(1, 9))

# Generador aleatorio de A
tamano_A = random.randint(2, 6) # Entre 2 y 6 elementos
A = set(random.sample(list(universo), tamano_A))

# Complemento de A
complemento_A = universo - A

# Mensaje de ejercicio y notación
print("Universo U =", universo)
print("Conjunto A =", A)
print("Ejercicio: Encuentra el complemento de A (denotado como A̅ o ~A)")
print(f"A̅ = U - A = {complemento_A}")

# Explicación del complemento
explicacion = (
    f"El complemento de A está formado por todos los elementos que "
    f"NO están en el conjunto A, pero sí en el universo. En este caso, "
    f"son los números {sorted(complemento_A)}, porque no pertenecen a {sorted(A)}."
)
print("\nExplicación:")
print(explicacion)

# Gráfica con Diagrama de Venn
# Para que el universo sea visible, lo mostramos como fondo
plt.figure(figsize=(5,5))
venn = venn2(
    subsets = (len(complemento_A), len(A), 0),
    set_labels = ("A̅ (Complemento)", "A"),
    set_colors=('#A7B7CF', '#485199')
)
# Mostrar los elementos dentro y fuera del conjunto
venn.get_label_by_id('10').set_text('\n'.join(map(str, complemento_A)))
venn.get_label_by_id('01').set_text('\n'.join(map(str, A)))
# As the intersection is 0, there is no label '11' to set text for.
# venn.get_label_by_id('11').set_text('') # Sin intersección

plt.title("Diagrama de Venn: A y su complemento")
plt.show()