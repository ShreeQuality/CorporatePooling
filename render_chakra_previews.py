import subprocess, os

# 1. Frontal (0 deg tilt) HTML
html_frontal = """<!DOCTYPE html>
<html>
<head>
<style>
  body { margin: 0; background: #070B19; display: flex; align-items: center; justify-content: center; height: 100vh; overflow: hidden; }
  .canvas { width: 440px; height: 440px; display: flex; align-items: center; justify-content: center; position: relative; }
  .glow { position: absolute; width: 340px; height: 340px; border-radius: 50%; background: radial-gradient(circle, rgba(255,180,0,0.45) 0%, rgba(255,80,0,0.18) 55%, transparent 75%); filter: blur(24px); }
  .chakra { width: 340px; height: 340px; filter: drop-shadow(0 0 22px rgba(255, 140, 0, 0.75)); }
</style>
</head>
<body>
<div class="canvas">
  <div class="glow"></div>
  <img class="chakra" src="C:/Users/shiva/CorporatePoolingApp/assets/images/sudarshan_chakra.svg" />
</div>
</body>
</html>"""

# 2. Subtle 3D Hover (18 deg tilt) HTML
html_hover = """<!DOCTYPE html>
<html>
<head>
<style>
  body { margin: 0; background: #070B19; display: flex; align-items: center; justify-content: center; height: 100vh; overflow: hidden; }
  .canvas { width: 440px; height: 440px; display: flex; align-items: center; justify-content: center; position: relative; perspective: 800px; }
  .glow { position: absolute; width: 340px; height: 340px; border-radius: 50%; background: radial-gradient(circle, rgba(255,180,0,0.45) 0%, rgba(255,80,0,0.18) 55%, transparent 75%); filter: blur(24px); }
  .chakra-container { transform: scale(1.15) rotateX(22deg) rotateZ(-8deg); }
  .chakra { width: 320px; height: 320px; filter: drop-shadow(0 0 22px rgba(255, 140, 0, 0.75)); }
</style>
</head>
<body>
<div class="canvas">
  <div class="glow"></div>
  <div class="chakra-container">
    <img class="chakra" src="C:/Users/shiva/CorporatePoolingApp/assets/images/sudarshan_chakra.svg" />
  </div>
</div>
</body>
</html>"""

with open('chakra_frontal.html', 'w', encoding='utf-8') as f:
    f.write(html_frontal)

with open('chakra_hover.html', 'w', encoding='utf-8') as f:
    f.write(html_hover)

chrome_path = 'C:/Program Files/Google/Chrome/Application/chrome.exe'
edge_path = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
browser = chrome_path if os.path.exists(chrome_path) else edge_path

out1 = os.path.abspath('C:/Users/shiva/CorporatePoolingApp/assets/images/sudarshan_chakra_frontal_preview.png')
out2 = os.path.abspath('C:/Users/shiva/CorporatePoolingApp/assets/images/sudarshan_chakra_hover_preview.png')

subprocess.run([browser, '--headless', '--disable-gpu', '--screenshot=' + out1, '--window-size=500,500', '--hide-scrollbars', 'file:///' + os.path.abspath('chakra_frontal.html').replace('\\', '/')])
subprocess.run([browser, '--headless', '--disable-gpu', '--screenshot=' + out2, '--window-size=500,500', '--hide-scrollbars', 'file:///' + os.path.abspath('chakra_hover.html').replace('\\', '/')])

print('Rendered both previews!')
