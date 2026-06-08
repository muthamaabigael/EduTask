const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '.env') });

const app = express();
const port = process.env.PORT || 3000;
const dataDir = path.join(__dirname, 'data');
const dbFile = path.join(dataDir, 'edutask-db.json');

if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

function normalizeEmail(value) {
  return value?.toString().trim().toLowerCase();
}

function loadDb() {
  if (!fs.existsSync(dbFile)) {
    return { users: [], pending: [], resets: [] };
  }

  try {
    const json = fs.readFileSync(dbFile, 'utf8');
    const data = JSON.parse(json);
    return {
      users: Array.isArray(data.users) ? data.users : [],
      pending: Array.isArray(data.pending) ? data.pending : [],
      resets: Array.isArray(data.resets) ? data.resets : [],
    };
  } catch (error) {
    console.error('Unable to load database file', error);
    return { users: [], pending: [], resets: [] };
  }
}

function saveDb(db) {
  fs.writeFileSync(dbFile, JSON.stringify(db, null, 2), 'utf8');
}

function cleanExpiredPending(db) {
  const now = Date.now();
  db.pending = db.pending.filter((record) => record.expiresAt > now);
}

function cleanExpiredResets(db) {
  const now = Date.now();
  db.resets = db.resets.filter((record) => record.expiresAt > now);
}

function createTransporter() {
  const authUser = process.env.MAIL_USER;
  const authPass = process.env.MAIL_PASS;
  const host = process.env.MAIL_HOST || 'smtp.gmail.com';
  const portNumber = parseInt(process.env.MAIL_PORT || '465', 10);
  const secure = process.env.MAIL_SECURE !== 'false';

  if (!authUser || !authPass) {
    throw new Error('MAIL_USER and MAIL_PASS must be set in .env');
  }

  return nodemailer.createTransport({
    host,
    port: portNumber,
    secure,
    auth: {
      user: authUser,
      pass: authPass,
    },
  });
}

function sendEmail(options) {
  const transporter = createTransporter();
  return transporter.sendMail(options);
}

function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function formatName(firstName, lastName) {
  const parts = [];
  if (firstName) parts.push(firstName.toString().trim());
  if (lastName) parts.push(lastName.toString().trim());
  return parts.join(' ');
}

app.use(cors());
app.use(express.json());

app.post('/api/send-otp', async (req, res) => {
  const { email, firstName, lastName, password, dob } = req.body;
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedEmail || !firstName || !lastName || !password || !dob) {
    return res.status(400).json({ success: false, message: 'First name, second name, email, password, and date of birth are required.' });
  }

  if (typeof password !== 'string' || password.length < 8) {
    return res.status(400).json({ success: false, message: 'Password must be at least 8 characters long.' });
  }

  const db = loadDb();
  cleanExpiredPending(db);

  const existingUser = db.users.find((user) => user.email === normalizedEmail);
  if (existingUser) {
    return res.status(409).json({ success: false, message: 'An account with this email already exists.' });
  }

  const otp = generateOtp();
  const otpHash = await bcrypt.hash(otp, 10);
  const passwordHash = await bcrypt.hash(password, 10);
  const expiresAt = Date.now() + 10 * 60 * 1000;

  const pendingRecord = {
    email: normalizedEmail,
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    passwordHash,
    dob,
    otpHash,
    expiresAt,
    createdAt: Date.now(),
  };

  db.pending = db.pending.filter((record) => record.email !== normalizedEmail);
  db.pending.push(pendingRecord);
  saveDb(db);

  const userName = formatName(firstName, lastName);
  const mailFrom = process.env.MAIL_FROM || process.env.MAIL_USER;
  const mailOptions = {
    from: mailFrom,
    to: normalizedEmail,
    subject: 'Your EduTask OTP Code',
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.5;">
        <h2 style="color:#1D4ED8;">Verify your email</h2>
        <p>Hi ${userName},</p>
        <p>Use the code below to complete your EduTask registration:</p>
        <div style="font-size: 28px; font-weight: 700; color:#1D4ED8; letter-spacing: 6px;">
          ${otp}
        </div>
        <p>This code expires in 10 minutes.</p>
      </div>
    `,
  };

  try {
    await sendEmail(mailOptions);
    return res.json({ success: true, message: 'OTP sent' });
  } catch (error) {
    console.error('Failed to send email', error);
    db.pending = db.pending.filter((record) => record.email !== normalizedEmail);
    saveDb(db);
    return res.status(500).json({ success: false, message: 'Unable to send OTP email.' });
  }
});

app.post('/api/verify-otp', async (req, res) => {
  const { email, code } = req.body;
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedEmail || !code) {
    return res.status(400).json({ success: false, message: 'Email and OTP code are required.' });
  }

  const db = loadDb();
  cleanExpiredPending(db);

  const pendingRecord = db.pending.find((record) => record.email === normalizedEmail);
  if (!pendingRecord) {
    return res.status(404).json({ success: false, message: 'OTP not found for this email.' });
  }

  if (Date.now() > pendingRecord.expiresAt) {
    db.pending = db.pending.filter((record) => record.email !== normalizedEmail);
    saveDb(db);
    return res.status(410).json({ success: false, message: 'OTP has expired.' });
  }

  const isValid = await bcrypt.compare(code.toString(), pendingRecord.otpHash);
  if (!isValid) {
    return res.status(401).json({ success: false, message: 'Incorrect OTP code.' });
  }

  const newUser = {
    email: normalizedEmail,
    firstName: pendingRecord.firstName,
    lastName: pendingRecord.lastName,
    passwordHash: pendingRecord.passwordHash,
    dob: pendingRecord.dob,
    phoneNumber: pendingRecord.phoneNumber || '',
    registeredAt: new Date().toISOString(),
  };

  db.users = db.users.filter((user) => user.email !== normalizedEmail);
  db.users.push(newUser);
  db.pending = db.pending.filter((record) => record.email !== normalizedEmail);
  saveDb(db);

  return res.json({ success: true, message: 'OTP verified successfully.' });
});

app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedEmail || !password) {
    return res.status(400).json({ success: false, message: 'Email and password are required.' });
  }

  const db = loadDb();
  const user = db.users.find((user) => user.email === normalizedEmail);

  if (!user) {
    return res.status(401).json({ success: false, message: 'Invalid email or password.' });
  }

  const isValidPassword = await bcrypt.compare(password, user.passwordHash);
  if (!isValidPassword) {
    return res.status(401).json({ success: false, message: 'Invalid email or password.' });
  }

  return res.json({
    success: true,
    message: 'Login successful.',
    user: {
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      dob: user.dob,
      phoneNumber: user.phoneNumber || '',
      registeredAt: user.registeredAt,
    },
  });
});

app.post('/api/update-profile', async (req, res) => {
  const { email, firstName, lastName, phoneNumber } = req.body;
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedEmail || !firstName || !lastName) {
    return res.status(400).json({ success: false, message: 'Email, first name, and last name are required.' });
  }

  const db = loadDb();
  const user = db.users.find((record) => record.email === normalizedEmail);
  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found.' });
  }

  user.firstName = firstName.trim();
  user.lastName = lastName.trim();
  user.phoneNumber = phoneNumber?.toString().trim() ?? '';
  saveDb(db);

  return res.json({
    success: true,
    message: 'Profile updated successfully.',
    user: {
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      dob: user.dob,
      phoneNumber: user.phoneNumber || '',
      registeredAt: user.registeredAt,
    },
  });
});

app.post('/api/password-reset-request', async (req, res) => {
  const { email } = req.body;
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedEmail) {
    return res.status(400).json({ success: false, message: 'Email is required.' });
  }

  const db = loadDb();
  cleanExpiredResets(db);

  const user = db.users.find((user) => user.email === normalizedEmail);
  const otp = generateOtp();
  const otpHash = await bcrypt.hash(otp, 10);
  const expiresAt = Date.now() + 10 * 60 * 1000;

  db.resets = db.resets.filter((record) => record.email !== normalizedEmail);
  db.resets.push({ email: normalizedEmail, otpHash, expiresAt, createdAt: Date.now() });
  saveDb(db);

  const userName = user ? formatName(user.firstName, user.lastName) : 'EduTask user';
  const mailOptions = {
    from: process.env.MAIL_FROM || process.env.MAIL_USER,
    to: normalizedEmail,
    subject: 'EduTask Password Reset',
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.5;">
        <h2 style="color:#1D4ED8;">Password Reset Request</h2>
        <p>Hi ${userName},</p>
        <p>Use the code below to reset your EduTask password:</p>
        <div style="font-size: 28px; font-weight: 700; color:#1D4ED8; letter-spacing: 6px;">
          ${otp}
        </div>
        <p>This code expires in 10 minutes.</p>
      </div>
    `,
  };

  try {
    await sendEmail(mailOptions);
    return res.json({ success: true, message: 'Password reset OTP sent to your email.' });
  } catch (error) {
    console.error('Failed to send password reset email', error);
    db.resets = db.resets.filter((record) => record.email !== normalizedEmail);
    saveDb(db);
    return res.status(500).json({ success: false, message: 'Unable to send password reset email.' });
  }
});

app.post('/api/password-reset-confirm', async (req, res) => {
  const { email, code, password } = req.body;
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedEmail || !code || !password) {
    return res.status(400).json({ success: false, message: 'Email, OTP code, and new password are required.' });
  }

  if (typeof password !== 'string' || password.length < 8) {
    return res.status(400).json({ success: false, message: 'New password must be at least 8 characters long.' });
  }

  const db = loadDb();
  cleanExpiredResets(db);

  const resetRecord = db.resets.find((record) => record.email === normalizedEmail);
  if (!resetRecord) {
    return res.status(404).json({ success: false, message: 'Password reset request not found or expired.' });
  }

  const isValid = await bcrypt.compare(code.toString(), resetRecord.otpHash);
  if (!isValid) {
    return res.status(401).json({ success: false, message: 'Incorrect password reset code.' });
  }

  const user = db.users.find((user) => user.email === normalizedEmail);
  if (!user) {
    return res.status(404).json({ success: false, message: 'No account found for this email.' });
  }

  user.passwordHash = await bcrypt.hash(password, 10);
  db.resets = db.resets.filter((record) => record.email !== normalizedEmail);
  saveDb(db);

  return res.json({ success: true, message: 'Password has been reset successfully.' });
});

app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'EduTask backend is alive.' });
});

app.listen(port, () => {
  console.log(`EduTask backend running on http://localhost:${port}`);
});
