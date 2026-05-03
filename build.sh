#!/bin/bash
set -eo pipefail

export DOCS_SRC="/docs"
export OUTPUT_DIR="/htmls"

# Safety: Strip any accidental trailing slashes so path math never breaks
export DOCS_SRC="${DOCS_SRC%/}"
export OUTPUT_DIR="${OUTPUT_DIR%/}"

mkdir -p "$OUTPUT_DIR"

# =========================================================
# LUA FILTER: Build-Time SVG Generator
# Intercepts Mermaid blocks, runs mermaid-cli headless, 
# and embeds the raw SVG directly into the HTML DOM!
# =========================================================
cat > mermaid-to-svg.lua <<'EOF'
function CodeBlock(block)
  if block.classes[1] == "mermaid" then
    -- Generate completely safe unique temp file names for parallel builds
    local base_tmp = os.tmpname()
    local tmp_in = base_tmp .. ".mmd"
    local tmp_out = base_tmp .. ".svg"

    -- Write mermaid code to temp file
    local f = io.open(tmp_in, "w")
    f:write(block.text)
    f:close()

    -- Run official Mermaid CLI quietly
    local cmd = "mmdc -i " .. tmp_in .. " -o " .. tmp_out .. " -p .puppeteer.json -b transparent > /dev/null 2>&1"
    os.execute(cmd)

    -- Read the generated SVG
    local f_svg = io.open(tmp_out, "r")
    local svg_content = ""
    if f_svg then
        svg_content = f_svg:read("*a")
        f_svg:close()
    else
        svg_content = "<p style='color:red;'>[Mermaid Build-Time Rendering Failed]</p>"
    end

    -- Cleanup temp files
    os.remove(tmp_in)
    os.remove(tmp_out)
    os.remove(base_tmp)

    -- Inject SVG directly into HTML!
    return pandoc.RawBlock("html", '<div class="mermaid-svg">\n' .. svg_content .. '\n</div>')
  end
end
EOF

# Use exactly the same Pandoc flags you use by hand.
# -s                produce standalone HTML with head/body
# -f markdown+hard_line_breaks preserve markdown hard line breaks
# --filter mermaid-filter render Mermaid diagrams
# --verbose forces Pandoc to output errors explicitly
# Pass the custom Lua filter instead of mermaid-filter
export PANDOC_OPTS="-s -f markdown+hard_line_breaks --lua-filter mermaid-to-svg.lua --verbose"

# Note: Client-side JS removed! SVGs are now rendered at build time natively.
# Styling added for Inline Code, Codeblocks, Tables, and Vazirmatn Font
# Using Vazirmatn-Regular.woff2 from CDN for the Persian unicode ranges
export RTL_STYLE='<style>
@font-face {
    font-family: "MixedFont";
    src: local("Times New Roman");
    unicode-range: U+0000-00FF;
}
@font-face {
    font-family: "MixedFont";
    src: url("https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.0.0/fonts/webfonts/Vazirmatn-Regular.woff2") format("woff2");
    unicode-range: U+0600-06FF, U+FB50-FDFF, U+FE70-FEFF;
}
body { text-align: justify; font-family: "MixedFont", serif; font-size: 16px; line-height: 1.8; direction: rtl; }
ol { list-style-type: persian; margin-right: 20px; }
ul { margin-right: 20px; }
h1, h2, h3, h4, h5, h6 { text-align: right; }

/* SVG Direct-Embed Formatting */
.mermaid-svg { direction: ltr; text-align: center; overflow-x: auto; margin: 20px 0; }
.mermaid-svg svg { max-width: 100%; height: auto; display: block; margin: 0 auto; } /* Prevents high-res diagrams from overflowing */

/* Table formatting */
table { border-collapse: collapse; width: 100%; display: block; overflow-x: auto; margin: 20px 0; }
table th, table td { border: 1px solid #d0d7de; padding: 10px 14px; }
table th { background-color: #f6f8fa; font-weight: bold; }
table tr:nth-child(even) { background-color: #fbfbfb; }

/* Inline code formatting */
code { background-color: #f4f4f4; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 0.95em; color: #d14; direction: ltr; display: inline-block; }
/* Codeblock formatting */
pre { background-color: #f6f8fa; border: 1px solid #d0d7de; padding: 16px; border-radius: 8px; overflow-x: auto; direction: ltr; white-space: pre; word-wrap: normal; }
/* Reset inline code styling inside codeblocks */
pre code { background-color: transparent; padding: 0; color: inherit; display: inline; border-radius: 0; }
</style>'

export LTR_STYLE='<style>
body { font-family: "Times New Roman", serif; font-size: 16px; line-height: 1.8; text-align: justify; direction: ltr; }
h1, h2, h3, h4, h5, h6 { text-align: left; }

/* SVG Direct-Embed Formatting */
.mermaid-svg { text-align: center; overflow-x: auto; margin: 20px 0; }
.mermaid-svg svg { max-width: 100%; height: auto; display: block; margin: 0 auto; }

/* Table formatting */
table { border-collapse: collapse; width: 100%; display: block; overflow-x: auto; margin: 20px 0; }
table th, table td { border: 1px solid #d0d7de; padding: 10px 14px; }
table th { background-color: #f6f8fa; font-weight: bold; }
table tr:nth-child(even) { background-color: #fbfbfb; }

/* Inline code formatting */
code { background-color: #f4f4f4; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 0.95em; color: #d14; }
/* Codeblock formatting */
pre { background-color: #f6f8fa; border: 1px solid #d0d7de; padding: 16px; border-radius: 8px; overflow-x: auto; white-space: pre; word-wrap: normal; }
/* Reset inline code styling inside codeblocks */
pre code { background-color: transparent; padding: 0; color: inherit; border-radius: 0; }
</style>'

# Create a Puppeteer config to allow Chrome to run as root in Docker
cat > .puppeteer.json <<'EOF'
{
  "args":["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF

# Set up automatic cleanup of temporary configurations to safely run even on failures
FILE_LIST=$(mktemp)
trap 'rm -f .puppeteer.json mermaid-to-svg.lua "$FILE_LIST"' EXIT

# =========================================================
# AWK PREPROCESSOR: Fix missing empty lines before lists & tables
# Includes rigorous array-based table look-ahead + Persian translation
# =========================================================
export PREPROCESS_AWK='
BEGIN { in_yaml = 0; in_code = 0; prev_was_list = 0; prev_was_table = 0 }
{ lines[NR] = $0 }
END {
    for (i = 1; i <= NR; i++) {
        # Toggle YAML frontmatter state
        if (i == 1 && lines[i] ~ /^---[ \t]*$/) { in_yaml = 1 }
        else if (in_yaml && lines[i] ~ /^---[ \t]*$/) { in_yaml = 0 }
        
        # Toggle Code Block state
        if (lines[i] ~ /^[ \t]*```/ || lines[i] ~ /^[ \t]*~~~/) { in_code = !in_code }
        
        is_list = 0
        is_table = 0
        
        # Only evaluate for lists and tables if outside of YAML and Code blocks
        if (!in_code && !in_yaml) {
            # List detection (English & Persian numerals)
            if (match(lines[i], /^[ \t]*([-*+]|[0-9]+[.)]|[۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩]+[.)])[ \t]+/)) {
                is_list = 1
            }
            
            # Rigorous Table detection
            # A valid markdown table separator line explicitly made of spaces, hyphens, pipes, and colons
            is_next_sep = (i < NR && lines[i+1] ~ /^[ \t|:-]+$/ && lines[i+1] ~ /\|/ && lines[i+1] ~ /-/)
            curr_is_sep = (lines[i] ~ /^[ \t|:-]+$/ && lines[i] ~ /\|/ && lines[i] ~ /-/)
            
            if (lines[i] ~ /\|/ && is_next_sep) {
                is_table = 1
            } else if (prev_was_table && (curr_is_sep || lines[i] ~ /\|/)) {
                is_table = 1
            }
        }
        
        is_prev_empty = (i == 1 || lines[i-1] ~ /^[ \t]*$/)
        is_prev_header = (i > 1 && lines[i-1] ~ /^[ \t]*#+/)
        
        # Insert empty line if: current is list/table + prev was normal text
        if (is_list && !is_prev_empty && !is_prev_header && !prev_was_list) {
            print ""
        }
        if (is_table && !is_prev_empty && !is_prev_header && !prev_was_table) {
            print ""
        }
        
        # In order for Pandoc to natively recognize Persian-enumerated lists, 
        # we convert the marker (and ONLY the marker) to Western Arabic [0-9].
        if (is_list) {
            if (match(lines[i], /^[ \t]*[۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩]+[.)][ \t]+/)) {
                marker = substr(lines[i], RSTART, RLENGTH)
                gsub(/۰/, "0", marker); gsub(/۱/, "1", marker); gsub(/۲/, "2", marker)
                gsub(/۳/, "3", marker); gsub(/۴/, "4", marker); gsub(/۵/, "5", marker)
                gsub(/۶/, "6", marker); gsub(/۷/, "7", marker); gsub(/۸/, "8", marker)
                gsub(/۹/, "9", marker)
                
                gsub(/٠/, "0", marker); gsub(/١/, "1", marker); gsub(/٢/, "2", marker)
                gsub(/٣/, "3", marker); gsub(/٤/, "4", marker); gsub(/٥/, "5", marker)
                gsub(/٦/, "6", marker); gsub(/٧/, "7", marker); gsub(/٨/, "8", marker)
                gsub(/٩/, "9", marker)
                
                lines[i] = marker substr(lines[i], RSTART + RLENGTH)
            }
        }
        
        print lines[i]
        
        # Reset continuity state if an empty line is encountered
        if (lines[i] ~ /^[ \t]*$/) {
            prev_was_list = 0
            prev_was_table = 0
        } else {
            prev_was_list = is_list
            prev_was_table = is_table
        }
    }
}
'

# --- Copy text files (.csv, .json, .yml) safely ---
while read -r txt_file; do
  rel="${txt_file#$DOCS_SRC/}"
  out_dir="$OUTPUT_DIR/$(dirname "$rel")"
  mkdir -p "$out_dir"
  cp "$txt_file" "$OUTPUT_DIR/$rel"
done < <(find "$DOCS_SRC" -type f \( -name "*.csv" -o -name "*.json" -o -name "*.yml" \) -print)

# --- Build index.html skeleton ---
cat >"$OUTPUT_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Documentation</title>
<style>
body{font-family:Arial,sans-serif;max-width:800px;margin:50px auto;padding:20px;}
h1{border-bottom:2px solid #333;padding-bottom:10px;}
ul{list-style:none;padding:0;}
li{margin:10px 0;}
a{color:#0066cc;text-decoration:none;font-size:18px;}
a:hover{text-decoration:underline;}
.lang-badge{background:#eee;padding:2px 8px;border-radius:3px;font-size:12px;margin-left:10px;}
</style>
</head>
<body>
<h1>Documentation</h1>
<ul id="doc-list"></ul>
<script>
const docs=DOC_LIST_PLACEHOLDER;
const ul=document.getElementById('doc-list');
docs.forEach(d=>{
 const li=document.createElement('li');
 li.innerHTML='<a href="'+d.path+'">'+d.name+'</a>'+
 (d.hasFA?' <span class="lang-badge"><a href="'+d.faPath+'" style="font-size:12px;">فارسی</a></span>':'');
 ul.appendChild(li);
});
</script>
</body>
</html>
EOF

# =========================================================
# DEFINE THE PARALLEL BUILD FUNCTION
# =========================================================
build_markdown() {
  # Added -x to print each executed command and its arguments to stderr
  # Added -o pipefail so errors inside pipes don't get swallowed
  set -exo pipefail
  
  # Argument $1 is now the "base_path" (e.g., /docs/proposal/logserver)
  base_path="$1"
  rel_base="${base_path#$DOCS_SRC/}"
  
  en_file="${base_path}.md"
  en_out="$OUTPUT_DIR/${rel_base}.html"

  has_en=false
  [[ -f "$en_file" ]] && has_en=true

  has_fa=false
  fa_file=""
  fa_out=""
  
  if [[ -f "${base_path}_fa.md" ]]; then
    has_fa=true
    fa_file="${base_path}_fa.md"
    fa_out="$OUTPUT_DIR/${rel_base}_fa.html"
  elif [[ -f "${base_path}-fa.md" ]]; then
    has_fa=true
    fa_file="${base_path}-fa.md"
    fa_out="$OUTPUT_DIR/${rel_base}-fa.html"
  fi

  # 1. Build Persian version (if exists)
  if [[ "$has_fa" == true ]]; then
    mkdir -p "$(dirname "$fa_out")"
    
    # Preprocess Persian Markdown (inject missing empty lines & parse numeric lists)
    temp_fa=$(mktemp)
    awk "$PREPROCESS_AWK" "$fa_file" > "$temp_fa"

    # Build RTL version from temporary preprocessed file
    pandoc "$temp_fa" -o "$fa_out" $PANDOC_OPTS \
      -V dir=rtl -V header-includes="$RTL_STYLE"

    rm -f "$temp_fa"

    # Convert .md links to .html in the generated RTL HTML
    sed -i -E 's/href="([^"#]+)\.md(#.*)?"/href="\1.html\2"/g' "$fa_out"
  fi

  # 2. Build English version (if exists)
  if [[ "$has_en" == true ]]; then
    mkdir -p "$(dirname "$en_out")"
    
    temp_en=$(mktemp)
    awk "$PREPROCESS_AWK" "$en_file" > "$temp_en"

  # Build English version from temporary preprocessed file
    pandoc "$temp_en" -o "$en_out" $PANDOC_OPTS -V header-includes="$LTR_STYLE"
    rm -f "$temp_en"
  # Convert .md links to .html in the generated LTR HTML
    sed -i -E 's/href="([^"#]+)\.md(#.*)?"/href="\1.html\2"/g' "$en_out"
  fi

  # 3. Insert bidirectional language links ONLY if both exist
  if [[ "$has_fa" == true && "$has_en" == true ]]; then
    fa_basename=$(basename "$fa_out")
    en_basename=$(basename "$en_out")

    # Appending the language toggle div right after body tag using the extracted basenames
    sed -i '/<body>/a <div style="position:fixed;top:10px;right:10px;background:#f0f0f0;padding:5px;border-radius:5px;z-index:9999;"><a href="'"$fa_basename"'">فارسی</a></div>' "$en_out"
    sed -i '/<body>/a <div style="position:fixed;top:10px;left:10px;background:#f0f0f0;padding:5px;border-radius:5px;z-index:9999;"><a href="'"$en_basename"'">English</a></div>' "$fa_out"
  fi
  
  echo "✔ Built base: $rel_base"
}
export -f build_markdown

# =========================================================
# GATHER FILES AND BUILD THE INDEX LIST
# =========================================================

# Extract a unique list of "Base Paths" (ignoring -fa, _fa, and .md extensions)
while read -r file; do
  base="${file%.md}"
  base="${base%_fa}"
  base="${base%-fa}"
  echo "$base"
done < <(find "$DOCS_SRC" -type f -name "*.md" -print) | sort -u > "$FILE_LIST"

# Iterate over base paths to generate the JSON index list
DOC_LIST="["
FIRST=true

while read -r base_path; do
  rel_base="${base_path#$DOCS_SRC/}"
  
  has_en=false
  [[ -f "${base_path}.md" ]] && has_en=true
  
  has_fa=false
  fa_rel=""
  
  if [[ -f "${base_path}_fa.md" ]]; then
    has_fa=true
    fa_rel="${rel_base}_fa.html"
  elif [[ -f "${base_path}-fa.md" ]]; then
    has_fa=true
    fa_rel="${rel_base}-fa.html"
  fi
  
  [ "$FIRST" = true ] || DOC_LIST+=","
  FIRST=false
  
  if [[ "$has_en" == true ]]; then
    # Standard Doc (English, with optional FA twin)
    DOC_LIST+="{\"name\":\"$rel_base\",\"path\":\"${rel_base}.html\",\"hasFA\":$has_fa,\"faPath\":\"$fa_rel\"}"
  elif [[ "$has_fa" == true ]]; then
    # Standalone Persian Doc
    DOC_LIST+="{\"name\":\"$rel_base (FA Only)\",\"path\":\"$fa_rel\",\"hasFA\":false,\"faPath\":\"\"}"
  fi
done < "$FILE_LIST"

DOC_LIST+="]"
sed -i "s|DOC_LIST_PLACEHOLDER|$DOC_LIST|" "$OUTPUT_DIR/index.html"

# =========================================================
# RUN THE PARALLEL BUILD
# =========================================================
echo "Starting multi-core Pandoc build..."

# Read the file list and pass it to xargs. 
# -P $(nproc) runs one process per CPU core.
# Using -t on xargs to print the command before executing
cat "$FILE_LIST" | xargs -t -I {} -P $(nproc) bash -c 'build_markdown "{}"'

echo "✅ Documentation built successfully at $OUTPUT_DIR"
