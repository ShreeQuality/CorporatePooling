import qrcode
import sys

url = "http://192.168.1.46:8088/app-release.apk"
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
    box_size=10,
    border=4,
)
qr.add_data(url)
qr.make(fit=True)

img = qr.make_image(fill_color="black", back_color="white")
img.save(r"C:\Users\shiva\.gemini\antigravity-ide\brain\52946d74-0968-482c-8d6d-71978aa794ee\download_apk_qr.png")
print("QR Code generated successfully!")
