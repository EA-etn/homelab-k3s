# Diagrams as code

Same kit as [devsecops-pipeline](https://github.com/EA-etn/devsecops-pipeline/tree/main/docs/diagrams/src): HTML + [Lucide](https://lucide.dev) icons, rendered in Spanish and English (`i18n.js`) to PNG and animated SVG.

- `01-architecture`: cluster architecture (README).
- `00-social`: repository social preview (1280×640): GitHub → Settings → Social preview.

```bash
cd docs/diagrams/src
npm install
npx playwright install chromium   # first time only
pip install fonttools brotli
npm run render
```
