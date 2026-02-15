#!/bin/bash

echo "🚀 Starr365 + Veera Food Corner - Online Deployment Setup"
echo "=========================================================="
echo ""

# Check if in deploy-online folder
if [ ! -f "netlify.toml" ]; then
    echo "❌ Error: Run this script from the deploy-online folder"
    echo "Command: cd ~/Desktop/deploy-online && bash setup-deploy.sh"
    exit 1
fi

echo "✅ Folder structure verified"
echo ""

# Git setup
if [ ! -d ".git" ]; then
    echo "📦 Initializing Git repository..."
    git init
    git add .
    git commit -m "Initial deployment - Starr365 + Veera Food Corner"
    echo "✅ Git initialized"
else
    echo "✅ Git repository already exists"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "📋 DEPLOYMENT OPTIONS:"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "1️⃣  NETLIFY (Recommended - 5 minutes)"
echo "   → Go to https://netlify.com"
echo "   → Drag & drop this folder"
echo "   → Get live at: https://yoursite.netlify.app"
echo ""
echo "2️⃣  GITHUB PAGES"
echo "   → Push this repo to GitHub"
echo "   → Enable GitHub Pages"
echo "   → Access at: https://yourusername.github.io/repo-name"
echo ""
echo "3️⃣  WEB HOSTING"
echo "   → Use cPanel/FTP to upload files"
echo "   → Access at: yourdomain.com"
echo ""
echo "📖 Full guide: cat DEPLOYMENT_GUIDE.md"
echo ""
echo "═══════════════════════════════════════════════════════"
echo ""
echo "🔗 Next Steps:"
echo "1. Choose a deployment option above"
echo "2. Follow the instructions in DEPLOYMENT_GUIDE.md"
echo "3. Share the live URL with customers!"
echo ""
