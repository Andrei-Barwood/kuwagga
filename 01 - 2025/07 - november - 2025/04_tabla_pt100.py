import sys
import os

def calcular_resistencia_pt(temp, tipo='PT100'):
    # Constantes IEC 60751 para RTD platinum
    R0 = 100 if tipo == "PT100" else 1000
    A = 3.9083e-3
    B = -5.775e-7
    C = -4.183e-12  # Solo para T < 0°C
    t = temp
    if t >= 0:
        return R0 * (1 + A*t + B*t**2)
    else:
        return R0 * (1 + A*t + B*t**2 + C*(t-100)*t**3)

# Solicitar parámetros al usuario
ti = float(input("Temperatura inicial (°C): "))
tf = float(input("Temperatura final (°C): "))
step = float(input("Subdivisión en grados (elija 1, 2, 5, 10, 20): "))
tipo = input("Sensor (PT100/PT1000): ").strip().upper()

# Generar filas para la tabla
rows = []
t_actual = ti
while t_actual <= tf:
    R = calcular_resistencia_pt(t_actual, tipo)
    rows.append((f"{t_actual:.2f}", f"{R:.2f} Ω"))
    t_actual += step

# Plantilla HTML con tus colores y texto tabla #63627C
html = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Tabla estándar {tipo}</title>
<style>
  body {{ background: #EAEEF4; font-family: Arial, sans-serif; }}
  h2 {{ color: #485199; }}
  table {{ border-collapse: collapse; width: 60%; margin:auto; box-shadow: 0 2px 8px #63627C44; }}
  th {{ background: #485199; color: #FFFFB8; border: 2px solid #63627C; padding: 10px; }}
  td {{ background: #A6A4D7; border: 1px solid #A7B7CF; text-align:center; padding: 6px; color: #63627C; }}
  tr:nth-child(even) td {{ background: #EAEEF4; color: #63627C; }}
  tr:hover td {{ background: #A7B7CF; color: #485199; }}
</style>
</head>
<body>
  <h2>Tabla estándar {tipo} &mdash; IEC 60751</h2>
  <p style="text-align:center; color: #63627C;">
    <b>Temperatura</b> de {ti:.2f} °C a {tf:.2f} °C &nbsp;|&nbsp; <b>Paso:</b> {step:.2f} °C
  </p>
  <table>
    <tr>
      <th>Temperatura (°C)</th>
      <th>Resistencia ({'Ω'})</th>
    </tr>
    {"".join([f"<tr><td>{t}</td><td>{R}</td></tr>" for t, R in rows])}
  </table>
</body>
</html>
"""

nombrehtml = "tabla_rtd.html"
with open(nombrehtml, "w", encoding="utf-8") as f:
    f.write(html)

if sys.platform == "darwin":
    os.system(f'open "{nombrehtml}"')         # macOS
elif sys.platform.startswith("win"):
    os.startfile(nombrehtml)                  # Windows
else:
    os.system(f'xdg-open "{nombrehtml}"')     # Linux
