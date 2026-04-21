# Rubik GameDev Workshop

> ¿Un cubo Rubik puede enseñarte a hacer videojuegos? Resulta que sí.

Proyecto desarrollado en **Godot 4** para el workshop **"Cualquier videojuego es un Rubik"** presentado en [Compufest](https://compufest.cc) por [Akai-Okami](https://github.com/Akai-Okami).

Un cubo Rubik 4×4 funcional construido desde cero en Godot, usado como vehículo para explicar los 6 conceptos fundamentales del game development.

---

## Conceptos demostrados

| Concepto | Equivalencia en el Rubik | Función en el código |
|---|---|---|
| **Colisionadores** | Caras y aristas | `_is_face_visible()` |
| **Estados** | Configuración del cubo | `is_rotating` + `rotate_layer()` |
| **Nodos** | Piezas individuales | `class Cubie` + `_build_cube()` |
| **Vectores** | Dirección y sentido de giro | `rot_axis` en `_animate()` |
| **Eventos** | Tus dedos girando el cubo | `_input()` |
| **Triggers** | Detectar que una cara está completa | `_finalize()` |

---

## Requisitos

- [Godot 4.x](https://godotengine.org/) — sin dependencias adicionales

---

## Cómo correrlo

```bash
git clone https://github.com/Akai-Okami/rubik-gamedev-workshop.git
```

1. Abre Godot 4
2. Importa la carpeta del proyecto
3. Ejecuta la escena principal (`F5`)

---

## Controles

| Tecla | Acción |
|---|---|
| `1` `2` `3` `4` | Capas en X |
| `Q` `W` `E` `R` | Capas en Y |
| `A` `S` `F` `G` | Capas en Z |
| `Shift` + cualquiera | Sentido contrario |
| `Espacio` | Reiniciar |

---
