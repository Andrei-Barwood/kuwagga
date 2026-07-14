# Tabla PT100 / PT1000 — IEC 60751

Aplicación web **estática** (PWA) para generar tablas de resistencia de sensores **PT100** y **PT1000** según la norma **IEC 60751**.

Funciona **online y offline** en el navegador. No requiere backend ni instalación de Python.

Portado del script `04_tabla_pt100.py`.

## Author / Autor

| Script | Name |
|--------|------|
| Romanized (Latin) | **Kirtan Teg Singh** |
| Gurmukhi (ਗੁਰਮੁਖੀ) | **ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ** |

---

## Características

- Cálculo IEC 60751 (rango positivo y negativo de temperatura)
- Sensores **PT100** y **PT1000**
- Paso configurable: 1, 2, 5, 10 o 20 °C
- Exportar tabla a HTML (mismo estilo que el script original)
- Imprimir desde el navegador
- **Uso offline** mediante Service Worker (caché local)
- Instalable como PWA en escritorio y móvil

---

## Uso rápido

### Opción A — Abrir en local (servidor estático)

Los Service Workers requieren servir la app por `http://` o `https://` (no siempre funcionan con `file://`).

```bash
# Clonar
git clone https://github.com/TU_USUARIO/pt100-tabla-app.git
cd pt100-tabla-app

# Python 3
python3 -m http.server 8080

# o Node.js
npx --yes serve -l 8080
```

Abre en el navegador: [http://localhost:8080](http://localhost:8080)

### Opción B — GitHub Pages (online + instalable offline)

1. Sube este repositorio a GitHub.
2. En **Settings → Pages**, publica la rama `main` desde la raíz `/` (o carpeta `/docs` si la usas).
3. Visita la URL de Pages una vez **online** para cachear la app.
4. Después podrás abrirla **sin conexión** (y/o instalarla como app).

### Opción C — Abrir el HTML directamente

Puedes abrir `index.html` con doble clic. El cálculo funciona sin red.  
La instalación offline completa (Service Worker) puede no registrarse en modo `file://` según el navegador.

---

## Cómo generar una tabla

1. Indica **temperatura inicial** y **final** (°C).
2. Elige el **paso** (subdivisión).
3. Elige el sensor (**PT100** o **PT1000**).
4. Pulsa **Generar tabla**.
5. Opcional: **Exportar HTML** o **Imprimir**.

---

## Fórmula (IEC 60751)

Constantes del platino:

| Constante | Valor        |
|-----------|--------------|
| \(A\)     | \(3{,}9083 \times 10^{-3}\) |
| \(B\)     | \(-5{,}775 \times 10^{-7}\) |
| \(C\)     | \(-4{,}183 \times 10^{-12}\) (solo si \(t < 0\) °C) |

- **PT100:** \(R_0 = 100~\Omega\)
- **PT1000:** \(R_0 = 1000~\Omega\)

Para \(t \ge 0\):

\[
R(t) = R_0 \left(1 + A t + B t^2\right)
\]

Para \(t < 0\):

\[
R(t) = R_0 \left(1 + A t + B t^2 + C (t - 100) t^3\right)
\]

---

## Estructura del repositorio

```
pt100-tabla-app/
├── index.html          # Interfaz principal
├── css/
│   └── styles.css      # Estilos (paleta del script original)
├── js/
│   └── app.js          # Cálculo y UI
├── sw.js               # Service Worker (offline)
├── manifest.json       # Manifiesto PWA
├── icons/
│   ├── icon.svg
│   ├── icon-192.png
│   └── icon-512.png
├── LICENSE
└── README.md
```

---

## Offline / PWA

1. Abre la app al menos una vez **con conexión** (localhost o GitHub Pages).
2. El Service Worker cachea los archivos estáticos.
3. Al desconectarte, la app sigue disponible; el badge **Offline** lo indica.
4. En Chrome/Edge/Safari puedes **Instalar** la app desde el menú del navegador.

Para forzar actualización de caché tras un cambio de código, incrementa `CACHE_NAME` en `sw.js` (por ejemplo `pt100-tabla-v2`).

---

## Desarrollo

No hay dependencias de build. Edita HTML/CSS/JS y recarga.

Comprobación rápida del cálculo en la consola del navegador:

```js
calcularResistenciaPt(0, "PT100");    // → 100
calcularResistenciaPt(100, "PT100");  // → ~138.51
calcularResistenciaPt(0, "PT1000");   // → 1000
```

---

## Licencia

MIT — Copyright (c) 2025 **Kirtan Teg Singh** (ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ). Ver [LICENSE](LICENSE).
