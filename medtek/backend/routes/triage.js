const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

// POST /triage/save
router.post('/save', async (req, res) => {
    try {
        const { userId, report, conversation, userProfile } = req.body;

        if (!report || !conversation) {
            return res.status(400).json({ error: 'Missing report or conversation data' });
        }

        const timestamp = new Date().getTime();
        const safeUserId = userId ? String(userId).replace(/[^a-zA-Z0-9_-]/g, '') : 'anonymous';
        const filename = `triage_${safeUserId}_${timestamp}.json`;

        // Define path to save JSON in the uploads/triage_reports folder
        const directoryPath = path.join(__dirname, '..', 'uploads', 'triage_reports');
        const filePath = path.join(directoryPath, filename);

        // Ensure directory exists
        if (!fs.existsSync(directoryPath)) {
            fs.mkdirSync(directoryPath, { recursive: true });
        }

        // Structure the data to save
        const triageData = {
            metadata: {
                timestamp: new Date().toISOString(),
                userId: safeUserId,
                patientProfile: userProfile || {}
            },
            diagnosis_report: report,
            conversation_history: conversation
        };

        // Write file
        fs.writeFileSync(filePath, JSON.stringify(triageData, null, 2), 'utf8');

        // Note: For production you'd upload this to Cloudinary or AWS S3. 
        // For now, we save locally and return the path URL.
        const fileUrl = `/uploads/triage_reports/${filename}`;

        res.json({ success: true, fileUrl: fileUrl, filename: filename });

    } catch (error) {
        console.error('❌ Error saving triage JSON:', error);
        res.status(500).json({ error: 'Failed to save triage data' });
    }
});

module.exports = router;
