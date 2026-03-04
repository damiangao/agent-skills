---
name: mermaid-render
description: Render Mermaid diagrams as PNG, SVG, or PDF images using the Mermaid CLI (mmdc).
---

# Mermaid Diagram Renderer

Render Mermaid chart syntax into PNG, SVG, or PDF images using the Mermaid CLI (`mmdc`).

## Quick Start

```bash
python3 /path/to/mermaid-render/render.py "mermaid code" output.png
```

## Installation

### Prerequisites

- Node.js and npm
- Python 3.6+
- puppeteer (for headless Chrome rendering)

### Install Mermaid CLI

```bash
npm install -g @mermaid-js/mermaid-cli
```

### Configure Puppeteer (Linux root users only)

```bash
echo '{"args": ["--no-sandbox", "--disable-setuid-sandbox"]}' > ~/.puppeteer.json
```

## Usage

### Basic Usage

```bash
python3 render.py "flowchart TD A[Start] --> B[End]" output.png
```

### Command Line Arguments

| Position | Parameter | Description | Default |
|----------|-----------|-------------|---------|
| 1 | Mermaid code | The Mermaid diagram code (required) | - |
| 2 | Output path | Output file path | `/tmp/mermaid.png` |
| 3 | Format | Output format: png, svg, pdf | `png` |
| 4 | Background | Background color | `white` |
| 5 | Scale | Scale factor (integer) | `2` |

### Examples

#### Flowchart

```bash
python3 render.py "flowchart TD
    A[User] --> B[AI]
    B --> C[Response]" flowchart.png
```

#### Sequence Diagram

```bash
python3 render.py "sequenceDiagram
    Alice->>John: Hello John, how are you?
    John-->>Alice: Great!" sequence.png
```

#### Class Diagram

```bash
python3 render.py "classDiagram
    Animal <|-- Duck
    Animal <|-- Fish
    Animal: +int age
    Animal: +eat()" class.png
```

#### Gantt Chart

```bash
python3 render.py "gantt
    title A Gantt Diagram
    dateFormat YYYY-MM-DD
    section Section
    A task :a1, 2024-01-01, 30d" gantt.png
```

## Programmatic Usage

```python
from render import render_mermaid

# Basic usage
output_path = render_mermaid(
    mermaid_code="flowchart TD A --> B",
    output_path="/tmp/diagram.png",
    output_format="png",
    background="white",
    scale=2
)
print(f"Diagram saved to: {output_path}")
```

## Supported Diagram Types

- Flowchart (`flowchart`, `graph`)
- Sequence Diagram (`sequenceDiagram`)
- Class Diagram (`classDiagram`)
- State Diagram (`stateDiagram`, `stateDiagram-v2`)
- Entity Relationship Diagram (`erDiagram`)
- User Journey (`journey`)
- Gantt Chart (`gantt`)
- Pie Chart (`pie`)
- Requirement Diagram (`requirementDiagram`)
- Git Graph (`gitGraph`)
- C4 Diagram (`C4Context`, `C4Container`, etc.)
- Mindmap (`mindmap`)
- Timeline (`timeline`)
- Quadrant Chart (`quadrantChart`)
- XY Chart (`xychart`)
- Block Diagram (`block`)

## Configuration

### Puppeteer Options

For advanced puppeteer configuration, edit `~/.puppeteer.json`:

```json
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"],
  "headless": true,
  "executablePath": "/usr/bin/chromium-browser"
}
```

### Custom Themes

You can customize the appearance using Mermaid themes:

```
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#ff0000' }}}%%
flowchart TD
    A --> B
```

## Troubleshooting

### mmdc command not found

```bash
# Verify installation
which mmdc

# Reinstall if needed
npm install -g @mermaid-js/mermaid-cli
```

### Puppeteer/Chrome issues

```bash
# Install Chrome dependencies (Ubuntu/Debian)
sudo apt-get install -y chromium-browser

# Or install puppeteer with bundled Chrome
npm install puppeteer
```

### Permission denied on Linux

```bash
# Create puppeteer config for root user
echo '{"args": ["--no-sandbox", "--disable-setuid-sandbox"]}' > ~/.puppeteer.json
```

## Output Files

| Format | MIME Type | Use Case |
|--------|-----------|----------|
| PNG | image/png | Web, presentations, documents |
| SVG | image/svg+xml | Scalable graphics, web |
| PDF | application/pdf | Print, documents |

## Tips

1. **Use newlines in complex diagrams**: Replace actual newlines with `\n` in command line
2. **Quote your code**: Always use quotes around Mermaid code to avoid shell interpretation
3. **Scale for quality**: Use higher scale values (3-4) for better resolution
4. **Transparent background**: Use `transparent` as background color for PNG/SVG

## See Also

- [Mermaid Documentation](https://mermaid.js.org/)
- [Mermaid CLI GitHub](https://github.com/mermaid-js/mermaid-cli)
- [Mermaid Live Editor](https://mermaid.live/)
