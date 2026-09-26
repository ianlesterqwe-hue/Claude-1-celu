# Pack de íconos "selva oscura"

Íconos minimalistas (trazo fino verde salvia sobre verde casi negro) pensados para
combinar con un wallpaper oscuro de hojas / selva.

- `ico/`: para accesos directos de Windows
- `png/`: 512×512 (para macOS / Linux o cualquier otro uso)
- `svg/`: fuente vectorial

Para regenerarlos: `pip install cairosvg pillow && python3 generate_icons.py`

## Cambiar el ícono de un acceso directo (Windows)

1. Clic derecho en el acceso directo → **Propiedades** → **Cambiar ícono...**
2. **Examinar...** → elegí el `.ico` de la carpeta `ico/`.

Para una carpeta: clic derecho → **Propiedades** → **Personalizar** → **Cambiar ícono...**

`folder-claude.ico` sirve para la carpeta donde juntes los accesos de Claude / Claude Code.
