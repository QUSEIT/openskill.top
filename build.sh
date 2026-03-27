#!/bin/bash

# Build script for OpenSkill.Top
# Bilingual site (zh/en) with Material for MkDocs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building OpenSkill.Top documentation..."
echo ""

# Clean previous build
echo "Cleaning previous build..."
rm -rf site

# Build site
echo "Building site..."
mkdocs build

# Create root index.html (redirect to Chinese by default)
echo "Creating root index.html..."
cat > site/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>OpenSkill.Top - OpenClaw 公开课</title>
    <meta http-equiv="refresh" content="5; url=zh/">
    <style>
        body {
            font-family: Roboto, Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: #1a1a1a;
            color: #fff;
        }
        .container {
            text-align: center;
        }
        h1 {
            font-weight: 300;
            margin-bottom: 40px;
            font-size: 2rem;
        }
        .languages {
            display: flex;
            gap: 20px;
            justify-content: center;
        }
        .lang-btn {
            padding: 15px 40px;
            border: 2px solid #ff6d00;
            color: #ff6d00;
            text-decoration: none;
            border-radius: 5px;
            transition: all 0.3s;
            font-size: 18px;
        }
        .lang-btn:hover {
            background: #ff6d00;
            color: #fff;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>OpenSkill.Top - OpenClaw 公开课</h1>
        <div class="languages">
            <a href="zh/" class="lang-btn">中文</a>
            <a href="en/" class="lang-btn">English</a>
        </div>
    </div>
</body>
</html>
EOF

# Copy CNAME file if exists
if [ -f docs/CNAME ]; then
    echo "Copying CNAME file..."
    cp docs/CNAME site/
fi

# Remove "Made with Material for MkDocs" footer from all HTML files
echo "Removing MkDocs Material footer..."
for f in site/*.html site/*/*.html site/*/*/*.html; do
    [ -f "$f" ] && sed -i '' '/Made with/,/<\/a>/d' "$f"
done

echo ""
echo "Build complete!"
echo ""
echo "Output: site/"
echo ""
echo "To preview locally:"
echo "  cd site && python3 -m http.server 8000"
