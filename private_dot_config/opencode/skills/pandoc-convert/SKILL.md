---
name: pandoc-convert
description: Конвертация документов между форматами (md, html, docx, pdf, epub, rst, latex, txt, ipynb, odt) через прямой вызов инструменат pandoc.
license: MIT
compatibility: opencode
metadata:
  depends_on: pandoc
---

## Когда использовать

Используй этот skill когда нужно конвертировать документы между форматами.

## Примеры быстрых команд

```bash
# Базовая конвертация
pandoc input.md -o output.html
pandoc input.md -o output.docx
pandoc input.md -o output.pdf --pdf-engine=xelatex

# Из stdin в stdout
echo "# Title" | pandoc -f markdown -t html

# Из строки (содержимое в аргументе)
pandoc -f markdown -t html <<< "# Title\n\nContent"
```

Если потребуется больше — смотри документацию pandoc.

## Форматы

| Формат      | Флаг            | Примечание                          |
|-------------|-----------------|-------------------------------------|
| markdown    | markdown        |                                     |
| html        | html            |                                     |
| plain text  | plain           |                                     |
| docx        | docx            |                                     |
| pdf         | pdf             | требует `--pdf-engine=xelatex`      |
| epub        | epub            |                                     |
| rst         | rst             |                                     |
| latex       | latex           |                                     |
| ipynb       | ipynb           |                                     |
| odt         | odt             |                                     |

## Примеры сценариев

### 1. Конвертация из строки (без сохранения файла)

Когда нужно просто показать результат конвертации (не создавая файл на диске):

```bash
result=$(pandoc -f markdown -t html <<< "$contents")
echo "$result"
```

**Параметры:**
- `-f`/`-r` — входной формат (по умолчанию определяется автоматически или markdown)
- `-t`/`-w` — выходной формат

### 2. Конвертация строки в файл

```bash
pandoc -f markdown -t docx -o "$output_file" <<< "$contents"
```

### 3. Конвертация файла в файл

```bash
pandoc -f markdown -t pdf --pdf-engine=xelatex -o "$output_file" "$input_file"
```

### 4. DOCX со стилями (reference-doc)

```bash
pandoc -f markdown -t docx --reference-doc="$reference_doc" -o "$output_file" "$input_file"
```

Создать шаблон:
```bash
pandoc -o custom-reference.docx --print-default-data-file reference.docx
```

### 5. Параметры для PDF

```bash
pandoc -f markdown -t pdf \
  --pdf-engine=xelatex \
  -V geometry:margin=1in \
  -o "$output_file" "$input_file"
```

### 6. YAML defaults file

```bash
pandoc --defaults="$defaults_file" -o "$output_file" "$input_file"
```

### 7. Pandoc-фильтры

```bash
pandoc --filter="$filter_path" -f markdown -t docx -o "$output_file" "$input_file"
```

Несколько фильтров:
```bash
pandoc --filter="filter1.py" --filter="filter2.py" -f markdown -t docx -o "$output_file" "$input_file"
```

## Правила валидации (делай сам, MCP их больше не проверяет)

- PDF, DOCX, RST, LaTeX, EPUB требуют `output_file` (путь + имя + расширение)
- `reference-doc` работает только для DOCX
- PDF требует `xelatex` (TeX Live); если `xelatex: not found` → установи: `sudo apt install texlive-xetex`
- Фильтры должны быть исполняемыми Python-скриптами
