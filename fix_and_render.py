import subprocess, os

svg_path = 'C:/Users/shiva/CorporatePoolingApp/assets/images/sudarshan_chakra.svg'
with open(svg_path, 'r', encoding='utf-8') as f:
    c = f.read()

c = c.replace('filte/>', 'filter="url(#softGlow)"/>')
with open(svg_path, 'w', encoding='utf-8') as f:
    f.write(c)

chrome_path = 'C:/Program Files/Google/Chrome/Application/chrome.exe'
edge_path = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
browser = chrome_path if os.path.exists(chrome_path) else edge_path

out1 = os.path.abspath('C:/Users/shiva/CorporatePoolingApp/assets/images/sudarshan_chakra_frontal_preview.png')
out2 = os.path.abspath('C:/Users/shiva/CorporatePoolingApp/assets/images/sudarshan_chakra_hover_preview.png')

subprocess.run([browser, '--headless', '--disable-gpu', '--screenshot=' + out1, '--window-size=500,500', '--hide-scrollbars', 'file:///' + os.path.abspath('chakra_frontal.html').replace('\\', '/')])
subprocess.run([browser, '--headless', '--disable-gpu', '--screenshot=' + out2, '--window-size=500,500', '--hide-scrollbars', 'file:///' + os.path.abspath('chakra_hover.html').replace('\\', '/')])

print('Successfully re-rendered frontal and hover previews!')
