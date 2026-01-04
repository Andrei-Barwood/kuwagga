#!/usr/bin/env python3
"""
Script para visualizar funciones trigonométricas y sus recíprocas
Requiere: numpy, matplotlib
"""

import sys
import numpy as np
import matplotlib.pyplot as plt

# Verificar dependencias
try:
    import numpy as np
    import matplotlib.pyplot as plt
except ImportError as e:
    print(f"Error: Faltan dependencias: {e}", file=sys.stderr)
    print("Instálalas con: pip install numpy matplotlib", file=sys.stderr)
    sys.exit(1)

# Crear el array de ángulos de 10 a 360 grados con incrementos de 10
grados = np.arange(10, 370, 10)

# Convertir grados a radianes (las funciones trigonométricas trabajan con radianes)
radianes = np.radians(grados)

# Calcular las funciones trigonométricas
seno = np.sin(radianes)
coseno = np.cos(radianes)
tangente = np.tan(radianes)

# Calcular funciones trigonométricas recíprocas
cosecante = 1 / seno
secante = 1 / coseno
cotangente = 1 / tangente

# Configurar el tamaño de la figura
plt.figure(figsize=(15, 10))

# Crear subgráficos para cada función (3 filas, 2 columnas)
# Gráfico 1: Seno
plt.subplot(3, 2, 1)
plt.plot(grados, seno, 'r-', linewidth=2, label='sen(x)')
plt.title('Función Seno', fontsize=12, fontweight='bold')
plt.xlabel('Grados')
plt.ylabel('sen(x)')
plt.grid(True, alpha=0.3)
plt.ylim(-1.5, 1.5)
plt.legend()

# Gráfico 2: Cosecante
plt.subplot(3, 2, 2)
plt.plot(grados, cosecante, 'b-', linewidth=2, label='csc(x)')
plt.title('Función Cosecante', fontsize=12, fontweight='bold')
plt.xlabel('Grados')
plt.ylabel('csc(x)')
plt.grid(True, alpha=0.3)
plt.ylim(-5, 5)
plt.legend()

# Gráfico 3: Coseno
plt.subplot(3, 2, 3)
plt.plot(grados, coseno, 'g-', linewidth=2, label='cos(x)')
plt.title('Función Coseno', fontsize=12, fontweight='bold')
plt.xlabel('Grados')
plt.ylabel('cos(x)')
plt.grid(True, alpha=0.3)
plt.ylim(-1.5, 1.5)
plt.legend()

# Gráfico 4: Secante
plt.subplot(3, 2, 4)
plt.plot(grados, secante, 'm-', linewidth=2, label='sec(x)')
plt.title('Función Secante', fontsize=12, fontweight='bold')
plt.xlabel('Grados')
plt.ylabel('sec(x)')
plt.grid(True, alpha=0.3)
plt.ylim(-5, 5)
plt.legend()

# Gráfico 5: Tangente
plt.subplot(3, 2, 5)
plt.plot(grados, tangente, 'c-', linewidth=2, label='tan(x)')
plt.title('Función Tangente', fontsize=12, fontweight='bold')
plt.xlabel('Grados')
plt.ylabel('tan(x)')
plt.grid(True, alpha=0.3)
plt.ylim(-5, 5)
plt.legend()

# Gráfico 6: Cotangente
plt.subplot(3, 2, 6)
plt.plot(grados, cotangente, 'orange', linewidth=2, label='cot(x)')
plt.title('Función Cotangente', fontsize=12, fontweight='bold')
plt.xlabel('Grados')
plt.ylabel('cot(x)')
plt.grid(True, alpha=0.3)
plt.ylim(-5, 5)
plt.legend()

# Ajustar el espaciado entre subgráficos
plt.tight_layout()

# Mostrar los gráficos
plt.show()

# Opcional: Imprimir tabla con valores
print("\n=== TABLA DE VALORES ===\n")
print(f"{'Grados':<8} {'Seno':<10} {'Coseno':<10} {'Tangente':<12} {'Cosec':<10} {'Secante':<10} {'Cotang':<10}")
print("-" * 80)
for i in range(len(grados)):
    print(f"{grados[i]:<8.0f} {seno[i]:<10.4f} {coseno[i]:<10.4f} {tangente[i]:<12.4f} {cosecante[i]:<10.4f} {secante[i]:<10.4f} {cotangente[i]:<10.4f}")

