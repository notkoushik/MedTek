const express = require('express');
const router = express.Router();
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// System instruction for the medical assistant
const SYSTEM_PROMPT = `
You are MedTek's AI Triage Assistant. 
Your goal is to help patients identify which medical specialist they should see based on their symptoms.
- Ask 1-2 clarifying questions if the symptoms are vague.
- Be empathetic, professional, and concise (keep responses under 50 words for voice output).
- DO NOT provide medical diagnoses or prescriptions.
- If it sounds like an emergency, tell them to call emergency services immediately.
- formatting: plain text only (no markdown).
`;

router.post('/chat', async (req, res) => {
    try {
        const { message, history } = req.body;

        if (!process.env.GEMINI_API_KEY) {
            return res.status(500).json({ error: 'GEMINI_API_KEY is not configured in backend .env' });
        }

        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

        // Construct chat history for Gemini
        // Gemini expects: { role: 'user' | 'model', parts: [{ text: '...' }] }
        // Incoming history might be: [{ role: 'user', content: '...' }]

        const chatHistory = (history || []).map(msg => ({
            role: msg.role === 'bot' ? 'model' : 'user', // Map 'bot' to 'model'
            parts: [{ text: msg.message || msg.content || '' }]
        }));

        const chat = model.startChat({
            history: [
                { role: 'user', parts: [{ text: SYSTEM_PROMPT }] },
                { role: 'model', parts: [{ text: 'Understood. I am ready to assist as MedTek AI.' }] },
                ...chatHistory
            ],
        });

        // chat.sendMessage with Retry Logic (3 attempts)
        let retries = 3;
        let responseText = '';

        while (retries > 0) {
            try {
                const result = await chat.sendMessage(message);
                const response = await result.response;
                responseText = response.text();
                break; // Success
            } catch (err) {
                // If it's a 503 (Overloaded) or 429 (Rate Limit - maybe wait longer?), we wait and retry.
                // Note: 429 usually needs longer wait, but 503 is often transient.
                if (err.status === 503 || err.message.includes('503') || err.message.includes('overloaded')) {
                    console.warn(`⚠️ Gemini 503 Overloaded. Retrying... (${retries} left)`);
                    retries--;
                    if (retries === 0) throw err; // Give up
                    await new Promise(res => setTimeout(res, 2000)); // Wait 2s
                } else {
                    throw err; // Re-throw other errors immediately
                }
            }
        }

        res.json({ reply: responseText });

    } catch (error) {
        console.error('❌ Gemini AI Error:', error);
        res.status(500).json({ error: 'Failed to generate response', details: error.message });
    }
});

module.exports = router;
