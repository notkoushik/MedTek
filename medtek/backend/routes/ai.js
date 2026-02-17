const express = require('express');
const router = express.Router();
const multer = require('multer');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Configure Multer (Memory Storage)
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// System instruction for the medical assistant (Chat)
const getChatSystemPrompt = (profile) => `
You are MedTek's AI Triage Assistant. 
You are speaking to a patient with the following profile:
- Name: ${profile.name || 'Patient'}
- Age: ${profile.age || 'Unknown'}
- Gender: ${profile.gender || 'Unknown'}
- Known Allergies: ${profile.allergies || 'None'}
- Chronic Conditions: ${profile.conditions || 'None'}

Your goal is to help them identify which medical specialist they should see based on their symptoms.
- context: Consider their age and conditions in your analysis (e.g., chest pain in a 60yo is different from a 20yo).
- tone: Be empathetic, professional, and concise (keep responses under 50 words).
- safety: DO NOT provide medical diagnoses. If emergency, advise calling help immediately.
- formatting: plain text only (no markdown).
`;

// System instruction for the Pharmacist Agent (Vision)
const PHARMACIST_PROMPT = `
Act as a senior clinical pharmacist. Analyze the provided image of a pill/medication.

YOUR TASK:
1. Identify the pill (Name, Dosage, Type) based on visual markings, shape, and color.
2. Check for interactions between the IDENTIFIED pill and the user's CURRENT MEDICATIONS (provided below).
3. Determine if it is safe for the user to take.

INPUT DATA:
- Image: [Provided Image]
- User's Current Meds: [CURRENT_MEDS_LIST]

OUTPUT FORMAT:
Return strictly valid JSON. Do not include markdown code blocks.
Structure:
{
  "pill_name": "Name of the pill (or 'Unknown' if unclear)",
  "confidence": 0.0 to 1.0 (float),
  "safe": boolean (true if no major interaction),
  "description": "Brief visual description of the pill",
  "interactions": [
    { 
      "drug1": "Identified Pill Name", 
      "drug2": "Conflicting Med Name", 
      "severity": "HIGH/MODERATE/LOW", 
      "description": "Brief explanation of the interaction",
      "mechanism": "Brief mechanism of action (e.g., 'Increases bleeding risk')" 
    }
  ],
  "message": "A short, patient-friendly summary (e.g., 'This looks like Aspirin. It is safe to take with your current meds.')"
}

CRITICAL RULES:
- If confidence is below 0.6, set "safe" to false and "message" to "I cannot clearly identify this pill. Please try again or consult a doctor."
- If "CURRENT_MEDS_LIST" is empty, assume no interactions.
- Always be conservative with safety. If unsure, mark as unsafe.
`;

// Helper: Retry function with exponential backoff
async function retryWithBackoff(fn, retries = 3, delay = 1000) {
    try {
        return await fn();
    } catch (error) {
        if (retries === 0 || (!error.message.includes('429') && !error.message.includes('503'))) {
            throw error;
        }
        console.log(`⚠️ Rate limit/Transient error. Retrying in ${delay}ms... (${retries} left)`);
        await new Promise(resolve => setTimeout(resolve, delay));
        return retryWithBackoff(fn, retries - 1, delay * 2);
    }
}

router.post('/chat', async (req, res) => {
    try {
        const { message, history, userProfile } = req.body;

        if (!process.env.GEMINI_API_KEY) {
            return res.status(500).json({ error: 'GEMINI_API_KEY is not configured in backend .env' });
        }

        // Use the correct model
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

        const chatHistory = (history || []).map(msg => ({
            role: msg.role === 'bot' ? 'model' : 'user',
            parts: [{ text: msg.message || msg.content || '' }]
        }));

        // Generate personalized system prompt
        const systemPrompt = getChatSystemPrompt(userProfile || {});

        const chat = model.startChat({
            history: [
                { role: 'user', parts: [{ text: systemPrompt }] },
                { role: 'model', parts: [{ text: `Understood. I have reviewed the profile for ${userProfile?.name || 'the patient'}. How can I help?` }] },
                ...chatHistory
            ],
        });

        // Wrap sendMessage with retry
        const result = await retryWithBackoff(async () => await chat.sendMessage(message));
        const response = await result.response;
        const text = response.text();

        res.json({ reply: text });

    } catch (error) {
        console.error('❌ Gemini AI Chat Error:', error);
        res.status(500).json({ error: 'Failed to generate response', details: error.message });
    }
});

// ✅ NEW: Vision Endpoint for Pill Identification
router.post('/identify-pill', upload.single('pill_image'), async (req, res) => {
    console.log('💊 /identify-pill called');
    try {
        // 1. Validate Input
        if (!req.file) {
            return res.status(400).json({ error: 'No image uploaded' });
        }
        if (!process.env.GEMINI_API_KEY) {
            return res.status(500).json({ error: 'GEMINI_API_KEY is not configured' });
        }

        const currentMeds = req.body.current_meds || '[]'; // Comes as string form-data
        console.log('   Stats:', { fileSize: req.file.size, currentMeds });

        // 2. Prepare Image for Gemini
        const imagePart = {
            inlineData: {
                data: req.file.buffer.toString('base64'),
                mimeType: req.file.mimetype,
            },
        };

        // 3. Prepare Prompt
        const currentMedsStr = Array.isArray(currentMeds) ? currentMeds.join(', ') : currentMeds;
        const prompt = PHARMACIST_PROMPT.replace('[CURRENT_MEDS_LIST]', currentMedsStr);

        // 4. Call Gemini Vision
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

        console.log('🤖 Sending to Gemini 2.5 Flash...');

        // Wrap generateContent with retry
        const result = await retryWithBackoff(async () => await model.generateContent([prompt, imagePart]));
        const response = await result.response;
        let text = response.text();

        // 5. Clean JSON
        console.log('📦 Raw Gemini Response (First 100 chars):', text.substring(0, 100));
        text = text.replace(/```json/g, '').replace(/```/g, '').trim();

        // 6. Parse & Return
        let jsonResponse;
        try {
            jsonResponse = JSON.parse(text);
        } catch (e) {
            console.error('❌ Failed to parse JSON:', text);
            return res.status(500).json({ error: 'AI returned invalid JSON', raw: text });
        }

        res.json(jsonResponse);

    } catch (error) {
        console.error('❌ Pill ID Error:', error);
        res.status(500).json({
            error: 'Failed to identify pill',
            details: error.message,
            success: false
        });
    }
});

module.exports = router;
