# EduTask Backend

This backend is a simple Node.js Express service to send OTP emails through Gmail and verify tokens.

## Setup

1. Install dependencies:

```bash
cd backend
npm install
```

2. Create a `.env` file based on `.env.example`.

3. Set your Google email credentials:

- `GMAIL_USER`: the Gmail address sending the OTP email
- `GMAIL_PASS`: the app password or SMTP password for your Google account

4. Start the server:

```bash
npm start
```

> If you are testing the Android app on a physical phone, the app cannot use `10.0.2.2`.
> Replace the backend host in `lib/services/auth_service.dart` with your PC's local IP address,
> for example `http://192.168.1.100:3000`, and make sure the phone and PC are on the same Wi-Fi network.

## API Endpoints

- `POST /api/send-otp`
  - Body: `{ email, name }`
  - Sends an OTP email and responds with success or failure.

- `POST /api/verify-otp`
  - Body: `{ email, code }`
  - Verifies the OTP and returns success or failure.

> If you use Google Workspace / Google Apps, use an app-specific password or configure SMTP access correctly.
