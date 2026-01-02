import matplotlib.pyplot as plt
import numpy as np

# Paleta y diseño
colors = ['#485199', '#63627C', '#A6A4D7', '#FFFF99', '#A7B7CF', '#EAEEF4']

# Intervalos a mostrar: nombre, notación matemática, romanizado, bordes
intervals = [
    {
        'name': 'Abierto',
        'interval': '(a, b)',
        'roman': 'a < x < b',
        'left_incl': False,
        'right_incl': False,
        'left_finite': True,
        'right_finite': True,
        'color': colors[0]
    },
    {
        'name': 'Abierto por la izquierda',
        'interval': '(a, b]',
        'roman': 'a < x ≤ b',
        'left_incl': False,
        'right_incl': True,
        'left_finite': True,
        'right_finite': True,
        'color': colors[1]
    },
    {
        'name': 'Abierto por la derecha',
        'interval': '[a, b)',
        'roman': 'a ≤ x < b',
        'left_incl': True,
        'right_incl': False,
        'left_finite': True,
        'right_finite': True,
        'color': colors[2]
    },
    {
        'name': 'Cerrado',
        'interval': '[a, b]',
        'roman': 'a ≤ x ≤ b',
        'left_incl': True,
        'right_incl': True,
        'left_finite': True,
        'right_finite': True,
        'color': colors[3]
    },
    {
        'name': 'Infinito por la izquierda y abierto',
        'interval': '(-∞, b)',
        'roman': 'x < b',
        'left_incl': False,
        'right_incl': False,
        'left_finite': False,
        'right_finite': True,
        'color': colors[4]
    },
    {
        'name': 'Infinito por la derecha y abierto',
        'interval': '(a, ∞)',
        'roman': 'x > a',
        'left_incl': False,
        'right_incl': False,
        'left_finite': True,
        'right_finite': False,
        'color': colors[0]
    },
    {
        'name': 'Infinito por la izquierda y cerrado',
        'interval': '(-∞, b]',
        'roman': 'x ≤ b',
        'left_incl': False,
        'right_incl': True,
        'left_finite': False,
        'right_finite': True,
        'color': colors[1]
    },
    {
        'name': 'Infinito por la derecha y cerrado',
        'interval': '[a, ∞)',
        'roman': 'x ≥ a',
        'left_incl': True,
        'right_incl': False,
        'left_finite': True,
        'right_finite': False,
        'color': colors[2]
    }
]

fig, axes = plt.subplots(len(intervals), 1, figsize=(8, 2.5*len(intervals)))

A = 2  # Valor para "a"
B = 6  # Valor para "b"

for i, intrv in enumerate(intervals):
    ax = axes[i] if len(intervals) > 1 else axes
    # Rango de vista
    x = np.linspace(A-2, B+2, 500)
    y = np.zeros_like(x)

    # Relleno del segmento
    lb = A if intrv['left_finite'] else x[0]
    rb = B if intrv['right_finite'] else x[-1]

    # Mostrar la base
    ax.plot(x, y, color='#A6A4D7', linewidth=1, zorder=1)

    # Rellenar el intervalo
    start_idx = np.where(x >= lb)[0][0] if intrv['left_finite'] else 0
    end_idx = np.where(x <= rb)[0][-1] if intrv['right_finite'] else -1
    ax.plot(x[start_idx:end_idx+1], y[start_idx:end_idx+1], color=intrv['color'], linewidth=8, zorder=2)
    
    # Puntos de borde
    if intrv['left_finite']:
        style = 'o' if intrv['left_incl'] else 'o'
        facecolor = intrv['color'] if intrv['left_incl'] else 'white'
        ax.plot(A, 0, marker=style, markerfacecolor=facecolor, markeredgecolor=intrv['color'],
                markersize=15, markeredgewidth=2, zorder=3)
    if intrv['right_finite']:
        style = 'o' if intrv['right_incl'] else 'o'
        facecolor = intrv['color'] if intrv['right_incl'] else 'white'
        ax.plot(B, 0, marker=style, markerfacecolor=facecolor, markeredgecolor=intrv['color'],
                markersize=15, markeredgewidth=2, zorder=3)
    
    # Ejes y etiquetas
    ax.set_ylim(-0.7, 0.7)
    ax.set_yticks([])
    ax.set_xticks([A, B])
    ax.set_xticklabels(["a", "b"])
    ax.set_xlim(A-2, B+2)
    ax.set_title(f"{intrv['name']}:  {intrv['interval']}   |   {intrv['roman']}", fontsize=13)
    ax.spines['left'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['top'].set_visible(False)

plt.tight_layout()
plt.show()
