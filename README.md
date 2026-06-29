# SkaniPay

Scan. Pay. Done.

SkaniPay is a Flutter-based mobile application designed to simplify mobile payments (like M-Pesa) by scanning Till numbers, Paybill numbers, Agent numbers, and Phone numbers directly from printed materials or screens.

## Features

- **Withdraw Cash**: Scan Agent & Store numbers.
- **Buy Goods & Services**: Scan Till numbers.
- **Pay Bill**: Scan Paybill & Account numbers.
- **Pochi la Biashara**: Scan Pochi numbers.
- **Gallery Support**: Select images from your gallery for scanning.
- **USSD Fallback**: If the M-Pesa app is not installed, the app provides a convenient USSD shortcut.

## Getting Started

### Prerequisites

- Flutter SDK (v3.11.5 or later)
- Android Studio / VS Code
- An Android or iOS device with a camera

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/skanipay.git
   ```
2. Navigate to the project directory:
   ```bash
   cd skanipay
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Permissions

The app requires the following permissions:
- **Camera**: To scan numbers.
- **Photo Library**: To select images from the gallery.
- **Phone/Dialer**: To initiate USSD codes (Android).

## Development Notes

- Uses `google_mlkit_text_recognition` for high-accuracy OCR.
- Uses `image_picker` for camera and gallery access.
- Implements `url_launcher` for M-Pesa app and USSD integration.

---
*Developed for a Software Engineer.*
