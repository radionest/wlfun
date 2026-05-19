#!/bin/bash
set -e

cd "$(dirname "$0")"

# Собираем Gleam
gleam build --target javascript

# Создаём entry point который вызывает main()
cat > entry.mjs << 'EOF'
import { main } from "./build/dev/javascript/wl_calculators/wl_calculators.mjs";
main();
EOF

# Бандлим JS как IIFE (самовызывающийся)
npx esbuild entry.mjs --bundle --minify --format=iife --outfile=bundle.min.js

# Читаем JS
JS_CONTENT=$(cat bundle.min.js)

# Читаем CSS
CSS_CONTENT=$(cat styles.css)

# Создаём директорию dist если нет
mkdir -p dist

# Копируем Web Workers если существуют
if [ -f probability_worker.js ]; then
  cp probability_worker.js dist/
  echo "✓ Скопирован probability_worker.js"
fi

if [ -f boosting_simulation_worker.js ]; then
  cp boosting_simulation_worker.js dist/
  echo "✓ Скопирован boosting_simulation_worker.js"
fi

# Создаём единый HTML
cat > dist/index.html << HTMLEOF
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Калькуляторы War Legends</title>
   <!-- Yandex.Metrika counter -->
<script type="text/javascript">
    (function(m,e,t,r,i,k,a){
        m[i]=m[i]||function(){(m[i].a=m[i].a||[]).push(arguments)};
        m[i].l=1*new Date();
        for (var j = 0; j < document.scripts.length; j++) {if (document.scripts[j].src === r) { return; }}
        k=e.createElement(t),a=e.getElementsByTagName(t)[0],k.async=1,k.src=r,a.parentNode.insertBefore(k,a)
    })(window, document,'script','https://mc.yandex.ru/metrika/tag.js?id=106066101', 'ym');

    ym(106066101, 'init', {ssr:true, webvisor:true, clickmap:true, accurateTrackBounce:true, trackLinks:true});
</script>
<noscript><div><img src="https://mc.yandex.ru/watch/106066101" style="position:absolute; left:-9999px;" alt="" /></div></noscript>
<!-- /Yandex.Metrika counter -->
  <style>
${CSS_CONTENT}
  </style>
</head>
<body>
  <div id="app"></div>
  <script>
${JS_CONTENT}
  </script>
</body>
</html>
HTMLEOF

# Очистка
rm -f entry.mjs bundle.min.js

echo "✓ Создан dist/index.html ($(du -h dist/index.html | cut -f1))"
