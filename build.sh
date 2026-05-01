#!/bin/bash
set -e

DOCS_SRC="/docs"
OUTPUT_DIR="/usr/share/nginx/html"

mkdir -p "$OUTPUT_DIR"

# Use exactly the same Pandoc flags you use by hand.
# -s                produce standalone HTML with head/body
# -f markdown+hard_line_breaks preserve markdown hard line breaks
# --filter mermaid-filter render Mermaid diagrams
PANDOC_OPTS="-s -f markdown+hard_line_breaks --filter mermaid-filter"

# --- Styles copied from your working command ---
RTL_STYLE='<style>
@font-face { font-family: "MixedFont"; src: local("Times New Roman"); unicode-range: U+0000-00FF; }
@font-face { font-family: "MixedFont"; src: local("B Nazanin"); unicode-range: U+0600-06FF, U+FB50-FDFF, U+FE70-FEFF; }
body { text-align: justify; font-family: "MixedFont", serif; font-size: 16px; line-height: 1.8; direction: rtl; }
ol { list-style-type: persian; margin-right: 20px; }
ul { margin-right: 20px; }
h1,h2,h3,h4,h5,h6 { text-align: right; }
.mermaid { direction:ltr;text-align:center; }
</style>'

LTR_STYLE='<style>
body { font-family:"Times New Roman",serif;font-size:16px;line-height:1.8;text-align:justify;direction:ltr; }
.mermaid{text-align:center;}
</style>'

# --- Copy text files (csv, json, yml) ignoring panel/ ---
while read -r txt_file; do
  rel="${txt_file#$DOCS_SRC/}"
  out_dir="$OUTPUT_DIR/$(dirname "$rel")"
  mkdir -p "$out_dir"
  cp "$txt_file" "$OUTPUT_DIR/$rel"
done < <(find "$DOCS_SRC" -type f \( -name "*.csv" -o -name "*.json" -o -name "*.yml" \) -not -path "*/panel/*")

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

DOC_LIST="["
FIRST=true

# --- Convert each Markdown file ignoring panel/ ---
while read -r file; do
  # skip Persian files (both _fa and -fa) during the primary iteration
  [[ "$file" == *_fa.md || "$file" == *-fa.md ]] && continue 
  
  rel="${file#$DOCS_SRC/}"
  out="$OUTPUT_DIR/${rel%.md}.html"
  mkdir -p "$(dirname "$out")"

  has_fa=false
  fa_file=""
  fa_rel=""

  # Check for both naming conventions
  if [ -f "${file%.md}_fa.md" ]; then
    has_fa=true
    fa_file="${file%.md}_fa.md"
  elif [ -f "${file%.md}-fa.md" ]; then
    has_fa=true
    fa_file="${file%.md}-fa.md"
  fi

  if [ "$has_fa" = true ]; then
    fa_rel="${fa_file#$DOCS_SRC/}"
    fa_out="$OUTPUT_DIR/${fa_rel%.md}.html"
    mkdir -p "$(dirname "$fa_out")"
    
    # Build RTL version
    pandoc "$fa_file" -o "$fa_out" $PANDOC_OPTS \
      -V dir=rtl -V header-includes="$RTL_STYLE"
  fi

  # Build English version
  pandoc "$file" -o "$out" $PANDOC_OPTS -V header-includes="$LTR_STYLE"

  # Insert bidirectional language links
  if [ "$has_fa" = true ]; then
    sed -i '/<body>/a <div style="position:fixed;top:10px;right:10px;background:#f0f0f0;padding:5px;border-radius:5px;"><a href="'"${fa_rel%.md}.html"'">فارسی</a></div>' "$out"
    sed -i '/<body>/a <div style="position:fixed;top:10px;left:10px;background:#f0f0f0;padding:5px;border-radius:5px;"><a href="'"${rel%.md}.html"'">English</a></div>' "$fa_out"
  fi

  [ "$FIRST" = true ] || DOC_LIST+=","
  FIRST=false
  DOC_LIST+="{\"name\":\"${rel%.md}\",\"path\":\"${rel%.md}.html\",\"hasFA\":$has_fa,\"faPath\":\"${fa_rel%.md}.html\"}"

done < <(find "$DOCS_SRC" -type f -name "*.md" -not -path "*/panel/*" | sort)

DOC_LIST+="]"
sed -i "s|DOC_LIST_PLACEHOLDER|$DOC_LIST|" "$OUTPUT_DIR/index.html"

echo "✅ Documentation built successfully at $OUTPUT_DIR"

# Start Nginx in the foreground
exec nginx -g "daemon off;"
