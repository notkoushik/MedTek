// routes/password-reset.js
const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// Generate random 6-digit OTP
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// POST /password-reset/request - Request password reset
router.post('/request', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    // Check if user exists
    const userResult = await pool.query(
      'SELECT id, email, name FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (userResult.rows.length === 0) {
      // Don't reveal if email exists or not (security best practice)
      return res.json({
        success: true,
        message: 'If an account exists with this email, a reset code has been sent.'
      });
    }

    const user = userResult.rows[0];

    // Generate OTP token
    const token = generateOTP();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    // Invalidate any existing tokens for this user
    await pool.query(
      'UPDATE password_reset_tokens SET used = TRUE WHERE user_id = $1 AND used = FALSE',
      [user.id]
    );

    // Insert new reset token
    await pool.query(
      `INSERT INTO password_reset_tokens (user_id, email, token, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [user.id, user.email, token, expiresAt]
    );

    console.log(`🔐 Password reset requested for: ${user.email}`);
    console.log(`🔑 Reset OTP: ${token} (expires in 15 minutes)`);

    // TODO: Send email with OTP
    // For now, we'll just log it (you can integrate email service later)
    console.log(`📧 Email would be sent to: ${user.email}`);
    console.log(`📧 Reset code: ${token}`);

    res.json({
      success: true,
      message: 'If an account exists with this email, a reset code has been sent.',
      // For development only - remove in production!
      dev_token: process.env.NODE_ENV === 'development' ? token : undefined
    });
  } catch (e) {
    console.error('Password reset request error:', e);
    res.status(500).json({ error: 'Failed to process reset request' });
  }
});

// POST /password-reset/verify - Verify OTP
router.post('/verify', async (req, res) => {
  try {
    const { email, token } = req.body;

    if (!email || !token) {
      return res.status(400).json({ error: 'Email and token are required' });
    }

    // Find valid token
    const result = await pool.query(
      `SELECT * FROM password_reset_tokens 
       WHERE email = $1 AND token = $2 AND used = FALSE AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [email.toLowerCase(), token]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ 
        error: 'Invalid or expired reset code' 
      });
    }

    console.log(`✅ Valid reset token verified for: ${email}`);

    res.json({
      success: true,
      message: 'Reset code verified successfully'
    });
  } catch (e) {
    console.error('Verify token error:', e);
    res.status(500).json({ error: 'Failed to verify token' });
  }
});

// POST /password-reset/reset - Reset password with token
router.post('/reset', async (req, res) => {
  try {
    const { email, token, newPassword } = req.body;

    if (!email || !token || !newPassword) {
      return res.status(400).json({ 
        error: 'Email, token, and new password are required' 
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ 
        error: 'Password must be at least 6 characters' 
      });
    }

    // Find valid token
    const tokenResult = await pool.query(
      `SELECT user_id FROM password_reset_tokens 
       WHERE email = $1 AND token = $2 AND used = FALSE AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [email.toLowerCase(), token]
    );

    if (tokenResult.rows.length === 0) {
      return res.status(400).json({ 
        error: 'Invalid or expired reset code' 
      });
    }

    const userId = tokenResult.rows[0].user_id;

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // ✅ FIXED: Update password_hash (not password)
    await pool.query(
      'UPDATE users SET password_hash = $1 WHERE id = $2',
      [hashedPassword, userId]
    );

    // Mark token as used
    await pool.query(
      'UPDATE password_reset_tokens SET used = TRUE WHERE email = $1 AND token = $2',
      [email.toLowerCase(), token]
    );

    console.log(`✅ Password reset successfully for user: ${userId}`);

    res.json({
      success: true,
      message: 'Password reset successfully'
    });
  } catch (e) {
    console.error('Password reset error:', e);
    res.status(500).json({ error: 'Failed to reset password' });
  }
});

module.exports = router;
