// middleware/auth.js
const jwt = require('jsonwebtoken');

function auth(req, res, next) {
  const header = req.headers.authorization;
  
  if (!header) {
    console.error('❌ Missing Authorization header');
    return res.status(401).json({ error: 'Missing Authorization header' });
  }

  const parts = header.split(' ');
  
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    console.error('❌ Invalid Authorization header format');
    return res.status(401).json({ error: 'Invalid Authorization header' });
  }

  const token = parts[1];

  if (!token) {
    console.error('❌ No token provided');
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || 'dev-secret'
    );
    
    req.user = decoded;
    console.log(`✅ Auth successful: User ${decoded.id} (${decoded.role})`);
    next();
  } catch (e) {
    console.error('❌ JWT verification error:', e.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = auth;
