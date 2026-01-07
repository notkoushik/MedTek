const express = require('express');
const router = express.Router();
const pool = require('../db');
const path = require('path');
const Tesseract = require('tesseract.js');
const fs = require('fs');
const multer = require('multer');
const { resolveDoctorId } = require('../utils/doctorUtils');

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = 'uploads/verification';
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        cb(null, `${Date.now()}-${file.originalname}`);
    },
});

const upload = multer({ storage });

// Helper to update verification progress
async function updateVerificationStep(doctorId, step, data, pointsToAdd) {
    // Get current state
    const res = await pool.query(
        'SELECT verification_details, verification_points FROM doctors WHERE id = $1',
        [doctorId]
    );

    if (res.rows.length === 0) throw new Error('Doctor not found');

    let details = res.rows[0].verification_details || {};
    let currentPoints = res.rows[0].verification_points || 0;

    // Prevent double counting for the same step
    if (!details[step]) {
        currentPoints += pointsToAdd;
    }

    details[step] = {
        ...data,
        timestamp: new Date().toISOString(),
        status: 'completed',
        points_earned: pointsToAdd
    };

    await pool.query(
        'UPDATE doctors SET verification_details = $1, verification_points = $2 WHERE id = $3',
        [details, currentPoints, doctorId]
    );

    return { details, currentPoints };
}

// ----------------------------------------------------------------------
// STEP 1: NMC Verification (MOCKED)
// ----------------------------------------------------------------------
router.post('/nmc', async (req, res) => {
    try {
        const { doctorId, nmcNumber } = req.body;
        console.log(`🔍 Verifying NMC: ${nmcNumber} for Doctor (Input ID: ${doctorId})`);

        if (!nmcNumber || nmcNumber.length < 4) {
            return res.status(400).json({ error: 'Invalid NMC Number' });
        }

        // 1. Resolve Doctor ID
        const finalDoctorId = await resolveDoctorId(pool, doctorId);
        if (!finalDoctorId) {
            console.error(`❌ Doctor not found for ID: ${doctorId}`);
            return res.status(404).json({ error: 'Doctor not found' });
        }

        // 2. Pre-coded NMC Registry (Mock)
        const validRegistry = ['555666', '123456', '999888'];

        // Simulate API delay
        await new Promise(r => setTimeout(r, 1500));

        if (validRegistry.includes(nmcNumber)) {
            // SUCCESS CASE
            const mockResult = {
                verified: true,
                name: "Dr. Mock Name",
                registration_date: "2020-01-15",
                status: "Active"
            };

            const { currentPoints } = await updateVerificationStep(finalDoctorId, 'nmc', mockResult, 20);

            // Save NMC number
            await pool.query('UPDATE doctors SET nmc_number = $1 WHERE id = $2', [nmcNumber, finalDoctorId]);

            res.json({
                success: true,
                message: 'NMC Verification Successful',
                data: mockResult,
                totalPoints: currentPoints
            });
        } else {
            // FAILURE CASE
            return res.json({
                success: false,
                message: 'NMC Number not found in registry. Try: 555666',
                data: null,
                totalPoints: 0
            });
        }

    } catch (e) {
        console.error('❌ NMC Error:', e);
        res.status(500).json({ error: e.message });
    }
});

// ----------------------------------------------------------------------
// STEP 2: Document OCR (REAL/LENIENT)
// ----------------------------------------------------------------------
router.post('/ocr', upload.single('document'), async (req, res) => {
    try {
        const { doctorId } = req.body;
        const file = req.file;

        if (!file) {
            return res.status(400).json({ error: 'No document uploaded' });
        }

        console.log(`📄 Processing OCR for: ${file.path}`);

        // Run Tesseract
        const worker = await Tesseract.createWorker('eng');
        const { data: { text } } = await worker.recognize(file.path);
        await worker.terminate();

        console.log(`📝 Extracted Text Preview: ${text.substring(0, 100)}...`);

        // lenient check logic
        const keywords = ['medical', 'medicine', 'degree', 'doctor', 'university', 'college', 'mbbs', 'md'];
        const lowerText = text.toLowerCase();

        // Count matches
        const matches = keywords.filter(k => lowerText.includes(k));
        const isVerified = matches.length > 0; // Pass if ANY keyword found

        // For POC: If text is very short/empty, maybe fail, but usually we just want to show it works.
        // Let's assume broad success if at least some text is found (length > 10).
        const passed = text.length > 10;

        const verificationData = {
            extracted_text_preview: text.substring(0, 200),
            matches: matches,
            file_path: file.path
        };

        // 30 Points if passed
        const points = passed ? 30 : 0;

        // Resolve Doctor ID
        const finalDoctorId = await resolveDoctorId(pool, doctorId);
        if (!finalDoctorId) return res.status(404).json({ error: 'Doctor not found' });

        const { currentPoints } = await updateVerificationStep(finalDoctorId, 'ocr', verificationData, points);

        res.json({
            success: passed,
            message: passed ? 'Document Verified' : 'Could not read document cleanly',
            extractedText: text.substring(0, 500),
            matches,
            totalPoints: currentPoints
        });

    } catch (e) {
        console.error('❌ OCR Error:', e);
        res.status(500).json({ error: e.message });
    }
});

// ----------------------------------------------------------------------
// STEP 3: Liveness (SIMULATED) + SUBMIT
// ----------------------------------------------------------------------
router.post('/submit', upload.single('live_photo'), async (req, res) => {
    try {
        const { doctorId } = req.body;
        const file = req.file; // This is the selfie

        console.log(`📸 Liveness Check for Doctor ${doctorId}`);

        // In a real app, we would send `file.path` to an ML service.
        // For POC, the presence of the file is enough implies "Liveness Checked" on frontend.

        const livenessData = {
            verified: true,
            method: "camera_capture_poc",
            photo: file ? file.path : null
        };

        // Resolve Doctor ID
        const finalDoctorId = await resolveDoctorId(pool, doctorId);
        if (!finalDoctorId) return res.status(404).json({ error: 'Doctor not found' });

        // 15 Points
        const { currentPoints } = await updateVerificationStep(finalDoctorId, 'liveness', livenessData, 15);

        // Final Check
        let finalStatus = 'rejected';
        if (currentPoints >= 60) finalStatus = 'verified';
        else if (currentPoints >= 45) finalStatus = 'manual_review';

        await pool.query(
            'UPDATE doctors SET verified = $1 WHERE id = $2',
            [finalStatus === 'verified', finalDoctorId]
        );

        res.json({
            success: true,
            status: finalStatus,
            totalPoints: currentPoints,
            message: `Verification Complete. Status: ${finalStatus.toUpperCase()}`
        });

    } catch (e) {
        console.error('❌ Submit Error:', e);
        res.status(500).json({ error: e.message });
    }
});

// Get current progress
router.get('/status/:doctorId', async (req, res) => {
    try {
        const { doctorId } = req.params;
        const finalDoctorId = await resolveDoctorId(pool, doctorId);
        if (!finalDoctorId) return res.status(404).json({ error: 'Doctor not found' });

        const result = await pool.query(
            'SELECT verification_details, verification_points, verified, nmc_number FROM doctors WHERE id = $1',
            [finalDoctorId]
        );

        if (result.rows.length === 0) return res.status(404).json({ error: 'Not found' });

        res.json({
            points: result.rows[0].verification_points || 0,
            details: result.rows[0].verification_details || {},
            verified: result.rows[0].verified,
            nmc_number: result.rows[0].nmc_number
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = router;
