# MedTek Deployment Guide

## System Requirements
*   **OS:** Ubuntu 20.04 / 22.04 LTS (Recommended) or Windows Server
*   **Runtime:** Node.js v18.x or v20.x
*   **Database:** PostgreSQL 14+ 
    *   *Note: Application supports SSL connections for cloud databases.*
*   **Process Manager:**  PM2 (Recommended for production)

## 1. Environment Variables
Create a file named `.env` in the `backend/` directory with the following values.  
**Use the provided `.env.example` as a template.**

| Variable | Description | Example |
| :--- | :--- | :--- |
| `PORT` | Port to run the API on | `4000` |
| `DATABASE_URL` | Full PostgreSQL connection string | `postgres://user:pass@host:5432/db_name?sslmode=require` |
| `DB_SSL` | Set to 'true' if DB requires SSL | `true` |
| `JWT_SECRET` | Strong secret for signing tokens | `super-secure-random-string-must-be-long` |
| `GEMINI_API_KEY` | Key for AI features | `AIzaSy...` |

## 2. Installation & Setup

1.  **Extract Code:** Upload the `medtek/backend` folder to the server.
2.  **Install Dependencies:**
    ```bash
    cd medtek/backend
    npm install --production
    ```
    *Note: This will install `helmet` and `rate-limit` which are now required.*

3.  **Validate Database Schema:**
    Before starting the app, run the schema check script to ensure the provided database has the correct tables.
    ```bash
    node scripts/check_schema.js
    ```
    *   **If this fails:** You are missing tables. Request the database administrator to run the schema creation SQL (located in `scripts/Sql.sql`).
    *   **If this passes:** Proceed to start.

## 3. Starting the Application (Production)

Use **PM2** to keep the application running in the background.

```bash
# Install PM2 globally if not installed
npm install -g pm2

# Start the application
pm2 start index.js --name "medtek-api"

# Save process list to restart on reboot
pm2 save
pm2 startup
```

## 4. Maintenance / scripts
All maintenance scripts have been moved to the `backend/scripts/` directory.
*   `check_schema.js`: Validates DB tables.
*   `Sql.sql`: Reference schema definition.
